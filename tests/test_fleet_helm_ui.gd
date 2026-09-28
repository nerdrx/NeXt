extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := "user://fleet-helm-ui-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = path
	root.add_child(game)
	await process_frame
	game.save_path = path
	game.set_process(false)
	game.close_menu()
	game._clear_actors()
	game.state.credits = 50000
	game.state.cargo.ore = 4
	game.state.fuel = 37.0
	game.shield_delay = 4.0
	var original_id := str(game.state.ship_identity.id)
	var original_modules: Array = game.state.ship_modules.duplicate(true)
	assert(game.crew_operations().purchase_ship("Command Merchant", "merchant").is_empty())
	var vessel: Dictionary = game.state.fleet_ships.back()
	var id := str(vessel.id)
	vessel.cargo = {"food":3}
	vessel.fuel = 62.0
	vessel.defense = {"charge":31.0, "delay":2.0}
	for guard in ["flight", "aboard", "visit", "surface", "manual"]:
		_set_guard(game, guard, true)
		var before: Dictionary = game.state._save_data().duplicate(true)
		assert(not game.exchange_fleet_helm(id).is_empty())
		assert(game.state._save_data() == before, "scene guard rejects atomically")
		_set_guard(game, guard, false)
	game.deck.show_page("fleet")
	var button: Button
	for node: Node in game.deck.find_children("*", "Button", true, false):
		if node.get_meta("fleet_take_command", "") == id: button = node
	assert(button != null and not button.disabled)
	button.pressed.emit()
	assert(str(game.state.ship_identity.id) == id)
	assert(game.state.cargo.get("food",0) == 3 and game.state.cargo.get("ore",0) == 0)
	assert(game.state.fuel == 62.0 and game.shield_delay == 2.0)
	assert(game.ship_display.get_node_or_null("FamilyPressureHull") != null)
	assert(game.pilot._module_shapes.size() == ShipBlueprint.family("merchant").modules.size())
	var stored: Dictionary = game.crew_operations()._ship(original_id)
	assert(stored.modules == original_modules and stored.cargo.ore == 4 and stored.fuel == 37.0)
	assert(stored.defense.delay == 4.0)
	assert(game.save_commander(false))
	var loaded := GameState.new()
	assert(loaded.load_save(path).is_empty() and loaded.ship_identity.id == id)
	assert(game.exchange_fleet_helm(original_id).is_empty())
	assert(game.state.ship_modules == original_modules and game.state.fuel == 37.0 and game.shield_delay == 4.0)
	assert(game.state.cargo.ore == 4)
	game.deck.show_page("fleet")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		assert(game.get_viewport().get_texture().get_image().save_png("user://fleet-helm-exchange.png") == OK)
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("FLEET_HELM_UI_OK: command callback, scene guards, collision rebuild, identity and cargo roundtrip")
	quit()

func _set_guard(game: Node, guard: String, enabled: bool) -> void:
	match guard:
		"flight": game.pilot.flying = enabled
		"aboard": game.aboard = enabled
		"visit": game.session.connected = enabled
		"surface": game.surface_index = 0 if enabled else -1
		"manual": game.manual_planet = 0 if enabled else -1
