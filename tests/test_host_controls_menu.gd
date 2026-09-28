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
	game.open_menu("settings")
	assert(game.deck.find_child("VisitorsOpen", true, false) == null)
	game.session.ship_modules = game.state.ship_modules.duplicate(true)
	game.session.ship_layout = game.state.ship_layout.duplicate(true)
	game.session.world_id = game.state.world_id
	assert(game.session.host(29000 + OS.get_process_id() % 10000).is_empty())
	game.deck._process(0.1)
	var admission: CheckButton = game.deck.find_child("VisitorsOpen", true, false)
	assert(admission != null and admission.button_pressed)
	admission.button_pressed = false
	assert(not game.session.visitors_open and game.session._peer.refuse_new_connections)
	admission.button_pressed = true
	assert(game.session.visitors_open and not game.session._peer.refuse_new_connections)
	assert(not game.session.remove_visitor(1).is_empty())
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(Vector2(12, 12))
		await process_frame
		(game.deck.content.get_parent() as ScrollContainer).ensure_control_visible(admission)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://host-admission-menu.png") == OK)
	game.session.leave()
	game.deck._process(0.1)
	assert(game.deck.find_child("VisitorsOpen", true, false) == null and game.session.visitors_open)
	game.queue_free()
	await process_frame
	print("HOST_CONTROLS_MENU_OK: host-only control, live refresh, admission toggle and leave reset")
	quit()
