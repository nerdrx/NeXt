extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := GameState.new()
	state.credits = 100000
	state.cargo.ore = 5
	state.hull = 0.0
	assert(ShipRecovery.destroy_ship(state, Vector3.ZERO, -1).ok)
	var wreck: Dictionary = state.recovery.wrecks[0]
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
	assert(vessel.defense.charge == 0.0 and vessel.modules == wreck.modules and vessel.cargo.is_empty())
	assert(wreck.salvaged and not wreck.cargo_recovered and wreck.cargo.ore == 5, "structure consumed once, cargo remains")
	before = state._save_data().duplicate(true)
	assert(not ShipRecovery.reclaim_wreck(state, wreck.id, Vector3.ZERO).is_empty())
	assert(not ShipRecovery.salvage_wreck(state, wreck.id, -1, Vector3.ZERO).is_empty())
	assert(state._save_data() == before, "no second hull or salvage payout")
	var path := "user://reclaim-wreck-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty())
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty() and restored.fleet_ships[0].modules == vessel.modules)
	assert(restored.recovery.wrecks[0].salvaged and restored.fleet_ships[0].fuel == 0.0)
	assert(ShipRecovery.recover_cargo(restored, wreck.id, -1, Vector3.ZERO).is_empty() and restored.cargo.ore == 5)
	assert(CrewOrders.new(restored).repair_fleet_ship(vessel.id).is_empty() and restored.fleet_ships[0].hull == 100.0)
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
