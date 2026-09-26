extends SceneTree

const SteamSessionScript = preload("res://scripts/steam_session.gd")


class FakeSteam extends RefCounted:
	signal lobby_created(result: int, lobby_id: int)
	signal lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int)
	signal join_requested(lobby_id: int, steam_id: int)
	const RESULT_OK: int = 1
	const CHAT_ROOM_ENTER_RESPONSE_SUCCESS: int = 1
	const LOBBY_TYPE_FRIENDS_ONLY: int = 2
	var app_id: int = 0
	var requested_lobby: int = 0
	var lobby_type: int = 0
	var max_members: int = 0
	var invited_lobby: int = 0
	var left_lobby: int = 0
	var shutdowns: int = 0
	var init_calls: int = 0
	var fail_init: bool = false

	func steamInitEx(explicit_app_id: int, callbacks: bool) -> Dictionary:
		init_calls += 1
		app_id = explicit_app_id
		return {"status": 1 if fail_init else 0}

	func createLobby(type: int, members: int) -> void:
		lobby_type = type
		max_members = members

	func joinLobby(lobby_id: int) -> void:
		requested_lobby = lobby_id

	func activateGameOverlayInviteDialog(lobby_id: int) -> void:
		invited_lobby = lobby_id

	func leaveLobby(lobby_id: int) -> void:
		left_lobby = lobby_id

	func steamShutdown() -> void:
		shutdowns += 1


class FakePeer extends RefCounted:
	var hosted_lobby: int = 0
	var connected_lobby: int = 0
	var result: int = OK

	func host_with_lobby(lobby_id: int) -> int:
		hosted_lobby = lobby_id
		return result

	func connect_to_lobby(lobby_id: int) -> int:
		connected_lobby = lobby_id
		return result


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(SteamSessionScript.parse_connect_lobby(PackedStringArray(["game.exe", "+connect_lobby", "76561198000000000"])) == 76561198000000000, "parse valid launch lobby")
	_check(SteamSessionScript.parse_connect_lobby(PackedStringArray(["+connect_lobby", "0"])) == 0, "reject zero launch lobby")
	_check(SteamSessionScript.parse_connect_lobby(PackedStringArray(["+connect_lobby", "12;evil"])) == 0, "reject malformed launch lobby")
	var steam := FakeSteam.new()
	var made_peers: Array[FakePeer] = []
	var session := SteamSessionScript.new()
	root.add_child(session)
	var received: Array[Object] = []
	var invitations: Array[int] = []
	session.transport_ready.connect(func(peer: Object, host: bool) -> void: received.append(peer))
	session.invitation_ready.connect(func(lobby_id: int) -> void: invitations.append(lobby_id))
	var peer_factory: Callable = func() -> Object:
		var peer := FakePeer.new()
		made_peers.append(peer)
		return peer
	_check(session.initialize(0, steam, func() -> Object:
		var peer := FakePeer.new()
		made_peers.append(peer)
		return peer
	).contains("AppID"), "reject missing AppID without fallback")
	_check(steam.app_id == 0, "missing AppID never initialized Steam")
	_check(session.initialize(123456, steam, peer_factory) == "", "initialize with explicit AppID")
	_check(steam.app_id == 123456, "pass explicit AppID")
	_check(session.host() == "", "request host lobby")
	_check(steam.lobby_type == FakeSteam.LOBBY_TYPE_FRIENDS_ONLY and steam.max_members == 8, "friends-only 8-player lobby")
	steam.lobby_joined.emit(555, 0, false, FakeSteam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS)
	_check(received.is_empty() and steam.left_lobby == 0, "host's lobby_joined callback before creation does not tear lobby down")
	steam.lobby_created.emit(FakeSteam.RESULT_OK, 555)
	_check(received.size() == 1 and received[0] == made_peers[0], "host callback returns transport")
	_check(made_peers[0].hosted_lobby == 555 and session.lobby_id == 555, "host transport bound to lobby")
	steam.lobby_joined.emit(555, 0, false, FakeSteam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS)
	_check(steam.left_lobby == 0 and received.size() == 1, "host's lobby_joined callback after creation is ignored")
	_check(session.invite_friends() == "" and steam.invited_lobby == 555, "invite overlay targets active lobby")
	steam.join_requested.emit(777, 42)
	_check(invitations == [777], "Steam join request becomes UI invite")
	session.leave()
	_check(session.active and steam.shutdowns == 0 and steam.left_lobby == 555, "leave closes lobby but keeps Steam initialized")
	_check(session.initialize(123456, steam, peer_factory) == "" and steam.init_calls == 1, "same AppID initialization is idempotent")
	session._on_lobby_joined(888, 0, false, FakeSteam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS)
	_check(steam.left_lobby == 888 and received.size() == 1, "stale callback after leave is cleaned without transport")
	_check(session.join(888) == "", "request joining lobby")
	steam.lobby_joined.emit(999, 0, false, 1)
	_check(received.size() == 1 and steam.left_lobby == 999, "ignore and clean stale callback for other lobby")
	steam.lobby_joined.emit(888, 0, false, FakeSteam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS)
	_check(received.size() == 2 and made_peers[1].connected_lobby == 888, "connect to accepted lobby")
	_check(session.active and session.lobby_id == 888, "session lobby remains active")
	_check(session.initialize(987654, steam, func() -> Object: return FakePeer.new()).contains("different AppID"), "reject reinitialization for another AppID")
	session.leave()
	_check(steam.left_lobby == 888 and steam.shutdowns == 0 and session.active, "leaving client preserves initialized Steam")
	session.shutdown()
	_check(steam.shutdowns == 1 and not session.active, "shutdown closes Steam when app exits")
	var leave_count_after_shutdown := steam.left_lobby
	session._on_lobby_joined(123, 0, false, FakeSteam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS)
	_check(steam.left_lobby == leave_count_after_shutdown, "callback after shutdown is ignored safely")
	var reverse_steam := FakeSteam.new()
	var reverse_session := SteamSessionScript.new()
	root.add_child(reverse_session)
	var reverse_transports: Array[Object] = []
	reverse_session.transport_ready.connect(func(peer: Object, host: bool) -> void: reverse_transports.append(peer))
	_check(reverse_session.initialize(123, reverse_steam, func() -> Object: return FakePeer.new()) == "", "initialize reverse-order host")
	_check(reverse_session.host() == "", "request reverse-order lobby")
	reverse_steam.lobby_created.emit(FakeSteam.RESULT_OK, 333)
	reverse_steam.lobby_joined.emit(333, 0, false, FakeSteam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS)
	_check(reverse_session.lobby_id == 333 and reverse_steam.left_lobby == 0 and reverse_transports.size() == 1, "creation callback before host join callback retains lobby")
	reverse_session.shutdown()
	var cancelled_steam := FakeSteam.new()
	var cancelled_session := SteamSessionScript.new()
	root.add_child(cancelled_session)
	var cancelled_transports: Array[Object] = []
	cancelled_session.transport_ready.connect(func(peer: Object, host: bool) -> void: cancelled_transports.append(peer))
	_check(cancelled_session.initialize(123, cancelled_steam, func() -> Object: return FakePeer.new()) == "", "initialize cancellable join")
	_check(cancelled_session.join(777) == "", "request cancellable join")
	cancelled_session.leave()
	_check(cancelled_session.active and cancelled_session._pending == "join_stale", "cancel join while retaining Steam callback listener")
	cancelled_steam.lobby_joined.emit(777, 0, false, FakeSteam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS)
	_check(cancelled_session._pending.is_empty() and cancelled_steam.left_lobby == 777 and cancelled_transports.is_empty(), "late canceled join is cleaned instead of adopted")
	cancelled_session.shutdown()
	var failed := FakeSteam.new()
	failed.fail_init = true
	var rejected_session := SteamSessionScript.new()
	root.add_child(rejected_session)
	_check(rejected_session.initialize(456, failed).contains("initialization failed"), "report Steam initialization failure")
	_check(not rejected_session.active and failed.app_id == 456, "failed initialization does not activate or change AppID")
	failed.fail_init = false
	var failed_session := SteamSessionScript.new()
	root.add_child(failed_session)
	_check(failed_session.initialize(42, failed, func() -> Object: return FakePeer.new()) == "", "initialize failure case")
	_check(failed_session.host() == "", "start lobby failure case")
	failed.lobby_created.emit(2, 456)
	_check(failed_session.lobby_id == 0 and failed_session._pending.is_empty(), "failed lobby callback clears pending state")
	_check(failed_session.host() == "", "start timeout case")
	failed_session._process(21.0)
	_check(failed_session._pending == "host_stale", "timed-out create remains serialized until callback")
	_check(failed_session.host().contains("pending"), "reject new request while timed-out callback is outstanding")
	failed.lobby_created.emit(FakeSteam.RESULT_OK, 456)
	_check(failed_session._pending.is_empty() and failed.left_lobby == 456, "late timed-out create is cleaned instead of adopted")
	failed_session.shutdown()
	var timed_join_steam := FakeSteam.new()
	var timed_join_session := SteamSessionScript.new()
	root.add_child(timed_join_session)
	_check(timed_join_session.initialize(44, timed_join_steam, func() -> Object: return FakePeer.new()) == "", "initialize join timeout case")
	_check(timed_join_session.join(888) == "", "request join timeout case")
	timed_join_session._process(21.0)
	_check(timed_join_session._pending == "join_stale" and timed_join_session.join(889).contains("pending"), "timed-out join remains serialized")
	timed_join_steam.lobby_joined.emit(888, 0, false, FakeSteam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS)
	_check(timed_join_session._pending.is_empty() and timed_join_steam.left_lobby == 888, "late timed-out join is cleaned")
	timed_join_session.shutdown()
	if _failures == 0:
		print("STEAM_SESSION_TEST_OK: explicit AppID, lobby lifecycle, invite routing, stale/failure/timeout handling")
		quit()
	else:
		quit(1)


var _failures: int = 0


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("STEAM_SESSION_TEST_FAILED: " + label)
