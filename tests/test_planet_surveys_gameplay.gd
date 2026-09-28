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
	assert(not game.survey_planet(0).is_empty(), "docked ship cannot survey")
	game.pilot.set_flight(true)
	var body: Dictionary = game.world.planets[0]
	var center: Vector3 = game._planet_center(0)
	game.pilot.teleport(center + Vector3.RIGHT * (float(body.visual_radius) + 2000.0))
	assert(not game.survey_planet(0).is_empty(), "distant survey rejected")
	game.pilot.teleport(center + Vector3.RIGHT * (float(body.visual_radius) + 600.0))
	game.pilot.restore_flight_velocity(Vector3.RIGHT * 150.0)
	assert(not game.survey_planet(0).is_empty(), "fast survey rejected")
	game.pilot.restore_flight_velocity(Vector3.ZERO)
	game.state.systems_online = false
	assert(not game.survey_planet(0).is_empty(), "offline scanner rejected")
	game.state.systems_online = true
	game.open_menu("navigation")
	if DisplayServer.get_name() != "headless": Input.warp_mouse(Vector2(12, 12))
	var scan: Button = game.deck.find_child("SurveyPlanet0", true, false)
	assert(scan != null and not scan.disabled)
	scan.pressed.emit()
	assert(game.state.planet_surveys.get("0:0", 0) == 1)
	var loaded := GameState.new()
	assert(loaded.load_save(game.save_path).is_empty() and loaded.planet_surveys.get("0:0", 0) == 1, "menu action persists scan")
	assert(not game.survey_planet(0).is_empty(), "duplicate rejected")
	assert(not game.sell_planet_surveys().is_empty(), "cannot sell while in flight")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var scroll := game.deck.content.get_parent() as ScrollContainer
		scroll.ensure_control_visible(game.deck.find_child("SellSurveyData", true, false))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://planet-survey-menu.png")
	game.close_menu()
	game.pilot.set_flight(false)
	game.manual_planet = 0
	assert(not game.sell_planet_surveys().is_empty(), "surface parking is not an orbital station")
	game.manual_planet = -1
	game.session.connected = true
	assert(not game.sell_planet_surveys().is_empty(), "visitor economies cannot claim surveys")
	game.session.connected = false
	var before: int = game.state.credits
	var payout: int = PlanetSurveys.pending_value(game.state)
	game.open_menu("navigation")
	var sell: Button = game.deck.find_child("SellSurveyData", true, false)
	assert(sell != null and not sell.disabled)
	sell.pressed.emit()
	assert(game.state.credits == before + payout and game.state.planet_surveys["0:0"] == 2)
	assert(not game.sell_planet_surveys().is_empty(), "sale cannot repeat")
	assert(loaded.load_save(game.save_path).is_empty() and loaded.planet_surveys["0:0"] == 2)
	var destination := GameState.new()
	game._copy_carried_ship(game.state, destination)
	assert(destination.planet_surveys.is_empty(), "survey archive is not carried between world economies")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + ".bak"))
	game.queue_free()
	await process_frame
	print("PLANET_SURVEYS_GAMEPLAY_OK: proximity, speed, power, menu scan/sale, persistence, duplicates and separate economies")
	quit()
