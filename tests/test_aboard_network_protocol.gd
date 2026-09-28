extends SceneTree

const NetworkSessionScript = preload("res://scripts/network_session.gd")
const TEST_PORT: int = 27872
const WORLD_ID: String = "0123456789abcdef0123456789abcdef"

var host: NetworkSession
var guest: NetworkSession
var damage_events: Array[float] = []
var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _session(scope_name: String) -> NetworkSession:
	var scope := Node.new()
	scope.name = scope_name
	root.add_child(scope)
	set_multiplayer(MultiplayerAPI.create_default_interface(), scope.get_path())
	var session: NetworkSession = NetworkSessionScript.new()
	session.name = "Session"
	session.world_id = WORLD_ID
	scope.add_child(session)
	return session


func _run() -> void:
	host = _session("Host")
	guest = _session("Guest")
	guest.npc_damage_received.connect(func(damage: float) -> void: damage_events.append(damage))
	if not _check(host.host(TEST_PORT).is_empty(), "host setup") or not _check(guest.join("127.0.0.1", TEST_PORT).is_empty(), "guest setup"):
		await _cleanup(1)
		return
	if not await _wait_until(func() -> bool: return guest.connected and host.presence.size() == 2, 3.0):
		_check(false, "guest admission")
		await _cleanup(1)
		return
	var guest_id: int = guest.multiplayer.get_unique_id()
	var origin := SectorPosition.new(Vector3i(2, -1, 4), Vector3(1200, -340, 900))
	var coasting_position := Vector3(4200, 2250, -1800)
	var coasting_rotation := Vector3(0.31, 1.27, -0.08)
	var expected_address := origin.clone()
	if not _check(expected_address.move_delta(coasting_position), "coasting address is representable"):
		await _cleanup(1)
		return
	await _publish_coasting_pose(guest, coasting_position, coasting_rotation, origin.to_save(), true)
	if not await _wait_until(func() -> bool: return host.presence.get(guest_id, {}).get("flying", false) and host.presence[guest_id].get("position", Vector3.ZERO) == coasting_position, 2.0):
		_check(false, "host receives aboard coasting hull pose as flying")
		await _cleanup(1)
		return
	var profile: Dictionary = host.presence[guest_id]
	if not _check(profile.rotation.is_equal_approx(coasting_rotation) and profile.address == expected_address.to_save()
		and host.is_visitor_flying(guest_id) and guest._local_flying,
		"coasting transform and absolute address round-trip with flying eligibility"):
		await _cleanup(1)
		return
	host.send_npc_damage(guest_id, 11.0)
	if not await _wait_until(func() -> bool: return damage_events.size() == 1, 2.0):
		_check(false, "flying occupied hull accepts exterior NPC damage")
		await _cleanup(1)
		return

	await _publish_coasting_pose(guest, coasting_position, coasting_rotation, origin.to_save(), false)
	if not await _wait_until(func() -> bool: return not host.presence[guest_id].flying, 2.0):
		_check(false, "grounded pose revokes remote flying state")
		await _cleanup(1)
		return
	if not _check(not host.is_visitor_flying(guest_id) and not guest._local_flying, "grounded visitor loses damage eligibility"):
		await _cleanup(1)
		return
	host.send_npc_damage(guest_id, 12.0)
	host._rpc_npc_damage.rpc_id(guest_id, 13.0, guest._pvp_epoch)
	await create_timer(0.12).timeout
	if not _check(damage_events.size() == 1, "grounded visitor rejects both host API and stale-target hit"):
		await _cleanup(1)
		return

	if not _check(host.travel(23).is_empty(), "host travel succeeds"):
		await _cleanup(1)
		return
	if not await _wait_until(func() -> bool: return guest._pvp_epoch == host._pvp_epoch, 2.0):
		_check(false, "guest receives travel epoch")
		await _cleanup(1)
		return
	if not _check(not guest._local_flying and not host.presence[guest_id].flying and not host.is_visitor_flying(guest_id),
		"travel resets flying eligibility on both ends"):
		await _cleanup(1)
		return
	await _publish_coasting_pose(guest, coasting_position, coasting_rotation, origin.to_save(), true)
	if not await _wait_until(func() -> bool: return host.is_visitor_flying(guest_id), 2.0):
		_check(false, "post-travel coasting pose restores eligibility")
		await _cleanup(1)
		return
	host.send_npc_damage(guest_id, 14.0)
	if not await _wait_until(func() -> bool: return damage_events.size() == 2, 2.0):
		_check(false, "post-travel visitor damage reaches the ship")
		await _cleanup(1)
		return

	guest.leave()
	host.leave()
	print("ABOARD_NETWORK_PROTOCOL_OK: hull pose round-trip, exterior damage, grounded revoke and travel reset")
	await _cleanup(0)


func _publish_coasting_pose(session: NetworkSession, position: Vector3, rotation: Vector3, origin: Dictionary, flying: bool) -> void:
	for _step in 3:
		session.publish_pose(position, rotation, origin, flying)
		await create_timer(0.06).timeout


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if condition.call(): return true
		await create_timer(0.01).timeout
		elapsed += 0.01
	return condition.call()


func _check(condition: bool, message: String) -> bool:
	if condition: return true
	failed = true
	push_error("ABOARD_NETWORK_PROTOCOL_FAIL: " + message)
	return false


func _cleanup(exit_code: int) -> void:
	if guest != null: guest.leave()
	if host != null: host.leave()
	await create_timer(0.05).timeout
	quit(exit_code)
