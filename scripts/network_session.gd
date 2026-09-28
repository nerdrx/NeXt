class_name NetworkSession
extends Node

signal world_joined(system_index: int)
signal ephemeris_received(seconds: float)
signal peers_changed
signal session_message(message: String)
signal steam_invitation_ready(lobby_id: int)
signal pvp_damage_received(attacker: int, damage: float)
signal pvp_hit_confirmed(attacker: int, target: int, origin_data: Dictionary, end_data: Dictionary)
signal npc_ships_received(records: Array)
signal npc_shot_requested(attacker: int, direction: Vector3, damage: float)
signal npc_hit_received(faction: String, killed: bool, assault: bool)

# Increment when wire payloads or shared simulation contracts become incompatible.
const PROTOCOL_VERSION: int = 3
const JOIN_TIMEOUT: float = 20.0
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
var visitors_open: bool = true

var _peer: MultiplayerPeer
var _steam_session: SteamSession
var _join_sent: bool = false
var _join_remaining: float = 0.0
var _last_pose_msec: int = 0
var _last_clock_sent_msec: int = -1000
var _last_npc_publish_msec: int = -1000
var _last_remote_pose_msec: Dictionary = {}
var _last_pvp_shot_msec: Dictionary = {}
var _last_npc_shot_msec: Dictionary = {}
var _pending_systems_online: Dictionary = {}
var _pvp_epoch: int = 0
var _local_pvp_allowed: bool = false
var _local_flying: bool = false
var _local_systems_online: bool = true
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
	visitors_open = true
	_peer.refuse_new_connections = false
	system_index = clampi(system_index, 0, MAX_SYSTEM_INDEX)
	world_seed = _seed_for(system_index)
	_last_clock_sent_msec = -1000
	var local_id := multiplayer.get_unique_id()
	presence.clear()
	presence[local_id] = _make_presence(Vector3.ZERO, Vector3.ZERO, ship_modules, ship_layout, display_name)
	presence[local_id].systems_online = _local_systems_online
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
	_join_remaining = JOIN_TIMEOUT
	presence.clear()
	_pending_systems_online.clear()
	_last_remote_pose_msec.clear()
	_last_pvp_shot_msec.clear()
	_last_npc_shot_msec.clear()
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
	visitors_open = true
	_join_sent = false
	_join_remaining = 0.0
	presence.clear()
	_pending_systems_online.clear()
	_last_remote_pose_msec.clear()
	_last_pvp_shot_msec.clear()
	_last_npc_shot_msec.clear()
	_local_pvp_allowed = false
	_local_flying = false
	_last_pose_msec = -1000
	_last_clock_sent_msec = -1000
	_last_npc_publish_msec = -1000
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
	var id := multiplayer.get_unique_id()
	var profile: Dictionary = presence.get(id, _make_presence(Vector3.ZERO, Vector3.ZERO, normalized.modules, normalized_layout.layout, display_name))
	if not _same_loadout(profile, normalized.modules, normalized_layout.layout): return
	ship_modules = normalized.modules
	ship_layout = normalized_layout.layout
	_local_flying = flying
	if presence.has(id): presence[id].flying = flying
	var now := Time.get_ticks_msec()
	if now - _last_pose_msec < 50:
		return
	_last_pose_msec = now
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


func publish_npc_ships(records: Array) -> void:
	if not is_host or not connected: return
	var snapshot := _validate_npc_snapshot(records)
	if not snapshot.ok: return
	var now := Time.get_ticks_msec()
	if now - _last_npc_publish_msec < 100: return
	_last_npc_publish_msec = now
	_rpc_npc_ships.rpc(snapshot.records, _pvp_epoch)


func travel(index: int) -> String:
	if not is_host or not connected:
		return "Only the host can change systems."
	if index < 0 or index > MAX_SYSTEM_INDEX:
		return "System address is out of range."
	system_index = index
	world_seed = _seed_for(index)
	_pvp_epoch += 1
	_last_npc_publish_msec = -1000
	_last_npc_shot_msec.clear()
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


func _on_peer_connected(peer_id: int) -> void:
	# An unadmitted transport must not hold a host slot indefinitely.
	if is_host: _disconnect_unadmitted(peer_id, JOIN_TIMEOUT)


func _process(delta: float) -> void:
	if is_host or connected or _peer == null: return
	_join_remaining = maxf(0.0, _join_remaining - delta)
	if _join_remaining == 0.0:
		session_message.emit("Host did not complete a compatible join handshake.")
		leave()


func _disconnect_unadmitted(peer_id: int, delay: float) -> void:
	var transport := _peer
	get_tree().create_timer(delay).timeout.connect(func():
		if _peer == transport and _peer != null and is_host and not presence.has(peer_id) and peer_id in multiplayer.get_peers():
			_peer.disconnect_peer(peer_id))


func _reject_join(peer_id: int, reason: String) -> void:
	_rpc_reject.rpc_id(peer_id, reason)
	# Give the reliable explanation time to flush before transport removal.
	_disconnect_unadmitted(peer_id, 0.2)


func _on_peer_disconnected(peer_id: int) -> void:
	_last_remote_pose_msec.erase(peer_id)
	_last_pvp_shot_msec.erase(peer_id)
	_last_npc_shot_msec.erase(peer_id)
	_pending_systems_online.erase(peer_id)
	if is_host:
		if presence.erase(peer_id):
			for remote_id: int in multiplayer.get_peers():
				if remote_id != peer_id: _rpc_peer_left.rpc_id(remote_id, peer_id)
			peers_changed.emit()
	elif peer_id != 1 and presence.erase(peer_id):
		peers_changed.emit()
		session_message.emit("A peer disconnected.")


func _on_connected_to_server() -> void:
	if _join_sent or _peer == null:
		return
	_join_sent = true
	_rpc_join_request.rpc_id(1, _sanitize_name(display_name), ship_modules.duplicate(true), ship_layout.duplicate(true), PROTOCOL_VERSION)


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
func _rpc_join_request(raw_name: String, raw_modules: Array, raw_layout: Variant, protocol: int = 0) -> void:
	if not is_host or not connected:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or sender > 0x7fffffff or presence.has(sender) or presence.size() >= MAX_PLAYERS:
		return
	if protocol != PROTOCOL_VERSION:
		_reject_join(sender, "Incompatible NeXt multiplayer protocol. Update both games to matching versions.")
		return
	if not visitors_open:
		_reject_join(sender, "The host has closed this world to new visitors.")
		return
	if raw_name.length() > 64 or raw_modules.size() > MAX_MODULES or not raw_layout is Dictionary or raw_layout.size() > 3:
		_reject_join(sender, "Join data is too large.")
		return
	var normalized := _normalize_modules(raw_modules)
	if not normalized.ok:
		_reject_join(sender, "Invalid ship design: %s" % normalized.error)
		return
	var normalized_layout := _normalize_layout(raw_layout, normalized.modules)
	if not normalized_layout.ok:
		_reject_join(sender, "Invalid ship layout: %s" % normalized_layout.error)
		return
	var safe_name := _sanitize_name(raw_name)
	var profile := _make_presence(Vector3.ZERO, Vector3.ZERO, normalized.modules, normalized_layout.layout, safe_name)
	presence[sender] = profile
	_rpc_welcome.rpc_id(sender, system_index, world_seed, world_id, presence.duplicate(true), _pvp_epoch, ephemeris_seconds, PROTOCOL_VERSION)
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
	var profile: Dictionary = presence[sender]
	if not _same_loadout(profile, normalized.modules, normalized_layout.layout): return
	var now := Time.get_ticks_msec()
	if now - int(_last_remote_pose_msec.get(sender, 0)) < 50:
		return
	_last_remote_pose_msec[sender] = now
	profile.flying = flying
	profile.position = position
	profile.rotation = rotation
	profile.address = address.to_save()
	profile.ship_modules = normalized.modules
	profile.ship_layout = normalized_layout.layout
	presence[sender] = profile
	_broadcast_presence(sender, profile)
	peers_changed.emit()


func _same_loadout(profile: Dictionary, modules: Array, layout: Dictionary) -> bool:
	if not profile.has("ship_modules") or not profile.has("ship_layout") or profile.ship_layout != layout:
		return false
	var saved: Dictionary = {}
	for module: Dictionary in profile.ship_modules:
		saved[Vector3i(int(module.x), int(module.y), int(module.z))] = str(module.kind)
	if saved.size() != modules.size(): return false
	for module: Dictionary in modules:
		if saved.get(Vector3i(int(module.x), int(module.y), int(module.z)), "") != str(module.kind):
			return false
	return true


@rpc("authority", "call_remote", "reliable")
func _rpc_welcome(index: int, seed: int, incoming_world_id: String, players: Dictionary, epoch: int = 0, seconds: float = 0.0, protocol: int = 0) -> void:
	if not is_host and protocol != PROTOCOL_VERSION:
		session_message.emit("Incompatible NeXt multiplayer protocol. Update both games to matching versions.")
		leave()
		return
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
	_join_remaining = 0.0
	connected = true
	var local_id := multiplayer.get_unique_id()
	presence[local_id] = _make_presence(Vector3.ZERO, Vector3.ZERO, ship_modules, ship_layout, display_name)
	presence[local_id].systems_online = _local_systems_online
	_rpc_systems_online.rpc_id(1, local_id, _local_systems_online, _pvp_epoch)
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
	# Power state has its own reliable stream too; pose snapshots may be stale.
	if presence.has(peer_id): normalized_profile.profile.systems_online = presence[peer_id].get("systems_online", true)
	if peer_id == multiplayer.get_unique_id():
		normalized_profile.profile.pvp = normalized_profile.profile.pvp and _local_pvp_allowed
		normalized_profile.profile.flying = _local_flying
		normalized_profile.profile.systems_online = _local_systems_online
	elif _pending_systems_online.has(peer_id):
		normalized_profile.profile.systems_online = _pending_systems_online[peer_id]
		_pending_systems_online.erase(peer_id)
	presence[peer_id] = normalized_profile.profile
	peers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_peer_left(peer_id: int) -> void:
	if is_host:
		return
	_pending_systems_online.erase(peer_id)
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
	# A toggle sent just before travel may have carried the previous epoch.
	_rpc_systems_online.rpc_id(1, multiplayer.get_unique_id(), _local_systems_online, _pvp_epoch)
	ephemeris_received.emit(ephemeris_seconds)
	world_joined.emit(system_index)


@rpc("authority", "call_remote", "reliable")
func _rpc_clock(seconds: float) -> void:
	if is_host or not connected or not _valid_ephemeris(seconds): return
	ephemeris_seconds = seconds
	ephemeris_received.emit(seconds)


func _valid_ephemeris(seconds: float) -> bool:
	return is_finite(seconds) and seconds >= 0.0 and seconds <= GameState.MAX_EPHEMERIS_SECONDS


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_npc_ships(records: Array, epoch: int) -> void:
	if is_host or not connected or epoch != _pvp_epoch: return
	var snapshot := _validate_npc_snapshot(records)
	if snapshot.ok: npc_ships_received.emit(snapshot.records)


func _validate_npc_snapshot(records: Variant) -> Dictionary:
	if not records is Array or records.size() > 7: return {"ok": false}
	var known_factions := {"raider_0": "pirate", "raider_1": "pirate", "raider_2": "pirate", "raider_3": "pirate", "raider_4": "pirate", "security_0": "police", "security_1": "police"}
	var seen: Dictionary = {}
	var normalized: Array[Dictionary] = []
	for raw: Variant in records:
		if not raw is Dictionary or raw.size() != 7 or not raw.has_all(["id", "faction", "address", "rotation", "hp", "shields", "max_shields"]): return {"ok": false}
		if not raw.id is String or not known_factions.has(raw.id) or not raw.faction is String or raw.faction != known_factions[raw.id] or seen.has(raw.id): return {"ok": false}
		var address: Variant = SectorPosition.from_save(raw.address)
		if address == null or not raw.rotation is Vector3 or not raw.rotation.is_finite(): return {"ok": false}
		for field: String in ["hp", "shields", "max_shields"]:
			if not _finite_number(raw[field]): return {"ok": false}
		var hp := float(raw.hp)
		var shields := float(raw.shields)
		var max_shields := float(raw.max_shields)
		if hp < 0.0 or hp > 100.0 or shields < 0.0 or shields > 1000000.0 or max_shields < 0.0 or max_shields > 1000000.0 or shields > max_shields: return {"ok": false}
		seen[raw.id] = true
		normalized.append({"id": raw.id, "faction": raw.faction, "address": address.to_save(), "rotation": raw.rotation, "hp": hp, "shields": shields, "max_shields": max_shields})
	return {"ok": true, "records": normalized}


func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _make_presence(pos: Vector3, rot: Vector3, modules: Array, layout: Dictionary, player_name: String, address: Dictionary = {}) -> Dictionary:
	var safe_address: Dictionary = address.duplicate(true) if not address.is_empty() and SectorPosition.from_save(address) != null else SectorPosition.new(Vector3i.ZERO, pos).to_save()
	return {"position": pos, "rotation": rot, "address": safe_address, "ship_modules": modules.duplicate(true), "ship_layout": layout.duplicate(true), "name": _sanitize_name(player_name), "pvp": false, "flying": false, "systems_online": true}


func _valid_presence(value: Variant) -> bool:
	return _normalize_presence(value).ok


func _normalize_presence(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() < 4 or value.size() > 9 or not value.has_all(["position", "rotation", "name", "ship_modules"]):
		return {"ok": false}
	for key: Variant in value:
		if not str(key) in ["position", "rotation", "name", "ship_modules", "ship_layout", "address", "pvp", "flying", "systems_online"]: return {"ok": false}
	if not value.position is Vector3 or not value.rotation is Vector3 or not _valid_vector(value.position, MAX_WORLD_COORD) or not _valid_rotation(value.rotation):
		return {"ok": false}
	if not value.name is String or str(value.name).length() > 20 or not value.ship_modules is Array or value.ship_modules.size() > MAX_MODULES:
		return {"ok": false}
	if not value.get("pvp", false) is bool or not value.get("flying", false) is bool or not value.get("systems_online", true) is bool:
		return {"ok": false}
	var modules := _normalize_modules(value.ship_modules)
	if not modules.ok: return {"ok": false}
	var raw_layout: Variant = value.get("ship_layout", ShipLayoutScript.empty_data())
	var layout := _normalize_layout(raw_layout, modules.modules)
	if not layout.ok: return {"ok": false}
	var raw_address: Variant = value.get("address", SectorPosition.new(Vector3i.ZERO, value.position).to_save())
	var address: Variant = SectorPosition.from_save(raw_address)
	if address == null: return {"ok": false}
	return {"ok": true, "profile": {"position": value.position, "rotation": value.rotation, "address": address.to_save(), "name": _sanitize_name(value.name), "ship_modules": modules.modules, "ship_layout": layout.layout, "pvp": value.get("pvp", false), "flying": value.get("flying", false), "systems_online": value.get("systems_online", true)}}


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
	_pending_systems_online.clear()
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


func set_systems_online(online: bool) -> void:
	if _local_systems_online == online: return
	_local_systems_online = online
	if not connected: return
	var id := multiplayer.get_unique_id()
	if presence.has(id): presence[id].systems_online = online
	if is_host:
		_accept_systems_online(id, online)
	else:
		_rpc_systems_online.rpc_id(1, id, online, _pvp_epoch)
	peers_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_systems_online(peer_id: int, online: bool, epoch: int) -> void:
	if not connected or epoch != _pvp_epoch or peer_id <= 0 or peer_id > 0x7fffffff: return
	if is_host:
		if multiplayer.get_remote_sender_id() != peer_id or not presence.has(peer_id): return
		_accept_systems_online(peer_id, online)
	else:
		if multiplayer.get_remote_sender_id() != 1: return
		if peer_id == multiplayer.get_unique_id():
			if presence.has(peer_id): presence[peer_id].systems_online = _local_systems_online
		elif presence.has(peer_id):
			presence[peer_id].systems_online = online
		else:
			if _pending_systems_online.size() < MAX_PLAYERS or _pending_systems_online.has(peer_id):
				_pending_systems_online[peer_id] = online
		peers_changed.emit()


func _accept_systems_online(peer_id: int, online: bool) -> void:
	if not presence.has(peer_id): return
	presence[peer_id].systems_online = online
	for remote_id: int in multiplayer.get_peers():
		_rpc_systems_online.rpc_id(remote_id, peer_id, online, _pvp_epoch)
	peers_changed.emit()


func request_pvp_shot(direction: Vector3) -> void:
	if not connected or not _local_pvp_allowed or not _local_systems_online: return
	if is_host:
		_accept_pvp_shot(multiplayer.get_unique_id(), direction)
	else:
		_rpc_pvp_shot.rpc_id(1, direction, _pvp_epoch)


func request_npc_shot(direction: Vector3) -> void:
	if is_host or not connected or not _local_systems_online: return
	_rpc_npc_shot.rpc_id(1, direction, _pvp_epoch)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_npc_shot(direction: Vector3, epoch: int) -> void:
	if not is_host or not connected or epoch != _pvp_epoch: return
	_accept_npc_shot(multiplayer.get_remote_sender_id(), direction)


func _accept_npc_shot(attacker: int, direction: Vector3) -> void:
	if not is_host or not connected or attacker <= 1 or not presence.has(attacker): return
	var profile: Dictionary = presence[attacker]
	if not profile.get("flying", false) or not profile.get("systems_online", true): return
	var now := Time.get_ticks_msec()
	var stamp := int(_last_remote_pose_msec.get(attacker, -10000))
	if now - stamp < 0 or now - stamp > 1000 or now - int(_last_npc_shot_msec.get(attacker, -1000)) < 180: return
	if not direction.is_finite() or not is_finite(direction.length_squared()) or direction.length_squared() < 0.000001: return
	var model := GameState.new()
	model.ship_modules.assign(profile.get("ship_modules", []))
	var damage := float(model.ship_stats().damage)
	if not is_finite(damage) or damage <= 0.0: return
	_last_npc_shot_msec[attacker] = now
	npc_shot_requested.emit(attacker, direction.normalized(), damage)


func confirm_npc_hit(attacker: int, faction: String, killed: bool, assault: bool) -> void:
	if not is_host or not connected or attacker <= 1 or not presence.has(attacker): return
	if faction not in ["pirate", "police"] or (assault and faction != "police"): return
	_rpc_npc_hit_confirmed.rpc_id(attacker, faction, killed, assault, _pvp_epoch)


@rpc("authority", "call_remote", "reliable")
func _rpc_npc_hit_confirmed(faction: String, killed: bool, assault: bool, epoch: int) -> void:
	if is_host or not connected or epoch != _pvp_epoch: return
	if faction not in ["pirate", "police"] or (assault and faction != "police"): return
	npc_hit_received.emit(faction, killed, assault)


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
	if not presence.has(attacker) or not presence[attacker].get("systems_online", true): return
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


func set_visitors_open(allowed: bool) -> String:
	if not connected or not is_host or _peer == null: return "Only the connected host can change admission."
	visitors_open = allowed
	_peer.refuse_new_connections = not allowed
	session_message.emit("World open to new visitors." if allowed else "New visits closed; current visitors may remain.")
	return ""

func remove_visitor(peer_id: int) -> String:
	if not connected or not is_host or _peer == null: return "Only the connected host can remove a visitor."
	if peer_id <= 1 or not presence.has(peer_id): return "Select a connected visitor."
	# Forced transport removal does not emit peer_disconnected; clear and broadcast explicitly.
	_peer.disconnect_peer(peer_id, true)
	_on_peer_disconnected(peer_id)
	session_message.emit("Visitor removed. Close new visits to prevent rejoining.")
	return ""
