extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _state() -> GameState:
	var state := GameState.new()
	state.credits = 100000
	state.stations = [{"name": "Mine", "system": 0, "level": 1, "stock": {"ore": 3}}, {"name": "Foundry", "system": 0, "level": 1, "stock": {}}]
	assert(state.hire("trader") == "")
	assert(CrewOrders.new(state).purchase_ship("Ore shuttle") == "")
	return state

func _run() -> void:
	var state := _state()
	var ops := CrewOrders.new(state)
	var id: String = state.crew[0].id
	var ship: Dictionary = state.fleet_ships[0]
	assert(ops.assign_station_transfer(id, ship.id, 0, 0, "ore", 3) != "")
	var credits := state.credits
	var market := state.market_stock("ore")
	assert(ops.assign_station_transfer(id, ship.id, 0, 1, "ore", 3) == "")
	var order: Dictionary = state.crew_orders[id]
	assert(order.escrow == 0 and state.credits == credits)
	ops.tick(600)
	assert(ship.cargo.ore == 3 and state.stations[0].stock.ore == 0)
	state.stations[1].stock.ore = CrewOrders.MAX_STOCK
	ops.tick(600)
	assert(ship.cargo.ore == 3 and order.phase == "inbound", "full destination preserves shipment")
	var path := "user://station-transfer-%d.json" % OS.get_process_id()
	assert(state.save(path) == "")
	var loaded := GameState.new()
	assert(loaded.load_save(path) == "" and loaded.crew_orders[id].source_station == 0 and loaded.crew_orders[id].delivery_station == 1)
	var valid := loaded._save_data().duplicate(true)
	for destination in [-1, 0, 99]:
		var bad := valid.duplicate(true)
		bad.crew_orders[id].delivery_station = destination
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		assert(loaded.load_save(path) != "" and loaded._save_data() == valid)
	var wrong_system := valid.duplicate(true)
	wrong_system.crew_orders[id].destination = 1
	var wrong_file := FileAccess.open(path, FileAccess.WRITE)
	wrong_file.store_string(JSON.stringify(wrong_system))
	wrong_file.close()
	assert(loaded.load_save(path) != "" and loaded._save_data() == valid)
	state.stations[1].stock.ore = 0
	credits = state.credits
	ops.tick(600)
	assert(ship.cargo.ore == 0 and state.stations[1].stock.ore == 3 and order.earned == 0)
	assert(state.credits == credits - int(state.crew[0].salary) and state.market_stock("ore") == market, "internal delivery costs wages but no market money or stock")
	ops.tick(600)
	assert(ship.cargo.ore == 0 and order.phase == "outbound", "empty source waits")
	assert(ops.cancel(id) == "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var remote := _state()
	remote.stations[1].system = 17
	remote.fleet_ships[0].system = 4
	var remote_ops := CrewOrders.new(remote)
	assert(remote_ops.assign_station_transfer(remote.crew[0].id, remote.fleet_ships[0].id, 0, 1, "ore", 3) == "")
	remote_ops.tick(600)
	assert(remote.fleet_ships[0].system == 0 and remote.fleet_ships[0].cargo.is_empty(), "remote vessel first repositions to source")
	remote_ops.tick(600)
	assert(remote.fleet_ships[0].system == 17 and remote.fleet_ships[0].cargo.ore == 3)
	remote_ops.tick(600)
	assert(remote.stations[1].stock.ore == 3 and remote.fleet_ships[0].cargo.ore == 0 and remote.fleet_ships[0].system == 0)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.state = _state()
	game._build_system()
	game._clear_actors()
	game.close_menu()
	ops = CrewOrders.new(game.state)
	id = game.state.crew[0].id
	var ship_id: String = game.state.fleet_ships[0].id
	assert(ops.assign_station_transfer(id, ship_id, 0, 1, "ore", 3) == "")
	game._sync_fleet_actors()
	var actor: ShipActor = game.fleet_actors[ship_id]
	actor.set_physics_process(false)
	var source: Vector3 = game._owned_station_system_position(0) + OwnedStation.FREIGHT_APPROACH
	var destination: Vector3 = game._owned_station_system_position(1) + OwnedStation.FREIGHT_APPROACH
	assert(actor.travel_target.distance_to(source) < 0.01)
	actor.position = source
	actor.velocity = Vector3.ZERO
	ops.tick(600, [], game._local_trade_status())
	game._sync_fleet_actors()
	actor = game.fleet_actors[ship_id]
	actor.set_physics_process(false)
	assert(actor.position.distance_to(source) < 0.01 and actor.travel_target.distance_to(destination) < 0.01, "loaded ship departs actual source toward destination without teleporting")
	ops.tick(600, [], game._local_trade_status())
	assert(game.state.fleet_ships[0].cargo.ore == 3, "local delivery requires physical arrival")
	actor.position = destination
	actor.velocity = Vector3.ZERO
	ops.tick(1, [], game._local_trade_status())
	game._sync_fleet_actors()
	actor = game.fleet_actors[ship_id]
	actor.set_physics_process(false)
	assert(game.state.stations[1].stock.ore == 3 and actor.position.distance_to(destination) < 0.01 and actor.travel_target.distance_to(source) < 0.01)
	assert(ops.cancel(id) == "")
	game.open_menu("fleet")
	var button := game.deck.find_child("TransferStationGoods", true, false) as Button
	assert(button != null and not button.disabled)
	button.pressed.emit()
	assert(game.state.crew_orders[id].source_station == 0 and game.state.crew_orders[id].delivery_station == 1, "menu assigns selected station pair")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var control := game.deck.find_child("TransferStationGoods", true, false) as Button
		var scroll: Node = control.get_parent()
		while scroll != null and not scroll is ScrollContainer: scroll = scroll.get_parent()
		scroll.ensure_control_visible(control)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://station-transfer.png")
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("STATION_TRANSFER_OK: finite stock, storage waits, save validation, no market sale, physical local legs and menu")
	quit()
