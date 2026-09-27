extends SceneTree

var game: Node
var save_path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	save_path = "user://shipyard-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.state.credits = 100000
	game.open_menu("shipyard")
	var designer: ShipDesigner
	for child: Node in game.deck.content.get_children():
		if child is ShipDesigner: designer = child
	if not _check(designer != null, "ship architect creates interactive designer"): return
	var install := _button(designer, "INSTALL MODULE")
	var remove := _button(designer, "REMOVE / REFUND")
	if not _check(install != null and remove != null, "assembly buttons exist"): return
	var before_count: int = game.state.ship_modules.size()
	for x in range(2, GameState.SHIP_CELL_LIMIT + 1):
		for side in [-1, 1]:
			if not await _install(designer, install, Vector3i(x * side, 0, 0)): return
	for y in range(1, GameState.SHIP_CELL_LIMIT + 1):
		if not await _install(designer, install, Vector3i(GameState.SHIP_CELL_LIMIT, y, 0)): return
	if not _check(game.state.ship_modules.size() == before_count + 46, "UI builds both outer edges and upper deck"): return
	var old_credits: int = game.state.credits
	if not _check(not game.state.add_module("cargo", Vector3i(17, 16, 0)).is_empty() and game.state.credits == old_credits, "coordinate limit rejects without charging"): return
	designer.select_cell(Vector3i(8, 0, 0))
	remove.pressed.emit()
	if not _check("split" in game.deck.feedback.text and game.state.credits == old_credits, "UI protects connected ship structure"): return
	designer.select_cell(Vector3i(-16, 0, 0))
	remove.pressed.emit()
	await process_frame
	if not _check(game.state._module_at(Vector3i(-16, 0, 0)) < 0 and game.state.credits > old_credits, "outer edge module can be removed and refunded"): return
	if not await _install(designer, install, Vector3i(-16, 0, 0)): return
	var saved := GameState.new()
	if not _check(saved.load_save(save_path).is_empty() and saved.ship_modules == game.state.ship_modules, "large UI-built ship survives saved-data validation"): return
	if not _check(game.pilot.hull_radius > 45.0 and designer.preview_camera.position.length() > game.pilot.hull_radius, "physical bounds and preview framing follow the large design"): return
	if not _check(game.deck.content.get_child(0).text == game.deck._ship_stats_line(game.state), "shipyard stats update after assembly edits"): return
	designer.select_cell(Vector3i(16, 16, 0))
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/large-shipyard.png")
	_cleanup()
	game.queue_free()
	await process_frame
	await process_frame
	print("SHIPYARD_GAMEPLAY_OK: menu assembly across large grid, connection guards, refunds, save and preview bounds")
	quit()

func _install(designer: ShipDesigner, button: Button, cell: Vector3i) -> bool:
	designer.select_cell(cell)
	designer.selected_kind = "cargo"
	button.pressed.emit()
	await process_frame
	return _check(game.state._module_at(cell) >= 0, "install through menu at " + str(cell))

func _button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child: Node in node.get_children():
		var found := _button(child, title)
		if found != null: return found
	return null

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		_cleanup()
		quit(1)
	return ok

func _cleanup() -> void:
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
