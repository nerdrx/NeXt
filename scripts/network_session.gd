class_name NetworkSession
extends Node

signal world_joined(system_index: int)
signal peers_changed
signal session_message(message: String)

const DEFAULT_PORT: int = 27840
const MAX_PLAYERS: int = 8
const MAX_MODULES: int = 100
const MAX_SYSTEM_INDEX: int = 999999999
const MAX_WORLD_COORD: float = 30000.0
const MODULE_KINDS: Array[String] = ["core", "cockpit", "reactor", "engine", "cargo", "weapon", "shield", "habitat"]

var system_index: int = 0
var world_id: String = ""
var world_seed: int = 0
var ship_modules: Array = []
var display_name: String = "Pilot"
var is_host: bool = false
var connected: bool = false
var presence: Dictionary = {}

var _peer: ENetMultiplayerPeer
var _join_sent: bool = false
var _last_pose_msec: int = 0
var _last_remote_pose_msec: Dictionary = {}


func _ready() -> void:
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
	ship_modules = normalized.modules
	display_name = _sanitize_name(display_name)
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		_peer = null
		return "Could not start ENet host (error %d)." % error
	multiplayer.multiplayer_peer = _peer
	is_host = true
	connected = true
	system_index = clampi(system_index, 0, MAX_SYSTEM_INDEX)
	world_seed = _seed_for(system_index)
	var local_id := multiplayer.get_unique_id()
	presence.clear()
	presence[local_id] = _make_presence(Vector3.ZERO, Vector3.ZERO, ship_modules, display_name)
	peers_changed.emit()
	session_message.emit("LAN session hosted on port %d." % port)
	return ""


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
	ship_modules = normalized.modules
	display_name = _sanitize_name(display_name)
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(host_address, port)
	if error != OK:
		_peer = null
		return "Could not connect to host (error %d)." % error
	multiplayer.multiplayer_peer = _peer
	is_host = false
	connected = false
	_join_sent = false
	presence.clear()
	_last_remote_pose_msec.clear()
	session_message.emit("Connecting to %s:%d…" % [host_address, port])
	return ""


func leave() -> void:
	var had_session := _peer != null
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected = false
	is_host = false
	_join_sent = false
	presence.clear()
	_last_remote_pose_msec.clear()
	if had_session:
		peers_changed.emit()


func publish_pose(position: Vector3, rotation: Vector3) -> void:
	if not connected or not _valid_vector(position, MAX_WORLD_COORD) or not _valid_rotation(rotation):
		return
	var now := Time.get_ticks_msec()
	if now - _last_pose_msec < 50:
		return
	_last_pose_msec = now
	var id := multiplayer.get_unique_id()
	var profile: Dictionary = presence.get(id, _make_presence(Vector3.ZERO, Vector3.ZERO, ship_modules, display_name))
	profile.position = position
	profile.rotation = rotation
	profile.ship_modules = ship_modules.duplicate(true)
	profile.name = display_name
	presence[id] = profile
	if is_host:
		_rpc_presence.rpc(id, profile)
		peers_changed.emit()
	else:
		_rpc_publish_pose.rpc_id(1, position, rotation)


func travel(index: int) -> String:
	if not is_host or not connected:
		return "Only the host can change systems."
	if index < 0 or index > MAX_SYSTEM_INDEX:
		return "System address is out of range."
	system_index = index
	world_seed = _seed_for(index)
	_rpc_world_joined.rpc(index, world_seed, world_id)
	world_joined.emit(system_index)
	session_message.emit("Traveling together to system %d." % system_index)
	return ""


func _on_peer_connected(_peer_id: int) -> void:
	# Presence is admitted only after the peer's validated join request.
	pass


func _on_peer_disconnected(peer_id: int) -> void:
	_last_remote_pose_msec.erase(peer_id)
	if is_host:
		if presence.erase(peer_id):
			_rpc_peer_left.rpc(peer_id)
			peers_changed.emit()
	elif peer_id != 1 and presence.erase(peer_id):
		peers_changed.emit()
		session_message.emit("A peer disconnected.")


func _on_connected_to_server() -> void:
	if _join_sent or _peer == null:
		return
	_join_sent = true
	_rpc_join_request.rpc_id(1, _sanitize_name(display_name), ship_modules.duplicate(true))


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
func _rpc_join_request(raw_name: String, raw_modules: Array) -> void:
	if not is_host or not connected:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or sender > 0x7fffffff or presence.has(sender) or presence.size() >= MAX_PLAYERS:
		return
	if raw_name.length() > 64 or raw_modules.size() > MAX_MODULES:
		_rpc_reject.rpc_id(sender, "Join data is too large.")
		return
	var normalized := _normalize_modules(raw_modules)
	if not normalized.ok:
		_rpc_reject.rpc_id(sender, "Invalid ship design: %s" % normalized.error)
		return
	var safe_name := _sanitize_name(raw_name)
	var profile := _make_presence(Vector3.ZERO, Vector3.ZERO, normalized.modules, safe_name)
	presence[sender] = profile
	_rpc_welcome.rpc_id(sender, system_index, world_seed, world_id, presence.duplicate(true))
	_rpc_presence.rpc(sender, profile)
	peers_changed.emit()
	session_message.emit("%s joined." % safe_name)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_publish_pose(position: Vector3, rotation: Vector3) -> void:
	if not is_host or not connected:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not presence.has(sender) or not _valid_vector(position, MAX_WORLD_COORD) or not _valid_rotation(rotation):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_remote_pose_msec.get(sender, 0)) < 50:
		return
	_last_remote_pose_msec[sender] = now
	var profile: Dictionary = presence[sender]
	profile.position = position
	profile.rotation = rotation
	presence[sender] = profile
	_rpc_presence.rpc(sender, profile)
	peers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_welcome(index: int, seed: int, incoming_world_id: String, players: Dictionary) -> void:
	if is_host or index < 0 or index > MAX_SYSTEM_INDEX or players.size() > MAX_PLAYERS or not _valid_world_id(incoming_world_id):
		return
	var validated: Dictionary = {}
	for key: Variant in players:
		var id := int(key)
		var player: Variant = players[key]
		if id <= 0 or not _valid_presence(player):
			return
		validated[id] = player
	system_index = index
	world_id = incoming_world_id
	world_seed = seed
	presence = validated
	connected = true
	var local_id := multiplayer.get_unique_id()
	presence[local_id] = _make_presence(Vector3.ZERO, Vector3.ZERO, ship_modules, display_name)
	peers_changed.emit()
	world_joined.emit(system_index)
	session_message.emit("Joined system %d." % system_index)


@rpc("authority", "call_remote", "reliable")
func _rpc_reject(reason: String) -> void:
	if reason.length() > 160:
		reason = "Host rejected the join request."
	session_message.emit(reason)
	leave()


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_presence(peer_id: int, profile: Dictionary) -> void:
	if is_host or not connected or peer_id <= 0 or peer_id > 0x7fffffff or not _valid_presence(profile):
		return
	presence[peer_id] = profile
	peers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_peer_left(peer_id: int) -> void:
	if is_host:
		return
	if presence.erase(peer_id):
		peers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_world_joined(index: int, seed: int, incoming_world_id: String) -> void:
	if is_host or not connected or index < 0 or index > MAX_SYSTEM_INDEX or not _valid_world_id(incoming_world_id) or incoming_world_id != world_id:
		return
	system_index = index
	world_seed = seed
	world_joined.emit(system_index)


func _make_presence(pos: Vector3, rot: Vector3, modules: Array, player_name: String) -> Dictionary:
	return {"position": pos, "rotation": rot, "ship_modules": modules.duplicate(true), "name": _sanitize_name(player_name)}


func _valid_presence(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if not value.get("position") is Vector3 or not value.get("rotation") is Vector3:
		return false
	if not _valid_vector(value.position, MAX_WORLD_COORD) or not _valid_rotation(value.rotation):
		return false
	if not value.get("name") is String or str(value.name).length() > 20:
		return false
	if not value.get("ship_modules") is Array:
		return false
	return _normalize_modules(value.ship_modules).ok


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
