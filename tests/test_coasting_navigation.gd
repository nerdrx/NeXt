extends SceneTree

const HullScript = preload("res://scripts/coasting_hull.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var hull = HullScript.new()
	root.add_child(hull)
	hull.configure([Vector3i.ZERO])
	await physics_frame
	var result: Dictionary = hull.navigate(0.25, Vector3(50, 0, 0), 20.0)
	assert(not result.arrived and not result.blocked and result.displacement.length() > 0.0, "navigation advances toward distant target")
	assert(hull.global_basis.z.x < 0.0, "hull turns toward target with negative Z forward")
	hull.global_position = Vector3.ZERO
	hull.velocity = Vector3(5, 0, 0)
	result = hull.navigate(0.1, Vector3(1, 0, 0), 20.0)
	assert(not result.arrived and hull.velocity.x > 0.0 and hull.thrust_g <= 3.001, "near target brakes within the thrust limit")
	result = hull.navigate(0.1, Vector3(1, 0, 0), 20.0)
	assert(result.arrived and hull.velocity == Vector3.ZERO, "arrival waits until the ship can stop within the thrust limit")
	hull.global_position = Vector3.ZERO
	for invalid in [NAN, INF]:
		result = hull.navigate(0.1, Vector3(invalid, 0, 0), 20.0)
		assert(not result.arrived and not result.blocked and hull.global_position == Vector3.ZERO, "non-finite target is rejected")
	result = hull.navigate(INF, Vector3(20, 0, 0), 20.0)
	assert(hull.global_position == Vector3.ZERO, "non-finite delta is rejected")
	result = hull.navigate(0.1, Vector3(20, 0, 0), NAN)
	assert(hull.global_position == Vector3.ZERO, "non-finite speed is rejected")
	var wall := _wall(Vector3(0, 0, -5), Vector3(1, 1, 0.4))
	await physics_frame
	hull.global_position = Vector3.ZERO
	hull.velocity = Vector3.ZERO
	result = hull.navigate(0.1, Vector3(0, 0, -20), 20.0)
	assert(result.blocked and result.displacement == Vector3.ZERO and hull.velocity == Vector3.ZERO, "world obstacle blocks conservative turn clearance")
	wall.queue_free()
	await physics_frame
	var close_wall := _wall(Vector3(2, 0, 0), Vector3(0.2, 1, 0.2))
	hull.global_basis = Basis.IDENTITY
	await physics_frame
	result = hull.navigate(0.1, Vector3(20, 0, 0), 20.0)
	assert(result.blocked and hull.global_basis.is_equal_approx(Basis.IDENTITY), "near obstacle prevents rotating the hull")
	hull.add_collision_exception_with(close_wall)
	result = hull.navigate(0.1, Vector3(20, 0, 0), 20.0)
	assert(not result.blocked and result.displacement.length() > 0, "interior collision exceptions are excluded from turn clearance")
	close_wall.queue_free()
	print("COASTING_NAVIGATION_OK: arrival, steering, invalid inputs and obstacle clearance")
	quit()


func _wall(at: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = at
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	wall.add_child(collision)
	root.add_child(wall)
	return wall
