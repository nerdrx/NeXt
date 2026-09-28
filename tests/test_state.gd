extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	var state = GameStateScript.new()
	assert(state.credits == 18000 and state.system_index == 0)
	assert(state.hull == state.ship_stats().max_hull and state.shield == state.ship_stats().max_shield, "starter ship begins fully restored")
	assert(state.ship_stats().speed >= 135.0 and state.ship_stats().speed <= 145.0, "starter ship cruises at roughly 140 m/s")
	assert(state.ship_stats().cargo_capacity == 35 and state.ship_stats().power_balance >= 0)
	assert(state.ship_stats().crew_capacity == 2 and not state.ship_stats().walkable)
	assert(state._connected(state.ship_modules), "starter ship is connected")
	assert(state.world_id.length() == 32 and state._valid_world_id(state.world_id))
	state.cargo.ore = 35
	assert(state.trade("ore", 1, true) != "", "hold capacity is enforced")
	state.cargo.ore = 0
	var old_credits: int = state.credits
	assert(state.trade("ore", 2, true) == "")
	assert(state.cargo.ore == 2 and state.credits < old_credits)
	assert(state.trade("ore", 99, false) != "" and state.cargo.ore == 2)
	assert(state.trade("ore", 2, false) == "" and state.cargo.ore == 0)
	assert(state.trade("ore", -1, true) != "" and state.credits >= 0)
	assert(state.add_module("habitat", Vector3i(0, 0, 1)) == "That ship cell is occupied.")
	assert(state.add_module("cargo", Vector3i(-1, 0, 2)) == "")
	assert(state.remove_module(Vector3i(-1, 0, 2)) == "")
	assert(state.remove_module(Vector3i(0, 0, 1)) != "", "ship connectivity is preserved")
	assert(state.remove_module(Vector3i(1, 0, 0)) != "", "reactor is required")
	assert(state.add_module("habitat", Vector3i(17, 0, 0)) != "", "construction bounds match designer grid")
	assert(state.hire("engineer") == "")
	assert(state.hire("trader") == "")
	assert(state.dismiss_crew(0) == "" and state.crew.size() == 1)
	assert(state.hire("engineer") == "" and state.crew[0].id != state.crew[1].id)
	assert(state.dismiss_crew(99) != "")
	assert(state.hire("gunner") != "", "crew cap follows available rooms")
	assert(state.add_module("habitat", Vector3i(0, 0, 3)) == "")
	assert(state.ship_stats().walkable and state.ship_stats().crew_capacity == 6)
	assert(state.hire("gunner") == "")
	assert(state.jump(7919) == "" and state.day == 1 and state.visited.has(7919))
	assert(state.crew_paid and state.ship_stats().damage == 30, "paid gunner improves ship damage")
	var before_fuel: float = state.fuel
	state.fuel = 5
	assert(state.jump(1) != "" and state.system_index == 7919)
	state.fuel = before_fuel
	assert(state.refuel() == "")
	state.record_kill("pirate")
	assert(state.kills == 1)
	var police_kills: int = state.kills
	state.record_kill("police")
	assert(state.kills == police_kills and state.wanted == 1, "police kills never satisfy bounties")
	var bounty: Dictionary = {}
	for offer: Dictionary in state.contracts:
		if offer.kind == "bounty": bounty = offer
	assert(not bounty.is_empty())
	assert(state.accept_contract(bounty.id) == "")
	assert(state.claim_contract(bounty.id) != "", "police kill does not satisfy bounty")
	state.record_kill("pirate")
	assert(state.claim_contract(bounty.id) == "")
	assert(state.accept_contract(bounty.id) != "", "completed contract cannot be reaccepted")
	assert(state.trade_stock("nova", 2, true) == "")
	assert(state.trade_stock("NOVA", 2, false) == "")
	assert(state.found_company("Wayfarer") == "")
	assert(state.build_station("Farpoint") != "", "station requires alloys")
	state.cargo.alloys = 30
	assert(state.build_station("Farpoint") == "")
	assert(state.upgrade_station(0) == "")
	state.hull = 50
	assert(state.repair() == "")
	state.hull = 100
	var prior_treasury: int = state.company_balance
	assert(state.jump(8000) == "")
	assert(state.hull == 100.0 and state.company_balance > prior_treasury and state.credits > 0, "payroll and income settle on travel without unrequested field repairs")
	var company_funds: int = state.company_balance
	var personal_funds: int = state.credits
	assert(state.withdraw_company(company_funds + 1) != "" and state.company_balance == company_funds)
	assert(state.withdraw_company(0) != "")
	assert(state.withdraw_company(25) == "" and state.company_balance == company_funds - 25 and state.credits == personal_funds + 25)
	state.hull = 100
	var unpaid_treasury: int = state.company_balance
	state.credits = 0
	assert(state.jump(8001) == "")
	assert(not state.crew_paid and state.hull == 100.0 and state.company_balance == unpaid_treasury + 100, "unpaid crew have no role benefits")
	assert(state.location.is_empty(), "successful jump clears stale local-frame location")
	var path: String = "user://state-test-%d.json" % OS.get_process_id()
	state.shield = 72.5
	state.reputation["Solar Union"] = 12
	state.world_flags["7919"] = ["pirate-1", "pirate-2"]
	state.world_flags["8000:4"] = ["surface-actor"]
	state.location = {"system": state.system_index, "surface": -1, "address": SectorPosition.new(Vector3i(3, -2, 9), Vector3(12, 20, -40)).to_save(), "rotation": [0.1, -1.2, 2.9], "flying": true}
	assert(state.save(path) == "")
	state.credits += 1
	assert(state.save(path) == "", "existing save is atomically replaced")
	var loaded = GameStateScript.new()
	var load_error: String = loaded.load_save(path)
	assert(load_error == "", load_error)
	assert(loaded._save_data() == state._save_data(), "all persistent fields round-trip: %s | %s" % [loaded._save_data(), state._save_data()])
	state.location = {"system": state.system_index, "surface": 4, "address": SectorPosition.new(Vector3i(7, 2, -1), Vector3(18, 5, 26)).to_save(), "ship_address": SectorPosition.new(Vector3i(7, 2, -1), Vector3(20, 0, 32)).to_save(), "rotation": [0.0, 0.5, 0.0], "flying": false}
	assert(state.save(path) == "")
	assert(loaded.load_save(path) == "" and loaded.location.ship_address == state.location.ship_address, "grounded planetary ship address round-trips")
	var prior_ground_location: Dictionary = loaded.location.duplicate(true)
	var bad_ship_location: Dictionary = state._save_data().duplicate(true)
	var bad_ship_file: FileAccess
	bad_ship_location.location.ship_address = {"version": 1, "sector": [2147483648, 0, 0], "local": [0, 0, 0]}
	bad_ship_file = FileAccess.open(path, FileAccess.WRITE)
	bad_ship_file.store_string(JSON.stringify(bad_ship_location))
	bad_ship_file.close()
	assert(loaded.load_save(path) != "" and loaded.location == prior_ground_location, "malformed ship address is rejected transactionally")
	bad_ship_location = state._save_data().duplicate(true)
	bad_ship_location.location.surface = -1
	bad_ship_file = FileAccess.open(path, FileAccess.WRITE)
	bad_ship_file.store_string(JSON.stringify(bad_ship_location))
	bad_ship_file.close()
	assert(loaded.load_save(path) != "" and loaded.location == prior_ground_location, "planetary ship address is rejected in orbit")
	bad_ship_location = state._save_data().duplicate(true)
	bad_ship_location.location.flying = true
	bad_ship_file = FileAccess.open(path, FileAccess.WRITE)
	bad_ship_file.store_string(JSON.stringify(bad_ship_location))
	bad_ship_file.close()
	assert(loaded.load_save(path) != "" and loaded.location == prior_ground_location, "planetary ship address is rejected for a flying save")
	var station_data: Dictionary = state._save_data().duplicate(true)
	station_data.stations[0].system = state.system_index
	station_data.location = {"system": state.system_index, "surface": -1, "station_index": 0, "address": SectorPosition.new(Vector3i(1, 2, 3), Vector3(4, 5, 6)).to_save(), "rotation": [0.0, 0.25, 0.0], "flying": false}
	var station_file := FileAccess.open(path, FileAccess.WRITE)
	station_file.store_string(JSON.stringify(station_data))
	station_file.close()
	assert(loaded.load_save(path) == "" and loaded.location.station_index == 0, "owned station walking location round-trips")
	var loaded_station_state: Dictionary = loaded._save_data().duplicate(true)
	var bad_station_location: Dictionary = station_data.duplicate(true)
	var bad_station_file: FileAccess
	for invalid_index: Variant in [0.5, 256, 1]:
		bad_station_location = station_data.duplicate(true)
		bad_station_location.location.station_index = invalid_index
		bad_station_file = FileAccess.open(path, FileAccess.WRITE)
		bad_station_file.store_string(JSON.stringify(bad_station_location))
		bad_station_file.close()
		assert(loaded.load_save(path) != "" and loaded._save_data() == loaded_station_state, "invalid station index is rejected transactionally")
	for conflict: String in ["flying", "surface", "ship_address"]:
		bad_station_location = station_data.duplicate(true)
		match conflict:
			"flying": bad_station_location.location.flying = true
			"surface": bad_station_location.location.surface = 0
			"ship_address": bad_station_location.location.ship_address = station_data.location.address
		bad_station_file = FileAccess.open(path, FileAccess.WRITE)
		bad_station_file.store_string(JSON.stringify(bad_station_location))
		bad_station_file.close()
		assert(loaded.load_save(path) != "" and loaded._save_data() == loaded_station_state, "contradictory station location is rejected transactionally")
	var old_v2: Dictionary = state._save_data().duplicate(true)
	old_v2.erase("world_id")
	old_v2.erase("location")
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string(JSON.stringify(old_v2))
	bad.close()
	assert(loaded.load_save(path) == "" and loaded._valid_world_id(loaded.world_id) and loaded.world_id != state.world_id and loaded.location.is_empty(), "older saves without identity or local location migrate")
	var invalid_location: Dictionary = state._save_data().duplicate(true)
	invalid_location.location.system = state.system_index + 1
	bad = FileAccess.open(path, FileAccess.WRITE)
	bad.store_string(JSON.stringify(invalid_location))
	bad.close()
	assert(loaded.load_save(path) != "" and loaded.location.is_empty(), "malformed saved location is rejected transactionally")
	var invalid_world: Dictionary = state._save_data().duplicate(true)
	invalid_world.world_id = "NOT-A-VALID-WORLD-ID"
	bad = FileAccess.open(path, FileAccess.WRITE)
	bad.store_string(JSON.stringify(invalid_world))
	bad.close()
	var migrated_world_id: String = loaded.world_id
	assert(loaded.load_save(path) != "" and loaded.world_id == migrated_world_id, "invalid world identity is rejected without mutation")
	var prior_credits: int = loaded.credits
	bad = FileAccess.open(path, FileAccess.WRITE)
	bad.store_string("{\"version\":2,\"credits\":\"bad\"}")
	bad.close()
	assert(loaded.load_save(path) != "" and loaded.credits == prior_credits, "malformed load is transactional")
	var invalid_key_data: Dictionary = state._save_data().duplicate(true)
	invalid_key_data.world_flags["8001:9"] = ["invalid-surface"]
	bad = FileAccess.open(path, FileAccess.WRITE)
	bad.store_string(JSON.stringify(invalid_key_data))
	bad.close()
	assert(loaded.load_save(path) != "" and loaded.credits == prior_credits, "invalid world key does not mutate state")
	var legacy_path: String = "user://state-test-v1-%d.json" % OS.get_process_id()
	var legacy := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 1, "system": 42, "credits": 900, "modules": 8, "hull": 75, "kills": 3, "cargo": {"Food": 2}}))
	legacy.close()
	var migrated = GameStateScript.new()
	var migration_error: String = migrated.load_save(legacy_path)
	assert(migration_error == "", migration_error)
	assert(migrated.system_index == 42 and migrated.cargo.food == 2 and migrated.visited.has(42) and migrated.ship_modules.size() == 15 and migrated._valid_world_id(migrated.world_id))
	var migrated_v2_path: String = legacy_path + ".v2"
	assert(migrated.save(migrated_v2_path) == "")
	var migrated_roundtrip = GameStateScript.new()
	assert(migrated_roundtrip.load_save(migrated_v2_path) == "" and migrated_roundtrip.ship_modules.size() == 15, "eight legacy modules survive v2 migration")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(migrated_v2_path))
	print("GameState tests passed")
	quit()
