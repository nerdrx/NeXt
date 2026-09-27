extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const ShipLayout = preload("res://scripts/ship_layout.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var state = GameStateScript.new()
	state.drive_temperature_k = 600.0
	var base: Dictionary = state.ship_stats()
	assert(base.radiator_area_m2 == 40.0, "ship starts with 40 m2 radiator area")
	var base_temperature: float = state.drive_temperature_k
	state.cool_drive(0.5)
	var baseline_cooling: float = base_temperature - state.drive_temperature_k
	state.drive_temperature_k = base_temperature

	var old_acceleration: float = base.acceleration_mps2
	assert(state.add_module("radiator", Vector3i(0, 1, 1)) == "", "radiator can be installed")
	var installed: Dictionary = state.ship_stats()
	assert(installed.radiator_area_m2 == 65.0, "one neighboring module blocks one of six radiator faces")
	assert(installed.dry_mass_kg == base.dry_mass_kg + 2000, "radiator adds two tonnes")
	assert(installed.acceleration_mps2 < old_acceleration, "radiator mass reduces acceleration")
	assert(state.drive_temperature_k == base_temperature, "refit preserves drive temperature")
	state.cool_drive(0.5)
	assert(base_temperature - state.drive_temperature_k > baseline_cooling, "larger radiator area cools drive faster")
	assert(is_equal_approx((base_temperature - state.drive_temperature_k) / baseline_cooling, 65.0 / 40.0), "heat rejection scales with exposed area")
	state.drive_temperature_k = base_temperature

	assert(state.add_module("habitat", Vector3i(0, 2, 1)) == "", "neighbor can cover radiator face")
	assert(state.ship_stats().radiator_area_m2 == 60.0, "neighbor blocks five square meters")
	assert(state.remove_module(Vector3i(0, 2, 1)) == "", "covering neighbor can be removed")
	assert(state.ship_stats().radiator_area_m2 == 65.0, "removal restores exposed radiator face")

	assert(ShipLayout.set_panel(state, Vector3i(0, 1, 1), "-x", "armored") == "", "armored panel can cover radiator face")
	assert(state.ship_stats().radiator_area_m2 == 60.0, "armored panel blocks radiator face")
	assert(ShipLayout.set_panel(state, Vector3i(0, 1, 1), "-x", "window") == "", "window panel can cover radiator face")
	assert(state.ship_stats().radiator_area_m2 == 60.0, "window panel blocks radiator face")
	assert(ShipLayout.set_panel(state, Vector3i(0, 1, 1), "-x", "standard") == "", "standard panel restores radiator face")
	assert(state.ship_stats().radiator_area_m2 == 65.0, "standard panel allows radiation")
	assert(state.remove_module(Vector3i(0, 1, 1)) == "", "radiator can be removed")
	assert(state.ship_stats().radiator_area_m2 == 40.0, "removal restores base radiator area")
	assert(state.drive_temperature_k == base_temperature, "removal preserves drive temperature")

	assert(state.add_module("radiator", Vector3i(0, 1, 1)) == "", "radiator can be reinstalled")
	state.drive_temperature_k = 547.25
	var path := "user://radiator-test-%d.json" % OS.get_process_id()
	assert(state.save(path) == "")
	var loaded = GameStateScript.new()
	assert(loaded.load_save(path) == "")
	assert(loaded.ship_stats().radiator_area_m2 == state.ship_stats().radiator_area_m2, "save/load recomputes radiator area")
	assert(is_equal_approx(loaded.drive_temperature_k, 547.25), "save/load preserves heat capacity temperature")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var session := NetworkSession.new()
	session.ship_modules = [{"kind": "core", "x": 0, "y": 0, "z": 0}, {"kind": "radiator", "x": 1, "y": 0, "z": 0}]
	assert(session._validate_local_design() == "", "network design validation accepts radiator module")
	session.free()
	var enclosed = GameStateScript.new()
	var radiator_cell := Vector3i(0, 1, 1)
	assert(enclosed.add_module("radiator", radiator_cell).is_empty())
	for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.FORWARD, Vector3i.BACK]:
		assert(enclosed.add_module("cargo", radiator_cell + direction).is_empty())
	assert(enclosed.radiator_area_m2() == 40.0, "fully enclosed radiator adds no cooling area")
	print("RADIATOR_TEST_OK: exposed area, occlusion, cooling, mass, refit, save and network validation")
	quit()
