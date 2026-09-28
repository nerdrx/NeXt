extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

func _initialize() -> void:
	_test_transfer_and_save()
	_test_capacity_rejections()
	_test_state_rejections()
	print("Fleet cargo transfer tests passed")
	quit()

func _test_transfer_and_save() -> void:
	var state := _state()
	var orders := CrewOrdersScript.new(state)
	state.cargo.ore = 8
	var credits_before: int = state.credits
	var market_before: Dictionary = state.market_stocks.duplicate(true)
	assert(orders.transfer_fleet_cargo("ship-test", "ORE", 5, true).is_empty())
	assert(state.cargo.ore == 3 and state.fleet_ships[0].cargo.ore == 5, "player cargo transfers to fleet")
	assert(orders.transfer_fleet_cargo("ship-test", "ore", 2, false).is_empty())
	assert(state.cargo.ore == 5 and state.fleet_ships[0].cargo.ore == 3, "fleet cargo transfers to player")
	assert(state.credits == credits_before and state.market_stocks == market_before, "cargo transfer does not change credits or market state")
	var path := "user://fleet-cargo-transfer-%d.json" % Time.get_ticks_usec()
	var absolute_path: String = ProjectSettings.globalize_path(path)
	assert(not FileAccess.file_exists(absolute_path), "save path is unique")
	assert(state.save(path).is_empty(), "transferred cargo saves")
	assert(FileAccess.file_exists(absolute_path), "save file exists")
	var loaded = GameStateScript.new()
	assert(loaded.load_save(path).is_empty(), "transferred cargo reloads")
	assert(loaded.cargo.ore == 5 and loaded.fleet_ships[0].cargo.ore == 3, "both holds retain transferred cargo")
	DirAccess.remove_absolute(absolute_path)
	DirAccess.remove_absolute(absolute_path + ".bak")

func _test_capacity_rejections() -> void:
	var state := _state()
	var orders := CrewOrdersScript.new(state)
	var ship: Dictionary = state.fleet_ships[0]
	state.cargo.ore = 4
	ship.cargo.ore = 4
	var before := state._save_data().duplicate(true)
	assert(not orders.transfer_fleet_cargo("ship-test", "ore", 2, true).is_empty(), "fleet capacity enforced")
	assert(state._save_data() == before, "fleet capacity rejection is atomic")
	ship.cargo.ore = 2
	state.cargo.ore = int(state.ship_stats().cargo_capacity) - 1
	before = state._save_data().duplicate(true)
	assert(not orders.transfer_fleet_cargo("ship-test", "ore", 2, false).is_empty(), "personal capacity enforced")
	assert(state._save_data() == before, "personal capacity rejection is atomic")

func _test_state_rejections() -> void:
	var state := _state()
	var orders := CrewOrdersScript.new(state)
	state.cargo.ore = 4
	var before := state._save_data().duplicate(true)
	for args: Array in [["missing", "ore", 1, true], ["ship-test", "bad", 1, true], ["ship-test", "ore", 0, true], ["ship-test", "ore", -1, true], ["ship-test", "ore", 5, true], ["ship-test", "ore", 1, false]]:
		assert(not orders.transfer_fleet_cargo(args[0], args[1], args[2], args[3]).is_empty())
		assert(state._save_data() == before, "invalid request leaves all state unchanged")
	var ship: Dictionary = state.fleet_ships[0]
	for condition: String in ["remote", "destroyed", "busy", "flight", "occupied"]:
		match condition:
			"remote": ship.system = state.system_index + 1
			"destroyed": ship.hull = 0.0
			"busy": state.crew_orders = {"crew-test": {"kind": "patrol", "ship_id": "ship-test"}}
			"flight": ship.flight = {}
			"occupied": orders.occupied_ship_id = "ship-test"
		before = state._save_data().duplicate(true)
		assert(not orders.transfer_fleet_cargo("ship-test", "ore", 1, true).is_empty(), "%s vessel rejected" % condition)
		assert(state._save_data() == before, "%s rejection is atomic" % condition)
		ship.system = state.system_index
		ship.hull = 100.0
		ship.erase("flight")
		state.crew_orders.clear()
		orders.occupied_ship_id = ""

func _state() -> GameState:
	var state := GameStateScript.new()
	state.fleet_ships = [{"id": "ship-test", "name": "Test Mule", "system": state.system_index, "hull": 100.0, "cargo": {"ore": 0}, "capacity": 5}]
	return state
