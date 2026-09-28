extends SceneTree

const NetworkSessionScript = preload("res://scripts/network_session.gd")
const TEST_PORT: int = 27866
const WORLD_ID: String = "0123456789abcdef0123456789abcdef"

var host: NetworkSession
var guest: NetworkSession
var joined_events: int = 0
var messages: Array[String] = []
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
	guest = _session("BadVersion")
	guest.session_message.connect(func(message: String) -> void: messages.append(message))
	guest.world_joined.connect(func(_index: int) -> void: joined_events += 1)
	if not _check(host.host(TEST_PORT).is_empty(), "host setup") or not _check(guest.join("127.0.0.1", TEST_PORT).is_empty(), "bad-version guest setup"):
		await _cleanup(1)
		return
	guest._join_sent = true
	if not await _wait_until(func() -> bool: return _transport_connected(guest), 3.0):
		_check(false, "bad-version guest transport connects")
		await _cleanup(1)
		return
	guest._rpc_join_request.rpc_id(1, "Bad Version", [], {}, 999)
	if not await _wait_until(func() -> bool: return _has_message("compatible") or _has_message("protocol"), 2.0):
		_check(false, "mismatched protocol reports a clear rejection")
		await _cleanup(1)
		return
	if not _check(host.presence.size() == 1 and joined_events == 0, "mismatched protocol is not admitted"):
		await _cleanup(1)
		return
	guest.leave()
	if not await _wait_until(func() -> bool: return host.presence.size() == 1, 2.0):
		_check(false, "mismatched guest cleanup")
		await _cleanup(1)
		return

	messages.clear()
	guest = _session("LegacyJoin")
	guest.session_message.connect(func(message: String) -> void: messages.append(message))
	guest.world_joined.connect(func(_index: int) -> void: joined_events += 1)
	if not _check(guest.join("127.0.0.1", TEST_PORT).is_empty(), "legacy guest setup"):
		await _cleanup(1)
		return
	guest._join_sent = true
	if not await _wait_until(func() -> bool: return _transport_connected(guest), 3.0):
		_check(false, "legacy guest transport connects")
		await _cleanup(1)
		return
	guest._rpc_join_request.rpc_id(1, "Legacy", [], {})
	if not await _wait_until(func() -> bool: return _has_message("Incompatible NeXt multiplayer protocol"), 2.0):
		_check(false, "missing protocol version is rejected")
		await _cleanup(1)
		return
	if not _check(host.presence.size() == 1 and joined_events == 0, "legacy join is not admitted"):
		await _cleanup(1)
		return
	guest.leave()
	await _wait_until(func() -> bool: return host.presence.size() == 1, 2.0)

	var legacy_welcome := _session("LegacyWelcome")
	legacy_welcome.system_index = 7
	legacy_welcome.world_seed = 12345
	legacy_welcome.world_id = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	legacy_welcome._rpc_welcome(12, 99, WORLD_ID, {}, 2, 0.0, 0)
	if not _check(not legacy_welcome.connected and legacy_welcome.system_index == 7 and legacy_welcome.world_seed == 12345 and legacy_welcome.world_id == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" and legacy_welcome.presence.is_empty(), "legacy welcome does not mutate session state"):
		await _cleanup(1)
		return

	guest = _session("NormalJoin")
	guest.world_joined.connect(func(_index: int) -> void: joined_events += 1)
	if not _check(guest.join("127.0.0.1", TEST_PORT).is_empty(), "normal guest setup") or not await _wait_until(func() -> bool: return guest.connected, 3.0):
		_check(false, "versioned join succeeds")
		await _cleanup(1)
		return
	if not _check(joined_events == 1 and guest.world_id == host.world_id, "versioned welcome joins the host world"):
		await _cleanup(1)
		return
	host._disconnect_unadmitted(guest.multiplayer.get_unique_id(), 0.02)
	await create_timer(0.06).timeout
	if not _check(guest.connected, "admitted visitor survives pending admission deadline"):
		await _cleanup(1)
		return
	guest.leave()
	await _wait_until(func() -> bool: return host.presence.size() == 1, 2.0)

	messages.clear()
	guest = _session("JoinTimeout")
	guest.session_message.connect(func(message: String) -> void: messages.append(message))
	guest.world_joined.connect(func(_index: int) -> void: joined_events += 1)
	if not _check(guest.join("127.0.0.1", TEST_PORT).is_empty(), "timeout guest setup"):
		await _cleanup(1)
		return
	guest._join_sent = true
	if not await _wait_until(func() -> bool: return _transport_connected(guest), 3.0):
		_check(false, "timeout guest transport connects")
		await _cleanup(1)
		return
	guest._join_remaining = 0.01
	guest._process(0.02)
	if not _check(guest._peer == null and not guest.connected and _has_message("Host did not complete a compatible join handshake.") and joined_events == 1, "handshake timeout leaves with a clear message"):
		await _cleanup(1)
		return

	guest = _session("SilentPeer")
	if not _check(guest.join("127.0.0.1", TEST_PORT).is_empty(), "silent guest setup"):
		await _cleanup(1)
		return
	guest._join_sent = true
	if not await _wait_until(func() -> bool: return _transport_connected(guest), 3.0):
		_check(false, "silent guest transport connects")
		await _cleanup(1)
		return
	host._disconnect_unadmitted(guest.multiplayer.get_unique_id(), 0.02)
	if not await _wait_until(func() -> bool: return guest._peer == null, 2.0):
		_check(false, "host removes transport that never submits a handshake")
		await _cleanup(1)
		return

	if not failed:
		print("NETWORK_PROTOCOL_OK: versioned join handshake, legacy rejection and timeout")
	await _cleanup(0)


func _transport_connected(session: NetworkSession) -> bool:
	return session._peer != null and session._peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _has_message(fragment: String) -> bool:
	for message: String in messages:
		if fragment.to_lower() in message.to_lower(): return true
	return false


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
	push_error("NETWORK_PROTOCOL_FAIL: " + message)
	return false


func _cleanup(exit_code: int) -> void:
	if guest != null: guest.leave()
	if host != null: host.leave()
	await create_timer(0.05).timeout
	quit(exit_code)
