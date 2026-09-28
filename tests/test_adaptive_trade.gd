extends SceneTree

func _initialize() -> void:
	var state := GameState.new()
	state.credits = 100000
	assert(state.hire("trader").is_empty())
	var orders := CrewOrders.new(state)
	assert(orders.purchase_ship("Adaptive Courier").is_empty())
	var ship: Dictionary = state.fleet_ships[0]
	var crew_id: String = state.crew[0].id
	var origin := int(ship.system)
	state.market_stocks[str(origin)] = {"luxuries": 5000}
	for address in range(17,49): state.market_stocks[str(address)] = {"luxuries": GameState.MARKET_CAPACITY}
	state.market_stocks["17"].luxuries = 0
	assert(orders.assign_adaptive_trade(crew_id, ship.id, "luxuries", 17, 20).is_empty())
	var order: Dictionary = state.crew_orders[crew_id]
	assert(order.destination == 17 and order.search_start == 17)
	var reserved := int(order.escrow)
	var cash := state.credits
	# Market conditions change before departure: choose the new viable buyer.
	state.market_stocks["17"].luxuries = GameState.MARKET_CAPACITY
	state.market_stocks["18"].luxuries = 0
	var reports := orders.tick(600)
	assert(reports.size() == 1 and reports[0].status == "cargo bought")
	assert(order.destination == 18 and ship.system == 18 and ship.cargo.luxuries == 20)
	assert(state.credits == cash - int(state.crew[0].salary), "rerouting never tops up cargo capital from commander credits")
	assert(int(order.escrow) + int(order.purchase_cost) == reserved)
	var path := "user://adaptive-trade-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty())
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty())
	state = restored
	orders = CrewOrders.new(state)
	order = state.crew_orders[crew_id]
	ship = state.fleet_ships[0]
	assert(order.search_start == 17 and order.destination == 18 and order.phase == "inbound")
	reports = orders.tick(600)
	assert(reports.size() == 1 and reports[0].status == "cargo sold")
	assert(ship.system == origin and order.phase == "outbound" and order.escrow == reserved)
	# Every candidate full: retain funds and position, only the attempt wage is due.
	for address in range(17,49): state.market_stocks[str(address)].luxuries = GameState.MARKET_CAPACITY
	cash = state.credits
	var fuel := float(ship.fuel)
	reports = orders.tick(600)
	assert(reports.size() == 1 and "no profitable route" in reports[0].status)
	assert(order.escrow == reserved and state.credits == cash - int(state.crew[0].salary))
	assert(ship.system == origin and float(ship.fuel) == fuel and int(ship.cargo.luxuries) == 0)
	# A positive sale margin is insufficient if the new purchase exceeds reserved capital.
	state.market_stocks["18"].luxuries = 0
	state.market_stocks[str(origin)].luxuries = 20
	reports = orders.tick(600)
	assert(reports.size() == 1 and "no profitable route" in reports[0].status)
	assert(order.escrow == reserved and int(ship.cargo.luxuries) == 0)
	# Malformed adaptive save fields must not alter the loaded state.
	var invalid: Dictionary = state._save_data().duplicate(true)
	invalid.crew_orders[crew_id].search_start = -1
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	var before := state._save_data().duplicate(true)
	assert(not state.load_save(path).is_empty() and state._save_data() == before)
	cash = state.credits
	assert(orders.cancel(crew_id).is_empty())
	assert(state.credits == cash + reserved and state.crew_orders.is_empty())
	for filename in [path,path+".bak",path+".tmp"]:
		if FileAccess.file_exists(filename): DirAccess.remove_absolute(filename)
	print("ADAPTIVE_TRADE_OK: live rerouting, bounded capital, waiting, save validation and cancellation")
	quit()
