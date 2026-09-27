extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._clear_actors()
	game.pilot.set_physics_process(false)
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(10000, 5000, 0))
	game.close_menu()
	var pilot = game.pilot
	var dt := 0.1

	assert(pilot.flight_assist_enabled, "flight assist defaults to enabled")
	game.state.fuel = 100.0
	pilot.restore_flight_velocity(Vector3(10, 0, 0))
	pilot._physics_process(dt)
	assert(pilot.flight_velocity().length() < 10.0 and game.state.fuel < 100.0, "assist brakes idle drift using fuel")

	pilot.flight_assist_enabled = false
	pilot.enabled = false
	game.state.fuel = 100.0
	var coast := Vector3(12, 3, 0)
	pilot.restore_flight_velocity(coast)
	pilot._physics_process(dt)
	assert(pilot.flight_velocity().is_equal_approx(coast) and is_equal_approx(game.state.fuel, 100.0), "inertial coasting survives disabled input without fuel use")

	pilot.enabled = true
	pilot.flight_speed = 100.0
	pilot.acceleration_mps2 = 30.0
	pilot.restore_flight_velocity(Vector3(150, 2, 0))
	Input.action_press("move_forward")
	pilot._physics_process(dt)
	Input.action_release("move_forward")
	var thrust_velocity: Vector3 = pilot.flight_velocity()
	assert(is_equal_approx(thrust_velocity.x, 150.0) and is_equal_approx(thrust_velocity.y, 2.0), "inertial thrust preserves orthogonal velocity")
	assert(thrust_velocity.z < -2.9 and thrust_velocity.length() > pilot.flight_speed, "inertial thrust adds camera-direction delta-v without a speed cap")

	game.state.fuel = 100.0
	pilot.restore_flight_velocity(Vector3(40, 0, 0))
	pilot.request_brake()
	pilot._physics_process(dt)
	assert(pilot.flight_velocity().length() < 40.0 and absf(pilot.flight_velocity().z) < 0.001, "explicit braking overrides inertial coasting")
	assert(game.state.fuel < 100.0, "inertial braking consumes fuel")

	game.state.fuel = 0.0
	pilot.braking = false
	var empty_drift := Vector3(20, -4, 3)
	pilot.restore_flight_velocity(empty_drift)
	pilot._physics_process(dt)
	assert(pilot.flight_velocity().is_equal_approx(empty_drift), "empty tank preserves inertial drift")

	game.state.fuel = 100.0
	pilot.restore_flight_velocity(Vector3(10, 0, 0))
	var brake_key := InputEventKey.new()
	brake_key.keycode = KEY_B
	brake_key.pressed = true
	game._unhandled_key_input(brake_key)
	assert(pilot.braking, "B key requests flight braking")

	game.state.fuel = 100.0
	pilot.restore_flight_velocity(Vector3.ZERO)
	pilot.autopilot_to(pilot.global_position + Vector3(0, 0, -100))
	pilot._physics_process(dt)
	assert(pilot.autopilot_active and pilot.flight_velocity().z < 0.0 and game.state.fuel < 100.0, "autopilot guidance continues using the fuel limiter")
	pilot.cancel_autopilot()

	var previous_automation: bool = game.automation
	game.automation = false
	var settings_path := "user://inertial-flight-settings-%d.cfg" % OS.get_process_id()
	pilot.flight_assist_enabled = false
	game.save_settings(settings_path)
	pilot.flight_assist_enabled = true
	game._load_settings(settings_path)
	assert(not pilot.flight_assist_enabled, "flight assist setting roundtrips")
	var legacy_path := "user://inertial-flight-legacy-%d.cfg" % OS.get_process_id()
	var legacy := ConfigFile.new()
	legacy.set_value("controls", "sensitivity", 0.003)
	assert(legacy.save(legacy_path) == OK)
	pilot.flight_assist_enabled = false
	game._load_settings(legacy_path)
	assert(pilot.flight_assist_enabled, "settings without flight assist default to enabled")
	game.automation = previous_automation
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
	game.open_menu("settings")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/inertial-flight-settings.png")

	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("INERTIAL_FLIGHT_OK: assist, drift, thrust, braking, empty tank, autopilot and settings")
	quit()
