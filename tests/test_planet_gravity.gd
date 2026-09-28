extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := SpaceWorld.new()
	root.add_child(world)
	world.planets.assign([{"position": Vector3.ZERO, "visual_radius": 10.0, "surface_gravity_mps2": 10.0}])
	assert(world.gravity_acceleration(Vector3(10, 0, 0)).is_equal_approx(Vector3(-10, 0, 0)))
	assert(world.gravity_acceleration(Vector3(20, 0, 0)).is_equal_approx(Vector3(-2.5, 0, 0)))
	assert(world.gravity_acceleration(Vector3(5, 0, 0)).is_equal_approx(Vector3(-5, 0, 0)))
	assert(world.gravity_acceleration(Vector3.ZERO).is_zero_approx())
	world.position = Vector3(-8192, 100, 30)
	assert(world.gravity_acceleration(world.to_global(Vector3(20, 0, 0))).is_equal_approx(Vector3(-2.5, 0, 0)), "origin shift preserves field")
	world.hide()
	assert(world.gravity_acceleration(Vector3.ZERO).is_zero_approx())
	world.show()
	world._surface_mode = true
	assert(world.gravity_acceleration(Vector3.ZERO).is_zero_approx(), "separate colony scene has no orbital field")
	world.queue_free()
	var down := func(_point: Vector3) -> Vector3: return Vector3(0, -10, 0)
	assert(FlightDynamics.gravity_step(down, Vector3.ZERO, 0.1).is_equal_approx(Vector3.DOWN))
	assert(FlightDynamics.gravity_step(down, Vector3.ZERO, NAN).is_zero_approx())
	var hull := CoastingHull.new()
	root.add_child(hull)
	hull.collision_mask = 0
	hull.gravity_source = down
	hull.advance(0.1)
	assert(hull.velocity.is_equal_approx(Vector3.DOWN) and hull.acceleration_vector.is_equal_approx(Vector3(0, -10, 0)))
	hull.velocity = Vector3.ZERO
	var response := hull.navigate(0.1, hull.global_position, 100)
	assert(hull.velocity.is_zero_approx() and response.arrived and hull.thrust_g > 1.0, "navigation spends thrust holding against gravity")
	hull.propulsion_limiter = func(before: Vector3, _after: Vector3) -> Vector3: return before
	hull.navigate(0.1, hull.global_position, 100)
	assert(hull.velocity.y < -0.9, "powerless guidance cannot cancel gravity")
	hull.queue_free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(2000, 2000, 2000))
	game.pilot.collision_mask = 0
	game.pilot.gravity_source = down
	game.pilot.atmospheric_density_source = Callable()
	game.pilot.flight_assist_enabled = true
	game.state.fuel = 100
	game.pilot._fly(0.1)
	assert(game.pilot.flight_velocity().is_zero_approx() and game.state.fuel < 100 and game.pilot.thrust_g > 1.0, "assisted hover consumes real fuel")
	game.pilot.flight_assist_enabled = false
	var fuel: float = game.state.fuel
	game.pilot._fly(0.1)
	assert(game.pilot.flight_velocity().is_equal_approx(Vector3.DOWN) and game.state.fuel == fuel, "inertial coasting free-falls")
	game.pilot.restore_flight_velocity(Vector3.ZERO)
	game.pilot.flight_assist_enabled = true
	game.state.fuel = 0
	game.pilot._fly(0.1)
	assert(game.pilot.flight_velocity().is_equal_approx(Vector3.DOWN), "empty fuel cannot hover")
	var npc := ShipActor.new()
	root.add_child(npc)
	npc.set_physics_process(false)
	npc.collision_mask = 0
	npc.gravity_source = down
	npc.propulsion_limiter = func(before: Vector3, _after: Vector3) -> Vector3: return before
	npc._physics_process(0.1)
	assert(npc.velocity.y < -0.9 and npc.aerodynamic_heat_w == 0, "NPC free-fall does not count as drag heating")
	npc.queue_free()
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("PLANET_GRAVITY_OK: field, rebasing, free fall, thrust/fuel compensation, coasting navigation and NPC forces")
	quit()
