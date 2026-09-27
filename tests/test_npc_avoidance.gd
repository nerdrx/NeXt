extends SceneTree


func _initialize() -> void:
	Engine.physics_ticks_per_second = 120
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Wider than the patrol's 26 m wander, so unsteered patrol cannot miss it.
	box.size = Vector3(4, 60, 60)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	wall.position = Vector3(100, 0, 0)
	world.add_child(wall)

	var ship := ShipActor.new()
	ship.position = Vector3.ZERO
	ship.speed = 65.0
	ship.set_patrol_center(Vector3(200, 0, 0))
	world.add_child(ship)
	await physics_frame
	var detour := ship._avoid_obstacles(Vector3.RIGHT * 65.0)
	assert(absf(detour.y) + absf(detour.z) > 1.0, "blocked direct command chooses a lateral route")

	var start := ship.global_position
	var cleared_wall := false
	var made_progress := false
	var crossed_wall_plane := false
	for _frame in 3000: # 25 seconds at 120 Hz.
		await physics_frame
		var p := ship.global_position
		if p.x > 20.0:
			made_progress = true
		if p.x > 90.0 and p.x < 110.0 and (absf(p.y) > 32.0 or absf(p.z) > 32.0):
			cleared_wall = true
		if p.x > 106.0:
			crossed_wall_plane = true
			break
	assert(made_progress and ship.global_position.distance_to(start) > 20.0, "ship makes forward progress toward patrol point")
	assert(cleared_wall and crossed_wall_plane, "ship routes around finite wall without crossing its occupied volume")

	# Once wall is behind, steering should settle back toward the patrol destination.
	for _frame in 180:
		await physics_frame
	assert(ship.velocity.x > 0.0 and absf(ship.velocity.x) >= absf(ship.velocity.z), "ship resumes mostly direct travel after clearing wall")

	var room := Node3D.new()
	room.position = Vector3(1000, 0, 0)
	world.add_child(room)
	for offset: Vector3 in [Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 6, 0), Vector3(0, -6, 0), Vector3(0, 0, 6), Vector3(0, 0, -6)]:
		var body := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var room_wall := BoxShape3D.new()
		room_wall.size = Vector3(12, 12, 12)
		if not is_zero_approx(offset.x): room_wall.size.x = 1.0
		elif not is_zero_approx(offset.y): room_wall.size.y = 1.0
		else: room_wall.size.z = 1.0
		shape_node.shape = room_wall
		body.add_child(shape_node)
		body.position = offset
		room.add_child(body)
	var trapped_ship := ShipActor.new()
	trapped_ship.set_physics_process(false)
	room.add_child(trapped_ship)
	await physics_frame
	assert(trapped_ship._avoid_obstacles(Vector3.FORWARD * 50.0) == Vector3.ZERO, "fully enclosed fan stops instead of commanding into a wall")

	# A distant wall can still block the current inertial path when braking is weak.
	var inertial_ship := ShipActor.new()
	inertial_ship.position = Vector3(2000, 0, 0)
	world.add_child(inertial_ship)
	var distant_wall := StaticBody3D.new()
	distant_wall.collision_layer = 1
	var distant_shape := CollisionShape3D.new()
	var distant_box := BoxShape3D.new()
	distant_box.size = Vector3(4, 60, 60)
	distant_shape.shape = distant_box
	distant_wall.add_child(distant_shape)
	distant_wall.position = Vector3(2400, 0, 0)
	world.add_child(distant_wall)
	await physics_frame
	inertial_ship.set_physics_process(false)
	inertial_ship.velocity = Vector3.RIGHT * 100.0
	assert(inertial_ship._avoid_obstacles(Vector3.FORWARD * 50.0, 10.0) == Vector3.ZERO,
		"inertial braking conflict stops even when desired direction is clear")
	assert(inertial_ship._avoid_obstacles(Vector3.FORWARD * 50.0, 30.0) == Vector3.FORWARD * 50.0,
		"strong acceleration preserves clear sideways command when wall is beyond stopping distance")
	inertial_ship.velocity = Vector3.ZERO
	var cautious_command := inertial_ship._avoid_obstacles(Vector3.RIGHT * 100.0, 10.0)
	assert(cautious_command.length() > 1.0 and absf(cautious_command.normalized().dot(Vector3.RIGHT)) < 0.99,
		"weak acceleration detects distant wall and chooses a lateral detour from rest")
	assert(inertial_ship._avoid_obstacles(Vector3.RIGHT * 100.0, 30.0) == Vector3.RIGHT * 100.0,
		"strong acceleration keeps direct command when distant wall is beyond desired-path horizon")
	print("NPC avoidance tests passed: wall clearance, progress, direct-path recovery, enclosed stop and braking horizons")
	quit()
