extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := GameState.new()
	state.credits = 50000
	state.stations.append({"name": "Foundry", "system": 0, "level": 2, "stock": {"ore": 4, "fuel": 2}})
	var ops := CrewOrders.new(state)
	assert(ops.station_recipe(0).good == "ore", "legacy station retains regional default")
	assert(state.hire("engineer") == "")
	var crew_id: String = state.crew[0].id
	assert(ops.assign_station_manager(crew_id, 0) == "")
	var order: Dictionary = state.crew_orders[crew_id]
	order.progress = 450.0
	assert(ops.set_station_production(0, "ore") == "" and order.progress == 450, "same recipe is a no-op")
	var stock: Dictionary = state.stations[0].stock.duplicate(true)
	assert(ops.set_station_production(0, "alloys") == "")
	assert(order.progress == 0 and state.stations[0].stock == stock)
	assert(ops.station_recipe(0).inputs == {"ore": 2, "fuel": 1})
	ops.tick(899)
	assert(not state.stations[0].stock.has("alloys"), "old partial progress cannot finish the new recipe")
	ops.tick(1)
	assert(state.stations[0].stock.alloys == 2 and state.stations[0].stock.ore == 0 and state.stations[0].stock.fuel == 0)
	var valid: Dictionary = state._save_data().duplicate(true)
	assert(ops.set_station_production(0, "magic") != "" and ops.set_station_production(-1, "ore") != "")
	assert(state._save_data() == valid, "invalid configuration is atomic")
	var path := "user://production-choice-%d.json" % OS.get_process_id()
	assert(state.save(path) == "")
	var loaded := GameState.new()
	assert(loaded.load_save(path) == "" and CrewOrders.new(loaded).station_recipe(0).good == "alloys")
	var before := loaded._save_data().duplicate(true)
	for invalid in ["magic", 5, null]:
		var malformed := valid.duplicate(true)
		malformed.stations[0].production_good = invalid
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(malformed))
		file.close()
		assert(loaded.load_save(path) != "" and loaded._save_data() == before)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game.state.stations = state.stations.duplicate(true)
	game.open_menu("stations")
	var choice := game.deck.find_child("StationProduction0", true, false) as OptionButton
	assert(choice != null and choice.get_selected_metadata() == "alloys")
	for i in choice.item_count:
		if choice.get_item_metadata(i) == "electronics": choice.select(i)
	(game.deck.find_child("SetStationProduction0", true, false) as Button).pressed.emit()
	assert(game.crew_operations().station_recipe(0).good == "electronics", "real menu applies chosen recipe")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://station-production-choice.png")
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("STATION_PRODUCTION_CHOICE_OK: legacy default, cycle reset, finite inputs, save validation and menu configuration")
	quit()
