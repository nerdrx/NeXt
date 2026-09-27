class_name NetworkSession
extends Node

signal world_joined(system_index: int)
signal ephemeris_received(seconds: float)
signal peers_changed
signal session_message(message: String)
signal steam_invitation_ready(lobby_id: int)
signal pvp_damage_received(attacker: int, damage: float)
signal pvp_hit_confirmed(attacker: int, target: int, origin_data: Dictionary, end_data: Dictionary)

const DEFAULT_PORT: int = 27840
const MAX_PLAYERS: int = 8
const MAX_MODULES: int = 100
const MAX_SYSTEM_INDEX: int = 999999999
const MAX_WORLD_COORD: float = 30000.0
const MODULE_KINDS: Array[String] = ["core", "cockpit", "reactor", "engine", "cargo", "weapon", "shield", "habitat", "radiator"]
const ShipLayoutScript = preload("res://scripts/ship_layout.gd")

var system_index: int = 0
var world_id: String = ""
var world_seed: int = 0
var ephemeris_seconds: float = 0.0
var ship_modules: Array = []
var ship_layout: Dictionary = {"version": 1, "rooms": {}, "panels": {}}
var display_name: String = "Pilot"
var is_host: bool = false
var connected: bool = false
var presence: Dictionary = {}

var _peer: MultiplayerPeer
var _steam_session: SteamSession
var _join_sent: bool = false
var _last_pose_msec: int = 0
var _last_clock_sent_msec: int = -1000
var _last_remote_pose_msec: Dictionary = {}
var _last_pvp_shot_msec: Dictionary = {}
var _pvp_epoch: int = 0
var _local_pvp_allowed: bool = false
var _local_flying: bool = false
var pvp_occlusion_check: Callable



func _ready() -> void:
	_steam_session = SteamSession.new()
	add_child(_steam_session)
	_steam_session.transport_ready.connect(_on_steam_transport_ready)
	_steam_session.invitation_ready.connect(_on_steam_invitation_ready)
	_steam_session.status_changed.connect(func(message: String) -> void: session_message.emit(message))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host(port: int = DEFAULT_PORT) -> String:
	leave()
	if not _valid_world_id(world_id):
		return "A valid world ID is required before hosting."
	if port < 1 or port > 65535:
		return "Port must be between 1 and 65535."
	var normalized := _normalize_modules(ship_modules)
	if not normalized.ok:
		return "Ship design is invalid: %s" % normalized.error
	var normalized_layout := _normalize_layout(ship_layout, normalized.modules)
	if not normalized_layout.ok:
		return "Ship layout is invalid: %s" % normalized_layout.error
	ship_modules = normalized.modules
	ship_layout = normalized_layout.layout
	display_name = _sanitize_name(display_name)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		return "Could not start ENet host (error %d)." % error
	_start_host(peer, "LAN session hosted on port %d." % port)
	return ""


func host_steam(app_id: int) -> String:
	leave()
	var error := _validate_local_design()
	if not error.is_empty():
		return error
	if not _valid_world_id(world_id):
		return "A valid world ID is required before hosting."
	var init_error := _steam_session.initialize(app_id)
	if not init_error.is_empty():
		return init_error
	return _steam_session.host()


func join_steam(app_id: int, lobby_id: int) -> String:
	leave()
	var error := _validate_local_design()
	if not error.is_empty():
		return error
	var init_error := _steam_session.initialize(app_id)
	if not init_error.is_empty():
		return init_error
	return _steam_session.join(lobby_id)


func invite_steam_friends() -> String:
	return _steam_session.invite_friends() if _steam_session != null else "Steam is unavailable."


func enable_steam(app_id: int) -> String:
	return _steam_session.initialize(app_id) if _steam_session != null else "Steam session is unavailable."


func _start_host(peer: MultiplayerPeer, status: String) -> void:
	_peer = peer
	multiplayer.multiplayer_peer = _peer
	is_host = true
	connected = true
	system_index = clampi(system_index, 0, MAX_SYSTEM_INDEX)
	world_seed = _seed_for(system_index)
	_last_clock_sent_msec = -1000
	var local_id := multiplayer.get_unique_id()
	presence.clear()
	presence[local_id] = _make_presence(Vector3.ZERO, Vector3.ZERO, ship_modules, ship_layout, display_name)
	peers_changed.emit()
	session_message.emit(status)


func join(address: String, port: int = DEFAULT_PORT) -> String:
	leave()
	var host_address := address.strip_edges()
	if host_address.is_empty() or host_address.length() > 255:
		return "Enter a valid host address."
	if port < 1 or port > 65535:
		return "Port must be between 1 and 65535."
	var normalized := _normalize_modules(ship_modules)
	if not normalized.ok:
		return "Ship design is invalid: %s" % normalized.error
	var normalized_layout := _normalize_layout(ship_layout, normalized.modules)
	if not normalized_layout.ok:
		return "Ship layout is invalid: %s" % normalized_layout.error
	ship_modules = normalized.modules
	ship_layout = normalized_layout.layout
	display_name = _sanitize_name(display_name)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host_address, port)
	if error != OK:
		return "Could not connect to host (error %d)." % error
	_start_client(peer, "Connecting to %s:%d…" % [host_address, port])
	return ""


func _start_client(peer: MultiplayerPeer, status: String) -> void:
	_peer = peer
	multiplayer.multiplayer_peer = _peer
	is_host = false
	connected = false
	_join_sent = false
	presence.clear()
	_last_remote_pose_msec.clear()
	_last_pvp_shot_msec.clear()
	_local_pvp_allowed = false
	_local_flying = false
	_last_pose_msec = -1000
	_last_clock_sent_msec = -1000
	session_message.emit(status)


func _validate_local_design() -> String:
	var normalized := _normalize_modules(ship_modules)
	if not normalized.ok:
		return "Ship design is invalid: %s" % normalized.error
	var normalized_layout := _normalize_layout(ship_layout, normalized.modules)
	if not normalized_layout.ok:
		return "Ship layout is invalid: %s" % normalized_layout.error
	ship_modules = normalized.modules
	ship_layout = normalized_layout.layout
	display_name = _sanitize_name(display_name)
	return ""



func _on_steam_transport_ready(candidate: Object, hosting: bool) -> void:
	if not candidate is MultiplayerPeer:
		session_message.emit("Steam returned an invalid multiplayer peer.")
		return
	var peer := candidate as MultiplayerPeer
	if hosting:
		_start_host(peer, "Steam lobby hosted.")
	else:
		_start_client(peer, "Connecting to Steam lobby…")


func _on_steam_invitation_ready(invited_lobby_id: int) -> void:
	steam_invitation_ready.emit(invited_lobby_id)
	session_message.emit("Steam invite ready: lobby %d." % invited_lobby_id)


func leave() -> void:
	var had_session := _peer != null
	if _peer != null:
		_peer.close()
		_peer = null
	if _steam_session != null:
		_steam_session.leave()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected = false
	is_host = false
	_join_sent = false
	presence.clear()
	_last_remote_pose_msec.clear()
	_last_pvp_shot_msec.clear()
	_local_pvp_allowed = false
	_local_flying = false
	_last_pose_msec = -1000
	_last_clock_sent_msec = -1000
	if had_session:
		peers_changed.emit()


func _exit_tree() -> void:
	if _steam_session != null:
		_steam_session.shutdown()


func publish_pose(position: Vector3, rotation: Vector3, origin_data: Dictionary = {}, flying: bool = false) -> void:
	if not connected or not _valid_vector(position, MAX_WORLD_COORD) or not _valid_rotation(rotation):
		return
	var origin: Variant = SectorPosition.new()
	if not origin_data.is_empty():
		origin = SectorPosition.from_save(origin_data)
	if origin == null:
		return
	var address: SectorPosition = origin
	if not address.move_delta(position):
		return
	var address_data: Dictionary = address.to_save()
	var normalized := _normalize_modules(ship_modules)
	if not normalized.ok: return
	var normalized_layout := _normalize_layout(ship_layout, normalized.modules)
	if not normalized_layout.ok: return
	ship_modules = normalized.modules
	ship_layout = normalized_layout.layout
	_local_flying = flying
	if presence.has(multiplayer.get_unique_id()): presence[multiplayer.get_unique_id()].flying = flying
	var now := Time.get_ticks_msec()
	if now - _last_pose_msec < 50:
		return
	_last_pose_msec = now
	var id := multiplayer.get_unique_id()
	var profile: Dictionary = presence.get(id, _make_presence(Vector3.ZERO, Vector3.ZERO, ship_modules, ship_layout, display_name))
	profile.flying = flying
	profile.position = position
	profile.rotation = rotation
	profile.address = address_data
	profile.ship_modules = ship_modules.duplicate(true)
	profile.ship_layout = ship_layout.duplicate(true)
	profile.name = display_name
	presence[id] = profile
	if is_host:
		_broadcast_presence(id, profile)
		peers_changed.emit()
	else:
		_rpc_publish_pose.rpc_id(1, position, rotation, ship_modules.duplicate(true), ship_layout.duplicate(true), address_data, flying, _pvp_epoch)


func travel(index: int) -> String:
	if not is_host or not connected:
		return "Only the host can change systems."
	if index < 0 or index > MAX_SYSTEM_INDEX:
		return "System address is out of range."
	system_index = index
	world_seed = _seed_for(index)
	_pvp_epoch += 1
	_reset_pvp()
	for peer_id: int in multiplayer.get_peers():
		_rpc_world_joined.rpc_id(peer_id, index, world_seed, world_id, _pvp_epoch, ephemeris_seconds)
	world_joined.emit(system_index)
	session_message.emit("Traveling together to system %d." % system_index)
	return ""


func publish_clock(seconds: float) -> void:
	if not _valid_ephemeris(seconds): return
	if not connected:
		ephemeris_seconds = seconds
		return
	if not is_host: return
	ephemeris_seconds = seconds
	var now := Time.get_ticks_msec()
	if now - _last_clock_sent_msec < 1000: return
	_last_clock_sent_msec = now
	_rpc_clock.rpc(seconds)


func _on_peer_connected(_peer_id: int) -> void:
	# Presence is admitted only after the peer's validated join request.
	pass


func _on_peer_disconnected(peer_id: int) -> void:
	_last_remote_pose_msec.erase(peer_id)
	_last_pvp_shot_msec.erase(peer_id)
	if is_host:
		if presence.erase(peer_id):
			for remote_id: int in multiplayer.get_peers():
				_rpc_peer_left.rpc_id(remote_id, peer_id)
			peers_changed.emit()
	elif peer_id != 1 and presence.erase(peer_id):
		peers_changed.emit()
		session_message.emit("A peer disconnected.")


func _on_connected_to_server() -> void:
	if _join_sent or _peer == null:
		return
	_join_sent = true
	_rpc_join_request.rpc_id(1, _sanitize_name(display_name), ship_modules.duplicate(true), ship_layout.duplicate(true))


func _on_connection_failed() -> void:
	connected = false
	session_message.emit("Could not reach the host.")
	leave()


func _on_server_disconnected() -> void:
	connected = false
	is_host = false
	presence.clear()
	peers_changed.emit()
	session_message.emit("Host disconnected.")
	leave()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_join_request(raw_name: String, raw_modules: Array, raw_layout: Variant) -> void:
	if not is_host or not connected:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or sender > 0x7fffffff or presence.has(sender) or presence.size() >= MAX_PLAYERS:
		return
	if raw_name.length() > 64 or raw_modules.size() > MAX_MODULES or not raw_layout is Dictionary or raw_layout.size() > 3:
		_rpc_reject.rpc_id(sender, "Join data is too large.")
		return
	var normalized := _normalize_modules(raw_modules)
	if not normalized.ok:
		_rpc_reject.rpc_id(sender, "Invalid ship design: %s" % normalized.error)
		return
	var normalized_layout := _normalize_layout(raw_layout, normalized.modules)
	if not normalized_layout.ok:
		_rpc_reject.rpc_id(sender, "Invalid ship layout: %s" % normalized_layout.error)
		return
	var safe_name := _sanitize_name(raw_name)
	var profile := _make_presence(Vector3.ZERO, Vector3.ZERO, normalized.modules, normalized_layout.layout, safe_name)
	presence[sender] = profile
	_rpc_welcome.rpc_id(sender, system_index, world_seed, world_id, presence.duplicate(true), _pvp_epoch, ephemeris_seconds)
	_broadcast_presence(sender, profile)
	peers_changed.emit()
	session_message.emit("%s joined." % safe_name)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_publish_pose(position: Vector3, rotation: Vector3, raw_modules: Array, raw_layout: Variant, raw_address: Variant, flying: bool = false, epoch: int = 0) -> void:
	if not is_host or not connected:
		return
	var address: Variant = SectorPosition.from_save(raw_address)
	var sender := multiplayer.get_remote_sender_id()
	if epoch != _pvp_epoch or address == null or not presence.has(sender) or not _valid_vector(position, MAX_WORLD_COORD) or not _valid_rotation(rotation) or raw_modules.size() > MAX_MODULES or not raw_layout is Dictionary:
		return
	var normalized := _normalize_modules(raw_modules)
	if not normalized.ok: return
	var normalized_layout := _normalize_layout(raw_layout, normalized.modules)
	if not normalized_layout.ok: return
	var now := Time.get_ticks_msec()
	if now - int(_last_remote_pose_msec.get(sender, 0)) < 50:
		return
	_last_remote_pose_msec[sender] = now
	var profile: Dictionary = presence[sender]
	profile.flying = flying
	profile.position = position
	profile.rotation = rotation
	profile.address = address.to_save()
	profile.ship_modules = normalized.modules
	profile.ship_layout = normalized_layout.layout
	presence[sender] = profile
	_broadcast_presence(sender, profile)
	peers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_welcome(index: int, seed: int, incoming_world_id: String, players: Dictionary, epoch: int = 0, seconds: float = 0.0) -> void:
	if is_host or index < 0 or index > MAX_SYSTEM_INDEX or players.size() > MAX_PLAYERS or not _valid_world_id(incoming_world_id) or not _valid_ephemeris(seconds):
		return
	var validated: Dictionary = {}
	for key: Variant in players:
		var id := int(key)
		var player: Variant = players[key]
		var normalized_profile := _normalize_presence(player)
		if id <= 0 or not normalized_profile.ok:
			return
		validated[id] = normalized_profile.profile
	system_index = index
	world_id = incoming_world_id
	world_seed = seed
	ephemeris_seconds = seconds
	_pvp_epoch = epoch
	presence = validated
	connected = true
	var local_id := multiplayer.get_unique_id()
	presence[local_id] = _make_presence(Vector3.ZERO, Vector3.ZERO, ship_modules, ship_layout, display_name)
	peers_changed.emit()
	ephemeris_received.emit(ephemeris_seconds)
	world_joined.emit(system_index)
	session_message.emit("Joined system %d." % system_index)


@rpc("authority", "call_remote", "reliable")
func _rpc_reject(reason: String) -> void:
	if reason.length() > 160:
		reason = "Host rejected the join request."
	session_message.emit(reason)
	leave()


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_presence(peer_id: int, profile: Dictionary, epoch: int = 0) -> void:
	if is_host or not connected or epoch != _pvp_epoch or peer_id <= 0 or peer_id > 0x7fffffff:
		return
	var normalized_profile := _normalize_presence(profile)
	if not normalized_profile.ok: return
	# Consent has its own reliable stream; a delayed pose cannot restore an old choice.
	if presence.has(peer_id): normalized_profile.profile.pvp = presence[peer_id].get("pvp", false)
	if peer_id == multiplayer.get_unique_id():
		normalized_profile.profile.pvp = normalized_profile.profile.pvp and _local_pvp_allowed
		normalized_profile.profile.flying = _local_flying
	presence[peer_id] = normalized_profile.profile
	peers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_peer_left(peer_id: int) -> void:
	if is_host:
		return
	if presence.erase(peer_id):
		peers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_world_joined(index: int, seed: int, incoming_world_id: String, epoch: int = 0, seconds: float = 0.0) -> void:
	if is_host or not connected or index < 0 or index > MAX_SYSTEM_INDEX or not _valid_world_id(incoming_world_id) or incoming_world_id != world_id or not _valid_ephemeris(seconds):
		return
	system_index = index
	world_seed = seed
	ephemeris_seconds = seconds
	_pvp_epoch = epoch
	_reset_pvp()
	ephemeris_received.emit(ephemeris_seconds)
	world_joined.emit(system_index)


@rpc("authority", "call_remote", "reliable")
func _rpc_clock(seconds: float) -> void:
	if is_host or not connected or not _valid_ephemeris(seconds): return
	ephemeris_seconds = seconds
	ephemeris_received.emit(seconds)


func _valid_ephemeris(seconds: float) -> bool:
	return is_finite(seconds) and seconds >= 0.0 and seconds <= GameState.MAX_EPHEMERIS_SECONDS


func _make_presence(pos: Vector3, rot: Vector3, modules: Array, layout: Dictionary, player_name: String, address: Dictionary = {}) -> Dictionary:
	var safe_address: Dictionary = address.duplicate(true) if not address.is_empty() and SectorPosition.from_save(address) != null else SectorPosition.new(Vector3i.ZERO, pos).to_save()
	return {"position": pos, "rotation": rot, "address": safe_address, "ship_modules": modules.duplicate(true), "ship_layout": layout.duplicate(true), "name": _sanitize_name(player_name), "pvp": false, "flying": false}


func _valid_presence(value: Variant) -> bool:
	return _normalize_presence(value).ok


func _normalize_presence(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() < 4 or value.size() > 8 or not value.has_all(["position", "rotation", "name", "ship_modules"]):
		return {"ok": false}
	for key: Variant in value:
		if not str(key) in ["position", "rotation", "name", "ship_modules", "ship_layout", "address", "pvp", "flying"]: return {"ok": false}
	if not value.position is Vector3 or not value.rotation is Vector3 or not _valid_vector(value.position, MAX_WORLD_COORD) or not _valid_rotation(value.rotation):
		return {"ok": false}
	if not value.name is String or str(value.name).length() > 20 or not value.ship_modules is Array or value.ship_modules.size() > MAX_MODULES:
		return {"ok": false}
	if not value.get("pvp", false) is bool or not value.get("flying", false) is bool:
		return {"ok": false}
	var modules := _normalize_modules(value.ship_modules)
	if not modules.ok: return {"ok": false}
	var raw_layout: Variant = value.get("ship_layout", ShipLayoutScript.empty_data())
	var layout := _normalize_layout(raw_layout, modules.modules)
	if not layout.ok: return {"ok": false}
	var raw_address: Variant = value.get("address", SectorPosition.new(Vector3i.ZERO, value.position).to_save())
	var address: Variant = SectorPosition.from_save(raw_address)
	if address == null: return {"ok": false}
	return {"ok": true, "profile": {"position": value.position, "rotation": value.rotation, "address": address.to_save(), "name": _sanitize_name(value.name), "ship_modules": modules.modules, "ship_layout": layout.layout, "pvp": value.get("pvp", false), "flying": value.get("flying", false)}}


func _normalize_layout(raw_layout: Variant, modules: Array) -> Dictionary:
	if not raw_layout is Dictionary or raw_layout.size() != 3 or not raw_layout.has_all(["version", "rooms", "panels"]):
		return {"ok": false, "error": "layout fields are invalid"}
	if not raw_layout.version is int and not raw_layout.version is float:
		return {"ok": false, "error": "layout version is invalid"}
	if not is_finite(float(raw_layout.version)) or float(raw_layout.version) != 1.0:
		return {"ok": false, "error": "layout version is invalid"}
	if not raw_layout.rooms is Dictionary or not raw_layout.panels is Dictionary or raw_layout.rooms.size() > MAX_MODULES or raw_layout.panels.size() > MAX_MODULES:
		return {"ok": false, "error": "layout exceeds limits"}
	for cell: Variant in raw_layout.rooms:
		if not cell is String or cell.length() > 16 or not raw_layout.rooms[cell] is String or raw_layout.rooms[cell].length() > 24:
			return {"ok": false, "error": "room cell key exceeds limits"}
	for cell: Variant in raw_layout.panels:
		var panels: Variant = raw_layout.panels[cell]
		if not cell is String or cell.length() > 16 or not panels is Dictionary or panels.size() > 6:
			return {"ok": false, "error": "panel cell data exceeds limits"}
		for face: Variant in panels:
			if not face is String or face.length() > 3 or not panels[face] is String or panels[face].length() > 16:
				return {"ok": false, "error": "panel value exceeds limits"}
	var normalized: Dictionary = raw_layout.duplicate(true)
	if normalized.version is float and is_finite(normalized.version) and floorf(normalized.version) == normalized.version:
		normalized.version = int(normalized.version)
	if not ShipLayoutScript.validate_data(normalized, modules):
		return {"ok": false, "error": "panel or room does not match this hull"}
	return {"ok": true, "layout": normalized, "error": ""}


func _broadcast_presence(peer_id: int, profile: Dictionary) -> void:
	for remote_id: int in multiplayer.get_peers():
		_rpc_presence.rpc_id(remote_id, peer_id, profile, _pvp_epoch)


func _normalize_modules(raw_modules: Array) -> Dictionary:
	if raw_modules.size() > MAX_MODULES:
		return {"ok": false, "error": "maximum is %d modules" % MAX_MODULES}
	var result: Array[Dictionary] = []
	var cells: Dictionary = {}
	for item: Variant in raw_modules:
		if not item is Dictionary:
			return {"ok": false, "error": "module entries must be objects"}
		if item.size() != 4 or not item.has_all(["kind", "x", "y", "z"]):
			return {"ok": false, "error": "module entries need kind and integer x/y/z"}
		var kind := str(item.get("kind", ""))
		if not MODULE_KINDS.has(kind):
			return {"ok": false, "error": "unknown module kind"}
		var coords: Array[int] = []
		for axis: String in ["x", "y", "z"]:
			var coordinate: Variant = item.get(axis, null)
			if not coordinate is int and not coordinate is float:
				return {"ok": false, "error": "module coordinates must be integers"}
			var numeric := float(coordinate)
			if not is_finite(numeric) or numeric < -16.0 or numeric > 16.0 or floorf(numeric) != numeric:
				return {"ok": false, "error": "module coordinates must be integers from -16 to 16"}
			coords.append(int(numeric))
		var key := Vector3i(coords[0], coords[1], coords[2])
		if cells.has(key):
			return {"ok": false, "error": "module cells must be unique"}
		cells[key] = true
		result.append({"kind": kind, "x": key.x, "y": key.y, "z": key.z})
	return {"ok": true, "modules": result, "error": ""}


func _sanitize_name(raw_name: String) -> String:
	var cleaned := ""
	for character: String in raw_name.strip_edges():
		var code := character.unicode_at(0)
		if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or character in [" ", "_", "-"]:
			cleaned += character
		if cleaned.length() >= 20:
			break
	cleaned = cleaned.strip_edges()
	return cleaned if not cleaned.is_empty() else "Pilot"


func _valid_vector(value: Vector3, limit: float) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z) and absf(value.x) <= limit and absf(value.y) <= limit and absf(value.z) <= limit


func _valid_rotation(value: Vector3) -> bool:
	return _valid_vector(value, 1000000.0)


func _seed_for(index: int) -> int:
	# Matches the deterministic station seed used by Universe.system_data().
	return int(Universe.system_data(index).station_seed)


func _valid_world_id(value: String) -> bool:
	if value.length() != 32:
		return false
	for character: String in value:
		if not ((character >= "0" and character <= "9") or (character >= "a" and character <= "f")):
			return false
	return true


func _reset_pvp() -> void:
	_local_pvp_allowed = false
	_local_flying = false
	_last_pose_msec = -1000
	_last_remote_pose_msec.clear()
	_last_pvp_shot_msec.clear()
	for id: int in presence:
		presence[id].pvp = false
		presence[id].flying = false
	peers_changed.emit()


func is_pvp_allowed() -> bool:
	return connected and _local_pvp_allowed


func set_pvp_allowed(allowed: bool) -> void:
	if not connected: return
	_local_pvp_allowed = allowed
	var id := multiplayer.get_unique_id()
	# Immediate local revocation cannot be undone by an in-flight host echo.
	if not allowed and presence.has(id): presence[id].pvp = false
	if is_host:
		_accept_pvp_consent(id, allowed)
	else:
		_rpc_pvp_consent.rpc_id(1, allowed, _pvp_epoch)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_pvp_consent(allowed: bool, epoch: int) -> void:
	if not is_host or not connected or epoch != _pvp_epoch: return
	_accept_pvp_consent(multiplayer.get_remote_sender_id(), allowed)


func _accept_pvp_consent(id: int, allowed: bool) -> void:
	if not presence.has(id): return
	presence[id].pvp = allowed
	for remote_id: int in multiplayer.get_peers():
		_rpc_pvp_consent_changed.rpc_id(remote_id, id, allowed, _pvp_epoch)
	peers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_pvp_consent_changed(id: int, allowed: bool, epoch: int) -> void:
	if not connected or epoch != _pvp_epoch or not presence.has(id): return
	presence[id].pvp = allowed and (id != multiplayer.get_unique_id() or _local_pvp_allowed)
	peers_changed.emit()


func request_pvp_shot(direction: Vector3) -> void:
	if not connected or not _local_pvp_allowed: return
	if is_host:
		_accept_pvp_shot(multiplayer.get_unique_id(), direction)
	else:
		_rpc_pvp_shot.rpc_id(1, direction, _pvp_epoch)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_pvp_shot(direction: Vector3, epoch: int) -> void:
	if not is_host or not connected or epoch != _pvp_epoch: return
	_accept_pvp_shot(multiplayer.get_remote_sender_id(), direction)


func _fresh_flight_profile(id: int, now: int) -> bool:
	if not presence.has(id) or not presence[id].get("pvp", false) or not presence[id].get("flying", false): return false
	var stamp: int = _last_pose_msec if id == multiplayer.get_unique_id() else int(_last_remote_pose_msec.get(id, -10000))
	return now - stamp >= 0 and now - stamp <= 1000


func _accept_pvp_shot(attacker: int, direction: Vector3) -> void:
	if not is_host or not connected: return
	var now := Time.get_ticks_msec()
	if not _fresh_flight_profile(attacker, now) or now - int(_last_pvp_shot_msec.get(attacker, -1000)) < 180: return
	_last_pvp_shot_msec[attacker] = now
	var candidates: Dictionary = {}
	for id: int in presence:
		if id == attacker: continue
		candidates[id] = presence[id].duplicate(true)
		if not _fresh_flight_profile(id, now): candidates[id].pvp = false
	var hit: Dictionary = PvPHits.trace(presence[attacker], candidates, direction)
	if hit.is_empty() or not pvp_occlusion_check.is_valid(): return
	var target: int = hit.target
	if not pvp_occlusion_check.call(attacker, target, direction, float(hit.distance)): return
	var origin: Variant = SectorPosition.from_save(presence[attacker].get("address"))
	var distance := float(hit.distance)
	if origin == null or not is_finite(distance) or distance < 0.0 or distance > PvPHits.RANGE: return
	if not origin.move_delta(PvPHits.CAMERA_OFFSET): return
	var end_position: SectorPosition = origin.clone()
	if not end_position.move_delta(direction.normalized() * distance): return
	var origin_data: Dictionary = origin.to_save()
	var end_data: Dictionary = end_position.to_save()
	_rpc_pvp_hit_confirmed.rpc(attacker, target, origin_data, end_data, _pvp_epoch)
	_receive_pvp_hit_confirmed(attacker, target, origin_data, end_data, _pvp_epoch)
	if target == multiplayer.get_unique_id():
		_receive_pvp_damage(attacker, float(hit.damage), _pvp_epoch)
	else:
		_rpc_pvp_damage.rpc_id(target, attacker, float(hit.damage), _pvp_epoch)


@rpc("authority", "call_remote", "reliable")
func _rpc_pvp_hit_confirmed(attacker: int, target: int, origin_data: Dictionary, end_data: Dictionary, epoch: int) -> void:
	_receive_pvp_hit_confirmed(attacker, target, origin_data, end_data, epoch)


func _receive_pvp_hit_confirmed(attacker: int, target: int, origin_data: Dictionary, end_data: Dictionary, epoch: int) -> void:
	if not connected or epoch != _pvp_epoch or attacker == target: return
	if not presence.has(attacker) or not presence.has(target): return
	var origin: Variant = SectorPosition.from_save(origin_data)
	var end_position: Variant = SectorPosition.from_save(end_data)
	if origin == null or end_position == null: return
	var distance: Variant = end_position.relative_to(origin, PvPHits.RANGE + 0.1)
	if distance == null or not distance.is_finite() or distance.length() > PvPHits.RANGE + 0.1: return
	pvp_hit_confirmed.emit(attacker, target, origin_data.duplicate(true), end_data.duplicate(true))


@rpc("authority", "call_remote", "reliable")
func _rpc_pvp_damage(attacker: int, damage: float, epoch: int) -> void:
	_receive_pvp_damage(attacker, damage, epoch)


func _receive_pvp_damage(attacker: int, damage: float, epoch: int) -> void:
	var local_id := multiplayer.get_unique_id()
	if not connected or epoch != _pvp_epoch or not _local_pvp_allowed or not _local_flying: return
	if attacker == local_id or not presence.has(attacker) or not is_finite(damage) or damage <= 0.0: return
	pvp_damage_received.emit(attacker, damage)
