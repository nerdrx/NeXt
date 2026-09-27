extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var base = GameStateScript.new()
	base.credits = 100000
	assert(base.hire("gunner").is_empty())
	var orders := CrewOrdersScript.new(base)
	assert(orders.purchase_ship("Remote Patrol", "merchant").is_empty())
	var ship: Dictionary = base.fleet_ships[0]
	ship.id = "ship-patrol-timing-fixed"
	var crew_id := str(base.crew[0].id)
	assert(orders.assign_patrol(crew_id, str(ship.id), 1).is_empty())
	base.crew_orders[crew_id].progress = 297.0
	ship.defense = {"charge": 0.0, "delay": 6.0}
	var fixed_day: int = base.day
	var path := "user://patrol-timing-%d.json" % OS.get_process_id()
	assert(base.save(path).is_empty())
	var batched = _load_state(path)
	var sliced = _load_state(path)
	assert(batched != null and sliced != null)
	var batch_reports: Array[Dictionary] = CrewOrdersScript.new(batched).tick(1204.0)
	assert(batch_reports.any(func(report: Dictionary): return report.status == "hostile intercepted"), "fixture includes actual shield damage")
	var slices := CrewOrdersScript.new(sliced)
	var sliced_reports: Array[Dictionary] = []
	for _second in range(1204):
		sliced_reports.append_array(slices.tick(1.0))
	assert(batched.day == fixed_day and sliced.day == fixed_day, "patrol comparisons keep day fixed")
	var batch_ship: Dictionary = batched.fleet_ships[0]
	var slice_ship: Dictionary = sliced.fleet_ships[0]
	var batch_order: Dictionary = batched.crew_orders[crew_id]
	var slice_order: Dictionary = sliced.crew_orders[crew_id]
	assert(int(batch_order.encounters) > 1, "long patrol interval contains multiple encounters")
	assert(batch_order.encounters == slice_order.encounters, "batched and one-second ticks encounter the same number of times")
	assert(is_equal_approx(float(batch_ship.hull), float(slice_ship.hull)), "batched and one-second ticks preserve patrol hull")
	assert(is_equal_approx(float(batch_ship.defense.charge), float(slice_ship.defense.charge)), "batched and one-second ticks preserve shield charge")
	assert(is_equal_approx(float(batch_ship.defense.delay), float(slice_ship.defense.delay)), "batched and one-second ticks preserve shield delay")
	assert(batched.credits == sliced.credits, "batched and one-second ticks preserve credits")
	assert(batch_reports.size() == sliced_reports.size(), "batched and one-second ticks report the same number of events")

	var boundary_batch = _load_state(path)
	var boundary_split = _load_state(path)
	assert(boundary_batch != null and boundary_split != null)
	CrewOrdersScript.new(boundary_batch).tick(7.0)
	var split_orders := CrewOrdersScript.new(boundary_split)
	split_orders.tick(3.0)
	split_orders.tick(4.0)
	var expected_ship: Dictionary = boundary_batch.fleet_ships[0]
	var actual_ship: Dictionary = boundary_split.fleet_ships[0]
	assert(boundary_batch.crew_orders[crew_id].encounters == boundary_split.crew_orders[crew_id].encounters, "split tick crosses the same patrol boundary")
	assert(is_equal_approx(float(expected_ship.defense.charge), float(actual_ship.defense.charge)), "post-encounter remainder recharges shields consistently")
	assert(is_equal_approx(float(expected_ship.defense.delay), float(actual_ship.defense.delay)), "post-encounter remainder reduces shield delay consistently")
	assert(is_equal_approx(float(expected_ship.hull), float(actual_ship.hull)) and boundary_batch.credits == boundary_split.credits, "split tick preserves encounter damage and bounty")
	var disabled = _load_state(path)
	var hostile_index := 0
	while batch_reports[hostile_index].status != "hostile intercepted": hostile_index += 1
	disabled.crew_orders[crew_id].encounters = hostile_index
	disabled.crew_orders[crew_id].progress = 300.0
	disabled.fleet_ships[0].hull = 0.001
	var fatal_reports := CrewOrdersScript.new(disabled).tick(900.0)
	assert(float(disabled.fleet_ships[0].hull) == 0.0 and fatal_reports.size() == 1, "disabled vessel cannot complete later batch encounters")
	assert(disabled.crew_orders[crew_id].paused)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	print("PATROL_TIMING_OK")
	quit()

func _load_state(path: String):
	var copy = GameStateScript.new()
	if not copy.load_save(path).is_empty():
		return null
	return copy
