extends SceneTree

const ShipBlueprintScript = preload("res://scripts/ship_blueprint.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var family_id := "ranger" if "--ranger" in OS.get_cmdline_user_args() else "merchant"
	var blueprint: Dictionary = ShipBlueprintScript.family(family_id)
	if family_id == "ranger":
		assert(blueprint.layout.rooms.get("0,0,-3") == "lounge", "Ranger default layout includes bow lounge")
		assert(blueprint.layout.rooms.get("-1,0,0") == "medical", "Ranger default layout includes medical bay")
		assert(blueprint.layout.rooms.get("0,0,1") == "workshop", "Ranger default layout includes workshop")
	var cabin := ShipInterior.new()
	scene.add_child(cabin)
	cabin.build(blueprint.modules, blueprint.layout)
	await physics_frame
	await physics_frame
	var positions: Array[Vector3] = cabin.crew_positions(12)
	var route := _find_bow_to_aft_route(cabin, positions) if family_id == "ranger" else _find_same_deck_route(cabin, positions)
	assert(not route.is_empty(), "built family cabin offers connected crew stops on one deck")
	var start: Vector3 = route[0]
	var target: Vector3 = route[1]
	if family_id == "ranger":
		assert(start.distance_to(target) > ShipInterior.CELL.z * 6.0, "Ranger roaming route spans long bow to aft hull")
	var path: PackedVector3Array = cabin.crew_path(start, target)
	assert(not path.is_empty() and path[-1].distance_to(target) < 0.5, "crew navigation returns a complete cabin-local route")
	assert(cabin.crew_path(start, target + Vector3.UP * ShipInterior.CELL.y).is_empty(), "crew navigation rejects another deck")

	var crew := ShipCrew.new()
	crew.actor_id = "roaming-engineer-test"
	crew.display_name = "Roaming Engineer"
	crew.role = "engineer"
	crew.position = start
	cabin.add_child(crew)
	crew.configure_roaming(cabin, [target])
	crew._next_stop = 0
	crew._room_wait = 0.0
	await physics_frame
	var began_moving := false
	for _frame: int in 120:
		await physics_frame
		if crew.position.distance_to(start) > 0.2:
			began_moving = true
			break
	assert(began_moving, "crew leaves its berth and starts following the saved cabin route")
	assert(crew.is_on_floor() and absf(crew.position.y - start.y) < 0.4, "roaming crew stays supported on its deck")

	crew.set_cabin_load(3.0)
	var braced_at := crew.position
	var braced_path := crew._local_path.duplicate()
	for _frame: int in 20: await physics_frame
	assert(crew.position.distance_to(braced_at) < 0.03 and crew._local_path == braced_path, "bracing stops roaming while preserving route")
	assert(crew._brace_blend > 0.99 and crew._left_arm.get_node("Elbow").rotation.x > 1.0, "bracing blends into articulated arm pose")
	assert(crew._left_leg.get_node("Knee").rotation.x < -0.5 and crew._right_leg.rotation.z > 0.09, "bracing bends knees and widens stance")
	crew.set_cabin_load(0.0)
	for _frame: int in 20: await physics_frame
	assert(crew.position.distance_to(braced_at) > 0.1, "crew resumes route after maneuver")
	assert(crew._brace_blend == 0.0 and crew._left_arm.get_node("Elbow").rotation.x == 0.0 and crew._left_leg.rotation.z == 0.0 and crew._visual.position.y == 0.0, "release restores rest joints")

	crew.active = false
	var paused_at: Vector3 = crew.position
	for _frame: int in 20: await physics_frame
	assert(crew.position.distance_to(paused_at) < 0.03, "inactive crew pauses its local movement")
	crew.active = true

	var local_before_transform: Vector3 = crew.position
	cabin.position = Vector3(22, 0, -15)
	cabin.rotation = Vector3(0.12, 0.73, -0.1)
	cabin.force_update_transform()
	var tilted_path_clear := true
	for _frame: int in 20:
		await physics_frame
		tilted_path_clear = tilted_path_clear and _crew_capsule_clear(cabin, crew)
	var local_after_transform: Vector3 = crew.position
	assert(local_after_transform.distance_to(local_before_transform) > 0.2, "cabin-local route keeps progressing after parent pitch, yaw, roll and translation")
	assert(tilted_path_clear, "crew capsule remains clear of cabin walls while following the tilted route")
	assert(crew.is_on_floor() and absf(crew.position.y - start.y) < 0.4, "crew remains on the moving cabin deck")
	var local_velocity: Vector3 = cabin.global_basis.inverse() * crew.velocity
	assert(absf(local_velocity.y) < 0.2, "crew movement velocity follows the cabin basis along the deck")

	crew.roaming_enabled = false
	paused_at = crew.position
	for _frame: int in 20: await physics_frame
	assert(crew.position.distance_to(paused_at) < 0.03, "disabled roaming holds local position")
	crew.roaming_enabled = true
	crew._room_wait = 0.0
	var arrived := false
	var remaining_path: PackedVector3Array = cabin.crew_path(crew.position, target)
	var remaining_distance := 0.0
	var previous := crew.position
	for point: Vector3 in remaining_path:
		remaining_distance += previous.distance_to(point)
		previous = point
	var arrival_frame_budget := maxi(720, ceili(remaining_distance / crew.speed * Engine.physics_ticks_per_second * 1.5) + 120)
	for _frame: int in arrival_frame_budget:
		await physics_frame
		if crew.position.distance_to(target) < 0.85:
			arrived = true
			break
	assert(arrived and crew.is_on_floor(), "crew resumes after pauses and reaches its destination")

	var disconnected_cabin := ShipInterior.new()
	scene.add_child(disconnected_cabin)
	var disconnected_modules: Array[Dictionary] = blueprint.modules.duplicate(true)
	disconnected_modules.append({"kind": "cargo", "x": 10, "y": 0, "z": 10})
	disconnected_cabin.build(disconnected_modules, blueprint.layout)
	await physics_frame
	await physics_frame
	var remote_room := Vector3(10 * ShipInterior.CELL.x, 0.08, 10 * ShipInterior.CELL.z)
	assert(disconnected_cabin.crew_path(start, remote_room).is_empty(), "crew navigation rejects a disconnected room")
	var rebuilt_cabin := ShipInterior.new()
	scene.add_child(rebuilt_cabin)
	rebuilt_cabin.build(blueprint.modules, blueprint.layout)
	await physics_frame
	assert(not rebuilt_cabin.crew_path(start, target).is_empty(), "fresh cabin has its expected route")
	rebuilt_cabin.build([], blueprint.layout)
	await physics_frame
	assert(rebuilt_cabin.crew_path(start, target).is_empty(), "rebuilding cabin disposes its former navigation map")

	crew.queue_free()
	cabin.queue_free()
	disconnected_cabin.queue_free()
	rebuilt_cabin.queue_free()
	await process_frame
	print("SHIP_CREW_ROAMING_OK: cabin-local paths, moving cabin, pauses and unreachable routes")
	quit()


func _find_same_deck_route(cabin: ShipInterior, positions: Array[Vector3]) -> Array[Vector3]:
	for start_index: int in range(positions.size()):
		for target_index: int in range(start_index + 1, positions.size()):
			var from: Vector3 = positions[start_index]
			var to: Vector3 = positions[target_index]
			if absf(from.y - to.y) > 0.5 or from.distance_to(to) < 1.5: continue
			if not cabin.crew_path(from, to).is_empty(): return [from, to]
	return []


func _find_bow_to_aft_route(cabin: ShipInterior, positions: Array[Vector3]) -> Array[Vector3]:
	var best_route: Array[Vector3] = []
	var best_distance := 0.0
	for from: Vector3 in positions:
		if roundi(from.x / ShipInterior.CELL.x) != 0 or roundi(from.z / ShipInterior.CELL.z) != -4: continue
		for to: Vector3 in positions:
			if abs(roundi(to.x / ShipInterior.CELL.x)) != 2 or roundi(to.z / ShipInterior.CELL.z) != 3: continue
			var distance := from.distance_to(to)
			var candidate_path := cabin.crew_path(from, to)
			if distance <= best_distance or candidate_path.is_empty(): continue
			best_route = [from, to]
			best_distance = distance
	return best_route


func _crew_capsule_clear(cabin: ShipInterior, crew: ShipCrew) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.75
	query.shape = capsule
	# Lift the clearance probe slightly to exclude normal floor contact.
	query.transform = cabin.global_transform * Transform3D(Basis.IDENTITY, crew.position + Vector3.UP * 0.96)
	query.collision_mask = 1
	query.exclude = [crew.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.margin = 0.0
	return cabin.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
