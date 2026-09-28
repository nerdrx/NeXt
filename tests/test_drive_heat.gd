extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var state = GameStateScript.new()
	state.fuel = 10.0
	var before := Vector3.ZERO
	var after: Vector3 = state.consume_propulsion(before, Vector3(100.0, 0.0, 0.0))
	var spent: float = 10.0 - state.fuel
	assert(spent > 0.0 and is_equal_approx(state.drive_temperature_k, 300.0 + spent * 20.0), "propulsion heat follows fuel spent")
	assert(after.x > before.x, "propulsion still applies its commanded impulse")

	state.drive_temperature_k = 699.0
	state.fuel = 10.0
	var capped: Vector3 = state.consume_propulsion(Vector3.ZERO, Vector3(100.0, 0.0, 0.0))
	assert(is_equal_approx(state.drive_temperature_k, 700.0) and state.fuel < 10.0, "propulsion fuel is capped at the thermal limit")
	assert(capped.length() > 0.0 and capped.length() < 100.0, "last impulse is limited by remaining heat capacity")
	var fuel_at_cutoff: float = state.fuel
	var momentum_at_cutoff: Vector3 = state.consume_propulsion(capped, capped + Vector3(100.0, 0.0, 0.0))
	assert(momentum_at_cutoff.is_equal_approx(capped) and is_equal_approx(state.fuel, fuel_at_cutoff), "drive cutoff preserves momentum and fuel")
	assert(state.ship_stats().acceleration_mps2 == 0.0, "drive has no force at maximum temperature")

	state.drive_temperature_k = 600.0
	var warm_force: float = state.ship_stats().acceleration_mps2
	state.cool_drive(0.5)
	assert(state.drive_temperature_k < 600.0 and state.drive_temperature_k > 300.0, "radiative cooling lowers temperature")
	assert(state.ship_stats().acceleration_mps2 > warm_force, "cooling recovers drive force")
	var cooler: float = state.drive_temperature_k
	state.cool_drive(0.5)
	assert(state.drive_temperature_k < cooler, "continued cooling is monotonic")
	state.drive_temperature_k = 300.0
	state.cool_drive(1.0)
	assert(state.drive_temperature_k > 300.0, "powered systems warm the drive above ambient")
	state.drive_temperature_k = 600.0
	for invalid_delta: float in [-1.0, 0.0, 1.01, NAN, INF]:
		var temperature: float = state.drive_temperature_k
		state.cool_drive(invalid_delta)
		assert(state.drive_temperature_k == temperature, "invalid cooling delta is ignored")
	state.drive_temperature_k = 550.0
	assert(state.add_module("habitat", Vector3i(0, 0, 3)) == "" and state.drive_temperature_k == 550.0, "refitting preserves drive temperature")
	assert(state.remove_module(Vector3i(0, 0, 3)) == "" and state.drive_temperature_k == 550.0, "removing a refit module preserves drive temperature")

	var path := "user://drive-heat-test-%d.json" % OS.get_process_id()
	state.drive_temperature_k = 547.25
	assert(state.save(path) == "")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(saved.drive_temperature_k == 547.25, "v3 save stores drive temperature")
	var restored = GameStateScript.new()
	assert(restored.load_save(path) == "" and is_equal_approx(restored.drive_temperature_k, 547.25), "drive temperature survives save/load")

	var legacy: Dictionary = state._save_data().duplicate(true)
	legacy.erase("drive_temperature_k")
	_write_save(path, legacy)
	assert(restored.load_save(path) == "" and restored.drive_temperature_k == 300.0, "v3 save without temperature defaults to cold")
	var stable: Dictionary = restored._save_data().duplicate(true)
	var invalid: Dictionary = state._save_data().duplicate(true)
	invalid.drive_temperature_k = 701.0
	_write_save(path, invalid)
	assert(restored.load_save(path) != "" and restored._save_data() == stable, "out-of-range temperature rejects load transactionally")
	invalid.drive_temperature_k = NAN
	var candidate = GameStateScript.new()
	assert(candidate._load_v2(invalid) != "", "non-finite temperature is rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("DRIVE_HEAT_TEST_OK: propulsion heat, thermal cutoff, cooling and save validation")
	quit()

func _write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
