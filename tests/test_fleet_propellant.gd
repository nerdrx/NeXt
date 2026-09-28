extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	game.close_menu()
	game.state.credits = 50000
	game.save_path = "user://fleet-propellant-%d.json" % OS.get_process_id()
	var orders := CrewOrders.new(game.state)
	assert(game.state.hire("trader").is_empty())
	assert(orders.purchase_ship("Propellant Test").is_empty())
	var ship: Dictionary = game.state.fleet_ships[0]
	ship.fuel = 0.02
	var result := orders.consume_propulsion(ship.id, Vector3(10, 0, 0), Vector3.ZERO, 40000.0)
	assert(is_equal_approx(result.x, 7.5) and is_zero_approx(ship.fuel), "partial braking spends remaining impulse budget")
	assert(orders.consume_propulsion(ship.id, result, Vector3.ZERO, 40000.0) == result, "empty tank retains momentum")
	ship.fuel = 10.0
	assert(orders.consume_propulsion(ship.id, result, Vector3(INF, 0, 0), 40000.0) == result and ship.fuel == 10.0)
	var cash: int = game.state.credits
	var stock: int = game.state.market_stock("fuel", int(ship.system))
	var cost: int = game.state.market_total("fuel", int(ship.system), 9, true)
	assert(orders.refuel_fleet_ship(ship.id).is_empty())
	assert(ship.fuel == 100.0 and game.state.credits == cash - cost and game.state.market_stock("fuel", int(ship.system)) == stock - 9, "fuel service spends credits and market stock")
	ship.fuel = 50.0
	game.state.credits = 0
	stock = game.state.market_stock("fuel", int(ship.system))
	assert(not orders.refuel_fleet_ship(ship.id).is_empty() and ship.fuel == 50.0 and game.state.market_stock("fuel", int(ship.system)) == stock, "unaffordable service preserves fuel and inventory")
	game.state.credits = 50000
	game.state.market_stocks[str(ship.system)].fuel = 0
	assert(not orders.refuel_fleet_ship(ship.id).is_empty() and ship.fuel == 50.0 and game.state.credits == 50000, "empty market cannot create fuel or charge credits")
	game.state.market_stocks[str(ship.system)].fuel = stock
	assert(orders.assign_trade_route(game.state.crew[0].id, ship.id, "ore", 17, 1).is_empty())
	game._sync_fleet_actors()
	var actor: ShipActor = game.fleet_actors[ship.id]
	assert(actor.propulsion_limiter.is_valid())
	actor.active = true
	var before_fuel: float = ship.fuel
	await create_timer(0.4).timeout
	assert(ship.fuel < before_fuel, "actual fleet actor thrust consumes persisted vessel fuel")
	ship.fuel = 0.0
	var speed_before := actor.velocity.length()
	assert(speed_before > 0.1)
	await create_timer(0.2).timeout
	assert(is_equal_approx(actor.velocity.length(), speed_before), "empty actor coasts without powered braking")
	game.open_menu("fleet")
	var found := false
	for node: Node in game.deck.find_children("*", "Button", true, false):
		if str(node.get_meta("fleet_refuel", "")) != str(ship.id): continue
		assert(not node.disabled)
		node.pressed.emit()
		found = true
		break
	assert(found and ship.fuel == 100.0, "fleet menu dispatches fuel service")
	var restored := GameState.new()
	assert(restored.load_save(game.save_path).is_empty() and restored.fleet_ships[0].fuel == 100.0, "service result persists")
	game.close_menu()
	await create_timer(0.1).timeout
	assert(ship.fuel < 100.0, "actor immediately uses refilled authoritative tank")
	for path: String in [game.save_path, game.save_path + ".bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("FLEET_PROPELLANT_OK: limited impulse, coasting, service cost/stock, actor binding, UI and persistence")
	quit()
