extends SceneTree

const NetworkSessionScript = preload("res://scripts/network_session.gd")
const TEST_PORT: int = 27873
const WORLD_ID: String = "0123456789abcdef0123456789abcdef"
const BEAM_RANGE: float = 2400.1

var host: NetworkSession
var guest: NetworkSession
var observer: NetworkSession
var guest_beams: Array[Dictionary] = []
var observer_beams: Array[Dictionary] = []
var host_beams: Array[Dictionary] = []


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
	guest.npc_beam_received.connect(func(actor_id: String, origin: Dictionary, end: Dictionary) -> void:
		guest_beams.append({"id": actor_id, "origin": origin, "end": end}))
	observer.npc_beam_received.connect(func(actor_id: String, origin: Dictionary, end: Dictionary) -> void:
		observer_beams.append({"id": actor_id, "origin": origin, "end": end}))
	host.npc_beam_received.connect(func(actor_id: String, origin: Dictionary, end: Dictionary) -> void:
		host_beams.append({"id": actor_id, "origin": origin, "end": end}))
	if not _check(host.host(TEST_PORT).is_empty(), "host setup") or not _check(guest.join("127.0.0.1", TEST_PORT).is_empty(), "guest setup") or not _check(observer.join("127.0.0.1", TEST_PORT).is_empty(), "observer setup"):
		await _cleanup(1)
		return
	if not await _wait_until(func() -> bool: return guest.connected and observer.connected and host.presence.size() == 3, 3.0):
		_check(false, "both visitors admitted")
		await _cleanup(1)
		return
	var guest_id: int = guest.multiplayer.get_unique_id()
	var origin: SectorPosition = SectorPosition.new(Vector3i(2, -3, 4), Vector3(125.0, 10.0, -50.0))
	var end_position: SectorPosition = origin.clone()
	end_position.move_delta(Vector3(100.0, 0.0, 0.0))
	var origin_data: Dictionary = origin.to_save()
	var end_data: Dictionary = end_position.to_save()
	host.publish_npc_beam("raider_0", origin_data, end_data)
	if not await _wait_until(func() -> bool: return guest_beams.size() == 1 and observer_beams.size() == 1, 2.0):
		_check(false, "valid beam reaches every visitor")
		await _cleanup(1)
		return
	if not _check(guest_beams[0].id == "raider_0" and guest_beams[0].origin == origin_data and guest_beams[0].end == end_data and observer_beams[0] == guest_beams[0] and host_beams.is_empty(), "payload broadcasts unchanged and host emits no local event"):
		await _cleanup(1)
		return

	# Client attempts and malformed authority payloads must produce no signal.
	guest.publish_npc_beam("raider_1", origin_data, end_data)
	host._rpc_npc_beam.rpc_id(guest_id, "civilian_0", origin_data, end_data, host._pvp_epoch)
	host._rpc_npc_beam.rpc_id(guest_id, "raider_0", {}, end_data, host._pvp_epoch)
	host._rpc_npc_beam.rpc_id(guest_id, "raider_0", origin_data, origin_data, host._pvp_epoch)
	var too_far: SectorPosition = origin.clone()
	too_far.move_delta(Vector3(BEAM_RANGE + 0.1, 0.0, 0.0))
	host._rpc_npc_beam.rpc_id(guest_id, "security_0", origin_data, too_far.to_save(), host._pvp_epoch)
	host._rpc_npc_beam.rpc_id(guest_id, "raider_0", origin_data, end_data, host._pvp_epoch + 1)
	for invalid_id: String in ["civilian_0", "", "raider_5"]:
		host.publish_npc_beam(invalid_id, origin_data, end_data)
	host.publish_npc_beam("raider_0", {}, end_data)
	host.publish_npc_beam("raider_0", origin_data, origin_data)
	host.publish_npc_beam("raider_0", origin_data, too_far.to_save())
	await create_timer(0.15).timeout
	if not _check(guest_beams.size() == 1 and observer_beams.size() == 1 and host_beams.is_empty(), "invalid ID, address, length, zero segment, stale epoch and guest publication are rejected"):
		await _cleanup(1)
		return

	# The host can emit a full simultaneous-fire burst; the limiter is a rolling window.
	await create_timer(1.02).timeout
	for _shot in 65:
		host.publish_npc_beam("security_1", origin_data, end_data)
	if not _check(host._npc_beam_times_msec.size() == 64, "64 beam events fit in a one-second burst and event 65 is rejected"):
		await _cleanup(1)
		return
	if not await _wait_until(func() -> bool: return guest_beams.size() > 1 and observer_beams.size() > 1, 2.0):
		_check(false, "rate-limited burst broadcasts")
		await _cleanup(1)
		return
	if not _check(guest_beams.size() <= 65 and observer_beams.size() <= 65, "burst stays within the 64-event limit"):
		await _cleanup(1)
		return

	guest.leave()
	observer.leave()
	host.leave()
	print("NPC_BEAM_PROTOCOL_OK: broadcast, validation, epochs, host-only publication and 64-per-second burst limit")
	await _cleanup(0)


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if condition.call(): return true
		await create_timer(0.01).timeout
		elapsed += 0.01
	return condition.call()


func _check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("NPC_BEAM_PROTOCOL_FAIL: " + message)
	return false


func _cleanup(exit_code: int) -> void:
	if guest != null: guest.leave()
	if observer != null: observer.leave()
	if host != null: host.leave()
	await create_timer(0.05).timeout
	quit(exit_code)
