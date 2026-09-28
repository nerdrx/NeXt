extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var sun := {"mu_m3_s2": CelestialPhysics.SOLAR_MU, "radius_m": CelestialPhysics.SOLAR_RADIUS_M, "luminosity_w": CelestialPhysics.SOLAR_LUMINOSITY_W}
	var at_au := StellarGravity.acceleration(sun, Vector3(4500, 0, 0), Vector3.ZERO)
	assert(absf(at_au.x + 0.00593) < 0.00001)
	assert(StellarGravity.acceleration(sun, Vector3(9000, 0, 0), Vector3.ZERO).is_equal_approx(at_au / 4.0))
	var hole := {"mu_m3_s2": 10.0 * CelestialPhysics.SOLAR_MU, "radius_m": CelestialPhysics.schwarzschild_radius(10.0 * CelestialPhysics.SOLAR_MU), "luminosity_w": 0.0}
	assert(StellarGravity.acceleration(hole, Vector3(4500, 0, 0), Vector3.ZERO).is_equal_approx(at_au * 10.0), "dark mass still attracts")
	var edge := StellarGravity.acceleration(hole, Vector3(250, 0, 0), Vector3.ZERO)
	assert(StellarGravity.acceleration(hole, Vector3(125, 0, 0), Vector3.ZERO).is_equal_approx(edge * 0.5))
	assert(StellarGravity.acceleration(hole, Vector3.ZERO, Vector3.ZERO).is_zero_approx())
	for bad in [{}, {"mu_m3_s2": INF}, {"mu_m3_s2": "bad"}, {"mu_m3_s2": -1.0}]:
		assert(StellarGravity.acceleration(bad, Vector3.ONE, Vector3.ZERO).is_zero_approx())
	assert(StellarGravity.acceleration(hole, Vector3(NAN, 0, 0), Vector3.ZERO).is_zero_approx())
	var world := SpaceWorld.new()
	root.add_child(world)
	world.stellar_profile = sun
	world.position = Vector3(8192, -2048, 200)
	world.rotation.y = 0.4
	var point := SpaceWorld.PRIMARY_POSITION + Vector3(4500, 0, 0)
	var expected := world.global_basis * at_au
	assert(world.gravity_acceleration(world.to_global(point)).is_equal_approx(expected), "rebasing and rotation preserve stellar field")
	world.planets.assign([{"position": point + Vector3(10, 0, 0), "visual_radius": 10.0, "surface_gravity_mps2": 1.0}])
	assert(world.gravity_acceleration(world.to_global(point)).distance_to(world.global_basis * (at_au + Vector3.RIGHT)) < 0.001, "stellar and planetary pulls superpose")
	world.hide()
	assert(world.gravity_acceleration(Vector3.ZERO).is_zero_approx())
	world.show()
	world._surface_mode = true
	assert(world.gravity_acceleration(Vector3.ZERO).is_zero_approx())
	world.queue_free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	for body: Dictionary in game.world.planets: body.surface_gravity_mps2 = 0.0
	game.world.stellar_profile = hole
	game.pilot.set_flight(true)
	game.pilot.teleport(game.world.to_global(SpaceWorld.PRIMARY_POSITION + Vector3(500, 0, 0)))
	game.pilot.collision_mask = 0
	game.pilot.flight_assist_enabled = false
	game.pilot.restore_flight_velocity(Vector3.ZERO)
	var pull: Vector3 = game.world.gravity_acceleration(game.pilot.global_position)
	game.pilot._fly(0.1)
	assert(game.pilot.flight_velocity().is_equal_approx(pull * 0.1), "live player binding free-falls toward dark primary")
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("STELLAR_GRAVITY_OK: inverse square, dark mass, softened core, invalid input, rebasing, superposition and live free fall")
	quit()
