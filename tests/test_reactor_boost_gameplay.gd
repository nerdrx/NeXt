extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	game.close_menu()
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(10000, 5000, 0))
	game.pilot.flight_speed = 1000.0
	await physics_frame
	await physics_frame
	game.pilot.set_physics_process(false)

	# Two valid shield refits consume the reactor headroom while keeping the
	# engine installed; boost should then provide no extra thrust.
	assert(game.state.add_module("shield", Vector3i(2, 0, 0)).is_empty())
	assert(game.state.add_module("shield", Vector3i(2, 0, 1)).is_empty())
	game.apply_ship_stats()
	var depleted_stats: Dictionary = game.state.ship_stats()
	assert(float(depleted_stats.boost_multiplier) == 1.0, "power-heavy refit uses nominal power for systems")
	var ordinary_delta := await _forward_speed_delta(game, false)
	var depleted_boost_delta := await _forward_speed_delta(game, true)
	assert(absf(depleted_boost_delta - ordinary_delta) < 0.2, "no reactor headroom means Shift adds no acceleration")

	# An attached reactor restores headroom and should increase measured speed
	# over the same physics interval under actual forward + Shift input.
	assert(game.state.add_module("reactor", Vector3i(2, 1, 0)).is_empty())
	game.apply_ship_stats()
	var restored_stats: Dictionary = game.state.ship_stats()
	assert(float(restored_stats.boost_multiplier) > 1.0, "additional reactor restores boost headroom")
	assert(is_equal_approx(game.pilot.boost_acceleration_mps2, float(restored_stats.boost_acceleration_mps2)))
	var restored_boost_delta := await _forward_speed_delta(game, true)
	assert(restored_boost_delta > depleted_boost_delta + 1.0, "reactor headroom measurably increases Shift acceleration")
	assert(restored_boost_delta < 6.0 * FlightDynamics.STANDARD_GRAVITY * 0.35 + 0.2, "boost stays under the explicit 6 g cap")
	game.open_menu("shipyard")
	assert("BOOST" in game.deck._ship_stats_line(game.state))
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/reactor-boost-shipyard.png")

	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("REACTOR_BOOST_GAMEPLAY_OK: refit power headroom drives measured manual boost")
	quit()

func _forward_speed_delta(game: Node, boost: bool) -> float:
	game.pilot.restore_flight_velocity(Vector3.ZERO)
	await physics_frame
	Input.action_press("move_forward")
	if boost:
		Input.action_press("boost")
	# Equal physics steps avoid comparing different timer/frame rounding.
	for frame in 20:
		game.pilot._physics_process(1.0 / 60.0)
	Input.action_release("move_forward")
	Input.action_release("boost")
	var measured: float = game.pilot.flight_velocity().length()
	game.pilot.restore_flight_velocity(Vector3.ZERO)
	await physics_frame
	return measured
