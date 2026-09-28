extends SceneTree

const PORT := 27872
const WAIT_SECONDS := 3.0

var host: NetworkSession
var guest: NetworkSession
var newcomer: NetworkSession


func _initialize() -> void:
	_run.call_deferred()


func _session(scope_name: String) -> NetworkSession:
	var scope := Node.new()
	scope.name = scope_name
	root.add_child(scope)
	set_multiplayer(MultiplayerAPI.create_default_interface(), scope.get_path())
	var session := NetworkSession.new()
	session.name = "Session"
	session.world_id = "0123456789abcdef0123456789abcdef"
	scope.add_child(session)
	return session


func _run() -> void:
	host = _session("Host")
	guest = _session("Guest")
	newcomer = _session("Newcomer")
	if not _check(host.host(PORT).is_empty(), "host starts"):
		_cleanup(1)
		return
	if not _check(guest.join("127.0.0.1", PORT).is_empty(), "first guest starts join"):
		_cleanup(1)
		return
	if not await _wait_until(func() -> bool: return guest.connected and host.presence.size() == 2):
		_check(false, "first guest admitted")
		_cleanup(1)
		return
	var guest_id := guest.multiplayer.get_unique_id()

	if not _check(host.set_visitors_open(false).is_empty(), "host closes visitor access"):
		_cleanup(1)
		return
	if not _check(host.presence.has(guest_id) and guest.connected, "locking preserves established guest"):
		_cleanup(1)
		return
	if not _check(newcomer.join("127.0.0.1", PORT).is_empty(), "new guest starts transport connection"):
		_cleanup(1)
		return
	await create_timer(0.5).timeout
	if not _check(not newcomer.connected and host.presence.size() == 2, "locked visitor not admitted or added to presence"):
		_cleanup(1)
		return
	newcomer.leave()
	await create_timer(0.1).timeout

	# Exercise the application admission gate even when a transport accepts the connection.
	host._peer.refuse_new_connections = false
	var rejected := [false]
	newcomer.session_message.connect(func(message: String):
		if "closed this world" in message: rejected[0] = true)
	newcomer.join("127.0.0.1", PORT)
	if not await _wait_until(func() -> bool: return rejected[0]):
		_check(false, "closed host rejects a transport-connected join request")
		_cleanup(1)
		return
	if not _check(not newcomer.connected and host.presence.size() == 2, "late join never enters presence"):
		_cleanup(1)
		return
	newcomer.leave()

	if not _check(guest.set_visitors_open(true) != "", "guest cannot change visitor access"):
		_cleanup(1)
		return
	if not _check(guest.remove_visitor(1) != "", "guest cannot remove the host"):
		_cleanup(1)
		return
	if not _check(host.remove_visitor(1) != "", "host cannot remove itself"):
		_cleanup(1)
		return
	if not _check(host.set_visitors_open(true).is_empty(), "host reopens visitor access"):
		_cleanup(1)
		return
	if not _check(newcomer.join("127.0.0.1", PORT).is_empty(), "new guest retries join"):
		_cleanup(1)
		return
	if not await _wait_until(func() -> bool: return newcomer.connected and host.presence.size() == 3):
		_check(false, "reopened access admits new guest")
		_cleanup(1)
		return

	var newcomer_id := newcomer.multiplayer.get_unique_id()
	if not _check(host.remove_visitor(newcomer_id).is_empty(), "host removes connected visitor"):
		_cleanup(1)
		return
	if not await _wait_until(func() -> bool: return not newcomer.connected and not host.presence.has(newcomer_id)):
		_check(false, "removal disconnects guest and clears host presence")
		_cleanup(1)
		return
	if not await _wait_until(func() -> bool: return not guest.presence.has(newcomer_id)):
		_check(false, "removal clears guest peer presence")
		_cleanup(1)
		return
	print("HOST_CONTROLS_OK: visitor lock, reopen, host removal and role checks")
	_cleanup(0)


func _wait_until(condition: Callable, timeout_seconds: float = WAIT_SECONDS) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if condition.call(): return true
		await create_timer(0.02).timeout
		elapsed += 0.02
	return condition.call()


func _check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("HOST_CONTROLS_FAILED: " + message)
	return false


func _cleanup(exit_code: int) -> void:
	if newcomer != null: newcomer.leave()
	if guest != null: guest.leave()
	if host != null: host.leave()
	quit(exit_code)
