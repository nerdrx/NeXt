extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var remote := _new_state("patrol")
	if _failed: quit(1); return
	var crew_id: String = remote.crew[0].id
	var ship: Dictionary = remote.fleet_ships[0]
	var orders := CrewOrdersScript.new(remote)
	var destination := int(ship.system) + 1
	_check(orders.assign_patrol(crew_id, ship.id, destination).is_empty(), "assign remote patrol")
	var order: Dictionary = remote.crew_orders[crew_id]
	order.progress = CrewOrdersScript.TRIP_SECONDS - 1.0
	ship.fuel = 9.0
	var credits_before: int = remote.credits
	var hull_before: float = ship.hull
	var report: Array[Dictionary] = orders.tick(1.0)
	_check(report.size() == 1 and report[0].status == "paused: fuel insufficient", "fuel gate reports pause")
	_check(order.paused and order.progress == CrewOrdersScript.TRIP_SECONDS, "fuel gate retains due event")
	_check(remote.credits == credits_before and ship.hull == hull_before and ship.fuel == 9.0, "fuel gate is atomic before wages and patrol")
	_check(orders.tick(0.1).is_empty(), "fuel pause does not emit an alert each frame")
	ship.fuel = 10.0
	var fuel_before := float(ship.fuel)
	report = orders.tick(1.0)
	_check(not order.paused and is_equal_approx(float(ship.fuel), fuel_before - 10.0), "record refuel resumes intersystem patrol at ten fuel")

	var remote_local := _new_state("patrol")
	if _failed: quit(1); return
	var local_ship: Dictionary = remote_local.fleet_ships[0]
	var local_orders := CrewOrdersScript.new(remote_local)
	var local_crew: String = remote_local.crew[0].id
	_check(local_orders.assign_patrol(local_crew, local_ship.id, remote_local.system_index).is_empty(), "assign local patrol")
	local_orders.tick(CrewOrdersScript.TRIP_SECONDS, [str(local_ship.id)])
	_check(float(local_ship.get("fuel", 100.0)) == 100.0, "represented patrol adds no abstract fuel cost")
	local_ship.system = remote_local.system_index + 1
	var remote_crew: String = remote_local.crew[0].id
	var remote_order: Dictionary = remote_local.crew_orders[remote_crew]
	remote_order.system = int(local_ship.system)
	remote_order.progress = CrewOrdersScript.TRIP_SECONDS - 1.0
	local_orders.tick(1.0, [str(local_ship.id)])
	_check(is_equal_approx(float(local_ship.fuel), 98.0), "remote same-system patrol costs two fuel")

	var trade := _new_state("trader")
	if _failed: quit(1); return
	var trade_crew: String = trade.crew[0].id
	var trade_ship: Dictionary = trade.fleet_ships[0]
	var trade_orders := CrewOrdersScript.new(trade)
	_check(trade_orders.assign_trade_route(trade_crew, trade_ship.id, "ore", int(trade_ship.system) + 1, 2).is_empty(), "assign trade route")
	var trade_order: Dictionary = trade.crew_orders[trade_crew]
	trade_order.progress = CrewOrdersScript.TRIP_SECONDS * 2.0 - 1.0
	trade_ship.fuel = 9.0
	var market_before: int = trade.market_stock("ore", int(trade_ship.system))
	credits_before = trade.credits
	report = trade_orders.tick(1.0)
	_check(report.size() == 1 and report[0].status == "paused: fuel insufficient", "trade fuel gate reports pause")
	_check(trade.credits == credits_before and trade.market_stock("ore", int(trade_ship.system)) == market_before and int(trade_ship.cargo.get("ore", 0)) == 0, "trade fuel gate precedes wages and market transfer")
	trade_ship.fuel = 100.0
	trade_orders.tick(1.0)
	_check(is_equal_approx(float(trade_ship.fuel), 90.0) and trade_order.phase == "inbound", "successful intersystem trade transfer costs ten")
	trade_order.progress = CrewOrdersScript.TRIP_SECONDS * 2.0 - 1.0
	trade_orders.tick(1.0, [], {str(trade_ship.id): true})
	_check(is_equal_approx(float(trade_ship.fuel), 80.0) and trade_order.phase == "outbound", "represented trader still pays hyperdrive cost separate from local thrust")

	var local_trade := _new_state("trader")
	if _failed: quit(1); return
	var local_trade_ship: Dictionary = local_trade.fleet_ships[0]
	var station_order_id: String = local_trade.crew[0].id
	var local_trade_orders := CrewOrdersScript.new(local_trade)
	var same_system: int = int(local_trade_ship.system)
	local_trade.stations.append({"name": "Local Fuel Station", "system": same_system, "stock": {"ore": 0}})
	_check(local_trade_orders.assign_trade_route(station_order_id, local_trade_ship.id, "ore", same_system, 1, 0).is_empty(), "assign local station delivery")
	var local_order: Dictionary = local_trade.crew_orders[station_order_id]
	local_trade_ship.cargo.ore = 1
	local_order.phase = "inbound"
	local_order.progress = CrewOrdersScript.TRIP_SECONDS * 2.0 - 1.0
	local_trade_orders.tick(1.0, [], {str(local_trade_ship.id): true})
	_check(float(local_trade_ship.get("fuel", 100.0)) == 100.0 and local_order.phase == "outbound", "represented same-system trade leg has no duplicate cost")

	var remote_trade := _new_state("trader")
	if _failed: quit(1); return
	var remote_trade_ship: Dictionary = remote_trade.fleet_ships[0]
	var remote_trade_crew: String = remote_trade.crew[0].id
	var remote_trade_orders := CrewOrdersScript.new(remote_trade)
	var remote_station_system: int = int(remote_trade_ship.system)
	remote_trade.stations.append({"name": "Remote Fuel Station", "system": remote_station_system, "stock": {"ore": 0}})
	_check(remote_trade_orders.assign_trade_route(remote_trade_crew, remote_trade_ship.id, "ore", remote_station_system, 1, 0).is_empty(), "assign remote local-system delivery")
	var remote_trade_order: Dictionary = remote_trade.crew_orders[remote_trade_crew]
	remote_trade_ship.cargo.ore = 1
	remote_trade_order.phase = "inbound"
	remote_trade_order.progress = CrewOrdersScript.TRIP_SECONDS * 2.0 - 1.0
	remote_trade_orders.tick(1.0)
	_check(is_equal_approx(float(remote_trade_ship.fuel), 98.0), "remote same-system successful trade costs two fuel")
	remote_trade.stations[0].stock.ore = CrewOrdersScript.MAX_STOCK
	remote_trade_ship.cargo.ore = 1
	remote_trade_order.phase = "inbound"
	remote_trade_order.progress = CrewOrdersScript.TRIP_SECONDS * 2.0 - 1.0
	var blocked_report: Array[Dictionary] = remote_trade_orders.tick(1.0)
	_check(blocked_report.size() == 1 and blocked_report[0].status == "waiting: station storage full" and is_equal_approx(float(remote_trade_ship.fuel), 98.0), "blocked storage leg does not consume fuel")

	var split_a := _new_state("trader")
	var split_b := _new_state("trader")
	if _failed: quit(1); return
	var crew_a: String = split_a.crew[0].id
	var crew_b: String = split_b.crew[0].id
	var ship_a: Dictionary = split_a.fleet_ships[0]
	var ship_b: Dictionary = split_b.fleet_ships[0]
	var orders_a := CrewOrdersScript.new(split_a)
	var orders_b := CrewOrdersScript.new(split_b)
	_check(orders_a.assign_trade_route(crew_a, ship_a.id, "ore", int(ship_a.system) + 1, 2).is_empty(), "assign batched trade")
	_check(orders_b.assign_trade_route(crew_b, ship_b.id, "ore", int(ship_b.system) + 1, 2).is_empty(), "assign split trade")
	ship_a.fuel = 99.0
	ship_b.fuel = 99.0
	orders_a.tick(CrewOrdersScript.TRIP_SECONDS * 2.0)
	for i in range(1200): orders_b.tick(0.5)
	_check(is_equal_approx(float(ship_a.fuel), float(ship_b.fuel)) and ship_a.cargo == ship_b.cargo and split_a.crew_orders[crew_a].phase == split_b.crew_orders[crew_b].phase, "split and batched timing conserve equal fuel and trade state")

	if not _failed:
		print("FLEET_ORDER_FUEL_OK: pause atomicity, refuel resume, local and remote costs, split timing")
	quit(1 if _failed else 0)

var _failed := false
func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("FLEET_ORDER_FUEL_FAILED: " + message)

func _new_state(kind: String) -> GameState:
	var state := GameStateScript.new()
	state.credits = 50000
	var hire_error := state.hire("gunner" if kind == "patrol" else kind)
	if not hire_error.is_empty():
		_check(false, "hire %s: %s" % ["gunner" if kind == "patrol" else kind, hire_error])
	var orders := CrewOrdersScript.new(state)
	var purchase_error := orders.purchase_ship("Fuel Test Vessel")
	if not purchase_error.is_empty():
		_check(false, "commission ship: %s" % purchase_error)
	return state
