extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	game.apply_ship_stats()
	var pilot = game.pilot
	pilot.set_physics_process(false)
	pilot.set_flight(true)
	pilot.flight_assist_enabled = false
	pilot.teleport(Vector3(10000, 5000, 0))
	pilot.restore_flight_velocity(Vector3.ZERO)
	game.state.fuel = 100.0
	game.state.drive_temperature_k = 300.0
	game._refresh_propulsion_limits()
	Input.action_press("move_forward")
	pilot._fly(0.1)
	Input.action_release("move_forward")
	var cold_thrust: float = pilot.flight_velocity().length()
	assert(cold_thrust > 0.0, "cold drive applies thrust in the actual flight scene")

	game.state.drive_temperature_k = 600.0
	game._refresh_propulsion_limits()
	var hot_acceleration: float = pilot.acceleration_mps2
	pilot.restore_flight_velocity(Vector3.ZERO)
	Input.action_press("move_forward")
	pilot._fly(0.1)
	Input.action_release("move_forward")
	var hot_thrust: float = pilot.flight_velocity().length()
	assert(hot_acceleration < 29.41995 and hot_thrust < cold_thrust, "600 K drive reduces actual helm thrust")
	if DisplayServer.get_name() != "headless":
		await game._capture("drive-heat-hud")

	for _tick in 20:
		game._physics_process(1.0)
	assert(game.state.drive_temperature_k < 600.0 and pilot.acceleration_mps2 > hot_acceleration, "physics ticks cool drive and restore helm acceleration")

	game.state.drive_temperature_k = 557.25
	var carried = GameStateScript.new()
	game._copy_carried_ship(game.state, carried)
	assert(is_equal_approx(carried.drive_temperature_k, 557.25), "carried ship preserves drive heat")

	game.state.drive_temperature_k = 600.0
	game.state.fuel = 100.0
	game._refresh_propulsion_limits()
	pilot.restore_flight_velocity(Vector3.ZERO)
	game.enter_interior()
	await physics_frame
	var hull = game.coasting_hull
	assert(game.aboard and hull.propulsion_limiter.is_valid(), "aboard hull has shared ship propulsion limiter")
	assert(is_equal_approx(hull.acceleration_mps2, pilot.acceleration_mps2), "aboard coasting acceleration matches helm limit")
	var helm_result: Vector3 = pilot._limit_propulsion(Vector3.ZERO, Vector3(10, 0, 0))
	game.state.drive_temperature_k = 600.0
	game.state.fuel = 100.0
	var hull_result: Vector3 = hull._limit_propulsion(Vector3.ZERO, Vector3(10, 0, 0))
	assert(hull_result.is_equal_approx(helm_result), "aboard coasting uses same hot propulsion limiter as helm")

	Input.action_release("move_forward")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("DRIVE_HEAT_GAMEPLAY_OK: hot helm thrust, cooling recovery, carried heat, aboard limiter")
	quit()
