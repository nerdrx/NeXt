extends SceneTree
var game: Node
var owned_save := ""
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._clear_actors()
	game.state.company_name = "Daybound"
	game.state.company_balance = 0
	var start_day: int = game.state.day
	var system: int = game.state.system_index
	game.state.day_progress = GameState.DAY_SECONDS - 0.15
	game.open_menu("company")
	await create_timer(0.35).timeout
	if not _check(game.state.day == start_day + 1 and game.state.system_index == system, "calendar advances without travel while menu is open"): return
	if not _check(game.state.company_balance == 100, "daily company account settles once"): return
	if not _check(game.ui_open and game.deck.page == "company" and ("DAY %03d" % game.state.day) in game.deck.subtitle.text, "day rollover refreshes current menu"): return
	game.state.day_progress = GameState.DAY_SECONDS * 0.5
	await process_frame
	await process_frame
	if not _check("12:00" in game.deck.subtitle.text, "open menu clock tracks time without rebuilding page"): return
	game.close_menu()
	var prior: float = game.state.day_progress
	await create_timer(0.1).timeout
	if not _check(game.state.day_progress > prior and game.state.company_balance == 100, "active walking continues calendar without extra settlement"): return
	var path := "user://calendar-gameplay-%d.json" % OS.get_process_id()
	if not _check(not FileAccess.file_exists(path), "isolated autosave path"): return
	owned_save = path
	game.save_path = path
	game.open_menu("company")
	game.automation = false
	game.autosave_clock = 61.0
	await create_timer(0.1).timeout
	game.automation = true
	var persisted := GameState.new()
	if not _check(persisted.load_save(path).is_empty() and persisted.day == game.state.day and persisted.day_progress >= prior and persisted.company_balance == 100, "menu autosave persists active economy and clock"): return
	DirAccess.remove_absolute(path)
	owned_save = ""
	if DisplayServer.get_name() != "headless":
		game.open_menu("company")
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/calendar-company.png")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("CALENDAR_GAMEPLAY_OK: active calendar, menu clocks, daily company settlement without travel")
	quit()
func _check(ok: bool, message: String) -> bool:
	if ok: return true
	push_error("CALENDAR_GAMEPLAY_FAIL: " + message)
	if not owned_save.is_empty() and FileAccess.file_exists(owned_save): DirAccess.remove_absolute(owned_save)
	game.sound.shutdown()
	quit(1)
	return false
