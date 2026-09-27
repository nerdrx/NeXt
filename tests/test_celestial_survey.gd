extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.open_menu("navigation")
	game.deck._select_destination(0)
	game.deck.show_page("survey")
	assert(game.deck.survey_labels.size() == Universe.system_data(0).planets.size())
	var initial: String = game.deck.survey_labels[0].text
	assert("Gravity" in initial and "Equilibrium" in initial and "Received radiation" in initial)
	game.state.advance_time(86400.0)
	game.deck._update_clock()
	assert(initial != game.deck.survey_labels[0].text, "persisted world time changes the displayed orbital and thermal estimates")
	await create_timer(0.5).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/celestial-survey.png")
	game.deck.show_page("overview")
	assert(game.deck.survey_catalog.is_empty() and game.deck.survey_labels.is_empty())
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("CELESTIAL_SURVEY_OK: navigation selection, live calendar estimates and page cleanup")
	quit()
