extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._clear_actors()
	game.save_path = "user://field-repair-ui-%d.json" % OS.get_process_id()
	assert(game.state.hire("engineer").is_empty())
	game.state.hull = float(game.state.ship_stats().max_hull) - 20.0
	game.state.cargo.alloys = 3
	game.open_menu("company")
	var toggle := game.deck.find_child("FieldRepairs", true, false) as CheckButton
	assert(toggle != null and not toggle.button_pressed)
	toggle.button_pressed = true
	var saved := GameState.new()
	assert(saved.load_save(game.save_path).is_empty() and saved.field_repairs_enabled, "UI opt-in persists")
	var before: float = game.state.hull
	game.state.day_progress = GameState.DAY_SECONDS - 0.1
	await create_timer(0.25).timeout
	assert(is_equal_approx(game.state.hull, before + 8.0) and game.state.cargo.alloys == 2, "active calendar performs resource-backed repair")
	toggle = game.deck.find_child("FieldRepairs", true, false) as CheckButton
	assert(toggle != null and toggle.button_pressed, "day refresh preserves policy display")
	toggle.button_pressed = false
	before = game.state.hull
	game.state.day_progress = GameState.DAY_SECONDS - 0.1
	await create_timer(0.25).timeout
	assert(is_equal_approx(game.state.hull, before) and game.state.cargo.alloys == 2, "disabled policy preserves trade cargo")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/field-repairs.png")
	for path: String in [game.save_path, game.save_path + ".bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("FIELD_REPAIRS_UI_OK: opt-in save, active daily repair and disabled cargo protection")
	quit()
