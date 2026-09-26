extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const PORT: int = 27847
const SYSTEM: int = 7919
const DESIGN: Array[Dictionary] = [
	{"kind": "core", "x": 0, "y": 0, "z": 0},
	{"kind": "engine", "x": 1, "y": 0, "z": 0},
]
const HOST_LAYOUT: Dictionary = {"version": 1, "rooms": {}, "panels": {"0,0,0": {"-x": "armored"}}}
const GUEST_LAYOUT: Dictionary = {"version": 1, "rooms": {}, "panels": {"0,0,0": {"-x": "window"}}}
const GUEST_UPDATED_LAYOUT: Dictionary = {"version": 1, "rooms": {}, "panels": {"0,0,0": {"-x": "armored"}}}
const INVALID_HIDDEN_FACE: Dictionary = {"version": 1, "rooms": {}, "panels": {"0,0,0": {"+x": "armored"}}}

var session: NetworkSession
var acknowledgement: NetworkAcknowledgement
var travel_received: bool = false
var joined_indices: Array[int] = []
var joined_seeds: Array[int] = []
var joined_world_ids: Array[String] = []
var saw_both_guests: bool = false
var saw_one_guest_depart: bool = false


class NetworkAcknowledgement extends Node:
	var session: NetworkSession
	var remaining_guest_verified: bool = false
	var departure_acknowledged: bool = false

	@rpc("any_peer", "call_remote", "reliable")
	func _rpc_departure_verified() -> void:
		if not session.is_host or session.presence.size() != 2:
			return
		var sender: int = multiplayer.get_remote_sender_id()
		if sender <= 1 or not session.presence.has(sender):
			return
		remaining_guest_verified = true
		_rpc_departure_ack.rpc_id(sender)

	@rpc("authority", "call_remote", "reliable")
	func _rpc_departure_ack() -> void:
		if not session.is_host:
			departure_acknowledged = true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	session = NetworkSession.new()
	root.add_child(session)
	acknowledgement = NetworkAcknowledgement.new()
	acknowledgement.name = "NetworkAcknowledgement"
	acknowledgement.session = session
	root.add_child(acknowledgement)
	var args := OS.get_cmdline_user_args()
	var role := str(args[0]) if not args.is_empty() else "host"
	match role:
		"client": await _run_client(false)
		"leaver": await _run_client(true)
		"invalid_layout": await _run_invalid_layout_client()
		_: await _run_host()


func _run_host() -> void:
	session.display_name = "Host"
	session.system_index = 41
	session.world_id = GameStateScript.new().world_id
	var host_world_id: String = session.world_id
	session.peers_changed.connect(_on_host_peers_changed)
	session.ship_modules = DESIGN.duplicate(true)
	session.ship_layout = HOST_LAYOUT.duplicate(true)
	var error: String = session.host(PORT)
	if not error.is_empty():
		_fail("host setup: " + error)
		return
	var old_profile: Dictionary = session.presence[session.multiplayer.get_unique_id()].duplicate(true)
	old_profile.erase("ship_layout")
	if not session._valid_presence(old_profile):
		_fail("legacy presence without optional ship layout was not accepted")
		return
	var project_path := ProjectSettings.globalize_path("res://")
	var script_path := "res://tests/test_network.gd"
	for role: String in ["client", "leaver", "invalid_layout"]:
		if OS.create_process(OS.get_executable_path(), ["--headless", "--path", project_path, "-s", script_path, "--", role]) < 0:
			_fail("could not launch %s process" % role)
			return
	if not await _wait_for(func() -> bool: return session.presence.size() == 3, 8.0):
		_fail("both clients did not complete their validated joins")
		return
	var guest: Dictionary = _guest_profile()
	if guest.is_empty() or guest.name != "Guestscript" or guest.ship_modules.size() != 2 or guest.get("ship_layout", {}).get("panels", {}).get("0,0,0", {}).get("-x", "") != "window":
		_fail("host did not receive the sanitized name and ship design")
		return
	if session.presence[1].get("ship_layout", {}).get("panels", {}).get("0,0,0", {}).get("-x", "") != "armored":
		_fail("host presence omitted its validated hull panel")
		return
	if session.travel(SYSTEM) != "":
		_fail("host could not initiate travel")
		return
	if session.world_id != host_world_id:
		_fail("host travel changed world identity")
	if not await _wait_for(func() -> bool: return _guest_profile().get("position", Vector3.ZERO).is_equal_approx(Vector3(13, 4, 5)), 6.0):
		_fail("guest pose was not relayed after shared travel")
		return
	if _guest_profile().get("ship_layout", {}).get("panels", {}).get("0,0,0", {}).get("-x", "") != "armored":
		_fail("edited guest panel did not reach the host with pose presence")
		return
	if not await _wait_for(func() -> bool: return saw_one_guest_depart, 6.0):
		_fail("leaving guest was not removed from host presence")
		return
	if not await _wait_for(func() -> bool: return acknowledgement.remaining_guest_verified, 6.0):
		_fail("remaining guest did not acknowledge peer departure")
		return
	print("NETWORK_TEST_OK: host/join, ship layout validation and sync, world identity, pose sync, shared travel, peer departure")
	session.leave()
	quit()


func _run_client(leaves_after_travel: bool) -> void:
	session.display_name = "Guest<script>" if not leaves_after_travel else "Leaver"
	session.world_id = GameStateScript.new().world_id
	var guest_initial_id: String = session.world_id
	session.ship_modules = DESIGN.duplicate(true)
	session.ship_layout = GUEST_LAYOUT.duplicate(true)
	session.world_joined.connect(_on_world_joined)
	session.ship_modules = [{"kind": "core", "x": 17, "y": 0, "z": 0}]
	if session.join("127.0.0.1", PORT).is_empty():
		_fail("client accepted an out-of-range ship cell")
		return
	session.ship_modules = DESIGN.duplicate(true)
	session.ship_layout = INVALID_HIDDEN_FACE.duplicate(true)
	if session.join("127.0.0.1", PORT).is_empty():
		_fail("client accepted a panel placed on a hidden hull face")
		return
	session.ship_layout = GUEST_LAYOUT.duplicate(true)
	var error: String = session.join("127.0.0.1", PORT)
	if not error.is_empty():
		_fail("client setup: " + error)
		return
	if not await _wait_for(func() -> bool: return session.connected, 6.0):
		_fail("client did not receive its welcome")
		return
	if joined_indices.is_empty() or joined_indices[0] != 41 or joined_seeds[0] != int(Universe.system_data(41).station_seed):
		_fail("welcome system or deterministic seed mismatch")
		return
	if session.world_id == guest_initial_id or not _valid_world_id(session.world_id) or joined_world_ids[0] != session.world_id:
		_fail("welcome did not replace the guest's ID with the host's ID")
		return
	var hosted_layout: Dictionary = session.presence.get(1, {}).get("ship_layout", {})
	if hosted_layout.get("panels", {}).get("0,0,0", {}).get("-x", "") != "armored":
		_fail("client welcome omitted the host's validated hull panel")
		return
	if not await _wait_for(func() -> bool: return session.presence.size() == 3, 6.0):
		_fail("host and both guests did not converge in presence")
		return
	if not await _wait_for(func() -> bool: return travel_received, 6.0):
		_fail("client did not receive the host's travel event")
		return
	if session.system_index != SYSTEM or session.world_seed != int(Universe.system_data(SYSTEM).station_seed):
		_fail("travel system or seed mismatch")
		return
	if session.world_id != joined_world_ids[0] or joined_world_ids.size() < 2 or joined_world_ids[1] != session.world_id:
		_fail("travel changed the shared world identity")
		return
	if leaves_after_travel:
		await create_timer(0.15).timeout
		session.leave()
		await create_timer(0.3).timeout
		quit()
		return
	if not await _wait_for(func() -> bool: return session.presence.size() == 2, 6.0):
		_fail("remaining guest lost the departed peer")
		return
	if not session.connected or not session.presence.has(1):
		_fail("disconnecting another guest ended the session")
		return
	acknowledgement._rpc_departure_verified.rpc_id(1)
	if not await _wait_for(func() -> bool: return acknowledgement.departure_acknowledged, 3.0):
		_fail("host did not acknowledge peer-departure verification")
		return
	session.leave()
	quit()


func _run_invalid_layout_client() -> void:
	session.display_name = "InvalidLayout"
	session.ship_modules = DESIGN.duplicate(true)
	session.ship_layout = GUEST_LAYOUT.duplicate(true)
	var messages: Array[String] = []
	session.session_message.connect(func(message: String) -> void: messages.append(message))
	var error: String = session.join("127.0.0.1", PORT)
	if not error.is_empty():
		_fail("invalid-layout test client could not connect: " + error)
		return
	# Replace the already locally validated layout before the asynchronous join RPC.
	session.ship_layout = INVALID_HIDDEN_FACE.duplicate(true)
	if not await _wait_for(func() -> bool:
		for message: String in messages:
			if message.contains("Invalid ship layout"): return true
		return false, 6.0):
		_fail("host admitted an invalid hidden-face panel")
		return
	if session.connected or not session.presence.is_empty():
		_fail("rejected layout client acquired host presence")
		return
	print("NETWORK_INVALID_LAYOUT_OK: host rejected hidden-face panel from join RPC")
	session.leave()
	quit()


func _on_world_joined(index: int) -> void:
	joined_indices.append(index)
	joined_seeds.append(session.world_seed)
	joined_world_ids.append(session.world_id)
	if index == SYSTEM:
		travel_received = true
		if session.display_name == "Guestscript":
			session.ship_layout = GUEST_UPDATED_LAYOUT.duplicate(true)
			session.publish_pose(Vector3(13, 4, 5), Vector3.ZERO)


func _guest_profile() -> Dictionary:
	for value: Variant in session.presence.values():
		if value is Dictionary and value.get("name") == "Guestscript":
			return value
	return {}


func _on_host_peers_changed() -> void:
	if not session.is_host:
		return
	if session.presence.size() == 3:
		saw_both_guests = true
	elif saw_both_guests and session.presence.size() == 2:
		saw_one_guest_depart = true


func _wait_for(condition: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if condition.call():
			return true
		await create_timer(0.05).timeout
		elapsed += 0.05
	return condition.call()


func _valid_world_id(value: String) -> bool:
	if value.length() != 32:
		return false
	for character: String in value:
		if not ((character >= "0" and character <= "9") or (character >= "a" and character <= "f")):
			return false
	return true


func _fail(message: String) -> void:
	push_error("NETWORK_TEST_FAILED: " + message)
	if session != null:
		session.leave()
	quit(1)
