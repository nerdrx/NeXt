extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	game.state.credits = 50000
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	game.apply_ship_stats()
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(10000, 5000, 0))
	game.pilot.flight_speed = 200
	game.close_menu()
	await physics_frame
	await physics_frame
	Input.action_press("move_forward")
	await create_timer(0.25).timeout
	assert(game.pilot.thrust_g > 2.9 and game.pilot.thrust_g < 3.01, "manual thrust observes cruise load limit")
	assert(game.pilot.flight_velocity().length() < 10.0, "ship cannot jump to commanded speed")
	Input.action_press("boost")
	await create_timer(0.25).timeout
	assert(game.pilot.thrust_g > 5.9 and game.pilot.thrust_g < 6.01)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/flight-thrust-load.png")
	Input.action_release("boost")
	Input.action_release("move_forward")
	await create_timer(0.1).timeout
	assert(game.pilot.thrust_g > 2.9 and game.pilot.thrust_g < 3.01, "braking also observes load limit")
	game.pilot.restore_flight_velocity(Vector3.ZERO)
	game.enter_interior()
	game.aboard_cruise = true
	game.aboard_cruise_target = game.coasting_hull.position + Vector3(1000, 0, 0)
	await create_timer(0.3).timeout
	assert(game.coasting_hull.thrust_g > 2.9 and game.coasting_hull.thrust_g < 3.01, "cruise uses same thruster model while walking aboard")
	assert(game.pilot.is_on_floor())
	game.aboard_cruise = false
	await physics_frame
	await physics_frame
	assert(game.coasting_hull.thrust_g == 0.0, "free coasting has no thruster load")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("FLIGHT_LOAD_GAMEPLAY_OK: manual thrust, boost, braking, aboard cruise and coasting")
	quit()
