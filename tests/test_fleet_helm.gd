extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")
const ShipBlueprintScript = preload("res://scripts/ship_blueprint.gd")

var save_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	save_path = "user://fleet-helm-%d.json" % OS.get_process_id()
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".tmp"):
		_fail("unique test save path already exists")
		return
	var state := GameStateScript.new()
	state.credits = 100000
	assert(state.add_module("habitat", Vector3i(0, 0, 3)).is_empty(), "custom helm design has a habitat")
	assert(state.ship_layout.rooms.size() == 0, "starter layout begins empty")
	state.ship_layout.rooms["0,0,3"] = "medical"
	state.ship_layout.panels["0,0,0"] = {"-z": "armored"}
	state.ship_identity = {"id": "commander-helm-01", "name": "My Custom Ship"}
	state.cargo.ore = 3
	state.cargo.alloys = 2
	state.hull = float(state.ship_stats().max_hull) * 0.61
	state.shield = float(state.ship_stats().max_shield) * 0.34
	state.fuel = 27.5
	state.drive_temperature_k = 641.0
	state.company_name = "Kepler Works"
	state.recovery.insurance_until_day = state.day + 19
	state.recovery.debt = 234
	assert(state.hire("engineer").is_empty(), "crew stays with commander during the exchange")
	var modules_before: Array[Dictionary] = state.ship_modules.duplicate(true)
	var layout_before: Dictionary = state.ship_layout.duplicate(true)
	var cargo_before: Dictionary = state.cargo.duplicate(true)
	var hull_ratio := state.hull / float(state.ship_stats().max_hull)
	var shield_before := state.shield
	var fuel_before := state.fuel
	var temperature_before := state.drive_temperature_k
	var crew_before: Array[Dictionary] = state.crew.duplicate(true)
	var recovery_before: Dictionary = state.recovery.duplicate(true)
	var orders := CrewOrdersScript.new(state)
	assert(orders.purchase_ship("Pathfinder One", "pathfinder").is_empty(), "commissioned family vessel is available for exchange")
	var incoming: Dictionary = state.fleet_ships.back()
	var incoming_id := str(incoming.id)
	incoming.hull = 73.0
	incoming.cargo = {"ore": 4, "food": 2}
	incoming.fuel = 82.0
	incoming.drive_temperature_k = 418.0
	var incoming_model := GameStateScript.new()
	incoming_model.ship_modules.assign(ShipBlueprintScript.family("pathfinder").modules)
	var incoming_stats: Dictionary = incoming_model.ship_stats()
	incoming.defense = {"charge": float(incoming_stats.max_shield) * 0.28, "delay": 3.25}
	var incoming_modules: Array[Dictionary] = incoming_model.ship_modules.duplicate(true)
	var incoming_layout: Dictionary = ShipBlueprintScript.family("pathfinder").layout.duplicate(true)
	var incoming_cargo: Dictionary = incoming.cargo.duplicate(true)
	var fleet_count := state.fleet_ships.size()
	var credits_before := state.credits

	assert(orders.exchange_helm(incoming_id, 1.75).is_empty(), "local idle family ship accepts helm exchange")
	assert(state.fleet_ships.size() == fleet_count and state.credits == credits_before, "exchange replaces one fleet slot without buying or dropping a vessel")
	var stored_custom := _ship_by_id(state.fleet_ships, "commander-helm-01")
	assert(not stored_custom.is_empty() and stored_custom.name == "My Custom Ship", "outgoing identity moves to the fleet record")
	assert(stored_custom.modules == modules_before and _layout_matches(stored_custom.layout, layout_before), "outgoing custom design and layout are preserved")
	assert(stored_custom.cargo == cargo_before and is_equal_approx(float(stored_custom.hull) / 100.0, hull_ratio), "outgoing cargo and hull fraction are preserved")
	assert(is_equal_approx(stored_custom.defense.charge, shield_before) and is_equal_approx(stored_custom.defense.delay, 1.75), "outgoing shield charge and recovery delay are preserved")
	assert(stored_custom.fuel == fuel_before and stored_custom.drive_temperature_k == temperature_before, "outgoing fuel and drive temperature are preserved")
	assert(state.ship_identity == {"id": incoming_id, "name": "Pathfinder One"}, "incoming fleet identity becomes the helm")
	assert(state.ship_modules == incoming_modules and _layout_matches(state.ship_layout, incoming_layout), "incoming family blueprint becomes the player design")
	assert(state.cargo == incoming_cargo and is_equal_approx(state.hull / float(state.ship_stats().max_hull), 0.73), "incoming cargo and hull condition become active")
	assert(is_equal_approx(state.shield, float(incoming.defense.charge)) and state.fuel == 82.0 and state.drive_temperature_k == 418.0, "incoming shield, fuel, and temperature are restored")
	assert(state.crew == crew_before and state.company_name == "Kepler Works" and state.recovery == recovery_before, "commander crew, company, and recovery policy remain in place")

	assert(state.save(save_path).is_empty(), "exchanged helm saves")
	assert(state.load_save(save_path).is_empty(), "exchanged helm reloads")
	var restored_custom := _ship_by_id(state.fleet_ships, "commander-helm-01")
	assert(not restored_custom.is_empty() and restored_custom.modules == modules_before and restored_custom.cargo == cargo_before, "stored custom hull reloads with identity, design, and cargo")
	assert(is_equal_approx(float(restored_custom.hull) / 100.0, hull_ratio) and is_equal_approx(restored_custom.defense.charge, shield_before), "stored custom hull reloads condition and shields")
	assert(restored_custom.fuel == fuel_before and restored_custom.drive_temperature_k == temperature_before and restored_custom.defense.delay == 1.75, "stored custom hull reloads fuel, heat, and shield delay")

	var returned_custom_modules := state.ship_modules.duplicate(true)
	var returned_custom_layout := state.ship_layout.duplicate(true)
	var incoming_hull_ratio := state.hull / float(state.ship_stats().max_hull)
	var incoming_shield := state.shield
	var incoming_fuel := state.fuel
	var incoming_temperature := state.drive_temperature_k
	var incoming_player_cargo := state.cargo.duplicate(true)
	assert(orders.exchange_helm("commander-helm-01", 0.5).is_empty(), "taking the stored custom vessel back succeeds")
	assert(state.ship_identity == {"id": "commander-helm-01", "name": "My Custom Ship"}, "second exchange restores the original identity")
	assert(state.ship_modules == modules_before and _layout_matches(state.ship_layout, layout_before), "second exchange restores custom modules and layout")
	assert(state.cargo == cargo_before and is_equal_approx(state.hull / float(state.ship_stats().max_hull), hull_ratio), "second exchange conserves personal cargo and hull condition")
	assert(is_equal_approx(state.shield, shield_before) and state.fuel == fuel_before and state.drive_temperature_k == temperature_before, "second exchange restores custom shield, fuel, and temperature")
	var stored_family := _ship_by_id(state.fleet_ships, incoming_id)
	assert(stored_family.modules == incoming_modules and stored_family.cargo == incoming_player_cargo, "outgoing family vessel retains its design and hold")
	assert(is_equal_approx(float(stored_family.hull) / 100.0, incoming_hull_ratio) and is_equal_approx(stored_family.defense.charge, incoming_shield), "outgoing family hull and shield condition are conserved")
	assert(stored_family.fuel == incoming_fuel and stored_family.drive_temperature_k == incoming_temperature and stored_family.defense.delay == 0.5, "outgoing family fuel, heat, and shield delay are conserved")
	assert(stored_family.modules == returned_custom_modules and _layout_matches(stored_family.layout, returned_custom_layout), "outgoing family design and layout remain saved in the fleet")
	assert(state.crew == crew_before and state.recovery == recovery_before, "second exchange keeps commander-level records")

	# Exchange replaces a selected slot, so a full fleet remains at its limit.
	for index: int in range(49):
		state.fleet_ships.append({"id": "filler-%02d" % index, "name": "Filler %02d" % index, "system": state.system_index, "hull": 100.0, "cargo": {}, "capacity": 25})
	assert(state.fleet_ships.size() == 50 and orders.exchange_helm(incoming_id, 0.0).is_empty(), "helm exchange succeeds at the fleet limit")
	assert(state.fleet_ships.size() == 50, "full-fleet exchange does not change fleet size")

	# Failed selections and invalid outgoing conditions must leave all state untouched.
	var active_id := str(state.ship_identity.id)
	var target_id := "commander-helm-01"
	var active_modules_before_guards: Array[Dictionary] = state.ship_modules.duplicate(true)
	var active_hull_before_guards: float = state.hull
	var legacy: Dictionary = {"id": "legacy-helm", "name": "Legacy Hull", "system": state.system_index, "hull": 100.0, "cargo": {}, "capacity": 25}
	state.fleet_ships.append(legacy)
	_expect_reject(state, orders, "legacy-helm", "legacy fleet hull has no saved pilotable blueprint")
	state.fleet_ships.pop_back()
	var selected := _ship_by_id(state.fleet_ships, target_id)
	selected.system = (state.system_index + 1) % GameStateScript.SYSTEM_LIMIT
	_expect_reject(state, orders, target_id, "remote fleet ship")
	selected.system = state.system_index
	selected.hull = 0.0
	_expect_reject(state, orders, target_id, "destroyed fleet ship")
	selected.hull = 100.0
	selected.flight = {"phase": "outbound"}
	_expect_reject(state, orders, target_id, "fleet ship already in flight")
	selected.erase("flight")
	orders.occupied_ship_id = target_id
	_expect_reject(state, orders, target_id, "fleet ship occupied")
	orders.occupied_ship_id = ""
	state.crew_orders = {"dummy-crew": {"ship_id": target_id}}
	_expect_reject(state, orders, target_id, "fleet ship has an active order")
	state.crew_orders.clear()
	state.ship_modules[0].kind = "unknown"
	_expect_reject(state, orders, target_id, "current player blueprint is invalid")
	state.ship_modules = active_modules_before_guards.duplicate(true)
	state.hull = 0.0
	_expect_reject(state, orders, target_id, "current player hull is destroyed")
	state.hull = active_hull_before_guards
	var incoming_capacity := int(CrewOrdersScript.vessel_combat_stats(selected).crew_capacity)
	state.crew.resize(incoming_capacity + 1)
	_expect_reject(state, orders, target_id, "incoming vessel cannot fit crew")
	state.crew = crew_before.duplicate(true)
	assert(not active_id.is_empty(), "active identity remains valid during rejection cases")

	# A crew defense order cannot be left assigned to a ship without weapons.
	state.fleet_ships.pop_back()
	state.ship_modules = modules_before.duplicate(true)
	assert(state.remove_module(Vector3i(1, 0, 1)).is_empty(), "weapon can be removed for an unarmed custom design")
	assert(orders.purchase_custom_ship("Unarmed Copy").is_empty(), "unarmed custom fleet design is commissioned")
	var unarmed_id: String = str(state.fleet_ships.back().id)
	state.ship_modules = active_modules_before_guards.duplicate(true)
	state.crew_orders = {"crew-defender": {"kind": "defend", "crew_id": "crew-defender", "progress": 0.0, "paused": false}}
	_expect_reject(state, orders, unarmed_id, "unarmed incoming ship with a defense crew order")
	state.crew_orders.clear()

	# Schema additions stay optional for older saves and strict when present.
	assert(state.save(save_path).is_empty(), "valid helm state saves before schema checks")
	var loaded := GameStateScript.new()
	assert(loaded.load_save(save_path).is_empty(), "valid helm state reloads before schema checks")
	var stable: Dictionary = loaded._save_data().duplicate(true)
	var bad: Dictionary = stable.duplicate(true)
	bad.fleet_ships[0].fuel = -1.0
	_write_save(bad)
	assert(not loaded.load_save(save_path).is_empty() and loaded._save_data() == stable, "negative optional fleet fuel is rejected transactionally")
	bad = stable.duplicate(true)
	bad.fleet_ships[0].fuel = 101.0
	_write_save(bad)
	assert(not loaded.load_save(save_path).is_empty() and loaded._save_data() == stable, "overfull optional fleet fuel is rejected transactionally")
	bad = stable.duplicate(true)
	bad.ship_identity.extra = true
	_write_save(bad)
	assert(not loaded.load_save(save_path).is_empty() and loaded._save_data() == stable, "unknown commander identity field is rejected transactionally")
	bad = stable.duplicate(true)
	bad.ship_identity.id = str(bad.fleet_ships[0].id)
	_write_save(bad)
	assert(not loaded.load_save(save_path).is_empty() and loaded._save_data() == stable, "commander identity collision with fleet ID is rejected transactionally")
	bad = stable.duplicate(true)
	bad.erase("ship_identity")
	for vessel: Dictionary in bad.fleet_ships: vessel.erase("fuel")
	_write_save(bad)
	assert(loaded.load_save(save_path).is_empty(), "older save without ship identity or fleet fuel migrates")
	assert(loaded.ship_identity.has_all(["id", "name"]) and not loaded.ship_identity.id.is_empty(), "missing commander identity receives a valid default")
	for vessel: Dictionary in loaded.fleet_ships: assert(vessel.get("fuel", 100.0) == 100.0, "missing fleet fuel defaults to full")

	_cleanup()
	print("FLEET_HELM_OK: reversible exchange, full fleet, conditions, crew, and save migration")
	quit()


func _ship_by_id(ships: Array[Dictionary], id: String) -> Dictionary:
	for ship: Dictionary in ships:
		if str(ship.id) == id: return ship
	return {}


func _expect_reject(state: GameState, orders: CrewOrders, ship_id: String, reason: String) -> void:
	var before: Dictionary = state._save_data().duplicate(true)
	assert(not orders.exchange_helm(ship_id, 1.25).is_empty(), reason + " rejects exchange")
	assert(state._save_data() == before, reason + " leaves all commander and fleet data unchanged")


func _layout_matches(actual: Dictionary, expected: Dictionary) -> bool:
	return int(actual.get("version", -1)) == 1 and actual.get("rooms", {}) == expected.get("rooms", {}) and actual.get("panels", {}) == expected.get("panels", {})


func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	assert(file != null, "test save can be written")
	file.store_string(JSON.stringify(data))
	file.close()


func _cleanup() -> void:
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	push_error("FLEET_HELM_FAILED: " + message)
	quit(1)
