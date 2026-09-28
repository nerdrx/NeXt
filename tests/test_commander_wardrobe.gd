extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _wardrobe(game: Node) -> CommanderWardrobe:
	for child in game.deck.content.get_children():
		if child is CommanderWardrobe: return child
	return null

func _run() -> void:
	assert("--capture-only" in OS.get_cmdline_user_args(), "run with -- --capture-only to isolate commander save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._clear_actors()
	game.pilot.set_physics_process(false)
	var path := "user://wardrobe-%d.json" % OS.get_process_id()
	game.save_path = path
	game.open_menu("overview")
	(game.deck.find_child("OpenSuitLocker", true, false) as Button).pressed.emit()
	var wardrobe := _wardrobe(game)
	assert(wardrobe != null)
	wardrobe.suit_choice.select(2)
	wardrobe.suit_choice.item_selected.emit(2)
	wardrobe.armor_choice.select(1)
	wardrobe.armor_choice.item_selected.emit(1)
	assert(game.state.commander_appearance == {"suit": 0, "armor": 0}, "preview is not applied")
	var torso := wardrobe.preview._visual.get_child(0) as MeshInstance3D
	assert((torso.material_override as StandardMaterial3D).albedo_color == CrewAppearance.SUITS[2])
	wardrobe._turn(PI / 4)
	assert(is_equal_approx(wardrobe.preview.rotation.y, PI / 4))
	game.open_menu("overview")
	game.open_menu("wardrobe")
	wardrobe = _wardrobe(game)
	assert(wardrobe.suit_choice.selected == 0, "leaving discards unapplied choices")
	wardrobe.suit_choice.select(5)
	wardrobe.suit_choice.item_selected.emit(5)
	wardrobe.armor_choice.select(3)
	wardrobe.armor_choice.item_selected.emit(3)
	(wardrobe.find_child("ApplyFinish", true, false) as Button).pressed.emit()
	assert(game.state.commander_appearance == {"suit": 5, "armor": 3})
	assert(game.pilot._sleeve_material.albedo_color == CrewAppearance.SUITS[5])
	assert(game.pilot._cuff_material.albedo_color == CrewAppearance.ARMORS[3])
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty())
	assert(restored.commander_appearance == game.state.commander_appearance)
	var carried := GameState.new()
	game._copy_carried_ship(game.state, carried)
	assert(carried.commander_appearance == game.state.commander_appearance)
	carried.commander_appearance.suit = 0
	assert(game.state.commander_appearance.suit == 5, "visitor copy has independent appearance record")
	game.close_menu()
	assert(_wardrobe(game).viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	game.open_menu("wardrobe")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://commander-wardrobe.png") == OK)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	print("COMMANDER_WARDROBE_OK: preview, discard, rotate, apply, save, sleeve/cuff, carried appearance and hidden preview")
	quit()
