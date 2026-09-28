extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	var state = GameStateScript.new()
	var powered_stats: Dictionary = state.ship_stats()
	state.systems_online = false
	var offline_stats: Dictionary = state.ship_stats()
	assert(offline_stats.max_hull == powered_stats.max_hull and offline_stats.cargo_capacity == powered_stats.cargo_capacity, "offline systems preserve ship capacities")
	assert(offline_stats.drive_thrust_factor == 0.0 and offline_stats.acceleration_mps2 == 0.0 and offline_stats.boost_acceleration_mps2 == 0.0 and offline_stats.systems_heat_w == 0.0, "offline systems disable thrust, boost, and heat")

	state.drive_temperature_k = 600.0
	var fuel_before: float = state.fuel
	var coast := Vector3(25.0, 2.0, 0.0)
	assert(state.consume_propulsion(coast, Vector3(100.0, 0.0, 0.0)) == coast and state.fuel == fuel_before, "offline systems preserve momentum and fuel")
	state.cool_drive(0.5)
	assert(state.drive_temperature_k < 600.0, "offline systems let the drive cool")

	state.shield = 20.0
	state.shield_delay = 1.0
	state.recharge_shields(0.5)
	assert(state.shield == 20.0 and state.shield_delay == 0.5, "offline systems tick shield delay without recharging")
	var day_before: int = state.day
	var visited_before: Array[int] = state.visited.duplicate()
	var system_before: int = state.system_index
	var jump_fuel: float = state.fuel
	assert(state.jump(system_before + 1) != "" and state.system_index == system_before and state.fuel == jump_fuel and state.day == day_before and state.visited == visited_before, "offline jump is rejected atomically")

	var path := "user://ship-power-test-%d.json" % OS.get_process_id()
	assert(state.save(path) == "")
	var restored = GameStateScript.new()
	assert(restored.load_save(path) == "" and not restored.systems_online, "restart preserves offline status")
	var stable: Dictionary = restored._save_data().duplicate(true)
	var invalid: Dictionary = state._save_data().duplicate(true)
	invalid.systems_online = "false"
	_write_save(path, invalid)
	assert(restored.load_save(path) != "" and restored._save_data() == stable, "malformed power status rejects load transactionally")
	var legacy: Dictionary = state._save_data().duplicate(true)
	legacy.erase("systems_online")
	_write_save(path, legacy)
	assert(restored.load_save(path) == "" and restored.systems_online, "older saves default systems online")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("SHIP_POWER_TEST_OK")
	quit()

func _write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
