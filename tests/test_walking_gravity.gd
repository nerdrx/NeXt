extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	var pilot: Pilot = game.pilot
	pilot.set_physics_process(false)
	pilot.set_flight(false)
	game.world.planets[0].surface_gravity_mps2 = 3.0
	game.manual_planet = 0
	game.docked_station = -1
	var planet: Dictionary = game.world.planets[0]
	var surface: Vector3 = game.world.to_global(Vector3(planet.position) + Vector3.UP * float(planet.visual_radius))
	pilot.teleport(surface)
	assert(is_equal_approx(pilot.walking_gravity(), 3.0), "manual surface uses planet gravity")
	var high: Vector3 = game.world.to_global(Vector3(planet.position) + Vector3.UP * float(planet.visual_radius) * 2.0)
	assert(is_equal_approx(game._walking_gravity(high), 0.75), "altitude weakens the local field")
	game.world.position -= Vector3(8192, 0, 0)
	assert(is_equal_approx(game._walking_gravity(surface - Vector3(8192, 0, 0)), 3.0), "rebasing preserves walking gravity")
	game.aboard = true
	assert(pilot.walking_gravity() == Pilot.DEFAULT_WALK_GRAVITY, "ship deck overrides planet gravity")
	game.aboard = false
	game.docked_station = 0
	assert(pilot.walking_gravity() == Pilot.DEFAULT_WALK_GRAVITY, "station artificial gravity")
	game.docked_station = -1
	game.manual_planet = -1
	game.surface_index = 0
	assert(pilot.walking_gravity() == 3.0, "separate colony scene uses planet gravity")
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(10000, -0.5, 10000)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 1, 30)
	collision.shape = box
	floor_body.add_child(collision)
	root.add_child(floor_body)
	await physics_frame
	await physics_frame
	pilot.set_walk_up(Vector3.UP)
	var low_peak := await _jump_peak(pilot)
	game.world.planets[0].surface_gravity_mps2 = 12.0
	var high_peak := await _jump_peak(pilot)
	assert(low_peak > 5.5 and low_peak < 6.5 and high_peak > 1.2 and high_peak < 1.8, "same impulse produces gravity-dependent jump height: %.3f / %.3f" % [low_peak, high_peak])
	pilot.walking_gravity_source = func(_point: Vector3) -> float: return NAN
	assert(pilot.walking_gravity() == Pilot.DEFAULT_WALK_GRAVITY, "invalid field falls back safely")
	pilot.walking_gravity_source = game._walking_gravity
	game.surface_index = -1
	assert(pilot.walking_gravity() == Pilot.DEFAULT_WALK_GRAVITY, "orbital concourse restores artificial gravity")
	if DisplayServer.get_name() != "headless":
		pilot.set_flight(true)
		game.land(0)
		pilot.set_physics_process(true)
		await create_timer(0.7).timeout
		assert(is_equal_approx(pilot.walking_gravity(), 12.0))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://walking-gravity.png")
	floor_body.queue_free()
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("WALKING_GRAVITY_OK: planet/altitude, rebasing, artificial decks, colony scene, measured jumps and invalid field")
	quit()

func _jump_peak(pilot: Pilot) -> float:
	pilot.teleport(Vector3(10000, 0.1, 10000))
	for step in range(60):
		await physics_frame
		pilot._walk(1.0 / 60.0)
	assert(pilot.is_on_floor())
	var start := pilot.position.y
	Input.action_press("move_up")
	pilot._walk(1.0 / 60.0)
	Input.action_release("move_up")
	var peak := pilot.position.y
	for step in range(180):
		await physics_frame
		pilot._walk(1.0 / 60.0)
		peak = maxf(peak, pilot.position.y)
	return peak - start
