extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const PlayerFactionScript = preload("res://scripts/player_faction.gd")

var main: Node
var home_path: String
var visit_path: String
var remote_id: String
var owns_paths: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pid_hex: String = "%08x" % OS.get_process_id()
	remote_id = "feedfacefeedfacefeedface" + pid_hex
	home_path = "user://visit-home-%d.json" % OS.get_process_id()
	visit_path = "user://visits/" + remote_id + ".json"
	if FileAccess.file_exists(home_path) or FileAccess.file_exists(visit_path):
		_fail("test save path already exists")
		return
	owns_paths = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.save_path = home_path
	main.state.day_progress = 320.0
	main.state.ephemeris_seconds = 123.0
	main.state.credits = 30000
	main.suit_health = 61.5
	if not _check(main.state.found_faction("Home Cooperative") == "", "found home faction"): return
	if not _check(main.state.faction_deposit(3000) == "", "fund home faction treasury"): return
	main.state.shares = {"NOVA": 7}
	main.state.company_name = "Home Cooperative"
	main.state.company_balance = 650
	main.state.wanted = 2
	main.state.cargo.ore = 4
	var home_faction: Dictionary = main.state.faction.duplicate(true)
	if not _check(ShipLayout.set_panel(main.state, Vector3i(0, 0, 0), "-z", "window").is_empty(), "home hull panel refit"): return
	var original_layout: Dictionary = main.state.ship_layout.duplicate(true)
	var home_credits: int = main.state.credits
	var original_modules: Array[Dictionary] = main.state.ship_modules.duplicate(true)
	var original_identity: Dictionary = main.state.ship_identity.duplicate(true)
	main.shield_delay = 4.0
	var host_state_id: String = main.state.world_id
	main.session.world_id = remote_id
	main.session.connected = true
	main.session.is_host = false
	main.session.ephemeris_seconds = 777.0
	main._visit_host(7919)
	if not _check(main.state.ephemeris_seconds == 777.0 and main.home_state.ephemeris_seconds == 123.0, "visitor adopts host physical epoch while home is paused"): return
	main.session._rpc_clock(778.0)
	if not _check(main.state.ephemeris_seconds == 778.0 and main.home_state.ephemeris_seconds == 123.0, "host clock updates only visiting state"): return
	if not _check(main.state.world_id == remote_id and main.state.system_index == 7919, "visitor profile gets host identity and location"): return
	if not _check(main.home_state != null and main.home_state.credits == home_credits and main.home_state.company_balance == 650 and main.home_state.faction == home_faction, "home economy and faction remain active in suspended home profile"): return
	if not _check(main.state.credits == 18000 and main.state.ship_modules == original_modules and main.state.cargo.ore == 4, "new visitor receives starting wallet plus carried ship and cargo"): return
	if not _check(main.state.faction == PlayerFactionScript.empty_data(), "new visitor starts with a separate faction and treasury"): return
	if not _check(main.state.ship_layout == original_layout, "room and hull refits travel with incoming ship"): return
	if not _check(main.state.ship_identity == original_identity, "vessel identity travels with incoming ship"): return
	if not _check(main.shield_delay == 4.0 and main.state.shield_delay == 4.0, "shield recovery delay travels with incoming ship"): return
	if not _check(main.state.day_progress == 0 and main.home_state.day_progress == 320.0, "new visit starts its own calendar and suspends home time"): return
	if not _check(main.suit_health == 61.5, "commander injury follows arrival"): return
	main.suit_health = 28.5
	main.state.day_progress = 640.0
	main.state.credits = 22222
	if not _check(main.state.found_faction("Visiting Ventures") == "", "found visiting faction"): return
	if not _check(main.state.faction_deposit(2222) == "", "fund visiting faction treasury"): return
	main.state.shares = {"HELI": 3}
	main.state.company_name = "Visiting Ventures"
	main.state.company_balance = 987
	main.state.wanted = 9
	main.state.cargo.alloys = 6
	main.state.hull = 72.0
	main.state.shield = 61.0
	main.state.fuel = 43.0
	var visitor_faction: Dictionary = main.state.faction.duplicate(true)
	var module_error: String = main.state.add_module("habitat", Vector3i(-1, 0, 2))
	if not _check(module_error.is_empty(), "visitor can modify carried ship: " + module_error): return
	if not _check(ShipLayout.set_panel(main.state, Vector3i(0, 0, 0), "-z", "armored").is_empty(), "visiting hull refit"): return
	var visiting_layout: Dictionary = main.state.ship_layout.duplicate(true)
	var visitor_credits: int = main.state.credits
	var visiting_modules: Array[Dictionary] = main.state.ship_modules.duplicate(true)
	var good_home_path: String = main.home_save_path
	main.home_save_path = "user://missing-visit-dir-%d/home.json" % OS.get_process_id()
	main.leave_visit()
	if not _check(main.home_state != null and main.state.world_id == remote_id and main._home_return_failed,
		"failed visit save retains unsaved visitor state instead of discarding its economy"): return
	main.load_commander()
	if not _check(main.state.credits == visitor_credits and main.state.world_id == remote_id,
		"reload cannot replace the unsaved failed-return profile"): return
	main.home_save_path = good_home_path
	main.leave_visit()
	if not _check(main.state.ephemeris_seconds == 123.0, "return preserves home physical epoch"): return
	if not _check(main.suit_health == 28.5, "visiting injury returns home"): return
	if not _check(main.state.day_progress == 320.0, "return restores home calendar without importing visiting time"): return
	if not _check(main.home_state == null and main.state.world_id == host_state_id, "leaving restores home identity"): return
	if not _check(main.state.credits == home_credits and main.state.shares == {"NOVA": 7} and main.state.company_name == "Home Cooperative" and main.state.company_balance == 650 and main.state.wanted == 2 and main.state.faction == home_faction, "visitor economics and faction do not leak into home"): return
	if not _check(main.state.ship_modules == visiting_modules and main.state.cargo.alloys == 6 and main.state.hull == 72.0 and main.state.shield == 61.0 and main.state.fuel == 43.0, "only carried ship, cargo, and vitals transfer home"): return
	if not _check(main.state.ship_layout == visiting_layout, "updated hull refit returns home with ship"): return
	if not _check(FileAccess.file_exists(visit_path) and FileAccess.file_exists(home_path), "home and visitor profiles are saved separately"): return
	var persisted_home := GameStateScript.new()
	if not _check(persisted_home.load_save(home_path).is_empty() and persisted_home.credits == home_credits and persisted_home.company_balance == 650 and persisted_home.world_id == host_state_id and persisted_home.faction == home_faction, "home commander save retains its separate economy and faction treasury"): return
	main.suit_health = 45.0
	main.session.connected = true
	main.session.world_id = remote_id
	main.session.ephemeris_seconds = 999.0
	main._visit_host(7919)
	if not _check(main.state.ephemeris_seconds == 999.0, "rejoining uses current host epoch rather than stale visit save"): return
	if not _check(main.suit_health == 45.0, "rejoin carries latest home injury instead of stale visitor health"): return
	if not _check(main.state.world_id == remote_id and main.state.credits == visitor_credits and main.state.shares == {"HELI": 3} and main.state.company_name == "Visiting Ventures" and main.state.company_balance == 987 and main.state.wanted == 9 and main.state.faction == visitor_faction, "rejoining restores visitor finances, faction treasury and reputation"): return
	if not _check(main.state.day_progress == 640.0, "visitor calendar resumes saved progress"): return
	if not _check(main.state.ship_modules == visiting_modules and main.state.cargo.alloys == 6, "rejoining carries the updated home ship"): return
	main.leave_visit()
	_cleanup()
	print("VISIT_TEST_OK: isolated world economy, carried ship, separate persistence")
	quit()


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("VISIT_TEST_FAILED: " + message)
	if main != null:
		if main.session != null: main.session.leave()
		if main.sound != null: main.sound.shutdown()
	_cleanup()
	quit(1)


func _cleanup() -> void:
	if not owns_paths:
		return
	if not home_path.is_empty() and FileAccess.file_exists(home_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(home_path))
	if not visit_path.is_empty() and FileAccess.file_exists(visit_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(visit_path))
