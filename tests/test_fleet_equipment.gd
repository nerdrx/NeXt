extends SceneTree

var state: GameState
var ship: Dictionary
var orders: CrewOrders
var save_path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	state = GameState.new()
	state.credits = 50000
	orders = CrewOrders.new(state)
	if not _check(orders.purchase_ship("Merchant", "merchant").is_empty(), "purchase merchant hull"): return
	ship = state.fleet_ships[0]
	ship.hull = 100.0
	var cell := Vector3i(-1, 0, 0)
	var before: Dictionary = ShipBlueprint.for_vessel(ship)
	var before_stats: Dictionary = _stats(before.modules)
	var credits := state.credits
	if not _check(orders.refit_module(str(ship.id), cell, "weapon").is_empty(), "replace merchant cargo with weapon"): return
	var fitted: Dictionary = ShipBlueprint.for_vessel(ship)
	var fitted_stats := _stats(fitted.modules)
	if not _check(fitted_stats.damage == int(before_stats.damage) + 15, "weapon improves damage"): return
	if not _check(int(ship.capacity) == int(before_stats.cargo_capacity) - 15, "refit updates fleet capacity"): return
	if not _check(state.credits == credits - 675, "charge full replacement cost minus half old module value"): return
	if not _check(is_equal_approx(float(ship.hull), 100.0), "refit preserves hull fraction"): return
	var modules_before_rejection: Variant = ship.get("modules", null)
	var layout_before_rejection: Dictionary = ship.get("layout", {}).duplicate(true)
	if not _reject(Vector3i(15, 0, 0), "weapon", "missing family cell", modules_before_rejection, layout_before_rejection): return
	if not _reject(Vector3i(0, 0, -1), "weapon", "locked core", modules_before_rejection, layout_before_rejection): return
	if not _reject(Vector3i(-1, 0, -1), "cargo", "last habitat", modules_before_rejection, layout_before_rejection): return
	if not _reject(Vector3i(1,0,2), "weapon", "insufficient reactor power", modules_before_rejection, layout_before_rejection): return
	# Fill current hold, then verify a second cargo loss cannot strand excess cargo.
	var remaining_capacity := int(ship.capacity)
	ship.cargo = {"ore": remaining_capacity}
	var cargo_before: Dictionary = ship.cargo.duplicate(true)
	var capacity_before := int(ship.capacity)
	var credits_before := state.credits
	if not _check(not orders.refit_module(str(ship.id), Vector3i(1, 0, 2), "radiator").is_empty(), "cargo overflow rejected"): return
	if not _check(int(ship.capacity) == capacity_before and ship.cargo == cargo_before and state.credits == credits_before, "cargo overflow rejection is atomic"): return
	ship.cargo = {}
	state.credits = 574
	credits_before = state.credits
	modules_before_rejection = ship.get("modules", null)
	layout_before_rejection = ship.get("layout", {}).duplicate(true)
	if not _check(not orders.refit_module(str(ship.id), Vector3i(1, 0, 2), "radiator").is_empty(), "insufficient credits rejected"): return
	if not _check(state.credits == credits_before and ship.get("modules", null) == modules_before_rejection and ship.get("layout", {}) == layout_before_rejection, "poor refit rejection is atomic"): return
	state.credits = 50000
	orders.occupied_ship_id = str(ship.id)
	modules_before_rejection = ship.get("modules", null)
	layout_before_rejection = ship.get("layout", {}).duplicate(true)
	credits_before = state.credits
	if not _check(not orders.refit_module(str(ship.id), Vector3i(1, 0, 2), "radiator").is_empty(), "occupied vessel rejected"): return
	if not _check(state.credits == credits_before and ship.get("modules", null) == modules_before_rejection and ship.get("layout", {}) == layout_before_rejection, "occupied rejection is atomic"): return
	orders.occupied_ship_id = ""
	# Persist both the explicit module overrides and their recalculated capacity.
	ship.hull = 63.5
	if not _check(orders.refit_module(str(ship.id), Vector3i(1, 0, 2), "radiator").is_empty(), "install radiator before save"): return
	if not _check(is_equal_approx(float(ship.hull), 63.5), "refit preserves damaged hull fraction"): return
	ship.defense = {"charge":150.0,"delay":2.0}
	if not _check(orders.refit_module(str(ship.id),Vector3i(1,0,0),"cargo").is_empty(), "replace shield generator"): return
	if not _check(float(ship.defense.charge) == 100.0 and float(ship.defense.delay) == 2.0, "lower shield capacity clamps charge without resetting delay"): return
	var final_blueprint: Dictionary = ShipBlueprint.for_vessel(ship)
	save_path = "user://fleet-equipment-%d.json" % OS.get_process_id()
	if not _check(state.save(save_path).is_empty(), "save refitted fleet"): return
	var restored := GameState.new()
	if not _check(restored.load_save(save_path).is_empty(), "load refitted fleet"): return
	var restored_ship: Dictionary = restored.fleet_ships[0]
	var restored_blueprint: Dictionary = ShipBlueprint.for_vessel(restored_ship)
	if not _check(restored_ship.get("modules", []) == ship.get("modules", []), "module overrides survive reload"): return
	if not _check(restored_ship.capacity == ship.capacity and restored_blueprint.modules == final_blueprint.modules, "modules and capacity survive reload"): return
	var stable := restored._save_data().duplicate(true)
	var valid := state._save_data().duplicate(true)
	var invalids: Array[Dictionary] = []
	for kind in ["unknown", "cargo"]:
		var broken := valid.duplicate(true)
		broken.fleet_ships[0].modules[0].kind = kind
		invalids.append(broken)
	var duplicate := valid.duplicate(true)
	duplicate.fleet_ships[0].modules[1] = duplicate.fleet_ships[0].modules[0].duplicate()
	invalids.append(duplicate)
	var missing_layout := valid.duplicate(true)
	missing_layout.fleet_ships[0].erase("layout")
	invalids.append(missing_layout)
	var wrong_capacity := valid.duplicate(true)
	wrong_capacity.fleet_ships[0].capacity += 1
	invalids.append(wrong_capacity)
	var legacy := valid.duplicate(true)
	legacy.fleet_ships[0].erase("hull_family")
	legacy.fleet_ships[0].capacity = 25
	invalids.append(legacy)
	for invalid: Dictionary in invalids:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(invalid))
		file.close()
		if not _check(not restored.load_save(save_path).is_empty() and restored._save_data() == stable, "invalid fleet equipment save rejected atomically"): return
	_cleanup()
	print("FLEET_EQUIPMENT_OK: refit stats, costs, guards, atomic failures, save and reload")
	quit()

func _stats(modules: Array) -> Dictionary:
	var typed_modules: Array[Dictionary] = []
	typed_modules.assign(modules)
	return state._stats_for(typed_modules)

func _reject(cell: Vector3i, kind: String, label: String, modules_before: Variant, layout_before: Dictionary) -> bool:
	var ship_before := ship.duplicate(true)
	var credits_before := state.credits
	if not _check(not orders.refit_module(str(ship.id), cell, kind).is_empty(), label + " rejected"): return false
	return _check(state.credits == credits_before and ship == ship_before and ship.get("modules", null) == modules_before and ship.get("layout", {}) == layout_before, label + " rejection is atomic")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("FLEET_EQUIPMENT_FAILED: " + message)
		_cleanup()
		quit(1)
	return ok

func _cleanup() -> void:
	for path: String in [save_path, save_path + ".bak"]:
		if not path.is_empty() and FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
