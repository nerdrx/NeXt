extends SceneTree

const NetworkSessionScript = preload("res://scripts/network_session.gd")
const TEST_PORT: int = 27867
const WORLD_ID: String = "0123456789abcdef0123456789abcdef"

var host: NetworkSession
var guest: NetworkSession
var snapshots: Array = []
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
	guest.npc_ships_received.connect(func(records: Array) -> void: snapshots.append(records.duplicate(true)))
	if not _check(host.host(TEST_PORT).is_empty(), "host setup") or not _check(guest.join("127.0.0.1", TEST_PORT).is_empty(), "guest setup"):
		await _cleanup(1)
		return
	if not await _wait_until(func() -> bool: return guest.connected, 3.0):
		_check(false, "guest admitted")
		await _cleanup(1)
		return
	var guest_id := guest.multiplayer.get_unique_id()
	var first := _record("raider_0", "pirate")
	var second := _record("security_0", "police")
	host.publish_npc_ships([first])
	var sent_at := host._last_npc_publish_msec
	# Immediate publication is rate-limited; clients cannot publish through the host API.
	host.publish_npc_ships([])
	guest.publish_npc_ships([second])
	if not await _wait_until(func() -> bool: return snapshots.size() == 1, 2.0):
		_check(false, "host snapshot reaches guest")
		await _cleanup(1)
		return
	if not _check(host._last_npc_publish_msec == sent_at and snapshots[0].size() == 1 and snapshots[0][0].id == "raider_0", "host-only publishing is capped at 10Hz"):
		await _cleanup(1)
		return

	# A stale epoch and an invalid member must leave the last whole snapshot intact.
	host._rpc_npc_ships.rpc_id(guest_id, [second], guest._pvp_epoch + 1)
	var malformed := [first.duplicate(true), first.duplicate(true)]
	host._rpc_npc_ships.rpc_id(guest_id, malformed, guest._pvp_epoch)
	await create_timer(0.15).timeout
	if not _check(snapshots.size() == 1, "stale epoch and duplicate ID reject the entire snapshot"):
		await _cleanup(1)
		return

	await create_timer(0.11).timeout
	host.publish_npc_ships([first, second])
	if not await _wait_until(func() -> bool: return snapshots.size() == 2, 2.0):
		_check(false, "valid multi-ship snapshot accepted")
		await _cleanup(1)
		return
	if not _check(snapshots[1].size() == 2 and snapshots[1][1].faction == "police", "known IDs preserve validated data"):
		await _cleanup(1)
		return

	await create_timer(0.11).timeout
	host.publish_npc_ships([])
	if not await _wait_until(func() -> bool: return snapshots.size() == 3, 2.0) or not _check(snapshots[2].is_empty(), "empty snapshot clears remote NPCs"):
		await _cleanup(1)
		return

	if not failed:
		print("NPC_REPLICATION_OK: host snapshots, rate cap, epoch guard, full-batch validation and clear snapshot")
	await _cleanup(0)


func _record(id: String, faction: String) -> Dictionary:
	return {"id": id, "faction": faction, "address": SectorPosition.new(Vector3i.ZERO, Vector3(20, 0, -30)).to_save(), "rotation": Vector3.ZERO, "hp": 100.0, "shields": 25.0, "max_shields": 50.0}


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
	push_error("NPC_REPLICATION_FAIL: " + message)
	return false


func _cleanup(exit_code: int) -> void:
	if guest != null: guest.leave()
	if host != null: host.leave()
	await create_timer(0.05).timeout
	quit(exit_code)
