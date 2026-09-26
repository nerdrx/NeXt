class_name SteamSession
extends Node

signal invitation_ready(lobby_id: int)
signal transport_ready(peer: Object, host: bool)
signal status_changed(message: String)

const MAX_PLAYERS: int = 8
const CALLBACK_TIMEOUT: float = 20.0

var lobby_id: int = 0
var active: bool = false
var app_id: int = 0
var _steam: Object
var _peer_factory: Callable
var _pending: String = ""
var _target_lobby: int = 0
var _elapsed: float = 0.0
var _launch_checked: bool = false


func initialize(app_id: int, steam_override: Object = null, peer_factory: Callable = Callable()) -> String:
	if app_id <= 0 or app_id > 4294967295:
		return "A valid positive Steam AppID is required."
	if active:
		return "" if self.app_id == app_id else "Steam is initialized for a different AppID."
	_steam = steam_override if steam_override != null else (Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null)
	if _steam == null:
		return "Steam support is unavailable in this Godot build."
	_peer_factory = peer_factory
	_connect_callback("lobby_created", _on_lobby_created)
	_connect_callback("lobby_joined", _on_lobby_joined)
	_connect_callback("join_requested", _on_join_requested)
	var result: Variant = _steam.call("steamInitEx", app_id, true)
	if not result is Dictionary or int(result.get("status", -1)) != 0:
		_disconnect_callbacks()
		_steam = null
		return "Steam initialization failed. Check Steam is running and the AppID is valid."
	active = true
	self.app_id = app_id
	if not _launch_checked:
		var launch_args := OS.get_cmdline_args()
		launch_args.append_array(OS.get_cmdline_user_args())
		_parse_launch_args(launch_args)
		_launch_checked = true
	return ""


func host() -> String:
	if not active or _pending != "":
		return "Steam is not ready or another lobby request is pending."
	_pending = "host"
	_elapsed = 0.0
	_steam.call("createLobby", _steam.get("LOBBY_TYPE_FRIENDS_ONLY"), MAX_PLAYERS)
	return ""


func join(target_lobby_id: int) -> String:
	if not active or _pending != "":
		return "Steam is not ready or another lobby request is pending."
	if target_lobby_id <= 0:
		return "Lobby ID must be positive."
	_pending = "join"
	_target_lobby = target_lobby_id
	_elapsed = 0.0
	_steam.call("joinLobby", target_lobby_id)
	return ""


func invite_friends() -> String:
	if not active or lobby_id <= 0:
		return "Host a Steam lobby before inviting friends."
	_steam.call("activateGameOverlayInviteDialog", lobby_id)
	return ""


func leave() -> void:
	var prior_lobby := lobby_id
	if _pending == "host":
		_pending = "host_stale"
	elif _pending == "join":
		_pending = "join_stale"
	elif not _pending.ends_with("_stale"):
		_clear_pending()
	_elapsed = 0.0
	lobby_id = 0
	if _steam != null:
		if prior_lobby > 0:
			_steam.call("leaveLobby", prior_lobby)
	if prior_lobby > 0:
		status_changed.emit("Steam session closed.")


func shutdown() -> void:
	if _steam == null:
		active = false
		app_id = 0
		_clear_pending()
		return
	leave()
	_clear_pending()
	active = false
	app_id = 0
	_steam.call("steamShutdown")
	_disconnect_callbacks()
	_steam = null


func _process(delta: float) -> void:
	if _pending.is_empty() or _pending.ends_with("_stale"):
		return
	_elapsed += delta
	if _elapsed >= CALLBACK_TIMEOUT:
		_pending = "host_stale" if _pending == "host" else "join_stale"
		status_changed.emit("Steam lobby request timed out.")


func _on_lobby_created(result: int, created_lobby_id: int) -> void:
	if _steam == null or not active:
		return
	if _pending == "host_stale":
		if result == int(_steam.get("RESULT_OK")) and created_lobby_id > 0:
			_steam.call("leaveLobby", created_lobby_id)
		_clear_pending()
		return
	if _pending != "host":
		if result == int(_steam.get("RESULT_OK")) and created_lobby_id > 0:
			_steam.call("leaveLobby", created_lobby_id)
		return
	if result != int(_steam.get("RESULT_OK")) or created_lobby_id <= 0:
		_fail("Steam could not create the lobby.")
		return
	var peer := _new_peer()
	if peer == null or int(peer.call("host_with_lobby", created_lobby_id)) != OK:
		_fail("Steam could not start the lobby transport.", created_lobby_id)
		return
	lobby_id = created_lobby_id
	_clear_pending()
	transport_ready.emit(peer, true)
	status_changed.emit("Steam lobby hosted.")


func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if _steam == null or not active:
		return
	var success_code := int(_steam.get("CHAT_ROOM_ENTER_RESPONSE_SUCCESS"))
	# createLobby also reports the host's own lobby_joined callback. It may
	# arrive either before or after lobby_created; host_with_lobby owns setup.
	if _pending == "host" or (lobby_id > 0 and joined_lobby_id == lobby_id):
		return
	if _pending == "join_stale":
		if joined_lobby_id == _target_lobby:
			if response == success_code:
				_steam.call("leaveLobby", joined_lobby_id)
			_clear_pending()
		return
	if _pending != "join" or joined_lobby_id != _target_lobby:
		if response == success_code and joined_lobby_id > 0:
			_steam.call("leaveLobby", joined_lobby_id)
		return
	if response != success_code:
		_fail("Steam could not join that lobby.", joined_lobby_id)
		return
	var peer := _new_peer()
	if peer == null or int(peer.call("connect_to_lobby", joined_lobby_id)) != OK:
		_fail("Steam could not connect to the lobby transport.", joined_lobby_id)
		return
	lobby_id = joined_lobby_id
	_clear_pending()
	transport_ready.emit(peer, false)
	status_changed.emit("Joined Steam lobby.")


func _on_join_requested(requested_lobby_id: int, _steam_id: int) -> void:
	if _steam != null and active and requested_lobby_id > 0:
		invitation_ready.emit(requested_lobby_id)


func _fail(message: String, failed_lobby: int = 0) -> void:
	_clear_pending()
	if failed_lobby > 0 and _steam != null:
		_steam.call("leaveLobby", failed_lobby)
	status_changed.emit(message)


func _clear_pending() -> void:
	_pending = ""
	_target_lobby = 0
	_elapsed = 0.0


func _new_peer() -> Object:
	if _peer_factory.is_valid():
		return _peer_factory.call()
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return null
	return ClassDB.instantiate("SteamMultiplayerPeer")


func _connect_callback(signal_name: String, callback: Callable) -> void:
	if _steam.has_signal(signal_name) and not _steam.is_connected(signal_name, callback):
		_steam.connect(signal_name, callback)


func _disconnect_callbacks() -> void:
	if _steam == null:
		return
	for pair: Array in [["lobby_created", _on_lobby_created], ["lobby_joined", _on_lobby_joined], ["join_requested", _on_join_requested]]:
		if _steam.is_connected(pair[0], pair[1]):
			_steam.disconnect(pair[0], pair[1])


func _parse_launch_args(args: PackedStringArray) -> void:
	var parsed := parse_connect_lobby(args)
	if parsed > 0:
		invitation_ready.emit(parsed)


static func parse_connect_lobby(args: PackedStringArray) -> int:
	for index in range(args.size() - 1):
		if args[index] != "+connect_lobby":
			continue
		var value := args[index + 1]
		if value.is_empty() or value.length() > 19:
			return 0
		for character: String in value:
			if character < "0" or character > "9":
				return 0
		var lobby := value.to_int()
		return lobby if lobby > 0 else 0
	return 0
