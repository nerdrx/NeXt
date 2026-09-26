extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const Recovery = preload("res://scripts/ship_recovery.gd")


func _initialize() -> void:
	var state = GameStateScript.new()
	state.recovery = Recovery.empty_data()
	state.cargo.ore = 10
	state.cargo.food = 8
	state.credits = 0
	state.hull = 0.0
	var wrecked: Dictionary = Recovery.destroy_ship(state, Vector3(12, 4, -8), -1)
	assert(wrecked.ok and wrecked.wreck_id == "wreck-000001")
	assert(state.ship_modules.size() == 7 and state.hull > 0 and state.fuel == 25.0)
	assert(state.cargo_total() == 0 and wrecked.debt_added > 0 and state.recovery.debt == wrecked.debt_added)
	assert(not Recovery.destroy_ship(state, Vector3.ZERO, -1).ok, "duplicate death ignored after replacement")
	assert(not Recovery.recover_cargo(state, wrecked.wreck_id, 0, Vector3(12, 4, -8)).is_empty(), "reject wrong surface")
	assert(not Recovery.salvage_wreck(state, "missing", -1, Vector3(12, 4, -8)).is_empty(), "reject nonexistent wreck")
	assert(not Recovery.salvage_wreck(state, wrecked.wreck_id, -1, Vector3(500, 0, 0)).is_empty(), "reject out-of-range interaction")
	state.cargo.ore = int(state.ship_stats().cargo_capacity)
	assert(not Recovery.recover_cargo(state, wrecked.wreck_id, -1, Vector3(12, 4, -8)).is_empty(), "full hold reports an error")
	state.cargo.ore = int(state.ship_stats().cargo_capacity) - 1
	var cargo_result: String = Recovery.recover_cargo(state, wrecked.wreck_id, -1, Vector3(12, 4, -8))
	assert(cargo_result.is_empty() and state.cargo_total() == int(state.ship_stats().cargo_capacity), "cargo recovery respects capacity and permits a second pass")
	state.cargo.ore = 0
	cargo_result = Recovery.recover_cargo(state, wrecked.wreck_id, -1, Vector3(12, 4, -8))
	assert(cargo_result.is_empty() and state.cargo_total() == 17)
	assert(not Recovery.recover_cargo(state, wrecked.wreck_id, -1, Vector3(12, 4, -8)).is_empty(), "cargo cannot be recovered twice")
	var paid_before: int = state.credits
	var salvage: String = Recovery.salvage_wreck(state, wrecked.wreck_id, -1, Vector3(12, 4, -8))
	assert(salvage.is_empty() and state.credits >= paid_before and state.recovery.debt < wrecked.debt_added, "salvage pays recovery debt first")
	assert(not Recovery.salvage_wreck(state, wrecked.wreck_id, -1, Vector3(12, 4, -8)).is_empty(), "salvage pays once")
	assert(not Recovery.buy_insurance(state).is_empty(), "insurance rejects insufficient funds")
	state.credits = 18000
	var repay: String = Recovery.repay_debt(state, 1000)
	assert(repay.is_empty() and state.recovery.debt < wrecked.debt_added)
	assert(not Recovery.buy_insurance(state).is_empty(), "unpaid debt blocks insurance")
	assert(Recovery.repay_debt(state, 10000).is_empty() and state.recovery.debt == 0)
	var insurance: String = Recovery.buy_insurance(state, 30)
	assert(insurance.is_empty() and state.recovery.insurance_until_day == state.day + 30)
	state.credits = 0
	state.hull = 0.0
	var insured_loss: Dictionary = Recovery.destroy_ship(state, Vector3.ZERO, 0)
	assert(insured_loss.ok and insured_loss.insured and state.ship_modules.size() == 7)
	assert(insured_loss.fee > int(state.recovery.wrecks[-1].salvage_value), "insured wreck salvage cannot exceed deductible")
	assert(state.recovery.wrecks.size() == 2 and Recovery.validate_data(state.recovery))
	var serialized: Dictionary = state.recovery.duplicate(true)
	serialized.wrecks[0].position = [12.0, 4.0, -8.0]
	assert(Recovery.validate_data(serialized), "JSON-decoded wreck positions validate")
	var invalid: Dictionary = serialized.duplicate(true)
	invalid.wrecks[0].surface = 99
	assert(not Recovery.validate_data(invalid), "reject invalid surface in persisted data")
	invalid = serialized.duplicate(true)
	invalid.wrecks[0].salvaged = 1
	assert(not Recovery.validate_data(invalid), "reject invalid flag type")
	invalid = serialized.duplicate(true)
	invalid.wrecks[0].cargo.unobtainium = 1
	assert(not Recovery.validate_data(invalid), "reject unknown cargo key")
	var save_path: String = "user://recovery-test-%d.json" % OS.get_process_id()
	assert(state.save(save_path).is_empty(), "recovery state saves")
	var loaded = GameStateScript.new()
	assert(loaded.load_save(save_path).is_empty() and loaded.recovery == state.recovery, "recovery state survives JSON round-trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var resolved: Dictionary = state.recovery.wrecks[0].duplicate(true)
	var active: Dictionary = state.recovery.wrecks[1].duplicate(true)
	resolved.cargo_recovered = false
	resolved.salvaged = false
	state.recovery.wrecks = [resolved, active]
	for i: int in range(3, Recovery.MAX_WRECKS + 1):
		var extra: Dictionary = active.duplicate(true)
		extra.id = "wreck-%06d" % i
		state.recovery.wrecks.append(extra)
	state.recovery.next_id = Recovery.MAX_WRECKS + 1
	assert(Recovery.validate_data(state.recovery), "full registry remains valid")
	state.hull = 0.0
	assert(not Recovery.destroy_ship(state, Vector3.ZERO, 0).ok and state.hull == 0.0, "full registry blocks rescue without corrupting state")
	state.recovery.wrecks[0].cargo_recovered = true
	state.recovery.wrecks[0].salvaged = true
	var reclaimed: Dictionary = Recovery.destroy_ship(state, Vector3.ZERO, 0)
	assert(reclaimed.ok and state.recovery.wrecks.size() == Recovery.MAX_WRECKS, "completed wreck is pruned to make room")
	print("ShipRecovery tests passed")
	quit()
