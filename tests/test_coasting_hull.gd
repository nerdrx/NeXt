extends SceneTree

const HullScript = preload("res://scripts/coasting_hull.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var hull = HullScript.new()
	root.add_child(hull)
	hull.configure([Vector3i(-1, 0, 0), Vector3i(1, 0, 0), {"x": 1, "y": 0, "z": 0}])
	await physics_frame
	assert(hull.collision_layer == 0 and hull.collision_mask == 1, "hull only queries world collision layer")
	assert(hull._module_shapes.size() == 2, "duplicate module cells produce one collider each")
	assert(hull._module_shapes[0].position == Vector3(-2.8, 0, 0) and hull._module_shapes[0].shape.size == Vector3(3.0, 2.8, 3.0), "module boxes match centered ShipVisual bounds")
	var wall := _wall(Vector3(4.05, 0, -5), Vector3(0.5, 8, 0.5))
	await physics_frame
	hull.velocity = Vector3(0, 0, -100)
	var move: Dictionary = hull.advance(0.1)
	assert(move.impact_speed > 99.0 and hull.velocity == Vector3.ZERO, "wide wing impact stops hull and reports incoming speed")
	assert(move.displacement.z < -3.0 and move.displacement.z > -5.0, "swept hull stops at wall without tunneling")
	await physics_frame
	assert(hull.advance(0.1).displacement == Vector3.ZERO, "stopped hull remains still")
	wall.queue_free()
	hull.global_position = Vector3.ZERO
	var gap_wall := _wall(Vector3(0, 0, -5), Vector3(0.2, 0.2, 0.5))
	await physics_frame
	hull.velocity = Vector3(0, 0, -10)
	move = hull.advance(0.6)
	assert(move.impact_speed == 0.0 and is_equal_approx(move.displacement.z, -6.0), "open gap between modules stays clear")
	assert(hull.advance(-0.1).displacement == Vector3.ZERO and hull.advance(1.01).displacement == Vector3.ZERO, "invalid time steps do not move hull")
	gap_wall.queue_free()
	print("COASTING_HULL_OK: deduplicated module boxes, swept wing collision, preserved gap and delta guards")
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
