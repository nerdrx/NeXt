extends SceneTree

var game: Node
var path := "user://station-industry-%d.json" % OS.get_process_id()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := GameState.new()
	state.credits = 50000
	assert(state.jump(1).is_empty())
	state.cargo.alloys = 20
	assert(state.build_station("Foundry").is_empty())
	assert(state.hire("engineer").is_empty())
	var orders := CrewOrders.new(state)
	var crew_id: String = state.crew[0].id
	assert(orders.assign_station_manager(crew_id, 0).is_empty())
	state.stations[0].level = 3
	var report := orders.tick(900)
	assert(report.size() == 1 and report[0].status == "waiting: production inputs missing")
	assert(state.stations[0].stock.is_empty() and state.crew_orders[crew_id].produced == 0)
	state.cargo.ore = 4
	state.cargo.fuel = 1
	assert(orders.deposit_station_stock(0, "ore", 4).is_empty())
	assert(orders.deposit_station_stock(0, "fuel", 1).is_empty())
	assert(state.cargo.ore == 0 and state.cargo.fuel == 0)
	assert(orders.tick(899).is_empty(), "supplies do not skip remaining work time")
	assert(state.save(path).is_empty())
	var resumed := GameState.new()
	var load_error := resumed.load_save(path)
	assert(load_error.is_empty(), load_error)
	orders = CrewOrders.new(resumed)
	report = orders.tick(1)
	assert(report.size() == 1 and report[0].quantity == 1, "scarce fuel limits a level-three batch to one unit")
	assert(resumed.stations[0].stock.ore == 2 and resumed.stations[0].stock.fuel == 0 and resumed.stations[0].stock.alloys == 1 and resumed.crew_orders[crew_id].produced == 1)
	assert(orders.withdraw_station_stock(0, "alloys", 1).is_empty())
	var market_before := resumed.market_stock("alloys")
	assert(resumed.trade("alloys", 1, false).is_empty() and resumed.market_stock("alloys") == market_before + 1, "manufactured output reaches exchange supply")
	for system: int in [1, 4, 5, 6]:
		resumed.system_index = system
		resumed.stations[0].system = system
		resumed.stations[0].stock = {}
		var recipe := orders.station_recipe(0)
		for good: String in recipe.inputs: resumed.stations[0].stock[good] = int(recipe.inputs[good]) * 2
		resumed.crew_orders[crew_id].produced = 9223372036854775806
		report = orders.tick(900)
		assert(resumed.crew_orders[crew_id].produced == 9223372036854775807, "production statistics saturate without overflow")
		assert(report.size() == 1 and report[0].quantity == 2 and resumed.stations[0].stock[recipe.good] == 2)
		for good: String in recipe.inputs: assert(resumed.stations[0].stock[good] == 0, "all recipes consume every required input")
		resumed.stations[0].stock[recipe.good] = CrewOrders.MAX_STOCK
		for good: String in recipe.inputs: resumed.stations[0].stock[good] = int(recipe.inputs[good])
		var before: Dictionary = resumed.stations[0].stock.duplicate(true)
		report = orders.tick(900)
		assert(report[0].status == "storage full" and resumed.stations[0].stock == before, "full output storage does not consume inputs")
	resumed.cargo.ore = 5
	resumed.stations[0].stock.ore = CrewOrders.MAX_STOCK
	var saved := resumed._save_data().duplicate(true)
	assert(not orders.deposit_station_stock(0, "ore", 1).is_empty() and resumed._save_data() == saved)
	assert(not orders.deposit_station_stock(0, "ore", 0).is_empty() and not orders.deposit_station_stock(99, "ore", 1).is_empty())
	resumed.system_index = 99
	assert(not orders.deposit_station_stock(0, "ore", 1).is_empty(), "remote delivery rejected")
	await _scene()
	for file_path: String in [path, path + ".bak"]:
		if FileAccess.file_exists(file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	print("STATION_INDUSTRY_OK: shortages, input-limited batches, cargo services, saves and market delivery")
	quit()

func _scene() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.save_path = path
	assert(game.state.jump(1).is_empty())
	game._build_system()
	game.state.credits = 50000
	game.state.cargo.alloys = 20
	assert(game.state.build_station("Foundry").is_empty())
	game.state.cargo.ore = 10
	game.state.cargo.fuel = 10
	game.pilot.set_flight(true)
	assert(not game.supply_station_stock(0, "ore", 1).is_empty())
	game.pilot.set_flight(false)
	game.aboard = true
	assert(not game.supply_station_stock(0, "ore", 1).is_empty())
	game.aboard = false
	assert(not game.supply_station_stock(0, "ore", 1).is_empty(), "public concourse is not the owned station dock")
	assert(not game.collect_station_stock(0, "ore", 1).is_empty())
	game.rebuild_owned_stations()
	var station: Node3D = game._station_node(0)
	game.pilot.set_flight(true)
	game.pilot.teleport(station.to_global(station.launch_position))
	game.pilot.velocity = Vector3.ZERO
	game._interact()
	assert(game.docked_station == 0 and not game.pilot.flying, "cargo transfer requires actual owned-station docking")
	assert(game.supply_station_stock(0, "ore", 1).is_empty())
	assert(game.state.cargo.ore == 9 and game.state.stations[0].stock.ore == 1)
	game.state.stations[0].stock.alloys = 100
	game.open_menu("stations")
	await process_frame
	(game.deck.content.get_parent() as ScrollContainer).scroll_vertical = 10000
	await process_frame
	if DisplayServer.get_name() != "headless": await game._capture("station-industry")
	var room_left: int = int(game.state.ship_stats().cargo_capacity) - game.state.cargo_total()
	var loaded: bool = false
	for button: Node in game.deck.find_children("*", "Button", true, false):
		if str(button.text).ends_with("ALLOYS STORED"):
			button.pressed.emit()
			loaded = true
			break
	assert(loaded and game.state.cargo.alloys == room_left and game.state.stations[0].stock.alloys == 100 - room_left, "collection button fills available hold instead of requiring the entire stockpile to fit")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
