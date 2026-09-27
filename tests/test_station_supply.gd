extends SceneTree

var path := "user://station-supply-%d.json" % OS.get_process_id()
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func _new_state() -> GameState:
	var state := GameState.new()
	state.credits = 50000
	assert(state.jump(1).is_empty())
	state.cargo.alloys = 20
	assert(state.build_station("Supply Foundry").is_empty())
	assert(state.hire("trader").is_empty())
	var ops := CrewOrders.new(state)
	assert(ops.purchase_ship("Factory Runner").is_empty())
	return state

func _run() -> void:
	var state := _new_state()
	var ops := CrewOrders.new(state)
	var crew_id: String = state.crew[0].id
	var ship: Dictionary = state.fleet_ships[0]
	assert(not ops.assign_trade_route(crew_id, ship.id, "ore", state.system_index, 2).is_empty(), "ordinary trade still requires another system")
	assert(ops.assign_station_supply(crew_id, ship.id, 0, "ore", 2).is_empty())
	var order: Dictionary = state.crew_orders[crew_id]
	var source_stock := state.market_stock("ore")
	var cost := state.market_total("ore", state.system_index, 2, true)
	var wealth: int = state.credits + int(order.escrow)
	var reports := ops.tick(600)
	assert(reports.size() == 1 and reports[0].status == "cargo bought")
	assert(ship.cargo.ore == 2 and state.market_stock("ore") == source_stock - 2 and state.credits + int(order.escrow) == wealth - int(state.crew[0].salary) - cost)
	state.stations[0].stock = {"ore": CrewOrders.MAX_STOCK}
	ops.tick(600)
	assert(ship.cargo.ore == 2 and order.phase == "inbound" and order.purchase_cost == cost, "full station cannot delete cargo or its cost")
	assert(state.save(path).is_empty())
	var restored := GameState.new()
	var error := restored.load_save(path)
	assert(error.is_empty(), error)
	assert(restored.crew_orders[crew_id].delivery_station == 0 and restored.fleet_ships[0].cargo.ore == 2)
	var valid := restored._save_data().duplicate(true)
	for bad: Variant in [-1, 99, 0.5, "0"]:
		var invalid := valid.duplicate(true)
		invalid.crew_orders[crew_id].delivery_station = bad
		_write(invalid)
		assert(not restored.load_save(path).is_empty() and restored._save_data() == valid)
	var mismatch := valid.duplicate(true)
	mismatch.stations[0].system = 2
	_write(mismatch)
	assert(not restored.load_save(path).is_empty() and restored._save_data() == valid, "station destination mismatch rejected atomically")
	state.stations[0].stock.ore = 0
	wealth = state.credits
	reports = ops.tick(600)
	assert(reports.size() == 1 and reports[0].status == "cargo delivered")
	assert(state.stations[0].stock.ore == 2 and ship.cargo.ore == 0 and state.credits == wealth - int(state.crew[0].salary) and order.earned == 0, "internal delivery is not a market sale or income")
	wealth = state.credits + int(order.escrow)
	cost = state.market_total("ore", state.system_index, 2, true)
	ops.tick(600)
	assert(ship.cargo.ore == 2 and state.credits + int(order.escrow) == wealth - int(state.crew[0].salary) - cost, "recurring supply buys with actual commander funds")
	var escrow: int = order.escrow
	wealth = state.credits
	assert(ops.cancel(crew_id).is_empty() and state.credits == wealth + escrow and ship.cargo.ore == 2)
	state.stations[0].stock.fuel = 1
	assert(state.hire("engineer").is_empty())
	assert(ops.assign_station_manager(str(state.crew[1].id), 0).is_empty())
	ops.tick(900)
	assert(state.stations[0].stock.alloys == 1 and state.stations[0].stock.ore == 0, "delivered ore feeds actual factory work")
	var poor := _new_state()
	var poor_ops := CrewOrders.new(poor)
	var poor_crew: String = poor.crew[0].id
	assert(poor_ops.assign_station_supply(poor_crew, str(poor.fleet_ships[0].id), 0, "ore", 2).is_empty())
	poor.crew_orders[poor_crew].escrow = 0
	poor.credits = int(poor.crew[0].salary)
	var poor_stock := poor.market_stock("ore")
	poor_ops.tick(600)
	assert(poor.fleet_ships[0].cargo.is_empty() and poor.market_stock("ore") == poor_stock and poor.credits == 0, "supply cannot purchase without funding")
	poor.credits = int(poor.crew[0].salary) + int(poor.crew_orders[poor_crew].escrow_limit)
	poor_ops.tick(600)
	assert(poor.fleet_ships[0].cargo.ore == 2, "funded supply resumes on next pickup cycle")
	var remote := _new_state()
	remote.fleet_ships[0].system = 2
	var remote_ops := CrewOrders.new(remote)
	assert(remote_ops.assign_station_supply(str(remote.crew[0].id), str(remote.fleet_ships[0].id), 0, "ore", 2).is_empty())
	remote_ops.tick(600)
	assert(remote.fleet_ships[0].system == 1 and remote.fleet_ships[0].cargo.ore == 2)
	remote_ops.tick(600)
	assert(remote.fleet_ships[0].system == 2 and remote.stations[0].stock.ore == 2, "inter-system suppliers return to their source market")
	await _scene()
	for file_path: String in [path, path + ".bak"]:
		if FileAccess.file_exists(file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	print("STATION_SUPPLY_OK: finite purchases, recurring funding, storage waits, persistence and continuous local delivery")
	quit()

func _scene() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state = _new_state()
	game.save_path = path
	game._build_system()
	game._clear_actors()
	game.close_menu()
	var ops := CrewOrders.new(game.state)
	var crew_id: String = game.state.crew[0].id
	var id: String = game.state.fleet_ships[0].id
	assert(ops.assign_station_supply(crew_id, id, 0, "ore", 2).is_empty())
	var patrols: Array[String] = game._sync_fleet_actors()
	var actor: ShipActor = game.fleet_actors[id]
	actor.set_physics_process(false)
	var pickup := actor.position
	assert(bool(game._local_trade_status().get(id, false)), "local supplier starts at its market pickup berth")
	ops.tick(600, patrols, game._local_trade_status())
	game._sync_fleet_actors()
	actor = game.fleet_actors[id]
	actor.set_physics_process(false)
	assert(actor.position.distance_to(pickup) < 0.01, "local pickup does not teleport cargo ship")
	var target: Vector3 = game._owned_station_system_position(0) + OwnedStation.FREIGHT_APPROACH
	assert(actor.travel_target.distance_to(target) < 0.01 and actor.position.distance_to(target) > 100)
	var origin := SectorPosition.new(Vector3i(1, 0, 0))
	game.flight_frame.rebase(game.flight_origin, origin)
	game.flight_origin = origin
	pickup -= Vector3(8192, 0, 0)
	target -= Vector3(8192, 0, 0)
	game._capture_fleet_flights()
	assert(game.state.save(path).is_empty())
	var reloaded := GameState.new()
	assert(reloaded.load_save(path).is_empty())
	game._clear_actors()
	game.state = reloaded
	ops = CrewOrders.new(game.state)
	game._sync_fleet_actors()
	actor = game.fleet_actors[id]
	actor.set_physics_process(false)
	assert(actor.position.distance_to(pickup) < 0.01 and actor.travel_target.distance_to(target) < 0.01, "saved local supplier restores its station destination in a rebased frame")
	ops.tick(600, patrols, game._local_trade_status())
	assert(int(game.state.stations[0].get("stock", {}).get("ore", 0)) == 0, "timer alone cannot deliver represented freight")
	await physics_frame
	for step: int in range(4000):
		actor._physics_process(1.0 / 60.0)
		if bool(game._local_trade_status().get(id, false)): break
	assert(bool(game._local_trade_status().get(id, false)), "supplier physically reaches the station approach")
	var arrival := actor.position
	ops.tick(1, patrols, game._local_trade_status())
	game._sync_fleet_actors()
	actor = game.fleet_actors[id]
	actor.set_physics_process(false)
	assert(game.state.stations[0].stock.ore == 2 and actor.position.distance_to(arrival) < 0.01, "delivery transfers actual cargo without teleporting the returning vessel")
	assert(actor.travel_target.distance_to(pickup) < 0.01)
	game.open_menu("fleet")
	await process_frame
	(game.deck.content.get_parent() as ScrollContainer).scroll_vertical = 10000
	await process_frame
	if DisplayServer.get_name() != "headless": await game._capture("station-supply")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame

func _write(data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
