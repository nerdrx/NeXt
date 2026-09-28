extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := GameStateScript.new()
	state.credits = 50000
	var orders := CrewOrdersScript.new(state)
	assert(orders.purchase_ship("Partial Fuel Test").is_empty())
	var ship: Dictionary = state.fleet_ships[0]
	var ship_id := str(ship.id)
	var system := int(ship.system)
	var stock_before := state.market_stock("fuel", system)
	var credits_before: int = state.credits

	# Nine available units cannot satisfy a default full refill, but one unit buys ten fuel.
	state.market_stocks[str(system)] = {"fuel": 9}
	ship.fuel = 0.0
	var full_cost := state.market_total("fuel", system, 10, true)
	assert(full_cost < 0 and state.market_stock("fuel", system) == 9,
		"market quote rejects full refill when stock is short")
	assert(not orders.refuel_fleet_ship(ship_id).is_empty())
	assert(ship.fuel == 0.0 and state.credits == credits_before and state.market_stock("fuel", system) == 9,
		"failed full refill leaves fuel, credits, and finite stock unchanged")
	var one_unit_cost := state.market_total("fuel", system, 1, true)
	assert(orders.refuel_fleet_ship(ship_id, 1).is_empty())
	assert(ship.fuel == 10.0 and state.credits == credits_before - one_unit_cost)
	assert(state.market_stock("fuel", system) == 8, "one commodity unit supplies ten fuel from finite stock")

	# An unaffordable partial order must not alter any part of the transaction.
	ship.fuel = 50.0
	var poor_cost := state.market_total("fuel", system, 3, true)
	state.credits = poor_cost - 1
	var poor_fuel := float(ship.fuel)
	var poor_stock := state.market_stock("fuel", system)
	var poor_credits: int = state.credits
	assert(not orders.refuel_fleet_ship(ship_id, 3).is_empty())
	assert(ship.fuel == poor_fuel and state.market_stock("fuel", system) == poor_stock and state.credits == poor_credits,
		"insufficient credits reject atomically")

	var affordable_cost := state.market_total("fuel", system, 1, true)
	assert(orders.refuel_fleet_ship(ship_id, 1).is_empty())
	assert(ship.fuel == poor_fuel + 10.0 and state.credits == poor_credits - affordable_cost and state.market_stock("fuel", system) == poor_stock - 1, "smaller purchase succeeds within limited budget")

	# Invalid quantities are atomic too.
	state.credits = 50000
	for quantity in [-1, 11]:
		var fuel_before := float(ship.fuel)
		var stock_before_invalid := state.market_stock("fuel", system)
		var invalid_credits: int = state.credits
		assert(not orders.refuel_fleet_ship(ship_id, quantity).is_empty())
		assert(ship.fuel == fuel_before and state.market_stock("fuel", system) == stock_before_invalid and state.credits == invalid_credits,
			"invalid quantity %d is atomic" % quantity)

	# A ten-unit request near full only buys the single unit the tank can accept.
	ship.fuel = 95.0
	var topoff_cost := state.market_total("fuel", system, 1, true)
	var topoff_stock := state.market_stock("fuel", system)
	credits_before = state.credits
	assert(orders.refuel_fleet_ship(ship_id, 10).is_empty())
	assert(ship.fuel == 100.0 and state.credits == credits_before - topoff_cost)
	assert(state.market_stock("fuel", system) == topoff_stock - 1, "topoff buys only the fuel unit needed")

	var save_path := "user://partial-fleet-refuel-%d.json" % OS.get_process_id()
	assert(state.save(save_path).is_empty())
	var restored := GameStateScript.new()
	assert(restored.load_save(save_path).is_empty())
	assert(restored.fleet_ships[0].fuel == ship.fuel)
	assert(restored.credits == state.credits and restored.market_stock("fuel", system) == state.market_stock("fuel", system),
		"refuel state and market inventory survive save roundtrip")
	for path: String in [ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".bak")]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	assert(stock_before > 0, "market began with finite fuel inventory")
	print("PARTIAL_FLEET_REFUEL_OK: partial units, finite stock, pricing, atomic rejection, topoff, persistence")
	quit()
