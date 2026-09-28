extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const ThermalSignatureScript = preload("res://scripts/thermal_signature.gd")

func _initialize() -> void:
	var ordinary_load := ThermalSignatureScript.overflow_damage(650.0, 40.0, 2500000.0, 1.0)
	assert(ordinary_load == 0.0, "ordinary load stays below the thermal storage ceiling")

	var hot_load := ThermalSignatureScript.overflow_damage(700.0, 40.0, 600000000.0, 1.0)
	assert(hot_load > 0.0, "positive net heat above 700 K damages the hull")
	assert(ThermalSignatureScript.overflow_damage(700.0, 40.0, 0.0, 1.0) == 0.0,
		"radiative cooling produces no overflow damage")
	assert(ThermalSignatureScript.overflow_damage(700.0, 40.0, 1000000.0, 0.0) == 0.0,
		"zero elapsed time produces no overflow damage")

	var small_radiator := ThermalSignatureScript.overflow_damage(700.0, 40.0, 600000000.0, 1.0)
	var large_radiator := ThermalSignatureScript.overflow_damage(700.0, 3000.0, 600000000.0, 1.0)
	assert(large_radiator < small_radiator, "larger radiators reduce thermal overflow")
	assert(is_equal_approx(
		ThermalSignatureScript.overflow_damage(700.0, 40.0, 600000000.0, 1.0),
		2.0 * ThermalSignatureScript.overflow_damage(700.0, 40.0, 600000000.0, 0.5)),
		"overflow damage composes linearly across half steps at the temperature ceiling")

	for invalid_temperature: float in [NAN, INF, -INF, 299.0, 701.0]:
		assert(ThermalSignatureScript.overflow_damage(invalid_temperature, 40.0, 600000000.0, 1.0) == 0.0,
			"invalid temperature causes no overflow damage")
	for invalid_area: float in [NAN, INF, -INF, -0.1, 3040.1]:
		assert(ThermalSignatureScript.overflow_damage(700.0, invalid_area, 600000000.0, 1.0) == 0.0,
			"invalid radiator area causes no overflow damage")
	for invalid_heat: float in [NAN, INF, -INF, -0.1]:
		assert(ThermalSignatureScript.overflow_damage(700.0, 40.0, invalid_heat, 1.0) == 0.0,
			"invalid heat causes no overflow damage")
	for invalid_delta: float in [NAN, INF, -INF, -0.1, 1.1]:
		assert(ThermalSignatureScript.overflow_damage(700.0, 40.0, 600000000.0, invalid_delta) == 0.0,
			"invalid elapsed time causes no overflow damage")

	var state = GameStateScript.new()
	state.drive_temperature_k = 700.0
	state.hull = 10.0
	state.shield = 25.0
	state.cool_drive(1.0, 600000000.0)
	assert(state.hull < 10.0 and state.hull >= 0.0, "thermal overflow bypasses shields and keeps hull nonnegative")
	assert(state.shield == 25.0, "thermal overflow leaves shields unchanged")

	var destroyed = GameStateScript.new()
	destroyed.drive_temperature_k = 700.0
	destroyed.hull = 0.5
	destroyed.cool_drive(1.0, 600000000.0)
	assert(destroyed.hull == 0.0, "thermal overflow cannot reduce hull below zero")
	print("THERMAL_OVERFLOW_TEST_OK")
	quit()
