extends SceneTree

const PilotScript = preload("res://scripts/pilot.gd")
const HullScript = preload("res://scripts/coasting_hull.gd")
const BRAKE_ACCELERATION := 3.0 * 9.80665


func _initialize() -> void:
	for action in ["move_back", "move_forward", "move_left", "move_right", "move_up", "move_down", "boost", "roll_left", "roll_right", "fire"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_run.call_deferred()


func _run() -> void:
	await _test_pilot_braking()
	await _test_disabled_pilot_braking()
	await _test_hull_braking()
	await _test_autopilot_wall_braking()
	print("SHIP_BRAKING_OK: physical braking, disabled-menu braking, hull stopping and obstacle approach")
	quit()


func _test_pilot_braking() -> void:
	var pilot := _pilot(Vector3.ZERO)
	pilot.set_flight(true)
	await physics_frame
	pilot._flight_velocity = Vector3(100, 0, 0)
	pilot.velocity = pilot._flight_velocity
	pilot.request_brake()
	assert(pilot.braking and pilot._flight_velocity.length() > 99.0, "brake request preserves initial speed")
	var elapsed := 0.0
	var previous_speed := pilot._flight_velocity.length()
	var max_acceleration := 0.0
	var start := pilot.global_position
	while pilot._flight_velocity.length() > 0.0 and elapsed < 4.0:
		await physics_frame
		var speed := pilot._flight_velocity.length()
		var step := 1.0 / Engine.physics_ticks_per_second
		max_acceleration = maxf(max_acceleration, (previous_speed - speed) / step)
		previous_speed = speed
		elapsed += step
	assert(pilot._flight_velocity == Vector3.ZERO and elapsed >= 3.3 and elapsed <= 3.6, "pilot brakes to rest in about 3.4 seconds")
	assert(max_acceleration <= BRAKE_ACCELERATION + 0.02, "pilot braking stays within three g")
	var stopped_distance := (pilot.global_position - start).length()
	assert(absf(stopped_distance - 100.0 * 100.0 / (2.0 * BRAKE_ACCELERATION)) < 6.0, "pilot stopping distance matches three-g physics")


func _test_disabled_pilot_braking() -> void:
	var pilot := _pilot(Vector3(500, 0, 0))
	pilot.set_flight(true)
	await physics_frame
	pilot._flight_velocity = Vector3(20, 0, 0)
	pilot.velocity = pilot._flight_velocity
	pilot.enabled = false
	pilot.request_brake()
	await physics_frame
	assert(pilot.braking and pilot._flight_velocity.length() < 20.0 and pilot._flight_velocity.length() > 19.0, "menu-disabled pilot continues gradual braking")
	assert(pilot.thrust_g <= 3.001, "menu-disabled braking remains within three g")


func _test_hull_braking() -> void:
	var hull: CoastingHull = HullScript.new()
	root.add_child(hull)
	hull.configure([Vector3i.ZERO])
	var wall := _wall(Vector3(200, 0, 0), Vector3(0.5, 20, 20))
	await physics_frame
	hull.velocity = Vector3(100, 0, 0)
	hull.request_brake()
	assert(hull.braking and hull.velocity.length() > 99.0, "hull brake request preserves initial speed")
	var start := hull.global_position
	var previous_speed := hull.velocity.length()
	var max_acceleration := 0.0
	for _i in 40:
		var move: Dictionary = hull.advance(0.1)
		var speed := hull.velocity.length()
		max_acceleration = maxf(max_acceleration, (previous_speed - speed) / 0.1)
		previous_speed = speed
		assert(move.impact_speed == 0.0, "braking hull stops clear of wall")
	assert(max_acceleration <= BRAKE_ACCELERATION + 0.02, "hull braking stays within three g")
	assert(hull.velocity == Vector3.ZERO, "hull reaches rest without reversing")
	assert(absf((hull.global_position - start).x - 100.0 * 100.0 / (2.0 * BRAKE_ACCELERATION)) < 7.0, "hull stopping distance matches three-g physics")
	assert(hull.global_position.x < 200.0 - 1.4, "hull body remains clear of wall")
	wall.queue_free()


func _test_autopilot_wall_braking() -> void:
	var pilot := _pilot(Vector3(1000, 0, 0))
	var wall := _wall(Vector3(1200, 1, 0), Vector3(0.5, 20, 20))
	pilot.set_flight(true)
	await physics_frame
	pilot._flight_velocity = Vector3(100, 0, 0)
	pilot.velocity = pilot._flight_velocity
	pilot.autopilot_to(Vector3(1500, 0, 0))
	var saw_braking := false
	var prior_speed := pilot._flight_velocity.length()
	var max_acceleration := 0.0
	var elapsed := 0.0
	while pilot._flight_velocity.length() > 0.0 and elapsed < 6.0:
		await physics_frame
		var speed := pilot._flight_velocity.length()
		var step := 1.0 / Engine.physics_ticks_per_second
		if pilot.braking:
			saw_braking = true
			max_acceleration = maxf(max_acceleration, (prior_speed - speed) / step)
		prior_speed = speed
		elapsed += step
	assert(saw_braking and max_acceleration <= BRAKE_ACCELERATION + 0.02, "autopilot obstacle response uses physical three-g braking")
	assert(pilot.global_position.x < 1200.0 - pilot.hull_radius and pilot._flight_velocity.length() < 1.0, "autopilot stops before the wall")
	wall.queue_free()


func _pilot(at: Vector3) -> Pilot:
	var pilot: Pilot = PilotScript.new()
	root.add_child(pilot)
	pilot.position = at
	return pilot


func _wall(at: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	return wall
