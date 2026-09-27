extends SceneTree

const PilotScript = preload("res://scripts/pilot.gd")

var blocked := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "move_up", "move_down", "boost", "roll_left", "roll_right", "fire"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var pilot := _pilot()
	pilot.set_physics_process(false)
	assert(pilot.get_child_count() > 0, "pilot is ready")
	assert(not pilot._walk_shape.disabled, "unconfigured pilot retains walking capsule")
	var wide := [{"x": -1, "y": 0, "z": 0}, {"x": 1, "y": 0, "z": 0}]
	pilot.configure_ship_collision(wide)
	await physics_frame
	assert(pilot._module_shapes.size() == 2 and pilot.hull_radius > 4.0, "per-module boxes preserve the wide hull and expose its conservative radius")
	pilot.set_flight(true)
	await physics_frame
	var wing_wall := _add_wall(Vector3(4.05, 0, -5), Vector3(0.5, 8, 1))
	await physics_frame
	assert(pilot.test_move(pilot.global_transform, Vector3(0, 0, -10)), "wide wing hits a wall outside the old capsule")
	assert(pilot._module_shapes.all(func(shape: CollisionShape3D) -> bool: return shape.get_parent() == pilot), "module collision shapes are direct body children")
	pilot.camera.rotation.z = PI * 0.5
	pilot._update_module_collision_basis()
	assert(not pilot.test_move(pilot.global_transform, Vector3(0, 0, -10)), "rolling the wide wing changes its actual wall contact")
	pilot.reset_view()
	pilot._update_module_collision_basis()
	assert(pilot.test_move(pilot.global_transform, Vector3(0, 0, -10)), "reset orientation restores wide-wing contact")
	var old_radius := pilot.hull_radius
	pilot.configure_ship_collision([{"x": 0, "y": 0, "z": 0}])
	await physics_frame
	assert(pilot._module_shapes.size() == 1 and pilot.hull_radius < old_radius, "rebuild removes old active shapes and shrinks hull radius")
	assert(not pilot.test_move(pilot.global_transform, Vector3(0, 0, -10)), "removed wing no longer collides")
	wing_wall.queue_free()
	pilot.camera.rotation = Vector3(0.45, 0, 0.35)
	pilot._pitch = 0.45
	pilot._roll = 0.35
	pilot._update_module_collision_basis()
	assert(pilot._module_shapes[0].basis.is_equal_approx(pilot.camera.basis), "module collision follows camera pitch and roll without camera translation")
	pilot.reset_view()
	pilot.configure_ship_collision(wide)
	await physics_frame
	var gap_wall := _add_wall(Vector3(0, 0, -5), Vector3(0.2, 0.2, 1))
	await physics_frame
	assert(not pilot.test_move(pilot.global_transform, Vector3(0, 0, -10)), "central gap between wing modules remains empty")
	gap_wall.queue_free()
	pilot.set_flight(false)
	await physics_frame
	assert(not pilot._walk_shape.disabled and pilot._module_shapes.all(func(shape: CollisionShape3D) -> bool: return shape.disabled), "walking uses capsule and disables all module boxes")
	var door_left := _add_wall(Vector3(-1.0, 1, -0.5), Vector3(0.6, 2, 1))
	var door_right := _add_wall(Vector3(1.0, 1, -0.5), Vector3(0.6, 2, 1))
	await physics_frame
	assert(not pilot.test_move(pilot.global_transform, Vector3(0, 0, -1)), "walking capsule fits the narrow doorway")
	door_left.queue_free()
	door_right.queue_free()
	pilot.set_flight(true)
	pilot.configure_ship_collision(wide)
	await physics_frame
	_add_wall(Vector3(4.05, 0, -5), Vector3(0.5, 8, 1))
	pilot.autopilot_blocked.connect(func(): blocked += 1)
	pilot.set_physics_process(true)
	pilot.autopilot_to(Vector3(0, 0, -100))
	await create_timer(0.2).timeout
	assert(blocked == 1 and not pilot.autopilot_active, "autopilot lookahead sweep uses modular hull boxes")
	print("SHIP_COLLISION_OK: modules, gaps, mode switching, rotation, rebuild and autopilot")
	quit()


func _pilot() -> Pilot:
	var pilot: Pilot = PilotScript.new()
	root.add_child(pilot)
	return pilot


func _add_wall(at: Vector3, size: Vector3) -> StaticBody3D:
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
