extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const IMPULSE_PER_FUEL := 5.0e6


func _initialize() -> void:
	_run()


func _run() -> void:
	var state = GameStateScript.new()
	var mass := float(state.ship_stats().loaded_mass_kg)
	var before := Vector3(2, -1, 4)
	var commanded := Vector3(8, 2, 4)
	var impulse := mass * before.distance_to(commanded)
	state.fuel = impulse / IMPULSE_PER_FUEL
	assert(state.consume_propulsion(before, commanded).is_equal_approx(commanded), "full impulse budget reaches commanded velocity")
	assert(is_zero_approx(state.fuel), "full impulse consumes exact fuel budget")

	state = GameStateScript.new()
	var dry_mass := float(state.ship_stats().loaded_mass_kg)
	state.cargo.ore = 1
	var loaded_mass := float(state.ship_stats().loaded_mass_kg)
	state.fuel = 1.0
	state.consume_propulsion(Vector3.ZERO, Vector3(100, 0, 0))
	var loaded_use: float = 1.0 - state.fuel
	state = GameStateScript.new()
	state.fuel = 1.0
	state.consume_propulsion(Vector3.ZERO, Vector3(100, 0, 0))
	var dry_use: float = 1.0 - state.fuel
	assert(loaded_mass == dry_mass + 1000 and loaded_use > dry_use, "cargo mass raises fuel cost")

	state = GameStateScript.new()
	state.fuel = 1.0
	var lumped := state.consume_propulsion(Vector3.ZERO, Vector3(100, 0, 0))
	var lumped_fuel: float = state.fuel
	state = GameStateScript.new()
	state.fuel = 1.0
	var split := state.consume_propulsion(Vector3.ZERO, Vector3(40, 0, 0))
	split = state.consume_propulsion(split, Vector3(100, 0, 0))
	assert(split.is_equal_approx(lumped) and is_equal_approx(state.fuel, lumped_fuel), "split and lumped impulses cost same fuel")

	state = GameStateScript.new()
	state.fuel = 0.00001
	var partial := state.consume_propulsion(Vector3(10, 0, 0), Vector3.ZERO)
	assert(partial.x > 0.0 and partial.x < 10.0 and is_zero_approx(state.fuel), "exhausted partial budget preserves residual momentum")
	state.fuel = 0.0
	assert(state.consume_propulsion(partial, Vector3.ZERO).is_equal_approx(partial), "empty tank cannot remove momentum")

	state = GameStateScript.new()
	state.fuel = 4.0
	for invalid in [Vector3(NAN, 0, 0), Vector3(INF, 0, 0)]:
		assert(state.consume_propulsion(before, invalid).is_equal_approx(before), "invalid command leaves velocity unchanged")
	assert(is_equal_approx(state.fuel, 4.0), "invalid input does not consume fuel")
	var huge := state.consume_propulsion(Vector3.ZERO, Vector3(INF, 0, 0))
	assert(huge.is_finite(), "invalid infinite velocity does not escape as nonfinite")

	var path := "user://propulsion-fuel-%d.json" % OS.get_process_id()
	state.fuel = 0.375
	assert(state.save(path).is_empty())
	var loaded = GameStateScript.new()
	assert(loaded.load_save(path).is_empty() and is_equal_approx(loaded.fuel, state.fuel), "save/load preserves remaining fuel")
	loaded.consume_propulsion(before, commanded)
	state.consume_propulsion(before, commanded)
	assert(is_equal_approx(loaded.fuel, state.fuel), "saved fuel continues with same propulsion cost")

	state = GameStateScript.new()
	state.credits = 0
	state.fuel = 0.0
	var fee := maxi(500, state.price("fuel") * 4)
	assert(state.emergency_refuel().is_empty(), "empty tank permits emergency delivery")
	assert(state.fuel == 20.0 and state.credits == 0 and state.recovery.debt == fee, "unpaid service charge becomes recovery debt")
	var recovered_velocity := state.consume_propulsion(Vector3.ZERO, Vector3(10, 0, 0))
	assert(recovered_velocity.x > 0.0 and state.fuel < 20.0, "emergency fuel restores propulsion")
	var fuel_after: float = state.fuel
	assert(not state.emergency_refuel().is_empty() and is_equal_approx(state.fuel, fuel_after), "repeat delivery rejected without charging or refilling")
	state.fuel = 0.02
	var credits_before: int = state.credits
	assert(not state.emergency_refuel().is_empty() and state.fuel == 0.02 and state.credits == credits_before, "service rejects a nonempty tank")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PROPULSION_FUEL_OK: impulse budget, cargo mass, split thrust, residual momentum and save continuity")
	quit()
