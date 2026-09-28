extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := GameStateScript.new()
	state.credits = 50000
	assert(state.hire("trader").is_empty())
	var orders := CrewOrdersScript.new(state)
	assert(orders.purchase_ship("Route Scout").is_empty())
	var ship: Dictionary = state.fleet_ships[0]
	var origin: int = int(ship.system)
	var origin_stock: Dictionary = {}
	for good: String in GameState.GOODS: origin_stock[good] = 10000
	origin_stock.fuel = 10000
	state.market_stocks[str(origin)] = origin_stock
	for destination: int in range(1, 80):
		var stock: Dictionary = {}
		for good: String in GameState.GOODS: stock[good] = 0
		state.market_stocks[str(destination)] = stock

	var before_credits: int = state.credits
	var before_stocks: Dictionary = state.market_stocks.duplicate(true)
	var before_ship: Dictionary = ship.duplicate(true)
	var routes: Array[Dictionary] = orders.discover_trade_routes(str(ship.id), 5, 1)
	assert(routes.size() == 5, "discovery returns at most five profitable routes")
	assert(routes == orders.discover_trade_routes(str(ship.id), 5, 1), "discovery ordering is deterministic")
	var previous_margin := INF
	var previous_destination := -1
	var previous_good := ""
	for route: Dictionary in routes:
		assert(route.ok and float(route.estimated_operating_margin) > 0.0)
		var quote: Dictionary = orders.route_quote(str(route.good), int(route.destination), 5, str(ship.id))
		assert(route == quote, "discovery result equals its current marginal route quote")
		var margin: float = float(route.estimated_operating_margin)
		assert(margin <= previous_margin, "results rank by descending operating margin")
		if margin == previous_margin:
			assert(int(route.destination) > previous_destination or
				(int(route.destination) == previous_destination and str(route.good) >= previous_good),
				"ties sort by destination, then good")
		previous_margin = margin
		previous_destination = int(route.destination)
		previous_good = str(route.good)
	assert(state.credits == before_credits and state.market_stocks == before_stocks and ship == before_ship,
		"discovery does not mutate credits, stocks, or vessel")
	for route: Dictionary in orders.discover_trade_routes(str(ship.id), 5, 40):
		assert(int(route.destination) >= 40 and int(route.destination) < 72, "scan examines only 32 addresses")
	for route: Dictionary in orders.discover_trade_routes(str(ship.id), 5, GameState.SYSTEM_LIMIT - 2):
		assert(int(route.destination) >= GameState.SYSTEM_LIMIT - 2 and int(route.destination) < GameState.SYSTEM_LIMIT,
			"scan stops at system limit")
	assert(orders.discover_trade_routes("missing-ship", 5, 1).is_empty())
	assert(orders.discover_trade_routes(str(ship.id), 0, 1).is_empty())
	assert(orders.discover_trade_routes(str(ship.id), int(ship.capacity) + 1, 1).is_empty())
	assert(orders.discover_trade_routes(str(ship.id), 101, 1).is_empty())
	assert(orders.discover_trade_routes(str(ship.id), 5, -1).is_empty())
	assert(orders.discover_trade_routes(str(ship.id), 5, GameState.SYSTEM_LIMIT).is_empty())

	# Actual quote guards must agree with discovery around market stock and receiving capacity.
	state.market_stocks[str(origin)].ore = 0
	assert(orders.route_quote("ore", 1, 5, str(ship.id)).ok == false)
	assert(orders.discover_trade_routes(str(ship.id), 5, 1).all(func(route: Dictionary) -> bool: return route.good != "ore"))
	state.market_stocks[str(origin)].ore = 10000
	state.market_stocks["1"] = {"ore": GameState.MARKET_CAPACITY, "fuel": 10000}
	assert(orders.route_quote("ore", 1, 5, str(ship.id)).ok == false)
	assert(orders.discover_trade_routes(str(ship.id), 5, 1).all(func(route: Dictionary) -> bool: return not (route.good == "ore" and int(route.destination) == 1)))
	ship.cargo = {"ore": 1}
	assert(orders.discover_trade_routes(str(ship.id), 5, 1).is_empty(), "loaded hold prevents unknown-cargo ranking")
	ship.cargo = {}

	state.market_stocks[str(origin)].fuel = 0
	assert(orders.discover_trade_routes(str(ship.id), 5, 1).is_empty(), "routes need a fuel replacement quote")
	state.market_stocks[str(origin)].fuel = 10000
	var credits: int = state.credits
	state.credits = 0
	assert(orders.discover_trade_routes(str(ship.id), 5, 1).is_empty(), "routes must fit escrow and operating costs")
	state.credits = credits
	ship.hull = 0.0
	assert(orders.discover_trade_routes(str(ship.id), 5, 1).is_empty(), "damaged vessel cannot be recommended")
	ship.hull = 100.0
	assert(state.hire("gunner").is_empty())
	var gunner_id: String = str(state.crew[1].id)
	assert(orders.assign_patrol(gunner_id, str(ship.id), origin).is_empty())
	assert(orders.discover_trade_routes(str(ship.id), 5, 1).is_empty(), "busy vessel cannot be recommended")
	print("ROUTE_DISCOVERY_OK: ranking, quote parity, scan bounds, eligibility, market limits, and purity")
	quit()
