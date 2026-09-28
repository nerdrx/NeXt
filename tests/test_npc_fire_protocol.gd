extends SceneTree

const NetworkSessionScript = preload("res://scripts/network_session.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const TEST_PORT: int = 27868
const WORLD_ID: String = "0123456789abcdef0123456789abcdef"

var host: NetworkSession
var guest: NetworkSession
var observer: NetworkSession
var shots: Array[Dictionary] = []
var guest_results: Array[Dictionary] = []
var observer_results: int = 0
var host_results: int = 0
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
	session.ship_modules = [
		{"kind": "core", "x": 0, "y": 0, "z": 0},
		{"kind": "weapon", "x": 1, "y": 0, "z": 0}
	]
	scope.add_child(session)
	return session


func _run() -> void:
	host = _session("Host")
	guest = _session("Guest")
	observer = _session("Observer")
	host.npc_shot_requested.connect(func(attacker: int, direction: Vector3, damage: float) -> void:
		shots.append({"attacker": attacker, "direction": direction, "damage": damage}))
	host.npc_hit_received.connect(func(_faction: String, _killed: bool, _assault: bool) -> void: host_results += 1)
	guest.npc_hit_received.connect(func(faction: String, killed: bool, assault: bool) -> void:
		guest_results.append({"faction": faction, "killed": killed, "assault": assault}))
	observer.npc_hit_received.connect(func(_faction: String, _killed: bool, _assault: bool) -> void: observer_results += 1)
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
	if not _check(host.presence[guest_id].flying and not host.presence[guest_id].pvp, "fresh flying visitor does not require PvP consent"):
		await _cleanup(1)
		return
	var expected_state: GameState = GameStateScript.new()
	expected_state.ship_modules.assign(guest.ship_modules)
	var expected_damage: float = float(expected_state.ship_stats().damage)
	guest.request_npc_shot(Vector3(0, 0, -4))
	guest.request_npc_shot(Vector3(0, 0, -4))
	if not await _wait_until(func() -> bool: return shots.size() >= 1, 2.0):
		_check(false, "valid remote NPC shot reaches host")
		await _cleanup(1)
		return
	await create_timer(0.22).timeout
	if not _check(shots.size() == 1 and shots[0].attacker == guest_id and shots[0].direction.is_equal_approx(Vector3.FORWARD) and is_equal_approx(shots[0].damage, expected_damage),
		"host derives attacker and weapon damage and enforces cooldown"):
		await _cleanup(1)
		return
	# Invalid directions, stale epochs and a grounded profile cannot produce shots.
	guest._rpc_npc_shot.rpc_id(1, Vector3.ZERO, guest._pvp_epoch)
	guest._rpc_npc_shot.rpc_id(1, Vector3.FORWARD, guest._pvp_epoch + 1)
	await _publish_pose(guest, false)
	guest._rpc_npc_shot.rpc_id(1, Vector3.FORWARD, guest._pvp_epoch)
	await create_timer(0.1).timeout
	if not _check(shots.size() == 1, "invalid, stale and grounded requests are rejected"):
		await _cleanup(1)
		return
	await _publish_pose(guest, true)
	host._last_remote_pose_msec[guest_id] = Time.get_ticks_msec() - 1001
	guest._rpc_npc_shot.rpc_id(1, Vector3.FORWARD, guest._pvp_epoch)
	await create_timer(0.1).timeout
	if not _check(shots.size() == 1, "stale pose cannot authorize visitor fire"):
		await _cleanup(1)
		return
	await _publish_pose(guest, true)
	guest.set_systems_online(false)
	await create_timer(0.1).timeout
	guest.request_npc_shot(Vector3.FORWARD)
	guest._rpc_npc_shot.rpc_id(1, Vector3.FORWARD, guest._pvp_epoch)
	await create_timer(0.1).timeout
	if not _check(shots.size() == 1 and not host.presence[guest_id].systems_online, "offline guest API and forged raw RPC are rejected"):
		await _cleanup(1)
		return
	guest.set_systems_online(true)
	await _publish_pose(guest, true)
	guest.request_npc_shot(Vector3.FORWARD)
	if not await _wait_until(func() -> bool: return shots.size() == 2, 2.0):
		_check(false, "cooldown allows a later fresh shot")
		await _cleanup(1)
		return

	# The host resolves NPC rewards to the shooter only; malformed confirmations are ignored.
	host.confirm_npc_hit(guest_id, "civilian", true, false)
	host.confirm_npc_hit(guest_id, "pirate", false, true)
	host.confirm_npc_hit(999999, "police", false, false)
	host._rpc_npc_hit_confirmed.rpc_id(guest_id, "pirate", true, false, guest._pvp_epoch + 1)
	await create_timer(0.1).timeout
	if not _check(guest_results.is_empty() and observer_results == 0 and host_results == 0, "invalid or stale hit results are ignored"):
		await _cleanup(1)
		return
	host.confirm_npc_hit(guest_id, "pirate", true, false)
	host.confirm_npc_hit(guest_id, "police", false, true)
	if not await _wait_until(func() -> bool: return guest_results.size() == 2, 2.0):
		_check(false, "valid hit rewards reach shooter")
		await _cleanup(1)
		return
	if not _check(guest_results[0] == {"faction": "pirate", "killed": true, "assault": false} and guest_results[1] == {"faction": "police", "killed": false, "assault": true}
		and observer_results == 0 and host_results == 0, "hit result is target-only and preserves reward flags"):
		await _cleanup(1)
		return

	# Travel resets shot cooldown and epoch, disconnect discards the visitor's limiter.
	if not _check(host.travel(18).is_empty(), "host travel succeeds"):
		await _cleanup(1)
		return
	if not await _wait_until(func() -> bool: return guest._pvp_epoch == host._pvp_epoch and observer._pvp_epoch == host._pvp_epoch, 2.0):
		_check(false, "visitors receive the new epoch")
		await _cleanup(1)
		return
	if not _check(host._last_npc_shot_msec.is_empty(), "travel clears shot cooldowns"):
		await _cleanup(1)
		return
	guest.set_systems_online(true)
	await _publish_pose(guest, true)
	guest.request_npc_shot(Vector3.FORWARD)
	if not await _wait_until(func() -> bool: return shots.size() == 3, 2.0):
		_check(false, "new-epoch shot is accepted")
		await _cleanup(1)
		return
	guest.leave()
	if not await _wait_until(func() -> bool: return not host.presence.has(guest_id), 2.0):
		_check(false, "disconnected guest removed")
		await _cleanup(1)
		return
	if not _check(not host._last_npc_shot_msec.has(guest_id), "disconnect clears that visitor cooldown"):
		await _cleanup(1)
		return
	observer.leave()
	host.leave()
	print("NPC_FIRE_PROTOCOL_OK: visitor authorization, damage, cooldown, epoch, power, freshness and target-only results")
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
	push_error("NPC_FIRE_PROTOCOL_FAIL: " + message)
	return false


func _cleanup(exit_code: int) -> void:
	if guest != null: guest.leave()
	if observer != null: observer.leave()
	if host != null: host.leave()
	await create_timer(0.05).timeout
	quit(exit_code)
