extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	var state = GameStateScript.new()
	assert(state.ephemeris_seconds == 0.0, "new games start at physical epoch zero")
	assert(state.advance_time(1234.5) == 1 and state.ephemeris_seconds == 1234.5, "physical time advances at game-time scale")
	var epoch_before_jump: float = state.ephemeris_seconds
	var day_before_jump: int = state.day
	assert(state.jump(7919) == "" and state.day == day_before_jump + 1)
	assert(state.ephemeris_seconds == epoch_before_jump, "economy day settlement does not advance orbital epoch")

	var split = GameStateScript.new()
	var lump = GameStateScript.new()
	split.advance_time(17.25)
	split.advance_time(23.5)
	lump.advance_time(40.75)
	assert(is_equal_approx(split.ephemeris_seconds, lump.ephemeris_seconds), "split and lump time steps reach same epoch")
	var capped = GameStateScript.new()
	capped.ephemeris_seconds = GameStateScript.MAX_EPHEMERIS_SECONDS - 0.5
	var capped_before: Dictionary = capped._save_data().duplicate(true)
	assert(capped.advance_time(1.0) == 0 and capped._save_data() == capped_before, "epoch capacity rejection preserves economy and physical time")

	var path: String = "user://ephemeris-clock-%d.json" % OS.get_process_id()
	assert(state.save(path) == "")
	var save_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(save_data.version == 3 and save_data.ephemeris_seconds == state.ephemeris_seconds, "v3 save stores physical epoch")
	var restored = GameStateScript.new()
	assert(restored.load_save(path) == "" and restored.ephemeris_seconds == state.ephemeris_seconds, "load does not add offline wall time")

	var legacy: Dictionary = state._save_data().duplicate(true)
	legacy.erase("ephemeris_seconds")
	var legacy_seconds: float = (float(legacy.day) + float(legacy.day_progress) / GameStateScript.DAY_SECONDS) * 86400.0
	_write_save(path, legacy)
	assert(restored.load_save(path) == "" and is_equal_approx(restored.ephemeris_seconds, legacy_seconds), "legacy v3 epoch derives once from calendar")
	var catalog: Dictionary = CelestialSystem.generate(legacy.system_index)
	assert(CelestialSystem.sample(catalog, 0, legacy_seconds) == CelestialSystem.sample(catalog, 0, restored.ephemeris_seconds), "legacy load preserves prior orbital positions")

	var legacy_v2: Dictionary = legacy.duplicate(true)
	legacy_v2.version = 2
	for key: String in ["fleet_ships", "crew_orders", "recovery", "ship_layout", "faction"]: legacy_v2.erase(key)
	_write_save(path, legacy_v2)
	assert(restored.load_save(path) == "" and is_equal_approx(restored.ephemeris_seconds, legacy_seconds), "legacy v2 epoch derives from calendar")
	var legacy_v1: Dictionary = {"version": 1, "system": 0, "credits": 1000, "modules": 0, "hull": 100, "kills": 0, "cargo": {}}
	_write_save(path, legacy_v1)
	assert(restored.load_save(path) == "" and restored.ephemeris_seconds == 0.0, "v1 save derives epoch from its default calendar")

	assert(restored.load_save(path) == "")
	var stable: Dictionary = restored._save_data().duplicate(true)
	for invalid: Variant in [-1.0, "5", 1e16]:
		var bad_epoch: Dictionary = state._save_data().duplicate(true)
		bad_epoch.ephemeris_seconds = invalid
		_write_save(path, bad_epoch)
		assert(restored.load_save(path) != "" and restored._save_data() == stable, "invalid physical epoch rejects load without mutation")
	var malformed: Dictionary = state._save_data().duplicate(true)
	malformed.ephemeris_seconds = NAN
	var candidate = GameStateScript.new()
	assert(candidate._load_v2(malformed) != "", "non-finite physical epoch rejects load")
	malformed.ephemeris_seconds = null
	assert(candidate._load_v2(malformed) != "", "null physical epoch rejects load")

	var orbital_state = GameStateScript.new()
	orbital_state.advance_time(1234.5)
	var orbital_epoch: float = orbital_state.ephemeris_seconds
	var orbit_catalog: Dictionary = CelestialSystem.generate(0)
	var current: Dictionary = CelestialSystem.sample(orbit_catalog, 0, orbital_epoch)
	var before: Dictionary = CelestialSystem.sample(orbit_catalog, 0, orbital_epoch - 0.1)
	var after: Dictionary = CelestialSystem.sample(orbit_catalog, 0, orbital_epoch + 0.1)
	assert(not current.is_empty() and not before.is_empty() and not after.is_empty())
	for component: int in 3:
		var position_derivative: float = (float(after.position_m[component]) - float(before.position_m[component])) / 0.2
		assert(absf(position_derivative - float(current.velocity_mps[component])) < 0.1, "orbital velocity matches derivative per elapsed game second")

	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("EPHEMERIS_CLOCK_OK: physical epoch continuity, persistence, validation, and orbital velocity")
	quit()

func _write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
