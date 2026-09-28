extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := "user://custom-fleet-ui-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = path
	root.add_child(game)
	await process_frame
	game.save_path = path
	game.set_process(false)
	game.close_menu()
	game._clear_actors()
	game.state.credits = 50000
	assert(game.state.add_module("habitat", Vector3i(0,0,3)).is_empty())
	game.apply_ship_stats()
	var expected: Array = game.state.ship_modules.duplicate(true)
	game.deck.show_page("fleet")
	var commission: Button
	for node: Node in game.deck.find_children("*", "Control", true, false):
		if node is LineEdit and node.placeholder_text == "Fleet vessel name": node.text = "Custom Explorer"
		if node is Button and node.has_meta("commission_custom_design"): commission = node
	assert(commission != null and not commission.disabled)
	commission.pressed.emit()
	var vessel: Dictionary = game.state.fleet_ships.back()
	assert(vessel.hull_family == "custom" and vessel.modules == expected)
	var id := str(vessel.id)
	assert(game.fleet_boarding_issue(id).is_empty())
	game.enter_interior(id)
	assert(game.aboard and game.aboard_fleet_id == id and is_instance_valid(game.interior))
	assert(game.crew_operations().occupied_ship_id == id)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		assert(game.get_viewport().get_texture().get_image().save_png("user://custom-fleet-interior.png") == OK)
	game.exit_interior()
	assert(not game.aboard and game.crew_operations().occupied_ship_id.is_empty())
	assert(game.state.hire("gunner").is_empty())
	var member: Dictionary = game.state.crew.back()
	assert(game.crew_operations().assign_patrol(str(member.id), id, game.state.system_index).is_empty())
	game._sync_fleet_actors()
	assert(game.fleet_actors.has(id))
	var actor: ShipActor = game.fleet_actors[id]
	assert(actor._visual is ShipVisual and actor.hull_modules == expected)
	assert(actor.weapon_damage == game.state.ship_stats().damage)
	assert(game.save_commander(false))
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty())
	assert(restored.fleet_ships.back().modules == expected)
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("CUSTOM_FLEET_UI_OK: commission callback, custom boarding, crew patrol actor, persistence")
	quit()
