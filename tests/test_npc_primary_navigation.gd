extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := SpaceWorld.new()
	root.add_child(world)
	world.stellar_profile = {"kind": "Black Hole"}
	var ship := ShipActor.new()
	ship.hostile = false
	ship.systems_heat_w = 0.0
	ship.drive_temperature_k = 300.0
	ship.celestial_obstacles_source = world.navigation_obstacles
	ship.primary_contact_source = world.primary_contact
	root.add_child(ship)
	ship.set_physics_process(false)
	ship.collision_mask = 0
	var center := world.to_global(SpaceWorld.PRIMARY_POSITION)
	ship.position = center + Vector3(-700, 0, 0)
	var goal := center + Vector3(700, 0, 0)
	ship.set_travel_target(goal)
	var first := ship._celestial_destination(goal, 0.1, 30.0)
	assert(ship._celestial_waypoints.size() > 2 and first != goal, "blocked course gets detour")
	var previous := ship.global_position
	var obstacle := world.primary_obstacle()
	for point: Vector3 in ship._celestial_waypoints:
		assert(not CruiseRoute._blocked(previous, point, obstacle), "planned chords clear primary")
		previous = point
	var cache := ship._celestial_waypoints.duplicate()
	ship._celestial_destination(goal, 0.1, 30.0)
	assert(ship._celestial_waypoints == cache, "route cache survives subsecond calls")
	var shift := Vector3(8192, 50, -8192)
	ship.position -= shift
	world.position -= shift
	ship.apply_origin_shift(shift)
	assert(ship._celestial_waypoints[0].is_equal_approx(cache[0] - shift) and ship.travel_target.is_equal_approx(goal-shift))
	center = world.to_global(SpaceWorld.PRIMARY_POSITION)
	goal -= shift
	# Run actual CharacterBody movement with accelerated hosted time.
	Engine.time_scale = 8.0
	var closest := INF
	var arrived := false
	for frame in 900:
		await physics_frame
		ship._physics_process(ship.get_physics_process_delta_time())
		assert(not ship._destroyed, "trader must not enter the core")
		closest = minf(closest, ship.global_position.distance_to(center))
		if ship.global_position.distance_to(goal) < 15.0:
			arrived = true
			break
	Engine.time_scale = 1.0
	assert(arrived and closest > world.primary_radius(), "physical trader completes detour")
	assert(ship.travel_target.is_equal_approx(goal), "navigation preserves the assigned order")
	ship._celestial_route_cooldown = 0.0
	assert(ship._celestial_destination(center, 0.1, 30.0).is_equal_approx(ship.global_position) and ship._celestial_route_blocked, "unsafe destination requests braking")
	world.hide()
	assert(ship._celestial_destination(goal, 0.1, 30.0) == goal and ship._celestial_waypoints.is_empty())
	ship.queue_free()
	world.queue_free()
	await process_frame
	print("NPC_PRIMARY_NAVIGATION_OK: cached detour, rebase, physical arrival, preserved order and unsafe-goal braking; closest=", closest)
	quit()
