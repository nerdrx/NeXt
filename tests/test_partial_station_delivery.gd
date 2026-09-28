extends SceneTree

func _initialize() -> void:
	var state := GameState.new()
	state.credits = 100000
	state.stations = [{"name": "Foundry", "system": 17, "level": 1, "stock": {"ore": CrewOrders.MAX_STOCK - 2}}]
	assert(state.hire("trader") == "")
	var ops := CrewOrders.new(state)
	assert(ops.purchase_ship("Supplier") == "")
	var id: String = state.crew[0].id
	var ship: Dictionary = state.fleet_ships[0]
	assert(ops.assign_station_supply(id, ship.id, 0, "ore", 5) == "")
	ops.tick(600)
	var order: Dictionary = state.crew_orders[id]
	var invoice: int = order.purchase_cost
	assert(ship.cargo.ore == 5 and invoice > 0)
	ship.fuel = 0.0
	var before := state.credits
	assert(ops.tick(600, [], {ship.id: false}).is_empty())
	assert(ship.cargo.ore == 5 and state.credits == before, "physical arrival still required")
	var reports := ops.tick(1, [], {ship.id: true})
	assert(reports.size() == 1 and reports[0].status == "cargo partially delivered")
	var first_cost: int = reports[0].cost
	assert(reports[0].quantity == 2 and reports[0].remaining == 3)
	assert(first_cost + int(order.purchase_cost) == invoice)
	assert(ship.cargo.ore == 3 and state.stations[0].stock.ore == CrewOrders.MAX_STOCK)
	assert(ship.system == 17 and ship.fuel == 0.0 and order.phase == "inbound")
	assert(state.credits == before - int(state.crew[0].salary) and order.earned == 0)
	var remaining_cost: int = order.purchase_cost
	reports = ops.tick(600)
	assert(reports[0].status == "waiting: station storage full" and ship.cargo.ore == 3 and order.purchase_cost == remaining_cost)
	var path := "user://partial-station-%d.json" % OS.get_process_id()
	assert(state.save(path) == "")
	var restored := GameState.new()
	assert(restored.load_save(path) == "")
	ops = CrewOrders.new(restored)
	ship = restored.fleet_ships[0]
	order = restored.crew_orders[id]
	assert(ship.cargo.ore == 3 and order.purchase_cost == remaining_cost)
	restored.stations[0].stock.ore -= 3
	reports = ops.tick(600)
	assert(reports[0].status == "paused: fuel insufficient" and ship.cargo.ore == 3, "final unload retains existing return-leg fuel requirement")
	ship.fuel = 10.0
	reports = ops.tick(1)
	assert(reports[0].status == "cargo delivered" and first_cost + int(reports[0].cost) == invoice)
	assert(ship.cargo.ore == 0 and ship.system == 0 and ship.fuel == 0.0 and order.purchase_cost == 0)
	# Station-produced cargo has no known invoice, including after a partial unload.
	ship.cargo.ore = 3
	ship.system = 17
	order.phase = "inbound"
	order.purchase_cost = -1
	restored.stations[0].stock.ore -= 1
	reports = ops.tick(600)
	assert(reports[0].cost == null and order.purchase_cost == -1 and ship.cargo.ore == 2)
	assert(ops.cancel(id) == "" and ship.cargo.ore == 2, "cancellation preserves remaining shipment")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	print("PARTIAL_STATION_DELIVERY_OK: capacity, arrival, zero-fuel partial unloading, invoice conservation, persistence and cancellation")
	quit()
