extends SceneTree

const CELL_SIZE := 2.8

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var cabin := ShipInterior.new()
	scene.add_child(cabin)
	var modules: Array[Dictionary] = []
	for deck in [0, 1]:
		for x in range(3):
			modules.append({"kind": "cargo", "x": x, "y": deck, "z": 0})
	cabin.build(modules)
	await physics_frame
	await physics_frame
	# Small rigid cabin motion must not change local navigation or lift coordinates.
	cabin.position = Vector3(31.0, 4.0, -23.0)
	cabin.rotation = Vector3(0.05, 0.42, -0.04)
	cabin.force_update_transform()
	await physics_frame
	await physics_frame

	var start := Vector3(2.0 * CELL_SIZE, 0.08, 0.0)
	var target := Vector3(2.0 * CELL_SIZE, CELL_SIZE + 0.08, 0.0)
	var route: Dictionary = cabin.crew_lift_route(start, target)
	assert(not route.is_empty(), "connected deck pair has an abstract lift route")
	assert(route.has("entry") and route.has("exit") and route.has("approach") and route.has("onward"))
	assert(route.approach is PackedVector3Array and not route.approach.is_empty(), "approach path reaches the lower lift")
	assert(route.onward is PackedVector3Array and not route.onward.is_empty(), "onward path leaves the upper lift")
	assert(cabin.crew_lift_route(start, Vector3(1.0, 0.08, 0.0)).is_empty(), "same-deck endpoints do not request a lift")
	assert(cabin.crew_lift_route(start, Vector3(0.0, CELL_SIZE * 2.0 + 0.08, 0.0)).is_empty(), "missing destination deck has no lift route")
	var arrival_probe := ShipCrew.new()
	arrival_probe.actor_id = "immediate-lift-clearance-probe"
	arrival_probe.position = route.exit
	cabin.add_child(arrival_probe)
	assert(not cabin.lift_clear(route.exit), "same-tick arrival clearance rejects a second crew capsule")
	arrival_probe.position = Vector3(100.0, 0.08, 0.0)
	arrival_probe.queue_free()

	var crew := ShipCrew.new()
	crew.actor_id = "crew-lift-transition-test"
	crew.display_name = "Lift Test"
	crew.role = "engineer"
	crew.position = start
	cabin.add_child(crew)
	var blocker := CharacterBody3D.new()
	blocker.name = "UpperLiftOccupant"
	blocker.collision_layer = 8
	blocker.collision_mask = 0
	blocker.position = route.exit
	var blocker_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.75
	blocker_shape.shape = capsule
	blocker_shape.position.y = 0.88
	blocker.add_child(blocker_shape)
	cabin.add_child(blocker)
	crew.configure_roaming(cabin, [target], blocker)
	crew._next_stop = 0
	crew._room_wait = 0.0
	await physics_frame

	var at_entry := false
	for _frame in 600:
		await physics_frame
		if crew.position.distance_to(route.entry) < 0.72:
			at_entry = true
			break
	assert(at_entry, "crew walks to the lower lift entry")
	var remained_lower := true
	for _frame in 180:
		await physics_frame
		remained_lower = remained_lower and crew.position.y < CELL_SIZE * 0.45
	assert(remained_lower, "occupied destination keeps crew on the lower deck")

	crew.active = false
	var paused_at := crew.position
	for _frame in 24: await physics_frame
	assert(crew.position.distance_to(paused_at) < 0.03 and crew.position.y < CELL_SIZE * 0.45, "inactive crew pauses before lift transition")
	crew.active = true
	crew.roaming_enabled = false
	paused_at = crew.position
	for _frame in 24: await physics_frame
	assert(crew.position.distance_to(paused_at) < 0.03 and crew.position.y < CELL_SIZE * 0.45, "disabled roaming pauses before lift transition")
	crew.roaming_enabled = true
	crew._room_wait = 0.0

	# Keep the destination occupied while roaming is paused, then clear the exit.
	blocker.position = Vector3(0.0, 0.08, 4.0)
	var changed_deck := false
	var arrived := false
	for _frame in 900:
		await physics_frame
		changed_deck = changed_deck or crew.position.y > CELL_SIZE * 0.65
		if crew.position.distance_to(target) < 0.9 and crew.is_on_floor():
			arrived = true
			break
	assert(changed_deck, "crew transitions to the upper deck after exit clearance")
	assert(arrived, "crew follows the upper-deck route to its selected stop")
	await _capture_landing(cabin, crew, route.exit)

	var disconnected := ShipInterior.new()
	scene.add_child(disconnected)
	var disconnected_modules: Array[Dictionary] = [
		{"kind": "cargo", "x": 0, "y": 0, "z": 0},
		{"kind": "cargo", "x": 10, "y": 0, "z": 0},
		{"kind": "cargo", "x": 0, "y": 1, "z": 0},
	]
	disconnected.build(disconnected_modules)
	await physics_frame
	await physics_frame
	assert(disconnected.crew_lift_route(Vector3(10.0 * CELL_SIZE, 0.08, 0.0), Vector3(0.0, CELL_SIZE + 0.08, 0.0)).is_empty(), "unreachable lower room cannot route to the deck lift")

	crew.queue_free()
	blocker.queue_free()
	cabin.queue_free()
	disconnected.queue_free()
	scene.queue_free()
	await process_frame
	print("CREW_LIFTS_OK: deck route, occupied lift wait, pauses, cabin transform, and invalid routes")
	quit()

func _capture_landing(cabin: ShipInterior, crew: ShipCrew, exit: Vector3) -> void:
	if DisplayServer.get_name() == "headless": return
	crew.active = false
	crew.position = exit
	crew.force_update_transform()
	var camera := Camera3D.new()
	cabin.add_child(camera)
	var deck_y: float = roundf(exit.y / CELL_SIZE) * CELL_SIZE
	camera.position = Vector3(exit.x, deck_y + 1.8, exit.z + 1.0)
	camera.look_at(cabin.to_global(Vector3(exit.x, deck_y + 0.025, exit.z)), cabin.global_basis.y)
	camera.make_current()
	for _frame in 2: await RenderingServer.frame_post_draw
	var capture_dir := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.get_texture().get_image().save_png(capture_dir.path_join("crew-lift-landing.png"))
	camera.queue_free()
