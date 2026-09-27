extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

func _initialize() -> void:
	var state = GameStateScript.new()
	state.credits = 5000
	assert(state.add_module("habitat", Vector3i(0, 0, 3)) == "")
	state.hire("gunner")
	state.hire("gunner")
	state.hire("engineer")
	var orders = CrewOrdersScript.new(state)
	var gunner: String = state.crew[0].id
	var second_gunner: String = state.crew[1].id
	var engineer: String = state.crew[2].id
	var modules: Array[Dictionary] = state.ship_modules.duplicate(true)
	var no_modules: Array[Dictionary] = []
	state.ship_modules = no_modules
	assert(orders.assign_ship_defense(gunner) != "", "defense requires a ship weapon")
	state.ship_modules = modules
	assert(orders.assign_ship_defense(engineer) != "", "defense requires a named gunner")
	assert(orders.assign_ship_defense(gunner) == "")
	assert(state.crew_orders[gunner].size() == 4 and state.crew_orders[gunner].kind == "defend")
	assert(orders.assign_ship_defense(gunner) != "", "busy gunner cannot get second order")
	assert(orders.assign_ship_defense(second_gunner) != "", "only one ship defense order is allowed")
	var wage: int = int(state.crew[0].salary)
	state.credits = 0
	var report: Array[Dictionary] = orders.tick(CrewOrdersScript.TRIP_SECONDS)
	assert(report.size() == 1 and report[0].status == "paused: wages unpaid" and state.crew_orders[gunner].paused)
	state.credits = wage
	report = orders.tick(1)
	assert(report.size() == 1 and report[0].status == "defense wages paid" and report[0].wages == wage and not state.crew_orders[gunner].paused)
	assert(orders.cancel(gunner) == "" and not state.crew_orders.has(gunner))
	assert(orders.assign_ship_defense(gunner) == "")
	var path: String = "user://defense-order-%d.json" % OS.get_process_id()
	assert(state.save(path) == "")
	var restored = GameStateScript.new()
	assert(restored.load_save(path) == "")
	assert(restored.crew_orders == state.crew_orders, "defense order survives save round-trip")
	var duplicate: Dictionary = state._save_data().duplicate(true)
	duplicate.crew_orders[second_gunner] = {"kind": "defend", "crew_id": second_gunner, "progress": 0.0, "paused": false}
	_write_save(path, duplicate)
	var unchanged: Dictionary = restored._save_data().duplicate(true)
	assert(restored.load_save(path) != "" and restored._save_data() == unchanged, "duplicate saved defense order is rejected transactionally")
	var wrong_role: Dictionary = state._save_data().duplicate(true)
	wrong_role.crew_orders.erase(gunner)
	wrong_role.crew_orders[engineer] = {"kind": "defend", "crew_id": engineer, "progress": 0.0, "paused": false}
	_write_save(path, wrong_role)
	assert(restored.load_save(path) != "" and restored._save_data() == unchanged, "wrong-role defense order is rejected transactionally")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("DEFENSE_ORDER_TEST_OK")
	quit()

func _write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
