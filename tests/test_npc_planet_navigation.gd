extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := SpaceWorld.new()
	root.add_child(world)
	world.position = Vector3(1000, 40, -300)
	world.planets.assign([{"position": Vector3.ZERO, "visual_radius": 250.0}])
	var obstacles := world.navigation_obstacles()
	assert(obstacles.size() == 1 and obstacles[0].center == world.global_position)
	assert(is_equal_approx(obstacles[0].radius, 250.0 + PlanetHeightField.HEIGHT_SCALE))
	var ship := ShipActor.new()
	ship.hostile = false
	ship.systems_heat_w = 0.0
	ship.drive_temperature_k = 300.0
	ship.celestial_obstacles_source = world.navigation_obstacles
	root.add_child(ship)
	ship.set_physics_process(false)
	ship.collision_mask = 0
	var center := world.global_position
	ship.position = center + Vector3(-700, 0, 0)
	var goal := center + Vector3(700, 0, 0)
	ship.set_travel_target(goal)
	ship._celestial_destination(goal, 0.1, 30.0)
	assert(ship._celestial_waypoints.size() > 2)
	var previous := ship.global_position
	for point: Vector3 in ship._celestial_waypoints:
		assert(not CruiseRoute._blocked(previous, point, obstacles[0]))
		previous = point
	assert(world.navigation_obstacles() == obstacles, "routing must not inflate world data")
	Engine.time_scale = 8.0
	var arrived := false
	var closest := INF
	for frame in 900:
		await physics_frame
		ship._physics_process(ship.get_physics_process_delta_time())
		closest = minf(closest, ship.global_position.distance_to(center))
		assert(closest > float(obstacles[0].radius), "ship remains above terrain envelope")
		if ship.global_position.distance_to(goal) < 15.0:
			arrived = true
			break
	Engine.time_scale = 1.0
	assert(arrived and ship.travel_target == goal)
	world.stellar_profile = {"kind": "Black Hole"}
	assert(world.navigation_obstacles().size() == 2, "primary and planets share route")
	world._surface_mode = true
	assert(world.navigation_obstacles().is_empty())
	ship.queue_free()
	world.queue_free()
	await process_frame
	print("NPC_PLANET_NAVIGATION_OK: translated planet, terrain envelope, immutable obstacles and physical arrival; closest=", closest)
	quit()
