extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "move_up", "move_down", "roll_left", "roll_right", "boost", "fire"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var hull := CoastingHull.new()
	root.add_child(hull)
	hull.configure([Vector3i.ZERO])
	hull.collision_mask = 0
	hull.gravity_source = func(_point: Vector3) -> Vector3: return Vector3.DOWN * 9.80665
	hull.advance(0.1)
	assert(hull.acceleration_vector.length() > 9.8 and hull.proper_acceleration_vector.is_zero_approx(), "free fall carries no maneuver load")
	hull.velocity = Vector3.ZERO
	hull.navigate(0.1, hull.position, 20.0)
	assert(hull.acceleration_vector.is_zero_approx() and is_equal_approx(hull.proper_acceleration_vector.length(), 9.80665), "hover thrust is felt despite zero net acceleration")
	hull.gravity_source = Callable()
	hull.velocity = Vector3.ZERO
	hull.navigate(0.1, hull.position + Vector3(0, 0, -100), 20.0)
	assert(hull.proper_acceleration_vector.is_equal_approx(hull.acceleration_vector) and hull.thrust_g > 0.0, "navigation retains commanded load")
	hull.atmospheric_density_source = func(_point: Vector3) -> float: return 1.225
	hull.velocity = Vector3(0, 0, -100)
	hull.advance(0.1)
	assert(hull.proper_acceleration_vector.length() > 0 and hull.proper_acceleration_vector.is_equal_approx(hull.acceleration_vector), "drag creates proper load")
	hull.advance(0.0)
	assert(hull.proper_acceleration_vector.is_zero_approx(), "zero step clears stale telemetry")
	var pilot := Pilot.new()
	root.add_child(pilot)
	pilot.set_physics_process(false)
	pilot.collision_mask = 0
	pilot.set_flight(true)
	pilot.gravity_source = func(_point: Vector3) -> Vector3: return Vector3.DOWN * 9.80665
	pilot.flight_assist_enabled = false
	pilot._fly(0.1)
	assert(pilot.proper_acceleration_vector.is_zero_approx(), "pilot free fall excludes gravity")
	pilot._flight_velocity = Vector3.ZERO
	pilot.flight_assist_enabled = true
	pilot._fly(0.1)
	assert(is_equal_approx(pilot.proper_acceleration_vector.length(), 9.80665), "pilot assist counters gravity with felt thrust")
	pilot.set_flight(false)
	Input.action_press("move_forward")
	pilot.cabin_load_g = 0.0
	pilot._walk(0.5)
	var normal_speed: float = pilot.velocity.slide(Vector3.UP).length()
	pilot.cabin_load_g = 3.0
	pilot._walk(0.5)
	Input.action_release("move_forward")
	assert(normal_speed > 1.0 and is_equal_approx(pilot.velocity.slide(Vector3.UP).length(), normal_speed * 0.25), "cabin load slows walking")
	var crew := ShipCrew.new()
	crew.set_cabin_load(1.5)
	assert(crew.bracing and crew.activity() == "Bracing for maneuver")
	crew.set_cabin_load(1.2)
	assert(crew.bracing, "hysteresis prevents flicker")
	crew.set_cabin_load(1.0)
	assert(not crew.bracing)
	crew.free()
	assert(FlightDynamics.cabin_mobility(NAN) == 1.0)
	pilot.queue_free()
	hull.queue_free()
	await process_frame
	print("CABIN_LOAD_OK: free fall, hover, cruise thrust, drag, telemetry reset, slower walking and bracing hysteresis")
	quit()
