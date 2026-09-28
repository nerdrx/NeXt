extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	game.state = GameState.new()
	game.state.credits = 100000
	assert(game.state.hire("trader").is_empty())
	assert(game.crew_operations().purchase_ship("Route Scout").is_empty())
	var origin := str(game.state.system_index)
	game.state.market_stocks[origin] = {"luxuries": 5000}
	game.state.market_stocks["17"] = {"luxuries": 0}
	game.open_menu("fleet")
	var destination: SpinBox
	var quantity: SpinBox
	var discover: Button
	var assign: Button
	for node in game.deck.find_children("*", "SpinBox", true, false):
		if node.prefix == "System ": destination = node
		if node.prefix == "Cargo ": quantity = node
	for node in game.deck.find_children("*", "Button", true, false):
		if node.text == "FIND PROFITABLE ROUTES": discover = node
		if node.text == "TRADE ROUTE": assign = node
	assert(destination != null and quantity != null and discover != null and assign != null)
	destination.value = 17
	quantity.value = 20
	var before: Dictionary = game.state._save_data().duplicate(true)
	discover.pressed.emit()
	var results: Node = game.deck.find_child("TradeDiscoveries", true, false)
	assert(results.get_child_count() > 0 and results.get_child_count() <= 5)
	var choice := results.get_child(results.get_child_count()-1) as Button
	assert(choice != null and choice.has_meta("trade_suggestion"))
	var quote: Dictionary = choice.get_meta("trade_suggestion")
	choice.pressed.emit()
	assert(int(destination.value) == int(quote.destination) and int(quantity.value) == int(quote.quantity))
	assert(game.state._save_data() == before, "discover/select cannot spend or reserve assets")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var scroll := results.get_parent().get_parent() as ScrollContainer
		scroll.ensure_control_visible(results)
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://route-discovery.png") == OK)
	assign.pressed.emit()
	var order: Dictionary = game.state.crew_orders[game.state.crew[0].id]
	assert(order.good == quote.good and order.destination == quote.destination and order.quantity == quote.quantity, "actual assignment uses selected result")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	print("ROUTE_DISCOVERY_UI_OK: search, select without spending, actual assignment")
	quit()
