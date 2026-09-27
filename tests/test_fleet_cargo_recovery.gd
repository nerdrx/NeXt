extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const Recovery = preload("res://scripts/ship_recovery.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")


func _initialize() -> void:
	_test_abandon_and_recover()
	_test_rejections_are_atomic()
	_test_registry_capacity()
	print("Fleet cargo recovery tests passed")
	quit()


func _test_abandon_and_recover() -> void:
	var state := _state_with_fleet_cargo()
	state.credits = 3210
	state.hull = 47.0
	var credits_before: int = state.credits
	var hull_before: float = state.hull
	var origin := SectorPosition.new(Vector3i(4, 0, 0), Vector3.ZERO)
	var result: Dictionary = Recovery.abandon_fleet_cargo(state, "ship-test", Vector3(12, 4, -8), origin.to_save())
	assert(result.get("ok", false), "disabled local fleet cargo can be abandoned")
	assert(state.credits == credits_before and state.hull == hull_before, "cargo abandonment does not charge or repair player ship")
	assert(state.fleet_ships[0].cargo.is_empty(), "cargo moves out of disabled ship")
	assert(not state.fleet_ships[0].has("flight"), "abandoned vessel flight is cleared")
	assert(state.crew_orders.trader_test.purchase_cost == 0, "trade invoice resets when cargo is abandoned")
	var wreck_id: String = str(result.get("wreck_id", ""))
	var wreck: Dictionary = _wreck(state, wreck_id)
	assert(not wreck.is_empty(), "cargo recovery record is created")
	assert(wreck.modules.is_empty() and wreck.salvaged and wreck.salvage_value == 0, "cargo-only wreck has no hull or salvage payout")
	assert(wreck.cargo.food == 5 and wreck.cargo.ore == 2 and Recovery.validate_data(state.recovery), "wreck stores complete cargo in valid schema")
	assert(not Recovery.abandon_fleet_cargo(state, "ship-test", Vector3(12, 4, -8), origin.to_save()).ok, "empty ship cannot create a duplicate cargo wreck")
	assert(CrewOrdersScript.new(state).repair_fleet_ship("ship-test").is_empty(), "disabled cargo ship can be repaired")
	var reports: Array = CrewOrdersScript.new(state).tick(CrewOrdersScript.TRIP_SECONDS * 2.0, [], {"ship-test": true})
	assert(reports.size() == 1 and reports[0].status == "no cargo to sell" and int(state.stations[0].get("stock", {}).get("food", 0)) == 0, "repaired trade route cannot deliver cargo that was abandoned")

	# Rebase from the wreck's saved absolute address and recover cargo in stages.
	var moved_origin := origin.clone()
	assert(moved_origin.move_delta(Vector3(5, 0, 0)))
	var moved_position: Variant = Recovery.wreck_relative(wreck, moved_origin.to_save())
	assert(moved_position == Vector3(7, 4, -8), "cargo wreck follows its address through origin shifts")
	state.cargo.ore = int(state.ship_stats().cargo_capacity) - 1
	var credits_at_recovery: int = state.credits
	assert(Recovery.recover_cargo(state, wreck_id, -1, moved_position, 80.0, moved_origin.to_save()).is_empty(), "cargo recovery supports partial capacity")
	assert(state.cargo.ore == int(state.ship_stats().cargo_capacity) and not wreck.cargo_recovered, "first recovery moves only available capacity")
	state.cargo.ore = 0
	assert(Recovery.recover_cargo(state, wreck_id, -1, moved_position, 80.0, moved_origin.to_save()).is_empty(), "remaining cargo can be recovered later")
	assert(wreck.cargo_recovered and wreck.cargo.food == 0 and state.cargo.food == 5, "second recovery completes cargo transfer")
	assert(state.credits == credits_at_recovery, "cargo recovery never pays salvage value")
	assert(not Recovery.salvage_wreck(state, wreck_id, -1, moved_position, 80.0, moved_origin.to_save()).is_empty(), "cargo-only wreck cannot be salvaged")

	state.crew_orders.clear()
	state.stations.clear()
	var path := "user://fleet-cargo-recovery-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty(), "cargo-only wreck saves")
	var loaded = GameStateScript.new()
	var load_error: String = loaded.load_save(path)
	assert(load_error.is_empty() and loaded.recovery.wrecks.size() == 1, "cargo-only wreck survives save/load: " + load_error)
	assert(loaded.recovery.wrecks[0].modules.is_empty() and loaded.recovery.wrecks[0].salvaged and Recovery.validate_data(loaded.recovery), "loaded cargo wreck keeps zero-salvage state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var malformed: Dictionary = state.recovery.duplicate(true)
	malformed.wrecks[0].salvage_value = 1
	assert(not Recovery.validate_data(malformed), "empty blueprint cannot carry salvage value")
	malformed = state.recovery.duplicate(true)
	malformed.wrecks[0].salvaged = false
	assert(not Recovery.validate_data(malformed), "empty blueprint must already be salvaged")


func _test_rejections_are_atomic() -> void:
	var state := _state_with_fleet_cargo()
	var before: Dictionary = _snapshot(state)
	assert(not Recovery.abandon_fleet_cargo(state, "missing", Vector3.ZERO).ok, "missing vessel is rejected")
	assert(_snapshot(state) == before, "missing vessel rejection is atomic")
	state.fleet_ships[0].hull = 10.0
	before = _snapshot(state)
	assert(not Recovery.abandon_fleet_cargo(state, "ship-test", Vector3.ZERO).ok, "healthy vessel is rejected")
	assert(_snapshot(state) == before, "healthy vessel rejection is atomic")
	state.fleet_ships[0].hull = 0.0
	state.fleet_ships[0].system = state.system_index + 1
	before = _snapshot(state)
	assert(not Recovery.abandon_fleet_cargo(state, "ship-test", Vector3.ZERO).ok, "remote vessel is rejected")
	assert(_snapshot(state) == before, "remote vessel rejection is atomic")
	state.fleet_ships[0].system = state.system_index
	before = _snapshot(state)
	assert(not Recovery.abandon_fleet_cargo(state, "ship-test", Vector3(INF, 0, 0)).ok, "invalid position is rejected")
	assert(_snapshot(state) == before, "invalid position rejection is atomic")
	assert(not Recovery.abandon_fleet_cargo(state, "ship-test", Vector3.ZERO, {"version": 999}).ok, "invalid origin address is rejected")
	assert(_snapshot(state) == before, "invalid address rejection is atomic")


func _test_registry_capacity() -> void:
	var state := _state_with_fleet_cargo()
	var template_state := GameStateScript.new()
	template_state.hull = 0.0
	assert(Recovery.destroy_ship(template_state, Vector3.ZERO, -1).ok, "valid blueprint template can be created")
	var template: Dictionary = template_state.recovery.wrecks[0].duplicate(true)
	template.cargo = _empty_goods()
	template.cargo_recovered = true
	state.recovery.wrecks.clear()
	for index: int in range(1, Recovery.MAX_WRECKS + 1):
		var wreck: Dictionary = template.duplicate(true)
		wreck.id = "wreck-%06d" % index
		state.recovery.wrecks.append(wreck)
	state.recovery.next_id = Recovery.MAX_WRECKS + 1
	assert(Recovery.validate_data(state.recovery), "synthetic full registry remains valid")
	var before: Dictionary = _snapshot(state)
	assert(not Recovery.abandon_fleet_cargo(state, "ship-test", Vector3.ZERO).ok, "full registry retains cargo without recyclable wreck")
	assert(_snapshot(state) == before, "full registry rejection is atomic")
	state.recovery.wrecks[0].salvaged = true
	assert(Recovery.validate_data(state.recovery), "completed wreck can be recycled")
	var result: Dictionary = Recovery.abandon_fleet_cargo(state, "ship-test", Vector3.ZERO)
	assert(result.get("ok", false) and state.recovery.wrecks.size() == Recovery.MAX_WRECKS, "completed wreck slot is recycled")
	assert(state.fleet_ships[0].cargo.is_empty(), "cargo transfers when a completed slot is available")


func _state_with_fleet_cargo() -> GameState:
	var state := GameStateScript.new()
	state.recovery = Recovery.empty_data()
	state.fleet_ships = [{"id": "ship-test", "name": "Disabled Courier", "system": state.system_index, "hull": 0.0, "cargo": {"food": 5, "ore": 2}, "capacity": 25, "flight": {"phase": "outbound", "address": SectorPosition.new().to_save(), "velocity": [1.0, 0.0, 0.0]}}]
	state.crew = [{"id": "trader_test", "role": "trader", "name": "Test Trader", "salary": 75}]
	state.stations = [{"name": "Factory Supply Depot", "system": state.system_index + 1, "level": 1, "rooms": [], "stock": {}}]
	state.crew_orders = {"trader_test": {"kind": "trade", "crew_id": "trader_test", "ship_id": "ship-test", "good": "food", "origin": state.system_index, "destination": state.system_index + 1, "quantity": 5, "escrow": 100, "escrow_limit": 100, "progress": 120.0, "phase": "inbound", "earned": 0, "paused": false, "purchase_cost": 90, "delivery_station": 0}}
	return state


func _snapshot(state: GameState) -> Dictionary:
	return {"credits": state.credits, "hull": state.hull, "shield": state.shield, "fuel": state.fuel, "ship": state.fleet_ships[0].duplicate(true), "order": state.crew_orders.duplicate(true), "recovery": state.recovery.duplicate(true)}


func _wreck(state: GameState, wreck_id: String) -> Dictionary:
	for wreck: Dictionary in state.recovery.wrecks:
		if str(wreck.id) == wreck_id: return wreck
	return {}


func _empty_goods() -> Dictionary:
	var cargo: Dictionary = {}
	for good: String in GameStateScript.GOODS: cargo[good] = 0
	return cargo
