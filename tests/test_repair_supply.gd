extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := GameState.new()
	state.credits = 1000000
	var maximum := float(state.ship_stats().max_hull)
	state.hull = maximum - 75.0
	var quote := state.hull_repair_quote(75.0)
	assert(quote.supplies == {"alloys": 2, "electronics": 1})
	assert(quote.price == 300 + state.market_total("alloys", state.system_index, 2, true) + state.market_total("electronics", state.system_index, 1, true))
	var alloys := state.market_stock("alloys")
	var electronics := state.market_stock("electronics")
	var funds := state.credits
	assert(state.repair().is_empty())
	assert(state.hull == maximum and state.credits == funds - int(quote.price))
	assert(state.market_stock("alloys") == alloys - 2 and state.market_stock("electronics") == electronics - 1)
	var before := state._save_data().duplicate(true)
	assert(not state.repair().is_empty() and state._save_data() == before, "full hull cannot consume supplies")
	state.hull -= 75.0
	assert(state.market_transfer("electronics", state.system_index, state.market_stock("electronics"), true).is_empty())
	before = state._save_data().duplicate(true)
	assert(not state.repair().is_empty() and state._save_data() == before, "missing component leaves hull, funds and alloys unchanged")
	assert(state.market_transfer("electronics", state.system_index, 1, false).is_empty())
	state.credits = 0
	before = state._save_data().duplicate(true)
	assert(not state.repair().is_empty() and state._save_data() == before, "unaffordable repair is atomic")
	state.credits = 1000000
	assert(state.repair().is_empty(), "market delivery enables repairs")
	var orders := CrewOrders.new(state)
	assert(orders.purchase_ship("Remote repair", "merchant").is_empty())
	var ship: Dictionary = state.fleet_ships.back()
	ship.system = 5
	ship.hull = 25.0
	quote = orders.fleet_repair_quote(ship.id)
	assert(quote.system == 5 and quote.supplies.alloys > 2, "large damaged hull needs scaled supplies")
	alloys = state.market_stock("alloys", 5)
	var home_alloys := state.market_stock("alloys")
	assert(orders.repair_fleet_ship(ship.id).is_empty() and ship.hull == 100.0)
	assert(state.market_stock("alloys", 5) == alloys - int(quote.supplies.alloys) and state.market_stock("alloys") == home_alloys)
	var path := "user://repair-supply-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty())
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty() and restored.market_stocks == state.market_stocks)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var limited := GameState.new()
	limited.credits = 1000000
	limited.hull -= 10.0
	for index in GameState.MAX_MARKETS: limited.market_stocks[str(index + 1)] = {"alloys": 1}
	before = limited._save_data().duplicate(true)
	assert(not limited.repair().is_empty() and limited._save_data() == before, "market record limit cannot consume funds or supplies")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.state.credits = 100000
	game.state.hull = float(game.state.ship_stats().max_hull) - 75.0
	game.open_menu("market")
	var button := _repair_button(game.deck)
	assert(button != null and not button.disabled and "CR" in button.text)
	if DisplayServer.get_name() != "headless":
		await process_frame
		var parent := button.get_parent()
		while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
		if parent is ScrollContainer: parent.scroll_vertical = int(parent.get_v_scroll_bar().max_value)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://repair-supplies.png")
	var stock: int = game.state.market_stock("alloys")
	button.pressed.emit()
	assert(game.state.hull == float(game.state.ship_stats().max_hull) and game.state.market_stock("alloys") == stock - 2)
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("REPAIR_SUPPLY_OK: priced finite components, delivery recovery, atomic failures, actual fleet hull scale, remote market and saves")
	quit()

func _repair_button(node: Node) -> Button:
	if node is Button and node.text.begins_with("REPAIR /"): return node
	for child: Node in node.get_children():
		var found := _repair_button(child)
		if found != null: return found
	return null
