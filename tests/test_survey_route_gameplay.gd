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
	var target_system := -1
	for system in range(1, 100):
		if Universe.system_data(system).planets.size() > 1:
			target_system = system
			break
	assert(target_system >= 1, "universe has a remote system with a second planet")
	game.state.planet_surveys["%d:1" % target_system] = 1
	var archive: Dictionary = game.state.planet_surveys.duplicate(true)
	var before_position: Vector3 = game.pilot.position
	var before_credits: int = game.state.credits
	game.open_menu("journal")
	var course: Button = game.deck.find_child("SurveyCourse%d_1" % target_system, true, false)
	assert(course != null, "journal offers exact second-planet course")
	course.pressed.emit()
	assert(game.deck.page == "navigation")
	assert(game.deck.survey_route == {"system": target_system, "planet": 1})
	assert(game.deck.destination == target_system and int(game.deck.navigation_address.value) == target_system)
	assert(game.deck.navigation_chart.destination == target_system)
	assert(game.pilot.position == before_position and game.state.system_index == 0, "setting course does not move or jump")
	var approach: Button = game.deck.find_child("SurveyRouteApproach", true, false)
	assert(approach != null and approach.disabled, "remote route cannot be approached")
	game.deck._approach_journal_planet()
	assert(game.cruise_address == null, "remote action is guarded even when called directly")
	game.close_menu()
	game.open_menu("journal")
	game.deck.show_page("navigation")
	assert(game.deck.survey_route == {"system": target_system, "planet": 1}, "menu close and rerender retain route")
	assert(game.deck.destination == target_system, "navigation selects route system")
	var clear_route: Button = game.deck.find_child("ClearSurveyRoute", true, false)
	assert(clear_route != null)
	clear_route.pressed.emit()
	assert(game.deck.survey_route.is_empty(), "clear button removes route")
	game.deck._journal_course(target_system, 1)
	game.deck._select_destination((target_system + 1) % 100)
	assert(game.deck.survey_route.is_empty(), "manual star selection clears route")
	game.deck._journal_course(target_system, 1)
	game.state.planet_surveys.erase("%d:1" % target_system)
	game.deck.show_page("navigation")
	assert(game.deck.survey_route.is_empty(), "navigation discards route without survey record")
	game.state.planet_surveys = archive.duplicate(true)
	game.deck._journal_course(target_system, 1)
	game.state.fuel = maxf(game.state.fuel, 10.0)
	game.pilot.set_flight(true)
	game.request_jump(target_system)
	assert(game.jump_destination == target_system and game.jump_charge > 0.0)
	assert(game.deck.survey_route == {"system": target_system, "planet": 1}, "jump retains exact planet")
	game.jump_charge = 0.0
	game._complete_jump()
	for actor: Node in game.actors: actor.set_physics_process(false)
	game.pilot.set_flight(false)
	game.deck.show_page("navigation")
	approach = game.deck.find_child("SurveyRouteApproach", true, false)
	assert(approach.disabled, "docked ship cannot approach")
	game.pilot.set_flight(true)
	game.aboard = true
	game.deck.show_page("navigation")
	approach = game.deck.find_child("SurveyRouteApproach", true, false)
	assert(approach.disabled, "aboard player cannot approach")
	game.aboard = false
	game.surface_index = 0
	game.deck.show_page("navigation")
	approach = game.deck.find_child("SurveyRouteApproach", true, false)
	assert(approach.disabled, "landed ship cannot approach")
	game.surface_index = -1
	game.pilot.set_flight(true)
	game.open_menu("navigation")
	approach = game.deck.find_child("SurveyRouteApproach", true, false)
	assert(game.state.system_index == target_system and not approach.disabled, "arrived ship can approach recorded planet")
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(Vector2(12, 12))
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://survey-route-menu.png") == OK)
	approach.pressed.emit()
	assert(game.cruise_address != null, "recorded planet starts a surface approach")
	var point: Vector3 = game.cruise_address.relative_to(SectorPosition.new(), SectorPosition.MAX_RELATIVE_DISTANCE)
	var target_body: Dictionary = game.world.planets[1]
	assert(absf(point.distance_to(Vector3(target_body.position)) - float(target_body.visual_radius)) < 200.0, "approach targets the selected second planet")
	assert(game.deck.survey_route == {"system": target_system, "planet": 1}, "approach retains route")
	assert(game.state.credits == before_credits and game.state.planet_surveys == archive, "routing does not pay or alter records")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + ".bak"))
	game.queue_free()
	await process_frame
	print("SURVEY_ROUTE_GAMEPLAY_OK: journal retention, jump, approach, clear and stale-record handling")
	quit()
