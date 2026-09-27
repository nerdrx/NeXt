extends SceneTree

const PORT: int = 27848
const MAX_TIME: float = 1.0e12

var session: NetworkSession
var acknowledgement: ClockAcknowledgement
var received: Array[float] = []
var travel_received: bool = false


class ClockAcknowledgement extends Node:
	var session: NetworkSession
	var client_ready: bool = false
	var received: bool = false
	var acknowledged: bool = false

	@rpc("any_peer", "call_remote", "reliable")
	func _rpc_ready() -> void:
		if session.is_host and multiplayer.get_remote_sender_id() > 1: client_ready = true

	@rpc("any_peer", "call_remote", "reliable")
	func _rpc_success() -> void:
		var sender := multiplayer.get_remote_sender_id()
		if not session.is_host or sender <= 1: return
		received = true
		_rpc_success_ack.rpc_id(sender)

	@rpc("authority", "call_remote", "reliable")
	func _rpc_success_ack() -> void:
		if not session.is_host: acknowledged = true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	session = NetworkSession.new()
	root.add_child(session)
	acknowledgement = ClockAcknowledgement.new()
	acknowledgement.name = "ClockAcknowledgement"
	acknowledgement.session = session
	root.add_child(acknowledgement)
	session.ephemeris_received.connect(func(seconds: float) -> void: received.append(seconds))
	session.world_joined.connect(func(index: int) -> void: travel_received = index == 42)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and str(args[0]) == "client":
		await _run_client()
	else:
		await _run_host()


func _run_host() -> void:
	session.world_id = "1234567890abcdef1234567890abcdef"
	session.publish_clock(123.5)
	var error: String = session.host(PORT)
	if not error.is_empty(): return _fail("host setup: " + error)
	var project_path := ProjectSettings.globalize_path("res://")
	if OS.create_process(OS.get_executable_path(), ["--headless", "--path", project_path, "-s", "res://tests/test_network_clock.gd", "--", "client"]) < 0:
		return _fail("could not launch client")
	if not await _wait_for(func() -> bool: return session.presence.size() == 2 and acknowledgement.client_ready, 6.0):
		return _fail("client did not join and validate welcome")
	session.publish_clock(124.0)
	await create_timer(1.05).timeout
	session.publish_clock(124.5)
	if session.ephemeris_seconds != 124.5:
		return _fail("host did not retain its published clock")
	if session.travel(42) != "":
		return _fail("host could not travel")
	if not await _wait_for(func() -> bool: return acknowledgement.received, 5.0):
		return _fail("client did not acknowledge successful clock checks")
	if not await _wait_for(func() -> bool: return session.presence.size() == 1, 3.0):
		return _fail("client did not finish after its success acknowledgement")
	if session.ephemeris_seconds != 124.5:
		return _fail("host adopted a guest clock")
	print("NETWORK_CLOCK_HOST_OK")
	session.leave()
	quit()


func _run_client() -> void:
	session.world_id = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	var error: String = session.join("127.0.0.1", PORT)
	if not error.is_empty(): return _fail("client setup: " + error)
	if not await _wait_for(func() -> bool: return session.connected, 6.0):
		return _fail("client did not receive welcome")
	if not received.has(123.5):
		return _fail("welcome clock mismatch: %s (received %s)" % [session.ephemeris_seconds, received])
	if session.ephemeris_seconds != 123.5:
		return _fail("welcome clock changed before validation")
	session.publish_clock(999.0)
	if session.ephemeris_seconds != 123.5:
		return _fail("guest changed the host clock")
	acknowledgement._rpc_ready.rpc_id(1)
	if not await _wait_for(func() -> bool: return received.has(124.0) and received.has(124.5), 5.0):
		return _fail("guest missed a host clock snapshot")
	session._rpc_clock.rpc_id(1, 999.0)
	if not await _wait_for(func() -> bool: return travel_received, 5.0) or session.ephemeris_seconds != 124.5:
		return _fail("travel clock snapshot mismatch")
	if session._valid_ephemeris(-1.0) or session._valid_ephemeris(MAX_TIME + 1.0) or session._valid_ephemeris(NAN) or session._valid_ephemeris(INF):
		return _fail("invalid clock value passed validation")
	acknowledgement._rpc_success.rpc_id(1)
	if not await _wait_for(func() -> bool: return acknowledgement.acknowledged, 3.0):
		return _fail("host did not acknowledge test success")
	print("NETWORK_CLOCK_CLIENT_OK")
	session.leave()
	quit()


func _wait_for(condition: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if condition.call(): return true
		await create_timer(0.05).timeout
		elapsed += 0.05
	return condition.call()


func _fail(message: String) -> void:
	push_error("NETWORK_CLOCK_FAILED: " + message)
	if session != null: session.leave()
	quit(1)
