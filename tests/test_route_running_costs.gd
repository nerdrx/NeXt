extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := GameState.new()
	var orders := CrewOrders.new(state)
	assert(orders.purchase_ship("Quoted Vessel").is_empty())
	var ship: Dictionary = state.fleet_ships[0]
	ship.system = 17
	var quote := orders.route_quote("ore", 18, 5, ship.id)
	assert(quote.ok and quote.origin == 17)
	var purchase := state.market_total("ore", 17, 5, true)
	var sale := state.market_total("ore", 18, 5, false, 0.85)
	var fuel := state.market_total("fuel", 17, 2, true)
	assert(quote.expected_profit == sale - purchase and quote.escrow == purchase, "cargo quote keeps original gross margin and escrow")
	assert(quote.round_trip_wages == 150 and quote.round_trip_fuel == 20.0)
	assert(quote.fuel_replacement_cost == fuel and quote.estimated_operating_margin == sale - purchase - 150 - fuel, "operating estimate includes two wages and origin fuel quote")
	var cash := state.credits
	var market := state.market_stocks.duplicate(true)
	var vessel_before := ship.duplicate(true)
	orders.route_quote("ore", 18, 5, ship.id)
	assert(state.credits == cash and state.market_stocks == market and ship == vessel_before, "quoting does not buy fuel or spend money")
	state.market_stocks["17"] = {"fuel": 0}
	quote = orders.route_quote("ore", 18, 5, ship.id)
	assert(quote.ok and quote.fuel_replacement_cost == null and quote.estimated_operating_margin == null, "missing fuel yields unknown margin, never a free-fuel estimate")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._clear_actors()
	assert(game.state.hire("trader").is_empty())
	assert(game.crew_operations().purchase_ship("UI Quote").is_empty())
	game.open_menu("fleet")
	for node: Node in game.deck.find_children("*", "SpinBox", true, false):
		if node.prefix == "System ": node.value = 17
	for node: Node in game.deck.find_children("*", "Button", true, false):
		if node.text == "QUOTE ROUTE": node.pressed.emit()
	var label := game.deck.find_child("RouteQuote", true, false) as Label
	assert(label != null and "after wages and jump fuel" in label.text and "cost extra" in label.text, "menu exposes running costs and estimate limits")
	if DisplayServer.get_name() != "headless":
		var scroll := label.get_parent().get_parent() as ScrollContainer
		await process_frame
		scroll.ensure_control_visible(label)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/route-running-costs.png")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("ROUTE_RUNNING_COSTS_OK: gross/net estimates, origin pricing, unavailable fuel, no purchase and menu disclosure")
	quit()
