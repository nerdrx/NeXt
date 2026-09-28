extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const ThermalSignatureScript = preload("res://scripts/thermal_signature.gd")
const ShipActorScript = preload("res://scripts/ship_actor.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state = GameStateScript.new()
	var stats: Dictionary = state.ship_stats()
	var expected_heat := 1500.0 * minf(float(stats.power_generation), maxf(0.0, float(stats.power_demand - stats.engine_power_demand)))
	assert(is_equal_approx(float(stats.systems_heat_w), expected_heat) and expected_heat > 0.0, "player systems heat follows supplied non-engine load")
	assert(float(state._stats_for([]).systems_heat_w) == 0.0, "unpowered layout produces no electrical heat")

	assert(ThermalSignatureScript.step_temperature(300.0, 40.0, 2500000.0, 1.0) == 301.0, "systems heat warms ambient drive")
	var balanced_heat := ThermalSignatureScript.emitted_power_w(500.0, 40.0) - ThermalSignatureScript.emitted_power_w(300.0, 40.0)
	assert(is_equal_approx(ThermalSignatureScript.step_temperature(500.0, 40.0, balanced_heat, 1.0), 500.0), "radiation balance holds temperature steady")
	var player_cool := ThermalSignatureScript.step_temperature(600.0, 40.0, 0.0, 1.0)
	var larger_radiator_cool := ThermalSignatureScript.step_temperature(600.0, 80.0, 0.0, 1.0)
	assert(larger_radiator_cool < player_cool, "larger radiator cools faster")

	for invalid_temperature: float in [NAN, INF, -INF, 299.0, 701.0]:
		var result := ThermalSignatureScript.step_temperature(invalid_temperature, 40.0, 1.0, 0.5)
		assert((not is_finite(invalid_temperature) and not is_finite(result)) or result == invalid_temperature, "invalid temperature is unchanged")
	for invalid_area: float in [NAN, INF, -INF, -0.1, 3040.1]:
		assert(ThermalSignatureScript.step_temperature(500.0, invalid_area, 1.0, 0.5) == 500.0, "invalid area leaves temperature unchanged")
	for invalid_heat: float in [NAN, INF, -INF, -0.1]:
		assert(ThermalSignatureScript.step_temperature(500.0, 40.0, invalid_heat, 0.5) == 500.0, "invalid heat leaves temperature unchanged")
	for invalid_delta: float in [NAN, INF, -INF, -0.1, 1.1]:
		assert(ThermalSignatureScript.step_temperature(500.0, 40.0, 1.0, invalid_delta) == 500.0, "invalid delta leaves temperature unchanged")

	state.drive_temperature_k = 300.0
	var fuel_before: float = state.fuel
	state.cool_drive(1.0)
	assert(state.drive_temperature_k > 300.0 and state.fuel == fuel_before, "powered player warms without spending propellant")
	var actor: ShipActor = ShipActorScript.new()
	actor.radiator_area_m2 = float(stats.radiator_area_m2)
	actor.systems_heat_w = float(stats.systems_heat_w)
	actor.drive_temperature_k = 300.0
	actor.hostile = false
	actor.propulsion_limiter = func(before: Vector3, _commanded: Vector3) -> Vector3: return before
	root.add_child(actor)
	actor.set_physics_process(false)
	actor._physics_process(1.0)
	assert(actor.drive_temperature_k == state.drive_temperature_k and actor.velocity == Vector3.ZERO,
		"actual NPC physics uses shared thermal balance even when thrust is unavailable")
	actor.free()
	assert(not state._save_data().has("systems_heat_w"), "systems heat derives from saved modules")
	var cold_state = GameStateScript.new()
	cold_state.hull = 0.0
	cold_state.drive_temperature_k = 300.0
	cold_state.cool_drive(1.0)
	assert(cold_state.drive_temperature_k == 300.0, "destroyed player systems produce no heat")
	print("SYSTEMS_HEAT_TEST_OK: electrical heating, shared thermal step and validation")
	quit()
