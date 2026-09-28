extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _new_state() -> GameState:
	var state := GameState.new()
	state.credits = 100000
	state.cargo.alloys = 20
	assert(state.build_station("Export Works").is_empty())
	assert(state.hire("trader").is_empty())
	assert(CrewOrders.new(state).purchase_ship("Outbound Freight").is_empty())
	return state

func _run() -> void:
	var state := _new_state()
	var ops := CrewOrders.new(state)
	var id: String = state.crew[0].id
	var ship: Dictionary = state.fleet_ships[0]
	var credits := state.credits
	assert(ops.assign_station_export(id, ship.id, 0, "alloys", 17, 5).is_empty())
	assert(state.credits == credits and state.crew_orders[id].escrow == 0, "exports reserve no purchase money")
	var reports := ops.tick(600)
	assert(reports[0].status == "waiting: station stock unavailable" and ship.cargo.is_empty())
	state.stations[0].stock = {"alloys": 3}
	var market_before := state.market_stock("alloys", 0)
	reports = ops.tick(600)
	assert(reports[0].status == "station cargo loaded")
	assert(state.stations[0].stock.alloys == 0 and ship.cargo.alloys == 3 and state.market_stock("alloys", 0) == market_before, "station cargo moves without buying imaginary market goods")
	assert(state.crew_orders[id].purchase_cost == -1)
	var path := "user://station-export-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty())
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty() and restored.crew_orders[id].source_station == 0 and restored.fleet_ships[0].cargo.alloys == 3)
	var valid := restored._save_data().duplicate(true)
	for invalid: Variant in [-1, 99, "0", 0.5, true]:
		var bad := valid.duplicate(true)
		bad.crew_orders[id].source_station = invalid
		assert(not restored.load_data(bad).is_empty() and restored._save_data() == valid)
	for field: String in ["delivery_station", "search_start"]:
		var bad := valid.duplicate(true)
		bad.crew_orders[id][field] = 0
		assert(not restored.load_data(bad).is_empty() and restored._save_data() == valid)
	var bad := valid.duplicate(true)
	bad.crew_orders[id].origin = 5
	assert(not restored.load_data(bad).is_empty() and restored._save_data() == valid)
	state = restored
	ops = CrewOrders.new(state)
	ship = state.fleet_ships[0]
	var initial := state.market_stock("alloys", 17)
	assert(state.market_transfer("alloys", 17, GameState.MARKET_CAPACITY - initial, false).is_empty())
	reports = ops.tick(600)
	assert(reports[0].status == "waiting: destination market full" and ship.cargo.alloys == 3)
	assert(state.market_transfer("alloys", 17, 1, true).is_empty())
	credits = state.credits
	var revenue := state.market_total("alloys", 17, 1, false, 0.85)
	reports = ops.tick(600)
	assert(reports[0].status == "cargo partially sold" and reports[0].profit == null)
	assert(ship.cargo.alloys == 2 and state.credits == credits - int(state.crew[0].salary) + revenue)
	assert(ops.cancel(id).is_empty() and ship.cargo.alloys == 2, "cancellation retains exported cargo")
	assert(not ops.assign_station_export(id, ship.id, 0, "alloys", 17).is_empty(), "loaded hold cannot be silently reassigned")
	var remote := _new_state()
	remote.stations[0].stock = {"alloys": 2}
	remote.fleet_ships[0].system = 4
	var remote_ops := CrewOrders.new(remote)
	assert(remote_ops.assign_station_export(remote.crew[0].id, remote.fleet_ships[0].id, 0, "alloys", 17, 2).is_empty())
	remote_ops.tick(600)
	assert(remote.fleet_ships[0].system == 0 and remote.fleet_ships[0].cargo.is_empty() and remote.stations[0].stock.alloys == 2, "remote exporter repositions before loading")
	remote_ops.tick(600)
	assert(remote.fleet_ships[0].system == 17 and remote.fleet_ships[0].cargo.alloys == 2 and remote.stations[0].stock.alloys == 0)
	await _scene()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("STATION_EXPORT_OK: finite loading, waiting, persistence, validation, partial revenue, cancellation and local continuity")
	quit()

func _scene() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.state = _new_state()
	game.state.stations[0].stock = {"alloys": 2}
	game._build_system()
	game._clear_actors()
	game.close_menu()
	var ops := CrewOrders.new(game.state)
	var id: String = game.state.crew[0].id
	var ship_id: String = game.state.fleet_ships[0].id
	assert(ops.assign_station_export(id, ship_id, 0, "alloys", 0, 2).is_empty())
	game._sync_fleet_actors()
	var actor: ShipActor = game.fleet_actors[ship_id]
	actor.set_physics_process(false)
	var target: Vector3 = game._owned_station_system_position(0) + OwnedStation.FREIGHT_APPROACH
	assert(actor.travel_target.distance_to(target) < 0.01)
	actor.position = target
	actor.velocity = Vector3.ZERO
	var start := actor.position
	assert(game._local_trade_status().get(ship_id, false))
	ops.tick(600, [], game._local_trade_status())
	assert(game.state.fleet_ships[0].cargo.alloys == 2)
	game._sync_fleet_actors()
	actor = game.fleet_actors[ship_id]
	actor.set_physics_process(false)
	assert(actor.position.distance_to(start) < 0.01 and actor.travel_target.distance_to(Vector3(-420, 100, -650)) < 0.01, "local export leaves station without teleporting")
	ops.tick(600, [], game._local_trade_status())
	assert(game.state.fleet_ships[0].cargo.alloys == 2, "time alone cannot sell a represented shipment")
	actor.position = actor.travel_target
	actor.velocity = Vector3.ZERO
	assert(game._local_trade_status().get(ship_id, false))
	ops.tick(1, [], game._local_trade_status())
	assert(game.state.fleet_ships[0].cargo.alloys == 0)
	var market_position := actor.position
	game._sync_fleet_actors()
	actor = game.fleet_actors[ship_id]
	actor.set_physics_process(false)
	assert(actor.position.distance_to(market_position) < 0.01 and actor.travel_target.distance_to(target) < 0.01, "empty exporter returns to station without teleporting")
	game.open_menu("fleet")
	var export_button: Button = game.deck.find_child("ExportStationGoods", true, false)
	assert(export_button != null and not export_button.disabled)
	if DisplayServer.get_name() != "headless":
		await process_frame
		var scroll: Node = export_button.get_parent()
		while scroll != null and not scroll is ScrollContainer: scroll = scroll.get_parent()
		assert(scroll != null)
		scroll.ensure_control_visible(export_button)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://station-export.png")
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
