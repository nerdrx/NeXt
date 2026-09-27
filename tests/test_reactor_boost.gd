extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	var state = GameStateScript.new()
	var stats: Dictionary = state.ship_stats()
	assert(stats.power_generation == 12 and stats.power_demand == 8 and stats.power_balance == 4)
	assert(stats.engine_power_demand == 2 and stats.boost_multiplier == 2.0)
	assert(stats.boost_acceleration_mps2 == 6.0 * 9.80665)

	assert(state.add_module("weapon", Vector3i(-2, 0, 0)) == "")
	assert(state.add_module("habitat", Vector3i(-3, 0, 0)) == "")
	stats = state.ship_stats()
	assert(stats.power_balance == 1 and stats.boost_multiplier == 1.5, "nominal loads reserve power before boost headroom")
	var acceleration_before_cargo: float = float(stats.boost_acceleration_mps2)
	state.cargo.ore = 2
	stats = state.ship_stats()
	assert(stats.loaded_mass_kg == int(stats.dry_mass_kg) + 2000)
	assert(float(stats.boost_acceleration_mps2) < acceleration_before_cargo, "cargo mass reduces boosted acceleration")
	state.cargo.ore = 0

	assert(state.add_module("reactor", Vector3i(2, 0, 0)) == "")
	stats = state.ship_stats()
	assert(stats.power_generation == 24 and stats.power_balance == 13 and stats.boost_multiplier == 2.0, "added reactor restores boost headroom")
	var no_engine: Dictionary = state._stats_for([{"kind": "reactor", "x": 0, "y": 0, "z": 0}])
	assert(no_engine.engine_power_demand == 0 and no_engine.boost_multiplier == 1.0, "ships without engines have safe boost fallback")
	var save_data: Dictionary = state._save_data()
	assert(not save_data.has("boost_multiplier") and not save_data.has("boost_acceleration_mps2"), "derived boost stats stay out of saves")
	print("REACTOR_BOOST_OK: power headroom, reactor refit, cargo mass and no-engine fallback")
	quit()
