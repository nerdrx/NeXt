extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const PlayerFactionScript = preload("res://scripts/player_faction.gd")
const UniverseScript = preload("res://scripts/universe.gd")


func _initialize() -> void:
	var state = GameStateScript.new()
	var start_credits: int = state.credits
	_check(PlayerFactionScript.validate_data(state.faction, 0), "empty faction schema")
	_check(state.found_faction(" ") != "" and state.credits == start_credits, "reject empty name without charge")
	_check(state.faction_deposit(1) != "" and state.set_diplomatic_stance("Solar Union", "friendly") != "", "require founding before treasury actions")
	state.credits = PlayerFactionScript.FOUNDING_COST - 1
	var before := state._save_data().duplicate(true)
	_check(state.found_faction("Wayfarers") != "" and state._save_data() == before, "insufficient founding credits do not mutate state")
	state.credits = start_credits
	_check(state.found_faction("The Wayfarers") == "", "found named faction")
	_check(state.credits == start_credits - 10000 and state.faction.treasury == 0, "founding debits personal wallet")
	_check(state.found_faction("Second Faction") != "" and state.credits == start_credits - 10000, "only one player faction")
	_check(state.faction_deposit(0) != "" and state.faction.treasury == 0, "reject zero deposit")
	_check(state.faction_deposit(8001) != "" and state.credits == 8000, "reject deposit beyond wallet")
	_check(state.faction_deposit(5000) == "", "deposit into treasury")
	_check(state.credits == 3000 and state.faction.treasury == 5000, "deposit transfers funds without creation")
	_check(state.faction_withdraw(5001) != "" and state.faction.treasury == 5000 and state.credits == 3000, "reject overdraw without mutation")
	_check(state.faction_withdraw(0) != "" and state.faction.treasury == 5000, "reject zero withdrawal")
	_check(state.faction_withdraw(1000) == "" and state.faction.treasury == 4000 and state.credits == 4000, "withdrawal transfers funds without creation")
	_check(state.faction_withdraw(3500) == "" and state.faction.treasury == 500 and state.credits == 7500, "withdrawal can fund personal purchases")
	state.stations.append({"name": "Farpoint", "system": 24, "level": 1})
	_check(state.claim_station_faction(-1) != "" and state.faction.treasury == 500, "reject invalid station index")
	_check(state.claim_station_faction(0) != "" and state.faction.treasury == 500, "station claim requires treasury funds")
	_check(state.faction_deposit(1000) == "", "fund station claim")
	_check(state.claim_station_faction(0) == "", "claim owned station")
	_check(state.faction.treasury == 500 and state.station_affiliation(0) == "The Wayfarers", "claim debits treasury and sets affiliation")
	_check(state.station_affiliation(44) == "Independent operator", "unclaimed station stays independently operated")
	_check(state.claim_station_faction(0) != "" and state.faction.treasury == 500, "duplicate claim is not charged twice")
	_check(state.set_diplomatic_stance("Not a faction", "friendly") != "" and state.faction.treasury == 500, "reject unknown diplomatic faction")
	_check(state.set_diplomatic_stance("Solar Union", "allied") != "" and state.faction.treasury == 500, "reject unknown stance")
	_check(state.set_diplomatic_stance("Solar Union", "friendly") == "", "purchase friendly diplomacy")
	_check(state.faction.treasury == 0 and state.diplomatic_stance("Solar Union") == "friendly", "diplomacy costs treasury credits")
	var after_friendly: int = int(state.faction.treasury)
	_check(state.set_diplomatic_stance("Solar Union", "friendly") == "" and state.faction.treasury == after_friendly, "same stance costs nothing twice")
	_check(state.faction_trade_multiplier("Solar Union", true) == 0.95 and state.faction_trade_multiplier("Solar Union", false) == 1.05, "friendly trade terms apply to purchases and sales")
	_check(not state.police_hostile(), "friendly local faction does not trigger police hostility")
	_check(state.faction_deposit(500) == "", "fund second diplomatic change")
	state.wanted = 1
	_check(state.police_hostile(), "wanted status keeps local police hostile")
	state.wanted = 0
	var matching_system := 0
	for system_index: int in range(100):
		if UniverseScript.system_data(system_index).faction == "Solar Union":
			matching_system = system_index
			break
	state.system_index = matching_system
	if not state.visited.has(matching_system): state.visited.append(matching_system)
	var neutral_buy: int = PlayerFactionScript.trade_multiplier(PlayerFactionScript.empty_data(), "Solar Union", true) as float * state.price("ore")
	_check(state.trade_quote("ore", true) <= neutral_buy, "friendly stance changes real trade quote")
	var friendly_sale: int = state.trade_quote("ore", false)
	state.cargo.ore = 1
	var wallet_before_sale: int = state.credits
	_check(state.trade("ore", 1, false) == "" and state.credits == wallet_before_sale + friendly_sale, "trade settles at displayed faction-adjusted quote")
	_check(state.set_diplomatic_stance("Solar Union", "hostile") == "", "set hostile diplomacy")
	_check(state.faction.treasury == 0 and state.diplomatic_stance("Solar Union") == "hostile", "hostile stance costs treasury")
	_check(state.faction_trade_multiplier("Solar Union", true) == 1.15 and state.faction_trade_multiplier("Solar Union", false) == 0.85, "hostile trade terms apply")
	_check(state.police_hostile(), "hostile stance makes local police hostile")
	_check(state.trade_quote("ore", true) > neutral_buy and state.trade_quote("ore", false) < friendly_sale, "hostility worsens real trade quotes")
	var unchanged := state._save_data().duplicate(true)
	var invalid: Dictionary = state.faction.duplicate(true)
	invalid.treasury = -1
	_check(not PlayerFactionScript.validate_data(invalid, state.stations.size()), "reject negative treasury")
	invalid = state.faction.duplicate(true)
	invalid.claimed_stations = [0, 0]
	_check(not PlayerFactionScript.validate_data(invalid, state.stations.size()), "reject duplicate station claim")
	invalid = state.faction.duplicate(true)
	invalid.claimed_stations = [1]
	_check(not PlayerFactionScript.validate_data(invalid, state.stations.size()), "reject nonexistent station claim")
	invalid = state.faction.duplicate(true)
	invalid.diplomacy["Solar Union"] = "unrecognized"
	_check(not PlayerFactionScript.validate_data(invalid, state.stations.size()), "reject invalid saved stance")
	invalid = state.faction.duplicate(true)
	invalid.extra = true
	_check(not PlayerFactionScript.validate_data(invalid, state.stations.size()), "reject unknown faction fields")
	_check(unchanged == state._save_data(), "validation checks do not mutate state")
	_roundtrip_and_migrations(state)
	if _failures == 0:
		print("FACTION_TEST_OK: founding, treasury, station claims, diplomacy, trade, police, save migration")
		quit()
	else:
		quit(1)


var _failures: int = 0


func _roundtrip_and_migrations(state: GameState) -> void:
	var path := "user://faction-test-%d.json" % OS.get_process_id()
	_check(state.save(path) == "", "save faction state")
	var loaded = GameStateScript.new()
	var roundtrip_error: String = loaded.load_save(path)
	_check(roundtrip_error == "" and loaded._save_data() == state._save_data(), "faction save round-trip: %s" % roundtrip_error)
	var path_file := FileAccess.open(path, FileAccess.READ)
	var full_data: Dictionary = JSON.parse_string(path_file.get_as_text())
	path_file.close()
	var old_v3: Dictionary = full_data.duplicate(true)
	old_v3.erase("faction")
	var old_v3_error := _load_data(loaded, old_v3, path + ".v3")
	_check(old_v3_error == "" and loaded.faction == PlayerFactionScript.empty_data(), "migrate previous v3 without faction field: %s" % old_v3_error)
	var old_v2: Dictionary = full_data.duplicate(true)
	old_v2.version = 2
	for field: String in ["fleet_ships", "crew_orders", "recovery", "ship_layout", "faction"]: old_v2.erase(field)
	var old_v2_error := _load_data(loaded, old_v2, path + ".v2")
	_check(old_v2_error == "" and loaded.faction == PlayerFactionScript.empty_data(), "migrate v2 into an empty faction: %s" % old_v2_error)
	var v2_with_optional_faction: Dictionary = full_data.duplicate(true)
	v2_with_optional_faction.version = 2
	for field: String in ["fleet_ships", "crew_orders", "recovery", "ship_layout"]: v2_with_optional_faction.erase(field)
	var v2_faction_error := _load_data(loaded, v2_with_optional_faction, path + ".v2f")
	_check(v2_faction_error == "" and loaded.faction == state.faction, "accept valid optional faction in transitional v2 save: %s" % v2_faction_error)
	var before: Dictionary = loaded._save_data().duplicate(true)
	var invalid: Dictionary = full_data.duplicate(true)
	invalid.faction.diplomacy["Unknown"] = "friendly"
	_check(_load_data(loaded, invalid, path + ".bad") != "" and loaded._save_data() == before, "reject malformed faction save transactionally")
	for suffix: String in ["", ".v3", ".v2", ".v2f", ".bad"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _load_data(state: GameState, data: Dictionary, path: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	return state.load_save(path)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FACTION_TEST_FAILED: " + message)
