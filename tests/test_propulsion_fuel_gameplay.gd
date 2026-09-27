extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	game.apply_ship_stats()
	game.state.fuel = 1.0
	game.pilot.set_flight(true)
	game.pilot.set_physics_process(false)
	game.pilot.teleport(Vector3(10000, 5000, 0))
	game.pilot.restore_flight_velocity(Vector3.ZERO)
	game.enter_interior()
	await physics_frame
	assert(game.aboard and game.coasting_hull.propulsion_limiter.is_valid(), "aboard hull shares ship propulsion limiter")

	var hull = game.coasting_hull
	hull.velocity = Vector3(20, 0, 0)
	var idle_fuel: float = game.state.fuel
	hull.advance(0.1)
	assert(is_equal_approx(game.state.fuel, idle_fuel) and hull.velocity.x > 19.0, "idle coasting preserves fuel and momentum")
	hull.request_brake()
	hull.advance(0.1)
	assert(game.state.fuel < idle_fuel and hull.velocity.x < 20.0, "aboard braking consumes shared tank")

	hull.velocity = Vector3(0.01, 0, 0)
	game.state.fuel = 0.000000001
	game.aboard_cruise = true
	game.aboard_cruise_target = hull.position + Vector3(0.5, 0, 0)
	game._physics_process(0.5)
	assert(game.aboard_cruise and hull.velocity.x > 0.0, "empty-tank cruise cannot report arrival while residual momentum moves ship")

	var momentum: Vector3 = hull.velocity
	game.exit_interior()
	assert(is_zero_approx(game.state.fuel) and game.pilot.flight_velocity().is_equal_approx(momentum), "returning to helm preserves empty tank and residual momentum")
	game.pilot.teleport(Vector3(10000, 5000, 0))
	game.pilot.restore_flight_velocity(Vector3(0.01, 0, 0))
	game.pilot.autopilot_to(game.pilot.position + Vector3(0.5, 0, 0))
	game.pilot._fly(0.5)
	assert(game.pilot.autopilot_active and game.pilot.flight_velocity().x > 0.0, "empty-tank helm cruise remains active while residual momentum moves ship")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("PROPULSION_FUEL_GAMEPLAY_OK: shared tank, idle coasting, braking, empty-tank cruise and helm handoff")
	quit()
