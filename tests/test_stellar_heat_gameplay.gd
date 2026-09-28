extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	assert("--capture-only" in OS.get_cmdline_user_args())
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	for actor: Node in game.actors: actor.set_physics_process(false)
	game.close_menu()
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	game.apply_ship_stats()
	game.world.stellar_profile = {"luminosity_w": CelestialPhysics.SOLAR_LUMINOSITY_W, "radius_m": CelestialPhysics.SOLAR_RADIUS_M}
	game.pilot.set_flight(true)
	assert(game.world.stellar_heat(game.world.to_global(SpaceWorld.PRIMARY_POSITION), Basis.IDENTITY, Vector3.ONE) > 0.0)
	var near_point: Vector3 = game.world.to_global(SpaceWorld.PRIMARY_POSITION + Vector3.RIGHT * 400)
	game.pilot.teleport(near_point)
	game.pilot.restore_flight_velocity(Vector3.ZERO)
	game.state.systems_online = false
	game.state.drive_temperature_k = 300.0
	game._physics_process(1.0)
	var near_heat: float = game.stellar_heat_w
	assert(near_heat > 0 and game.state.drive_temperature_k > 300.0, "sunlight heats an unpowered ship")
	for frame in 600: game._physics_process(1.0)
	assert(game.state.drive_temperature_k > 500.0 and game.state.ship_stats().drive_thrust_factor < 1.0, "sustained exposure derates drive")
	var hot: float = game.state.drive_temperature_k
	game.pilot.teleport(game.world.to_global(SpaceWorld.PRIMARY_POSITION + Vector3.RIGHT * 9000))
	for frame in 120: game._physics_process(1.0)
	assert(game.stellar_heat_w < near_heat / 50 and game.state.drive_temperature_k < hot, "retreat lets radiators cool the ship")
	game.pilot.teleport(near_point)
	game._physics_process(0.1)
	if DisplayServer.get_name() != "headless":
		game.pilot.camera.look_at(game.world.to_global(SpaceWorld.PRIMARY_POSITION), Vector3.UP)
		game.hud._process(6.0)
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://stellar-heating.png") == OK)
	var planets: Array = game.world.planets.duplicate(true)
	game.world.planets.assign([{"position": SpaceWorld.PRIMARY_POSITION + Vector3.RIGHT * 200, "visual_radius": 60.0}])
	assert(game._sample_stellar_heat() == 0.0, "planet eclipse removes direct heat")
	game.world.planets.assign(planets)
	var npc: ShipActor
	for actor: Node in game.actors:
		if actor is ShipActor:
			npc = actor
			assert(npc.stellar_heat_source.is_valid(), "spawned ships share the local stellar field")
	assert(npc != null)
	npc.global_position = near_point
	npc.drive_temperature_k = 300.0
	npc._physics_process(0.1)
	assert(npc.stellar_heat_w > 0.0 and npc.drive_temperature_k > 300.0)
	game._clear_actors()
	game.enter_interior()
	await physics_frame
	assert(game.aboard and is_instance_valid(game.coasting_hull))
	var cabin_heat: float = game._sample_stellar_heat()
	game.pilot.position += Vector3(0.5, 0, 0)
	assert(is_equal_approx(game._sample_stellar_heat(), cabin_heat), "interior passenger position does not move ship exposure")
	game._rebase_flight()
	assert(is_equal_approx(game._sample_stellar_heat(), cabin_heat), "floating origin preserves exposure")
	var path := "user://stellar-heat-%d.json" % OS.get_process_id()
	assert(game.state.save(path).is_empty())
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty() and is_equal_approx(restored.drive_temperature_k, game.state.drive_temperature_k))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	print("STELLAR_HEAT_GAMEPLAY_OK: powered-off absorption, derating, retreat cooling, eclipse, NPC field, cabin/rebase invariance and saved temperature")
	quit()
