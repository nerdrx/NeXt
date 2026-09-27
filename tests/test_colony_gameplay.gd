extends SceneTree

var game: Node
var save_path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	save_path = "user://colony-gameplay-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.close_menu()
	if not _check(game.colonies.size() == game.world.planets.size(), "planet ports instantiated"): return
	var colony: Node3D = game.colonies[0]
	var world_id: int = game.world.get_instance_id()
	var colony_id: int = colony.get_instance_id()
	var pad: Vector3 = colony.to_global(colony.landing_position)
	game.pilot.set_flight(true)
	game.approach_colony(0)
	if not _check(game.pilot.autopilot_active, "colony approach engages flight autopilot"): return
	game.pilot.teleport(pad + Vector3.UP * 25)
	game.pilot.velocity = Vector3.RIGHT * 30
	game._interact()
	if not _check(game.pilot.flying and game.manual_planet == -1, "fast port docking rejected"): return
	game.pilot.velocity = Vector3.ZERO
	game._interact()
	if not _check(not game.pilot.flying and game.manual_planet == 0, "slow port docking accepted"): return
	if not _check(game.world.get_instance_id() == world_id and colony.get_instance_id() == colony_id and game.surface_index == -1, "docking preserves world and port"): return
	if not _check(game._ship_pad().distance_to(pad) < 0.02, "ship anchored on port pad"): return
	await create_timer(0.7).timeout
	if not _check(game.pilot.is_on_floor(), "port deck supports walking"): return
	var before: Vector3 = game.pilot.position
	Input.action_press("move_forward")
	await create_timer(0.4).timeout
	Input.action_release("move_forward")
	if not _check(game.pilot.position.distance_to(before) > 1, "pilot can walk across port deck"): return
	if not _check(game.pilot.is_on_floor(), "walking retains deck contact"): return
	game.pilot.teleport(colony.to_global(colony.service_position + Vector3(0, 0.3, 2)))
	await create_timer(0.3).timeout
	game._interact()
	if not _check(game.ui_open and game.deck.page == "market", "terminal interaction opens market"): return
	game.close_menu()
	# Enter all service rooms under walking physics, rather than teleporting inside.
	for index in colony.door_positions.size():
		var door: Vector3 = colony.door_positions[index]
		var room: Vector3 = colony.interior_positions[index]
		game.pilot.teleport(colony.to_global(door + Vector3(0, 0.3, 0.5)))
		game.pilot.reset_view()
		game.pilot.set_walk_up(colony.global_basis.y)
		game.pilot.global_basis = colony.global_basis
		await create_timer(0.2).timeout
		var nearby_service: Dictionary = game._colony_service()
		if not _check(nearby_service.is_empty() or nearby_service.label == "Port services", "interior services require entering doorway"): return
		Input.action_press("move_forward")
		var walked := 0
		while colony.to_local(game.pilot.position).z > room.z + 0.7 and walked < 180:
			await physics_frame
			walked += 1
		Input.action_release("move_forward")
		await create_timer(0.2).timeout
		if not _check(walked < 180 and game.pilot.is_on_floor(), "walk through doorway %d onto room floor" % index): return
		game._interact()
		if not _check(game.ui_open and game.deck.page == colony.interior_services[index].page, "interior service opens correct page %d" % index): return
		game.close_menu()
		if DisplayServer.get_name() != "headless" and index == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/port-interior.png")
	# An actual physics blocker must deny interaction even within service range.
	var obstruction := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var obstruction_shape := BoxShape3D.new()
	obstruction_shape.size = Vector3(0.6, 0.6, 0.6)
	collision.shape = obstruction_shape
	obstruction.add_child(collision)
	game.add_child(obstruction)
	var service_target: Vector3 = colony.to_global(colony.interior_services.back().position + Vector3.UP * 1.5)
	var eye: Vector3 = game.pilot.camera.global_position
	obstruction.global_position = eye + eye.direction_to(service_target)
	await physics_frame
	await physics_frame
	if not _check(game._colony_service().is_empty(), "physical obstruction denies nearby service"): return
	obstruction.queue_free()
	await physics_frame
	await physics_frame
	if not _check(not game._colony_service().is_empty(), "removing obstruction restores nearby service"): return
	var saved_ship: Dictionary = game.landed_ship_address.to_save()
	if not _check(game.save_commander(false), "port save writes"): return
	game.pilot.teleport(Vector3.ZERO)
	game.load_commander()
	game._clear_actors()
	game.close_menu()
	if not _check(not game.pilot.flying and game.manual_planet == 0, "load restores port walking"): return
	colony = game.colonies[0]
	pad = colony.to_global(colony.landing_position)
	if not _check(game.landed_ship_address.to_save() == saved_ship and game._ship_pad().distance_to(pad) < 0.02, "load preserves port ship anchor"): return
	await create_timer(0.5).timeout
	if not _check(game.pilot.is_on_floor() and game._near_colony_terminal(), "loaded pilot stands beside port services"): return
	if DisplayServer.get_name() != "headless":
		game.pilot.teleport(colony.to_global(Vector3(10, 0.3, 15)))
		game.pilot.reset_view()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/surface-city.png")
	world_id = game.world.get_instance_id()
	colony_id = colony.get_instance_id()
	game.pilot.teleport(pad + Vector3(12, 1, 0))
	game._interact()
	if not _check(game.pilot.flying and game.manual_planet == -1, "boarding lifts off from port"): return
	if not _check(game.world.get_instance_id() == world_id and colony.get_instance_id() == colony_id, "liftoff preserves world and port"): return
	if not _check(game.pilot.position.distance_to(pad + Vector3.UP * 25) < 0.02, "liftoff uses port pad"): return
	_cleanup()
	game.queue_free()
	await process_frame
	await process_frame
	print("COLONY_GAMEPLAY_OK: approach, docking speed guard, same-scene port walking, four doorway walks and interior services, save restore and liftoff")
	quit()

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("COLONY_GAMEPLAY_FAILED: " + message)
		_cleanup()
		quit(1)
	return ok

func _cleanup() -> void:
	Input.action_release("move_forward")
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
