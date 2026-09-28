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
	state.shield_delay = 6.0
	var wrecked: Dictionary = Recovery.destroy_ship(state, Vector3(12, 4, -8), -1)
	assert(wrecked.ok and wrecked.wreck_id == "wreck-000001")
	assert(state.ship_modules.size() == 7 and state.hull > 0 and state.fuel == 25.0)
	assert(state.shield_delay == 0.0, "replacement shield does not inherit the destroyed ship's damage timer")
	assert(state.cargo_total() == 0 and wrecked.debt_added > 0 and state.recovery.debt == wrecked.debt_added)
	assert(Recovery.wreck_relative(state.recovery.wrecks[0], {}) == Vector3(12, 4, -8), "legacy wreck keeps local-coordinate display")
	var legacy_state = GameStateScript.new()
	legacy_state.cargo.ore = 2
	legacy_state.hull = 0.0
	var legacy_wreck: Dictionary = Recovery.destroy_ship(legacy_state, Vector3(12, 4, -8), -1)
	var shifted_origin := SectorPosition.new(Vector3i.ZERO, Vector3(20, 0, 0))
	var shifted_wreck_position := Vector3(-8, 4, -8)
	assert(Recovery.wreck_relative(legacy_state.recovery.wrecks[0], shifted_origin.to_save()) == shifted_wreck_position, "legacy system-space wreck resolves after origin shift")
	assert(Recovery.recover_cargo(legacy_state, legacy_wreck.wreck_id, -1, shifted_wreck_position, 80.0, shifted_origin.to_save()).is_empty() and legacy_state.cargo.ore == 2, "legacy wreck cargo remains recoverable after rebase")
	assert(not Recovery.destroy_ship(state, Vector3.ZERO, -1).ok, "duplicate death ignored after replacement")
	assert(not Recovery.recover_cargo(state, wrecked.wreck_id, 0, Vector3(12, 4, -8)).is_empty(), "reject wrong surface")
	assert(not Recovery.salvage_wreck(state, "missing", -1, Vector3(12, 4, -8)).is_empty(), "reject nonexistent wreck")
	assert(not Recovery.salvage_wreck(state, wrecked.wreck_id, -1, Vector3(500, 0, 0)).is_empty(), "reject out-of-range interaction")
	var rebase_state = GameStateScript.new()
	var wreck_origin := SectorPosition.new(Vector3i(4, 0, 0), Vector3.ZERO)
	rebase_state.hull = 0.0
	var rebased: Dictionary = Recovery.destroy_ship(rebase_state, Vector3(10, 0, 0), -1, wreck_origin.to_save())
	assert(rebased.ok and Recovery.wreck_relative(rebase_state.recovery.wrecks[-1], wreck_origin.to_save()) == Vector3(10, 0, 0), "wreck resolves in its original sector frame")
	var distant_origin := SectorPosition.new(Vector3i.ZERO, Vector3.ZERO)
	assert(not Recovery.recover_cargo(rebase_state, rebased.wreck_id, -1, Vector3(10, 0, 0), 80.0, distant_origin.to_save()).is_empty(), "local-coordinate coincidence cannot recover wreck in another sector")
	var json_wreck: Dictionary = rebase_state.recovery.wrecks[-1].duplicate(true)
	json_wreck.address = SectorPosition.from_save(json_wreck.address).to_save()
	assert(Recovery.validate_data({"next_id": 2, "insurance_until_day": -1, "debt": 0, "wrecks": [json_wreck]}), "address survives JSON-form canonical serialization")
	assert(Recovery.recover_cargo(rebase_state, rebased.wreck_id, -1, Vector3(10, 0, 0), 80.0, wreck_origin.to_save()).is_empty(), "matching absolute address permits local recovery")
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
	invalid = rebase_state.recovery.duplicate(true)
	invalid.wrecks[0].address = {"version": 1, "sector": [1, 2], "local": [0, 0, 0]}
	assert(not Recovery.validate_data(invalid), "reject malformed absolute wreck address")
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
	var debris_state := GameState.new()
	assert(not Recovery.combat_debris(debris_state, Vector3.ZERO, NAN).ok)
	assert(not Recovery.combat_debris(debris_state, Vector3.ZERO, -1.0).ok)
	assert(debris_state.recovery.wrecks.is_empty(), "invalid debris requests leave registry untouched")
	assert(Recovery.combat_debris(debris_state, Vector3.ZERO, 1000000.0).ok)
	assert(debris_state.recovery.wrecks[0].cargo.alloys == 8, "large hull debris yield is bounded")
	var large := GameState.new()
	large.ship_modules = ShipBlueprint.family("merchant").modules.duplicate(true)
	large.cargo = {"ore": 3}
	large.hull = 0.0
	var large_origin := SectorPosition.new(Vector3i(4, 0, 0), Vector3.ZERO)
	assert(Recovery.destroy_ship(large, Vector3.ZERO, -1, large_origin.to_save()).ok)
	var large_wreck: Dictionary = large.recovery.wrecks[0]
	var geometry := Recovery.wreck_geometry(large_wreck)
	var outer: Dictionary = geometry.boxes[0]
	for box: Dictionary in geometry.boxes:
		if box.center.x > outer.center.x: outer = box
	var edge: Vector3 = outer.center + Vector3.RIGHT * float(outer.size.x) * 0.5
	var rotation := Basis.from_euler(geometry.rotation)
	var nearby: Vector3 = rotation * (edge * float(geometry.scale) + Vector3.RIGHT * 7.9)
	var distant: Vector3 = rotation * (edge * float(geometry.scale) + Vector3.RIGHT * 8.1)
	assert(nearby.length() > 8.0, "large wreck center is beyond walking recovery range")
	assert(is_equal_approx(Recovery.wreck_distance(large_wreck, nearby, large_origin.to_save()), 7.9))
	assert(not Recovery.recover_cargo(large, large_wreck.id, -1, distant, 8.0, large_origin.to_save()).is_empty())
	assert(Recovery.recover_cargo(large, large_wreck.id, -1, nearby, 8.0, large_origin.to_save()).is_empty())
	var shifted: SectorPosition = SectorPosition.from_save(large_origin.to_save())
	shifted.move_delta(Vector3(10, 0, 0))
	assert(is_equal_approx(Recovery.wreck_distance(large_wreck, nearby - Vector3(10, 0, 0), shifted.to_save()), 7.9), "surface distance survives rebasing")
	assert(Recovery.wreck_distance(large_wreck, Vector3(INF, 0, 0), large_origin.to_save()) == INF)
	print("ShipRecovery tests passed")
	quit()
