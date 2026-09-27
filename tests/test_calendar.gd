extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	var state = GameStateScript.new()
	assert(state.advance_time(1199.0) == 0 and state.day == 0 and state.day_progress == 1199.0)
	assert(state.clock_text() == "23:58")
	assert(state.hire("engineer") == "")
	var before_payroll: int = state.credits
	assert(state.advance_time(1.0) == 1 and state.day == 1)
	assert(state.credits == before_payroll - 90, "one timed day charges passive crew exactly once")
	assert(state.advance_time(0.0) == 0 and state.credits == before_payroll - 90, "zero elapsed time does not settle twice")
	assert(state.clock_text() == "00:00")
	assert(state.advance_time(GameStateScript.DAY_SECONDS / 2.0) == 0)
	assert(state.clock_text() == "12:00")
	var progress_before_jump: float = state.day_progress
	assert(state.jump(7919) == "" and state.day == 2 and state.day_progress == progress_before_jump, "jump settles one day and preserves partial clock")
	assert(state.credits == before_payroll - 180, "jump and clock settlement each charge once")
	var assigned = GameStateScript.new()
	assert(assigned.hire("engineer") == "")
	assigned.cargo.alloys = 20
	assert(assigned.build_station("Clockworks") == "")
	var orders := CrewOrders.new(assigned)
	assert(orders.assign_station_manager(assigned.crew[0].id, 0) == "")
	var assigned_credits: int = assigned.credits
	assert(assigned.advance_time(GameStateScript.DAY_SECONDS) == 1 and assigned.credits == assigned_credits + 150, "daily settlement does not charge assigned crew wages")
	orders.tick(CrewOrders.STATION_SECONDS)
	assert(assigned.credits == assigned_credits + 150 - 90, "assigned engineer charges once on its operation timer")
	var path: String = "user://calendar-test-%d.json" % OS.get_process_id()
	assert(state.save(path) == "")
	var resumed = GameStateScript.new()
	assert(resumed.load_save(path) == "" and resumed.day_progress == state.day_progress)
	assert(resumed.advance_time(GameStateScript.DAY_SECONDS - progress_before_jump) == 1 and resumed.day == 3)
	assert(resumed.credits == state.credits - 90, "saved fractional progress resumes into one settlement")
	var no_progress: Dictionary = state._save_data().duplicate(true)
	no_progress.erase("day_progress")
	var legacy_path: String = path + ".legacy"
	_write_save(legacy_path, no_progress)
	assert(resumed.load_save(legacy_path) == "" and resumed.day_progress == 0.0, "old v3 saves default clock to midnight")
	var old_v2: Dictionary = no_progress.duplicate(true)
	old_v2.version = 2
	for key: String in ["fleet_ships", "crew_orders", "recovery", "ship_layout", "faction"]: old_v2.erase(key)
	_write_save(legacy_path, old_v2)
	assert(resumed.load_save(legacy_path) == "" and resumed.day_progress == 0.0, "old v2 saves default clock to midnight")
	var old_v1: Dictionary = {"version": 1, "system": 0, "credits": 1000, "modules": 0, "hull": 100, "kills": 0, "cargo": {}}
	_write_save(legacy_path, old_v1)
	var v1_error: String = resumed.load_save(legacy_path)
	assert(v1_error == "" and resumed.day_progress == 0.0, "v1 saves default clock to midnight: %s" % v1_error)
	var stable: Dictionary = resumed._save_data().duplicate(true)
	for invalid: Variant in [-1.0, GameStateScript.DAY_SECONDS, "5"]:
		var bad: Dictionary = state._save_data().duplicate(true)
		bad.day_progress = invalid
		_write_save(legacy_path, bad)
		assert(resumed.load_save(legacy_path) != "" and resumed._save_data() == stable, "invalid day progress is rejected without state mutation")
	var unchanged: Dictionary = state._save_data().duplicate(true)
	for elapsed: float in [-1.0, INF, NAN, 86401.0]:
		assert(state.advance_time(elapsed) == 0 and state._save_data() == unchanged, "invalid elapsed time does not mutate state")
	for remove_path: String in [path, legacy_path]:
		if FileAccess.file_exists(remove_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(remove_path))
	print("CALENDAR_TEST_OK: timed settlement, jumps, persistence, validation, and clock display")
	quit()

func _write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
