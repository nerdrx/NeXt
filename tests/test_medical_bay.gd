extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	var path := "user://medical-test-%d.json" % OS.get_process_id()
	game.save_path = path
	root.add_child(game)
	await process_frame
	game.save_path = path
	game.set_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	game.state = GameState.new()
	game.state.credits = 50000
	var cell := Vector3i(0, 0, 3)
	assert(game.state.add_module("habitat", cell).is_empty())
	assert(ShipLayout.configure_room(game.state, cell, "medical").is_empty())
	game.state.cargo.medicine = 2
	game.suit_health = 35
	assert(not game.treat_in_medbay().is_empty(), "no remote treatment outside ship")
	game.apply_ship_stats()
	game.rebuild_player_ship()
	game.enter_interior()
	assert(game.aboard)
	var bay: Vector3 = Vector3(cell) * ShipInterior.CELL
	game.pilot.teleport(game.interior.to_global(bay + Vector3(0, 0.1, 0)))
	assert(game.medical_treatment_issue().is_empty())
	game.jump_charge = 1
	assert(not game.treat_in_medbay().is_empty())
	game.jump_charge = 0
	game.session.connected = true
	assert(not game.treat_in_medbay().is_empty())
	game.session.connected = false
	game.state.systems_online = false
	assert(not game.treat_in_medbay().is_empty())
	game.state.systems_online = true
	game.state.cargo.medicine = 0
	assert(not game.treat_in_medbay().is_empty())
	game.state.cargo.medicine = 2
	game.aboard_fleet_id = "other-ship"
	assert(not game.treat_in_medbay().is_empty(), "cannot debit own cargo inside another vessel")
	game.aboard_fleet_id = ""
	game.suit_health = 0
	assert(not game.treat_in_medbay().is_empty(), "cannot bypass rescue")
	game.suit_health = 35
	game.pilot.teleport(game.interior.to_global(bay + Vector3(0, 0.1, -2.8)))
	assert(not game.treat_in_medbay().is_empty(), "adjacent room is outside treatment area")
	game.pilot.teleport(game.interior.to_global(bay + Vector3(0, 2.8, 0)))
	assert(not game.treat_in_medbay().is_empty(), "another deck is outside treatment area")
	# The same room bounds apply inside a translated, rotated ship.
	game.interior.transform = Transform3D(Basis.from_euler(Vector3(0.2, 0.7, -0.1)), Vector3(90, 70, 40))
	game.pilot.teleport(game.interior.to_global(bay + Vector3(0, 0.1, 0)))
	assert(game.interaction_hint().contains("Medical treatment"))
	var event := InputEventKey.new()
	event.keycode = KEY_F
	event.pressed = true
	game._unhandled_key_input(event)
	assert(game.suit_health == 100 and game.state.cargo.medicine == 1, "keyboard treatment heals and consumes once")
	assert(not game.treat_in_medbay().is_empty() and game.state.cargo.medicine == 1, "full health consumes nothing")
	var saved := GameState.new()
	assert(saved.load_save(path).is_empty() and saved.cargo.medicine == 1, "cargo debit persists")
	assert(saved.commander_health == 100, "treatment health persists with medicine debit")
	game.suit_health = 50
	game.open_menu()
	var button: Button = game.deck.find_child("MedicalTreatment", true, false)
	assert(button != null and not button.disabled)
	button.pressed.emit()
	assert(game.suit_health == 100 and game.state.cargo.medicine == 0, "menu routes through same treatment")
	button = game.deck.find_child("MedicalTreatment", true, false)
	assert(button.disabled)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://medical-treatment.png")
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	for file: String in [path, path + ".bak"]:
		if FileAccess.file_exists(file): DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("MEDICAL_BAY_OK: room bounds, power, supply, rescue, fleet isolation, keyboard, menu and cargo persistence")
	quit()
