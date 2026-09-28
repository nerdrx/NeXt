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
	game.open_menu("navigation")
	(game.deck.find_child("OpenSurveyJournal", true, false) as Button).pressed.emit()
	assert(game.deck.page == "journal")
	assert((game.deck.find_child("NextSurveys", true, false) as Button).disabled)
	var keys: Array[String] = []
	for system in 100:
		if Universe.system_data(system).planets.is_empty(): continue
		var key := "%d:0" % system
		keys.append(key)
		game.state.planet_surveys[key] = 1 if keys.size() % 2 == 0 else 2
		if keys.size() == 23: break
	var archive: Dictionary = game.state.planet_surveys.duplicate(true)
	var before_position: Vector3 = game.pilot.position
	var before_credits: int = game.state.credits
	game.deck.show_page("journal")
	assert(_rows(game.deck.content) == 20)
	(game.deck.find_child("NextSurveys", true, false) as Button).pressed.emit()
	assert(game.deck.journal_page_index == 1 and _rows(game.deck.content) == 3)
	assert((game.deck.find_child("NextSurveys", true, false) as Button).disabled)
	var filter: CheckButton = game.deck.find_child("PendingSurveysOnly", true, false)
	filter.button_pressed = true
	assert(game.deck.journal_page_index == 0 and game.deck.journal_pending_only and _rows(game.deck.content) == 11)
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(Vector2(12, 12))
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://survey-journal.png") == OK)
	var target_system := int(keys[1].split(":")[0])
	var course: Button = game.deck.find_child("SurveyCourse%d_0" % target_system, true, false)
	assert(course != null)
	course.pressed.emit()
	assert(game.deck.page == "navigation" and game.deck.destination == target_system)
	assert(int(game.deck.navigation_address.value) == target_system and game.deck.navigation_chart.destination == target_system)
	assert(game.pilot.position == before_position and game.state.system_index == 0, "setting course does not jump automatically")
	assert(game.state.credits == before_credits and game.state.planet_surveys == archive, "journal browsing never pays or mutates records")
	game.queue_free()
	await process_frame
	print("SURVEY_JOURNAL_GAMEPLAY_OK: empty state, paging, filter, course controls and read-only browsing")
	quit()

func _rows(content: VBoxContainer) -> int:
	var count := 0
	for child in content.get_children():
		if str(child.name).begins_with("SurveyRecord"): count += 1
	return count
