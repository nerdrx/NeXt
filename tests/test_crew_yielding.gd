extends SceneTree

const MIN_CAPSULE_SEPARATION := 0.82

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var cabin := ShipInterior.new()
	scene.add_child(cabin)
	var modules: Array[Dictionary] = []
	for x in range(-1, 2):
		modules.append({"kind": "room", "x": x, "y": 0, "z": 0})
	cabin.build(modules)
	_add_corridor_rails(cabin)
	_add_nonblocking_hull_probe(cabin)
	await physics_frame
	await physics_frame

	var left_start := Vector3(-2.55, 0.08, 0.0)
	var right_start := Vector3(2.55, 0.08, 0.0)
	var left_goal := right_start
	var right_goal := left_start
	var left := _make_crew("yield-left", left_start)
	var right := _make_crew("yield-right", right_start)
	cabin.add_child(left)
	cabin.add_child(right)
	left.configure_roaming(cabin, [left_goal])
	right.configure_roaming(cabin, [right_goal])
	_force_departure(left)
	_force_departure(right)

	var closest := INF
	var left_passed := false
	var right_passed := false
	for frame in 900:
		await physics_frame
		var separation := _horizontal_distance(left.position, right.position)
		closest = minf(closest, separation)
		assert(separation >= MIN_CAPSULE_SEPARATION, "opposing crew capsules overlapped in the corridor")
		left_passed = left_passed or left.position.x > 0.55
		right_passed = right_passed or right.position.x < -0.55
		if left_passed and right_passed and left.position.distance_to(left_goal) < 0.9 and right.position.distance_to(right_goal) < 0.9:
			break
	assert(left_passed and right_passed, "both crew eventually passed one another")
	assert(left.position.distance_to(left_goal) < 0.9 and right.position.distance_to(right_goal) < 0.9, "both crew reached the opposite stops")
	print("CREW_YIELDING_HEADON_OK closest_separation=", closest)

	# Recenter both crew and check that local routes remain valid after cabin motion.
	left.position = left_start
	right.position = right_start
	_force_departure(left)
	_force_departure(right)
	left._local_path.clear()
	right._local_path.clear()
	cabin.position = Vector3(24.0, 3.0, -17.0)
	cabin.rotation = Vector3(0.07, 0.43, -0.05)
	cabin.force_update_transform()
	var local_left_start := left.position
	var local_right_start := right.position
	for _frame in 120:
		await physics_frame
	assert(left.position.distance_to(local_left_start) > 0.3 and right.position.distance_to(local_right_start) > 0.3, "translated, tilted cabin preserves local walking")

	# A stationary, colliding player occupant blocks the corridor without overlap.
	_add_player_choke(cabin)
	right.queue_free()
	await physics_frame
	var blocker := CharacterBody3D.new()
	blocker.name = "StationaryPlayer"
	blocker.collision_layer = 8
	blocker.collision_mask = 1 | 4
	blocker.position = Vector3(0.0, 0.08, 0.0)
	var blocker_shape := CollisionShape3D.new()
	var blocker_capsule := CapsuleShape3D.new()
	blocker_capsule.radius = 0.43
	blocker_capsule.height = 1.8
	blocker_shape.shape = blocker_capsule
	blocker_shape.position.y = 0.9
	blocker.add_child(blocker_shape)
	cabin.add_child(blocker)
	left.position = Vector3(-2.0, 0.08, 0.0)
	left.configure_roaming(cabin, [left_goal], blocker)
	_force_departure(left)
	var blocked_frames := 0
	for _frame in 300:
		await physics_frame
		if _horizontal_distance(left.position, blocker.position) < 1.4:
			blocked_frames += 1
		assert(_horizontal_distance(left.position, blocker.position) >= MIN_CAPSULE_SEPARATION, "crew capsule overlapped stationary player")
	assert(blocked_frames >= 180, "crew remains blocked near the stationary player")
	assert(left.position.x < -0.6, "crew does not pass through the player in the narrow corridor")
	print("CREW_YIELDING_OCCUPANT_BLOCK_OK frames=", blocked_frames)
	blocker.position = Vector3(0.0, 0.08, 3.0)
	for _frame in 750:
		await physics_frame
	assert(left.position.distance_to(left_goal) < 0.9, "crew resumes and reaches its stop when the player moves aside")

	left.queue_free()
	if is_instance_valid(right): right.queue_free()
	blocker.queue_free()
	cabin.queue_free()
	scene.queue_free()
	await process_frame
	print("CREW_YIELDING_OK closest_separation=", closest, " occupied corridor blocked then resumed")
	quit()

func _make_crew(id: String, start: Vector3) -> ShipCrew:
	var crew := ShipCrew.new()
	crew.actor_id = id
	crew.display_name = id
	crew.role = "engineer"
	crew.position = start
	return crew

func _force_departure(crew: ShipCrew) -> void:
	crew._next_stop = 0
	crew._room_wait = 0.0
	crew._local_path.clear()

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _add_corridor_rails(cabin: ShipInterior) -> void:
	for side in [-1.0, 1.0]:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		wall.position = Vector3(0.0, 0.8, side * 1.0)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(9.0, 1.5, 0.1)
		shape.shape = box
		wall.add_child(shape)
		cabin.add_child(wall)

func _add_nonblocking_hull_probe(cabin: ShipInterior) -> void:
	var hull := StaticBody3D.new()
	hull.name = "LayerTwoHullProbe"
	hull.collision_layer = 2
	hull.collision_mask = 0
	hull.position = Vector3(0.0, 0.9, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 1.8, 1.8)
	shape.shape = box
	hull.add_child(shape)
	cabin.add_child(hull)

func _add_player_choke(cabin: ShipInterior) -> void:
	# Crew still fits individually; two capsules cannot pass the player here.
	for side in [-1.0, 1.0]:
		var rail := StaticBody3D.new()
		rail.collision_layer = 1
		rail.collision_mask = 0
		rail.position = Vector3(0.0, 0.9, side * 0.72)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.6, 1.8, 0.1)
		shape.shape = box
		rail.add_child(shape)
		cabin.add_child(rail)
