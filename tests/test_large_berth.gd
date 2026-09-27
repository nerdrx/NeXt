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
	save_path = "user://large-berth-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.state.credits = 200000
	game.state.cargo.alloys = 20
	assert(game.state.build_station("Heavy Logistics").is_empty())
	game.rebuild_owned_stations()
	var station: OwnedStation = game._station_node(0)
	assert(not game._uses_large_berth())
	assert(game._station_berth_point(station, "dock") == station.to_global(station.dock_position))
	for x in range(2, 17):
		for side in [-1, 1]: assert(game.state.add_module("cargo", Vector3i(x * side, 0, 0)).is_empty())
	for y in range(1, 17): assert(game.state.add_module("cargo", Vector3i(16, y, 0)).is_empty())
	game.apply_ship_stats()
	assert(game._uses_large_berth())
	game.pilot.set_flight(true)
	game.pilot.teleport(game._station_berth_point(station, "launch"))
	game.pilot.velocity = Vector3(80, 0, 0)
	assert(game._dock_owned_station() and game.pilot.flying)
	game.pilot.velocity = Vector3.ZERO
	assert(game._dock_owned_station() and not game.pilot.flying)
	assert(game._ship_pad() == station.to_global(station.large_dock_position))
	await create_timer(0.4).timeout
	assert(game.pilot.is_on_floor())
	assert(station.contains_walk_position(station.to_local(game.pilot.position)))
	for local_point: Vector3 in [Vector3(54, 0.1, 150), Vector3(35, 0.1, 115), Vector3(35, 0.1, 100), Vector3(18, 0.1, 100), station.stand_position]:
		var arrived := false
		for frame in 2000:
			var offset: Vector3 = station.to_global(local_point) - game.pilot.position
			offset.y = 0
			if offset.length() < 0.4:
				arrived = true
				break
			game.pilot.rotation.y = atan2(-offset.x, -offset.z)
			Input.action_press("move_forward")
			await physics_frame
			assert(station.to_local(game.pilot.position).y > -0.5)
		Input.action_release("move_forward")
		assert(arrived, "walk connects large berth to existing apron")
	game.pilot.teleport(station.to_global(station.large_stand_position))
	assert(game.save_commander(false))
	var saved_point: Vector3 = game.pilot.position
	game.load_commander()
	game.set_process(false)
	game._clear_actors()
	game.close_menu()
	station = game._station_node(0)
	assert(game.docked_station == 0 and not game.pilot.flying)
	assert(game.pilot.position.distance_to(saved_point) < 0.1)
	assert(game._ship_pad() == station.to_global(station.large_dock_position))
	if DisplayServer.get_name() != "headless":
		var view := Camera3D.new()
		game.add_child(view)
		view.position = station.to_global(Vector3(175, 135, 365))
		view.look_at(station.to_global(Vector3(0, 15, 170)))
		view.current = true
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/large-berth.png")
		view.queue_free()
	game._interact()
	assert(game.pilot.flying and game.docked_station == -1)
	assert(game.pilot.position.distance_to(game._station_berth_point(station, "launch")) < 0.1)
	await physics_frame
	await physics_frame
	assert(not game.pilot.test_move(game.pilot.global_transform, Vector3(0, -0.1, 0)))
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game.queue_free()
	await process_frame
	await process_frame
	print("LARGE_BERTH_OK: hull selection, speed guard, supported boarding, save restoration and clear launch")
	quit()
