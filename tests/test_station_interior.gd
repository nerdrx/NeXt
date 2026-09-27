extends SceneTree

var game: Node
var save_path: String

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	game.close_menu()
	save_path = "user://station-interior-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.state.credits = 50000
	game.state.cargo.alloys = 20
	if not _check(game.state.build_station("Wayfarer Exchange").is_empty(), "build station"): return
	game.rebuild_owned_stations()
	var station: OwnedStation = game._station_node(0)
	game.pilot.set_flight(true)
	game.pilot.teleport(station.to_global(station.launch_position))
	game._interact()
	await create_timer(0.4).timeout
	if not _check(game.docked_station == 0 and game.pilot.is_on_floor(), "start on station pad"): return
	var route: Array[Vector3] = station.interior_route.duplicate()
	var visited: Dictionary = {}
	var saved := false
	for local_point: Vector3 in route:
		var target := station.to_global(local_point)
		var arrived := false
		for frame in 1600:
			var offset: Vector3 = target - game.pilot.position
			offset.y = 0
			if offset.length() < 0.4:
				arrived = true
				break
			game.pilot.rotation.y = atan2(-offset.x, -offset.z)
			Input.action_press("move_forward")
			await physics_frame
			if not _check(station.to_local(game.pilot.position).y > -0.5, "walk remains supported on bridge and room floors"): return
		Input.action_release("move_forward")
		if not _check(arrived, "walk reaches %s; actual %s" % [local_point, station.to_local(game.pilot.position)]): return
		var service: Dictionary = game._station_service()
		if service.is_empty(): continue
		visited[service.page] = true
		game._interact()
		if not _check(game.ui_open and game.deck.page == service.page, "room terminal opens its service"): return
		game.close_menu()
		if not saved:
			game.pilot.teleport(station.to_global(service.position))
			var saved_point: Vector3 = game.pilot.position
			if not _check(game.save_commander(false), "save inside station room"): return
			game.load_commander()
			game._clear_actors()
			game.close_menu()
			station = game._station_node(0)
			if not _check(game.docked_station == 0 and not game.pilot.flying and game.pilot.position.distance_to(saved_point) < 0.1, "load restores station and interior position"): return
			if not _check(game._ship_pad().distance_to(station.to_global(station.dock_position)) < 0.1, "load restores ship to the same dock"): return
			var shifted_origin := SectorPosition.new(Vector3i(1, 0, 0))
			game.flight_frame.rebase(game.flight_origin, shifted_origin)
			game.pilot.position -= Vector3(8192, 0, 0)
			game.flight_origin = shifted_origin
			if not _check(game.save_commander(false), "save interior after origin shift"): return
			game.load_commander()
			game._clear_actors()
			game.close_menu()
			station = game._station_node(0)
			if not _check(game.docked_station == 0 and station.to_local(game.pilot.position).distance_to(service.position) < 0.1, "rebased interior restores in the same room"): return
			saved_point = game.pilot.position
			if DisplayServer.get_name() != "headless":
				Engine.time_scale = 1
				game.pilot.teleport(station.to_global(Vector3(133, 0.1, service.position.z + 5)))
				game.pilot.rotation.y = -PI / 2
				game.hud.message_time = 0
				await create_timer(0.2).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://build/station-room.png")
				game.pilot.teleport(saved_point)
				Engine.time_scale = 4
			saved = true
	if not _check(visited.size() == station.interior_services.size(), "walk visits every level-one room"): return
	if not _check(not station.contains_walk_position(Vector3(90, 0, 10)), "space outside the bridge is not a save landing location"): return
	var expanded := OwnedStation.new()
	game.add_child(expanded)
	expanded.position = Vector3(20000, 5000, 20000)
	expanded.build({"level": 100, "name": "Expanded fixture"})
	await physics_frame
	await physics_frame
	if not _check(expanded.interior_services.size() == 8, "largest station has eight service rooms"): return
	for service: Dictionary in expanded.interior_services:
		var glass_ray := PhysicsRayQueryParameters3D.create(expanded.to_global(Vector3(146, 2.4, service.position.z + 1.5)), expanded.to_global(Vector3(150, 2.4, service.position.z + 1.5)), 1)
		if not _check(not game.get_world_3d().direct_space_state.intersect_ray(glass_ray).is_empty(), "glazing blocks passage between central window posts"): return
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	for index in range(1, expanded.interior_route.size()):
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = 1
		query.transform.origin = expanded.to_global(expanded.interior_route[index - 1] + Vector3.UP * 0.9)
		query.motion = expanded.interior_route[index] - expanded.interior_route[index - 1]
		if query.motion.length() < 0.01: continue
		var fraction: PackedFloat32Array = game.get_world_3d().direct_space_state.cast_motion(query)
		if not _check(fraction[0] > 0.99, "expanded station route clears pilot capsule at segment %d" % index): return
	expanded.queue_free()
	# A bad spatial address falls back to the orbital dock, never restores into space.
	game.state.location.address = SectorPosition.new(Vector3i.ZERO, station.to_global(Vector3(90, 0, 10)) + Vector3(game.flight_origin.sector) * SectorPosition.SECTOR_SIZE).to_save()
	game._build_system()
	game._restore_flight_location()
	if not _check(game.docked_station == -1, "unsupported saved position cannot restore station walking"): return
	_cleanup()
	game.queue_free()
	await process_frame
	Engine.time_scale = 1
	Engine.physics_ticks_per_second = 60
	print("STATION_INTERIOR_OK: physical walk to every room and back, services, interior save/load and invalid position fallback")
	quit()

func _check(ok: bool, message: String) -> bool:
	if ok: return true
	push_error("STATION_INTERIOR_FAIL: " + message)
	_cleanup()
	quit(1)
	return false

func _cleanup() -> void:
	Input.action_release("move_forward")
	if game != null:
		game.sound.shutdown()
		game.session.leave()
	if not save_path.is_empty() and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
