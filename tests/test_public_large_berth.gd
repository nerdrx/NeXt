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
	save_path = "user://public-berth-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.state.credits = 200000
	assert(not game._uses_large_berth())
	assert(game._public_berth_point("launch") == game.world.to_global(game.world.launch_position))
	for x in range(2, 17):
		for side in [-1, 1]: assert(game.state.add_module("cargo", Vector3i(x * side, 0, 0)).is_empty())
	for y in range(1, 17): assert(game.state.add_module("cargo", Vector3i(16, y, 0)).is_empty())
	game.apply_ship_stats()
	assert(game._uses_large_berth())
	game.pilot.set_flight(true)
	game.pilot.teleport(game._public_berth_point("launch"))
	game.pilot.velocity = Vector3(80, 0, 0)
	game._interact()
	assert(game.pilot.flying)
	game.pilot.velocity = Vector3.ZERO
	game._interact()
	assert(not game.pilot.flying)
	assert(game._ship_pad() == game.world.to_global(game.world.large_dock_position))
	await create_timer(0.4).timeout
	assert(game.pilot.is_on_floor())
	for local_point: Vector3 in game.world.large_berth_route:
		var arrived := false
		for frame in 2000:
			var offset: Vector3 = game.world.to_global(local_point) - game.pilot.position
			offset.y = 0
			if offset.length() < 0.4:
				arrived = true
				break
			game.pilot.rotation.y = atan2(-offset.x, -offset.z)
			Input.action_press("move_forward")
			await physics_frame
			assert(game.world.to_local(game.pilot.position).y > -0.5)
		Input.action_release("move_forward")
		assert(arrived, "walk connects public large berth to hangar")
	game.pilot.teleport(game.world.to_global(game.world.large_stand_position))
	assert(game.save_commander(false))
	game.load_commander()
	game.set_process(false)
	game._clear_actors()
	game.close_menu()
	assert(game.docked_station == -1 and not game.pilot.flying)
	assert(game.pilot.position.distance_to(game._public_berth_point("stand")) < 0.1)
	assert(game._ship_pad() == game.world.to_global(game.world.large_dock_position))
	if DisplayServer.get_name() != "headless":
		var view := Camera3D.new()
		game.add_child(view)
		view.position = game.world.to_global(Vector3(-365, 155, -365))
		view.look_at(game.world.to_global(game.world.large_dock_position))
		view.current = true
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/public-large-berth.png")
		view.queue_free()
	game._interact()
	assert(game.pilot.flying and game.docked_station == -1)
	assert(game.pilot.position.distance_to(game._public_berth_point("launch")) < 0.1)
	await physics_frame
	await physics_frame
	assert(not game.pilot.test_move(game.pilot.global_transform, Vector3(0, -0.1, 0)))
	game.pilot.teleport(Vector3(8193, 112, -180))
	game._rebase_flight()
	game.approach_public_station()
	assert(game.cruise_address != null)
	assert(game.cruise_address.relative_to(game.flight_origin, 60000).distance_to(game._public_berth_point("launch")) < 0.1)
	game.pilot.cancel_autopilot()
	game.jump_destination = (game.state.system_index + 1) % Universe.SYSTEM_LIMIT
	game._complete_jump()
	assert(game.pilot.position.distance_to(game._public_berth_point("launch")) < 0.1)
	await physics_frame
	await physics_frame
	assert(not game.pilot.test_move(game.pilot.global_transform, Vector3(0, -0.1, 0)))
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game.queue_free()
	await process_frame
	await process_frame
	print("PUBLIC_LARGE_BERTH_OK: hull selection, speed guard, supported boarding, save restoration and clear launch")
	quit()
