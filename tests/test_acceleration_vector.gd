extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	assert(FlightDynamics.acceleration_vector(Vector3.ZERO, Vector3(1, -2, 3), 0.5).is_equal_approx(Vector3(2, -4, 6)))
	assert(FlightDynamics.acceleration_vector(Vector3.INF, Vector3.ZERO, 1) == Vector3.ZERO)
	assert(FlightDynamics.acceleration_vector(Vector3.ZERO, Vector3.ONE, 0) == Vector3.ZERO)
	assert(FlightDynamics.acceleration_vector(Vector3.ZERO, Vector3.ONE, NAN) == Vector3.ZERO)
	var hull := CoastingHull.new()
	root.add_child(hull)
	hull.collision_mask = 0
	hull.acceleration_mps2 = 10.0
	hull.velocity = Vector3(0, 0, -100)
	hull.braking = true
	hull.advance(0.1)
	assert(hull.acceleration_vector.is_equal_approx(Vector3(0, 0, 10)), "braking vector opposes velocity")
	hull.braking = false
	hull.advance(0.1)
	assert(hull.acceleration_vector.is_zero_approx(), "vacuum coasting has zero acceleration")
	# At this density, drag removes the 1 m/s gained during this thrust step.
	hull.drag_dimensions = Vector3.ONE
	hull.drag_mass_kg = 100.0
	hull.atmospheric_density_source = func(_point: Vector3) -> float: return 2.0 / 10.1
	hull.velocity = Vector3(0, 0, -100)
	hull.navigate(0.1, hull.global_position + Vector3(0, 0, -10000), 1000)
	assert(hull.thrust_g > 1.0 and hull.aerodynamic_g > 1.0, "both opposing forces are active")
	assert(hull.acceleration_vector.length() < 0.001, "opposing thrust and drag cancel as vectors")
	hull.braking = true
	var before := hull.velocity
	hull.advance(0.1)
	assert(hull.acceleration_vector.is_equal_approx((hull.velocity - before) / 0.1), "braking and drag combine without double counting")
	hull.advance(0)
	assert(hull.acceleration_vector.is_zero_approx(), "zero step clears stale acceleration")
	# A collision remains an impact event, not a thrust/drag acceleration sample.
	hull.atmospheric_density_source = Callable()
	hull.configure([{"kind":"core", "x":0, "y":0, "z":0}])
	hull.collision_mask = 1
	hull.braking = false
	hull.position = Vector3.ZERO
	hull.velocity = Vector3(0, 0, -100)
	var wall := StaticBody3D.new()
	wall.position.z = -5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, 0.2)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	var collision := hull.advance(0.1)
	assert(collision.impact_speed > 0 and hull.velocity.is_zero_approx())
	assert(hull.acceleration_vector.is_zero_approx(), "collision impulse is not reported as sustained acceleration")
	wall.queue_free()
	hull.queue_free()
	await process_frame
	print("ACCELERATION_VECTOR_OK: signed forces, cancellation, braking, zero step and collision separation")
	quit()
