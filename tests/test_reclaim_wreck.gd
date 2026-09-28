extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := GameState.new()
	state.credits = 100000
	state.ship_modules.assign(ShipBlueprint.family("merchant").modules)
	state.ship_layout = ShipBlueprint.family("merchant").layout.duplicate(true)
	assert(ShipLayout.configure_room(state, Vector3i(-1, 0, -1), "medical").is_empty())
	assert(ShipLayout.set_panel(state, Vector3i(0, 0, -2), "-z", "window").is_empty())
	var original_layout := state.ship_layout.duplicate(true)
	state.cargo.ore = 5
	state.hull = 0.0
	assert(ShipRecovery.destroy_ship(state, Vector3.ZERO, -1).ok)
	var wreck: Dictionary = state.recovery.wrecks[0]
	assert(wreck.layout == original_layout)
	state.ship_layout = ShipLayout.empty_data()
	assert(wreck.layout == original_layout, "wreck owns an independent layout snapshot")
	var quote := ShipRecovery.reclaim_quote(wreck)
	assert(str(quote.error).is_empty())
	var before := state._save_data().duplicate(true)
	assert(not ShipRecovery.reclaim_wreck(state, wreck.id, Vector3(10000, 0, 0)).is_empty())
	assert(state._save_data() == before, "remote recovery cannot mutate state")
	state.credits = 0
	before = state._save_data().duplicate(true)
	assert(not ShipRecovery.reclaim_wreck(state, wreck.id, Vector3.ZERO).is_empty())
	assert(state._save_data() == before, "unaffordable recovery is atomic")
	state.credits = 100000
	var funds: int = state.credits
	assert(ShipRecovery.reclaim_wreck(state, wreck.id, Vector3.ZERO).is_empty())
	var vessel: Dictionary = state.fleet_ships[0]
	assert(state.credits == funds - int(quote.price) and vessel.hull == 25.0 and vessel.fuel == 0.0)
	assert(vessel.layout == original_layout, "reclaim preserves customized rooms and panels")
	assert(vessel.defense.charge == 0.0 and vessel.modules == wreck.modules and vessel.cargo.is_empty())
	assert(wreck.salvaged and not wreck.cargo_recovered and wreck.cargo.ore == 5, "structure consumed once, cargo remains")
	before = state._save_data().duplicate(true)
	assert(not ShipRecovery.reclaim_wreck(state, wreck.id, Vector3.ZERO).is_empty())
	assert(not ShipRecovery.salvage_wreck(state, wreck.id, -1, Vector3.ZERO).is_empty())
	assert(state._save_data() == before, "no second hull or salvage payout")
	var path := "user://reclaim-wreck-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty())
	var restored := GameState.new()
	var load_error := restored.load_save(path)
	assert(load_error.is_empty(), load_error)
	assert(restored.fleet_ships[0].modules == vessel.modules)
	assert(restored.recovery.wrecks[0].salvaged and restored.fleet_ships[0].fuel == 0.0)
	assert(restored.recovery.wrecks[0].layout == original_layout and restored.fleet_ships[0].layout == original_layout)
	var invalid := restored.recovery.duplicate(true)
	invalid.wrecks[0].layout.rooms["999,0,0"] = "medical"
	assert(not ShipRecovery.validate_data(invalid), "out-of-hull layout is rejected")
	invalid = restored.recovery.duplicate(true)
	invalid.wrecks[0].modules[0] = "broken"
	assert(not ShipRecovery.validate_data(invalid), "malformed module rejected before layout validation")
	var legacy := restored.recovery.duplicate(true)
	legacy.wrecks[0].erase("layout")
	legacy.wrecks[0].salvaged = false
	assert(ShipRecovery.validate_data(legacy) and ShipRecovery.reclaim_quote(legacy.wrecks[0]).error.is_empty(), "legacy wreck accepts default layout")
	var legacy_state := GameState.new()
	legacy_state.credits = 100000
	legacy_state.recovery = legacy
	assert(ShipRecovery.reclaim_wreck(legacy_state, wreck.id, Vector3.ZERO).is_empty())
	assert(legacy_state.fleet_ships[0].layout == ShipLayout.empty_data(), "legacy reclaim uses default layout")
	assert(ShipRecovery.recover_cargo(restored, wreck.id, -1, Vector3.ZERO).is_empty() and restored.cargo.ore == 5)
	assert(CrewOrders.new(restored).repair_fleet_ship(vessel.id).is_empty() and restored.fleet_ships[0].hull == 100.0)
	assert(CrewOrders.new(restored).exchange_helm(vessel.id).is_empty())
	assert(restored.ship_layout == original_layout, "taking reclaimed helm keeps original refits")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var explorer := GameState.new()
	explorer.credits = 1000000
	for system in 30:
		explorer.system_index = system
		if ShipRecovery.scan_derelict(explorer).is_empty(): break
	assert(not explorer.recovery.wrecks.is_empty())
	var derelict: Dictionary = explorer.recovery.wrecks.back()
	var origin := SectorPosition.new().to_save()
	var point: Vector3 = ShipRecovery.wreck_relative(derelict, origin)
	assert(ShipRecovery.reclaim_wreck(explorer, derelict.id, point, origin).is_empty(), "discovered derelict can join fleet")
	assert(explorer.fleet_ships[0].layout == derelict.layout, "discovered family rooms preserved")
	assert(explorer.save(path).is_empty() and restored.load_save(path).is_empty(), "discovered design saves")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	game.state.credits = 100000
	game.state.hull = 0.0
	var at := Vector3(2000, 1800, 1000)
	assert(ShipRecovery.destroy_ship(game.state, at, -1, game.flight_origin.to_save()).ok)
	var id: String = game.state.recovery.wrecks.back().id
	assert(not game.reclaim_wreck(id).is_empty(), "on-foot service rejected")
	game.pilot.set_flight(true)
	game.pilot.teleport(at + Vector3(0, 0, 50))
	game.rebuild_wrecks()
	game.open_menu("recovery")
	var button := _find(game.deck, id)
	assert(button != null and not button.disabled, "nearby recovery offer appears")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var parent: Node = button.get_parent()
		while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://reclaim-wreck.png")
	button.pressed.emit()
	assert(game.state.fleet_ships.size() == 1 and game.state.recovery.wrecks.back().salvaged, "menu reclaims actual wreck")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("RECLAIM_WRECK_OK: range/funds atomicity, damaged fleet, retained cargo, duplicate prevention, save/repair and live menu")
	quit()

func _find(node: Node, id: String) -> Button:
	if node is Button and node.get_meta("reclaim_wreck", "") == id: return node
	for child: Node in node.get_children():
		var found := _find(child, id)
		if found != null: return found
	return null
