extends SceneTree

const NetworkSessionScript = preload("res://scripts/network_session.gd")
const TEST_PORT: int = 27871
const WORLD_ID: String = "0123456789abcdef0123456789abcdef"

var host: NetworkSession
var guest: NetworkSession
var observer: NetworkSession
var guest_damage: Array[float] = []
var observer_damage: Array[float] = []
var host_damage: Array[float] = []
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
	observer = _session("Observer")
	guest.npc_damage_received.connect(func(damage: float) -> void: guest_damage.append(damage))
	observer.npc_damage_received.connect(func(damage: float) -> void: observer_damage.append(damage))
	host.npc_damage_received.connect(func(damage: float) -> void: host_damage.append(damage))
	if not _check(host.host(TEST_PORT).is_empty(), "host setup") or not _check(guest.join("127.0.0.1", TEST_PORT).is_empty(), "guest setup") or not _check(observer.join("127.0.0.1", TEST_PORT).is_empty(), "observer setup"):
		await _cleanup(1)
		return
	if not await _wait_until(func() -> bool: return guest.connected and observer.connected and host.presence.size() == 3, 3.0):
		_check(false, "both visitors admitted")
		await _cleanup(1)
		return
	var guest_id: int = guest.multiplayer.get_unique_id()
	var observer_id: int = observer.multiplayer.get_unique_id()
	await _publish_pose(guest, true)
	if not _check(host.is_visitor_flying(guest_id) and not host.is_visitor_flying(1) and not host.is_visitor_flying(999999),
		"only fresh flying admitted visitors qualify"):
		await _cleanup(1)
		return
	# The visitor does not need PvP consent for an NPC hit.
	if not _check(not host.presence[guest_id].pvp and host.presence[guest_id].systems_online, "visitor starts without PvP consent"):
		await _cleanup(1)
		return
	host.send_npc_damage(guest_id, 42.5)
	if not await _wait_until(func() -> bool: return guest_damage.size() == 1, 2.0):
		_check(false, "host damage reaches its visitor target")
		await _cleanup(1)
		return
	if not _check(is_equal_approx(guest_damage[0], 42.5) and observer_damage.is_empty() and host_damage.is_empty(),
		"damage is target-only"):
		await _cleanup(1)
		return

	# Clients cannot invoke the authority-only damage RPC, and stale authority data is ignored.
	guest._rpc_npc_damage.rpc_id(1, 99.0, guest._pvp_epoch)
	host._rpc_npc_damage.rpc_id(guest_id, 17.0, guest._pvp_epoch + 1)
	await create_timer(0.12).timeout
	if not _check(guest_damage.size() == 1 and observer_damage.is_empty() and host_damage.is_empty(), "forged and stale damage are rejected"):
		await _cleanup(1)
		return

	for invalid: float in [0.0, -1.0, NAN, INF, 1000000.1]: host.send_npc_damage(guest_id, invalid)
	host.send_npc_damage(observer_id, 15.0)
	await create_timer(0.12).timeout
	if not _check(guest_damage.size() == 1 and observer_damage.is_empty(), "invalid damage and grounded target are rejected"):
		await _cleanup(1)
		return

	await _publish_pose(guest, false)
	if not _check(not host.is_visitor_flying(guest_id), "grounded visitor cannot be hit"):
		await _cleanup(1)
		return
	host.send_npc_damage(guest_id, 10.0)
	await create_timer(0.1).timeout
	if not _check(guest_damage.size() == 1, "grounded visitor receives no damage"):
		await _cleanup(1)
		return

	await _publish_pose(guest, true)
	host._last_remote_pose_msec[guest_id] = Time.get_ticks_msec() - 1001
	if not _check(not host.is_visitor_flying(guest_id), "stale pose is not considered flying"):
		await _cleanup(1)
		return
	host.send_npc_damage(guest_id, 10.0)
	await create_timer(0.1).timeout
	if not _check(guest_damage.size() == 1, "stale visitor pose receives no damage"):
		await _cleanup(1)
		return

	await _publish_pose(guest, true)
	guest.set_systems_online(false)
	if not await _wait_until(func() -> bool: return not host.presence[guest_id].systems_online, 2.0):
		_check(false, "offline state reaches host")
		await _cleanup(1)
		return
	if not _check(host.is_visitor_flying(guest_id), "offline but flying visitor remains hittable"):
		await _cleanup(1)
		return
	host.send_npc_damage(guest_id, 7.0)
	if not await _wait_until(func() -> bool: return guest_damage.size() == 2, 2.0):
		_check(false, "offline flying visitor receives NPC damage")
		await _cleanup(1)
		return
	if not _check(is_equal_approx(guest_damage[1], 7.0) and observer_damage.is_empty(), "offline NPC damage remains target-only"):
		await _cleanup(1)
		return

	guest.leave()
	observer.leave()
	host.leave()
	print("NPC_DAMAGE_PROTOCOL_OK: fresh visitor eligibility, authority, epochs, bounded damage and target-only offline hits")
	await _cleanup(0)


func _publish_pose(session: NetworkSession, flying: bool) -> void:
	for _step in 3:
		session.publish_pose(Vector3(0, 0, -100), Vector3.ZERO, {}, flying)
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
	push_error("NPC_DAMAGE_PROTOCOL_FAIL: " + message)
	return false


func _cleanup(exit_code: int) -> void:
	if guest != null: guest.leave()
	if observer != null: observer.leave()
	if host != null: host.leave()
	await create_timer(0.05).timeout
	quit(exit_code)
