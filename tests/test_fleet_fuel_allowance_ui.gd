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
	game.save_path = "user://fuel-allowance-ui-%d.json" % OS.get_process_id()
	var orders := CrewOrders.new(game.state)
	assert(game.state.hire("trader").is_empty())
	assert(orders.purchase_ship("Allowance UI").is_empty())
	var ship: Dictionary = game.state.fleet_ships[0]
	assert(orders.assign_trade_route(game.state.crew[0].id, ship.id, "ore", 17, 1).is_empty())
	ship.fuel = 0.0
	game.open_menu("fleet")
	var field: SpinBox
	var apply: Button
	for node: Node in game.deck.find_children("*", "", true, false):
		if node is SpinBox and str(node.get_meta("fleet_fuel_allowance", "")) == str(ship.id): field = node
		if node is Button and str(node.get_meta("fleet_fuel_allowance_apply", "")) == str(ship.id): apply = node
	assert(field != null and apply != null and field.value == 0, "allowance starts opt-out")
	var unit_cost: int = game.state.market_total("fuel", int(ship.system), 1, true)
	var cash: int = game.state.credits
	field.value = unit_cost
	apply.pressed.emit()
	assert(ship.fuel_allowance == unit_cost and game.state.credits == cash, "setting cap does not reserve or spend money")
	var saved := GameState.new()
	assert(saved.load_save(game.save_path).is_empty() and saved.fleet_ships[0].fuel_allowance == unit_cost)
	var stock: int = game.state.market_stock("fuel", int(ship.system))
	orders.tick(0.1, [], {ship.id: false})
	assert(ship.fuel == 10.0 and ship.fuel_allowance == 0, "crew refuels while still travelling toward departure")
	assert(game.state.credits == cash - unit_cost and game.state.market_stock("fuel", int(ship.system)) == stock - 1)
	assert(game.save_commander(false))
	assert(saved.load_save(game.save_path).is_empty() and saved.fleet_ships[0].fuel_allowance == 0 and saved.fleet_ships[0].fuel == 10.0)
	game.open_menu("fleet")
	for node: Node in game.deck.find_children("*", "SpinBox", true, false):
		if str(node.get_meta("fleet_fuel_allowance", "")) == str(ship.id): assert(node.value == 0, "menu shows remaining allowance")
	var save_path: String = game.save_path
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	for path: String in [save_path, save_path + ".bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("FLEET_FUEL_ALLOWANCE_UI_OK: opt-in budget, save, travelling purchase and remaining balance")
	quit()
