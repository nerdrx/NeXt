extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := _new_state("trader")
	if _failed: quit(1); return
	var ship: Dictionary = state.fleet_ships[0]
	var crew_id: String = state.crew[0].id
	var orders := CrewOrdersScript.new(state)
	var system_id := int(ship.system)
	_check(ship.fuel_allowance == 0, "new vessels start with allowance disabled")
	_check(orders.assign_trade_route(crew_id, ship.id, "ore", system_id + 1, 1).is_empty(), "assign trade route")
	var order: Dictionary = state.crew_orders[crew_id]
	ship.fuel = 9.0
	var stock := state.market_stock("fuel", system_id)
	var credits_before := state.credits
	orders.tick(1.0, [], {str(ship.id): false})
	_check(ship.fuel == 9.0 and state.credits == credits_before and state.market_stock("fuel", system_id) == stock, "zero allowance disables automatic refuel")
	var cost := state.market_total("fuel", system_id, 1, true)
	_check(orders.set_fuel_allowance(ship.id, cost).is_empty() and state.credits == credits_before, "setting exact allowance does not spend treasury")
	_check(not orders.set_fuel_allowance(ship.id, -1).is_empty() and not orders.set_fuel_allowance(ship.id, 1000001).is_empty(), "setter rejects out-of-range allowance")
	var reports := orders.tick(1.0, [], {str(ship.id): false})
	_check(reports.is_empty() and is_equal_approx(float(ship.fuel), 19.0), "local trader refuels before arrival gate")
	_check(state.credits == credits_before - cost and state.market_stock("fuel", system_id) == stock - 1 and ship.fuel_allowance == 0, "one unit charges exact price and allowance")
	var allowance_after := int(ship.fuel_allowance)
	orders.tick(10.0, [], {str(ship.id): false})
	_check(ship.fuel == 19.0 and ship.fuel_allowance == allowance_after, "tank above threshold does not spend allowance again")
	var fuel_before := float(ship.fuel)
	var cash_before := state.credits
	var market_before := state.market_stock("fuel", system_id)
	orders.tick(0.0)
	_check(float(ship.fuel) == fuel_before and state.credits == cash_before and state.market_stock("fuel", system_id) == market_before, "zero elapsed time does not refuel")

	var disabled := _new_state("trader")
	if _failed: quit(1); return
	var disabled_ship: Dictionary = disabled.fleet_ships[0]
	var disabled_orders := CrewOrdersScript.new(disabled)
	disabled_ship.fuel = 0.0
	disabled_ship.fuel_allowance = 1000
	var disabled_stock := disabled.market_stock("fuel", int(disabled_ship.system))
	disabled_orders.tick(10.0)
	_check(disabled_ship.fuel == 0.0 and disabled.market_stock("fuel", int(disabled_ship.system)) == disabled_stock, "unassigned vessel does not refuel")

	var blocked := _new_state("gunner")
	if _failed: quit(1); return
	var blocked_ship: Dictionary = blocked.fleet_ships[0]
	var blocked_orders := CrewOrdersScript.new(blocked)
	var blocked_crew: String = blocked.crew[0].id
	_check(blocked_orders.assign_patrol(blocked_crew, blocked_ship.id, int(blocked_ship.system) + 1).is_empty(), "assign blocked patrol")
	blocked_ship.fuel = 0.0
	blocked_ship.fuel_allowance = 1000
	var blocked_system := int(blocked_ship.system)
	var blocked_cost := blocked.market_total("fuel", blocked_system, 1, true)
	blocked.market_stocks[str(blocked_system)] = {"fuel": 0}
	var blocked_cash := blocked.credits
	_check(blocked_orders.tick(1.0).size() == 0 and blocked_ship.fuel == 0.0 and blocked_ship.fuel_allowance == 1000 and blocked.credits == blocked_cash, "empty stock leaves all allowance and cash untouched")
	blocked.market_stocks.erase(str(blocked_system))
	blocked_ship.fuel_allowance = blocked_cost - 1
	blocked_orders.tick(1.0)
	_check(blocked_ship.fuel == 0.0 and blocked.credits == blocked_cash, "insufficient allowance leaves state unchanged")
	blocked_ship.fuel_allowance = blocked_cost
	blocked.credits = int(blocked.crew[0].salary) + blocked_cost - 1
	var enough_stock := blocked.market_stock("fuel", blocked_system)
	blocked_orders.tick(1.0)
	_check(blocked_ship.fuel == 0.0 and blocked_ship.fuel_allowance == blocked_cost and blocked.credits == int(blocked.crew[0].salary) + blocked_cost - 1 and blocked.market_stock("fuel", blocked_system) == enough_stock, "cash reserved for salary prevents purchase")

	var batch_a := _new_state("gunner")
	var batch_b := _new_state("gunner")
	if _failed: quit(1); return
	var batch_ship_a: Dictionary = batch_a.fleet_ships[0]
	var batch_ship_b: Dictionary = batch_b.fleet_ships[0]
	var batch_orders_a := CrewOrdersScript.new(batch_a)
	var batch_orders_b := CrewOrdersScript.new(batch_b)
	for pair: Array in [[batch_a, batch_ship_a, batch_orders_a], [batch_b, batch_ship_b, batch_orders_b]]:
		var model: GameState = pair[0]
		var vessel: Dictionary = pair[1]
		var manager: CrewOrders = pair[2]
		var member_id: String = model.crew[0].id
		_check(manager.assign_patrol(member_id, vessel.id, int(vessel.system) + 1).is_empty(), "assign batch patrol")
		vessel.fuel = 1.0
		vessel.fuel_allowance = 1000
	batch_orders_a.tick(CrewOrdersScript.TRIP_SECONDS * 2.0)
	for i: int in range(600): batch_orders_b.tick(1.0)
	_check(is_equal_approx(float(batch_ship_a.fuel), float(batch_ship_b.fuel)) and int(batch_ship_a.fuel_allowance) == int(batch_ship_b.fuel_allowance), "large and split ticks refill at due leg boundaries equally")

	var save_path := "user://fleet-fuel-allowance-%d.json" % OS.get_process_id()
	ship.fuel_allowance = 456
	_check(state.save(save_path).is_empty(), "save allowance")
	var restored := GameStateScript.new()
	_check(restored.load_save(save_path).is_empty() and restored.fleet_ships[0].fuel_allowance == 456, "allowance survives save roundtrip")
	var data: Dictionary = state._save_data()
	data.fleet_ships[0].fuel_allowance = 1000001
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	restored.credits = 321
	var load_error := restored.load_save(save_path)
	_check(not load_error.is_empty() and restored.credits == 321 and restored.fleet_ships[0].fuel_allowance == 456, "invalid allowance rejects save atomically")
	data.fleet_ships[0].erase("fuel_allowance")
	file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var legacy := GameStateScript.new()
	_check(legacy.load_save(save_path).is_empty() and legacy.fleet_ships[0].fuel_allowance == 0, "legacy vessel defaults to disabled allowance")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if not _failed: print("FLEET_FUEL_ALLOWANCE_OK: purchase gate, atomic budgets, due-leg timing, persistence")
	quit(1 if _failed else 0)

var _failed := false
func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("FLEET_FUEL_ALLOWANCE_FAILED: " + message)

func _new_state(role: String) -> GameState:
	var state: GameState = GameStateScript.new()
	state.credits = 50000
	_check(state.hire(role).is_empty(), "hire " + role)
	var orders := CrewOrdersScript.new(state)
	_check(orders.purchase_ship("Allowance Test Vessel").is_empty(), "commission test vessel")
	return state
