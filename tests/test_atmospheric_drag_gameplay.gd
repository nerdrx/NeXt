extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	assert("--capture-only" in OS.get_cmdline_user_args())
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.close_menu()
	game.pilot.set_physics_process(false)
	for actor: Node in game.actors: actor.set_physics_process(false)
	var planet: Dictionary = game.world.planets[0]
	planet["atmosphere"] = true
	var local_sea: Vector3 = planet.position + Vector3.RIGHT * float(planet.visual_radius)
	var local_vacuum: Vector3 = planet.position + Vector3.RIGHT * (float(planet.visual_radius) + 220.0)
	var sea: Vector3 = game.world.to_global(local_sea)
	var sea_density: float = game.world.atmospheric_density(sea)
	assert(sea_density > 1.2, "atmospheric planet has sea-level density")
	assert(game.world.atmospheric_density(game.world.to_global(local_vacuum)) == 0.0, "vacuum altitude has no density")
	var old_world_position: Vector3 = game.world.position
	game.world.position += Vector3(1200, -300, 700)
	assert(is_equal_approx(game.world.atmospheric_density(game.world.to_global(local_sea)), sea_density), "origin shift preserves density")
	game.world.position = old_world_position
	planet["atmosphere"] = false
	assert(game.world.atmospheric_density(game.world.to_global(local_sea)) == 0.0, "airless planet has no density")
	planet["atmosphere"] = true

	var pilot = game.pilot
	pilot.set_flight(true)
	pilot.collision_mask = 0
	assert(pilot.atmospheric_density_source.is_valid(), "player receives world density callback")
	pilot.flight_assist_enabled = false
	pilot.teleport(sea)
	pilot.restore_flight_velocity(Vector3(100, 0, 0))
	game.state.systems_online = false
	game.state.fuel = 0.0
	game._refresh_propulsion_limits()
	var fuel_before: float = game.state.fuel
	var pilot_speed: float = pilot.flight_velocity().length()
	pilot._fly(0.1)
	assert(pilot.flight_velocity().length() < pilot_speed and pilot.aerodynamic_g > 0.0, "unpowered pilot loses speed to atmospheric drag")
	assert(game.state.fuel == fuel_before, "atmospheric drag consumes no propellant")
	assert(pilot.acceleration_vector.is_equal_approx((pilot.flight_velocity() - Vector3(100, 0, 0)) / 0.1), "pilot reports signed net acceleration before collision")
	if DisplayServer.get_name() != "headless":
		pilot.camera.look_at(game.world.to_global(planet.position), Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://atmospheric-drag-flight.png") == OK)

	var hull := CoastingHull.new()
	root.add_child(hull)
	hull.collision_mask = 0
	hull.atmospheric_density_source = func(_point: Vector3) -> float: return 1.225
	hull.drag_mass_kg = 100.0
	hull.drag_dimensions = Vector3.ONE * 5.0
	hull.velocity = Vector3(100, 0, 0)
	var hull_speed: float = hull.velocity.length()
	var expected := AtmosphericFlight.drag_velocity(hull.velocity, 1.225, hull.drag_dimensions, hull.global_basis, hull.drag_mass_kg, 0.1)
	hull.advance(0.1)
	assert(hull.velocity.is_equal_approx(expected), "coasting applies exactly one drag step")
	assert(hull.velocity.length() < hull_speed and hull.aerodynamic_g > 0.0, "coasting advance applies drag once")

	var npc: ShipActor
	for candidate: Node in game.actors:
		if candidate is ShipActor:
			npc = candidate
			break
	assert(npc != null and npc.atmospheric_density_source.is_valid(), "spawned NPC receives world density callback")
	npc.collision_mask = 0
	npc.global_position = sea
	npc.velocity = Vector3(100, 0, 0)
	npc.thrust_newtons = 0.0
	var npc_speed: float = npc.velocity.length()
	npc._physics_process(0.1)
	assert(npc.velocity.length() < npc_speed and npc.aerodynamic_g > 0.0, "NPC physics applies drag without thrust")

	pilot.teleport(game.world.to_global(local_vacuum))
	pilot.restore_flight_velocity(Vector3(100, 0, 0))
	pilot._fly(0.1)
	assert(pilot.flight_velocity().is_equal_approx(Vector3(100, 0, 0)) and pilot.aerodynamic_g == 0.0, "vacuum coasting preserves velocity")
	assert(pilot.acceleration_vector.is_zero_approx(), "vacuum coasting clears net acceleration")
	planet["atmosphere"] = false
	pilot.teleport(sea)
	pilot.restore_flight_velocity(Vector3(100, 0, 0))
	pilot._fly(0.1)
	assert(pilot.flight_velocity().is_equal_approx(Vector3(100, 0, 0)), "airless coasting preserves velocity")
	planet["atmosphere"] = true
	game.state.credits = 50000
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	game.apply_ship_stats()
	pilot.teleport(sea)
	pilot.restore_flight_velocity(Vector3(100, 0, 0))
	game.enter_interior()
	assert(game.aboard and is_instance_valid(game.coasting_hull), "walkable flight hull created")
	assert(game.coasting_hull.atmospheric_density_source.is_valid(), "boarding wires the world drag field")
	assert(game.coasting_hull.drag_mass_kg == pilot.drag_mass_kg and game.coasting_hull.drag_dimensions == pilot.drag_dimensions)
	game.coasting_hull.collision_mask = 0
	game.coasting_hull.advance(0.1)
	assert(game.coasting_hull.velocity.length() < 100.0, "boarded ship keeps slowing in atmosphere")
	game.exit_interior()
	game.world.build_surface(0)
	assert(game.world.atmospheric_density(game.world.to_global(local_sea)) == 0.0, "surface mode disables atmospheric drag")
	hull.queue_free()
	game.queue_free()
	await process_frame
	print("ATMOSPHERIC_DRAG_GAMEPLAY_OK: world field, origin shift, pilot, coasting hull, NPC and surface mode")
	quit()
