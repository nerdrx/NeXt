extends SceneTree

var save_paths: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var disabled := _state_with_crew(["engineer"])
	var max_hull: float = float(disabled.ship_stats().max_hull)
	disabled.cargo.alloys = 3
	disabled.hull = max_hull - 32.0
	var disabled_credits: int = disabled.credits
	disabled.advance_time(GameState.DAY_SECONDS)
	if not _check(not disabled.field_repairs_enabled, "repairs default to disabled"): return
	if not _check(disabled.hull == max_hull - 32.0 and int(disabled.cargo.get("alloys", 0)) == 3, "disabled repairs neither heal nor consume cargo alloys"): return
	if not _check(disabled.credits == disabled_credits - 90, "normal engineer wages remain enabled"): return

	var pair := _state_with_crew(["engineer", "engineer"])
	max_hull = float(pair.ship_stats().max_hull)
	pair.field_repairs_enabled = true
	pair.cargo.alloys = 5
	pair.hull = max_hull - 20.0
	var pair_credits: int = pair.credits
	pair.advance_time(GameState.DAY_SECONDS)
	if not _check(pair.hull == max_hull - 4.0 and int(pair.cargo.get("alloys", 0)) == 3, "two paid engineers each spend one alloy for eight hull"): return
	if not _check(pair.credits == pair_credits - 180, "field repairs preserve ordinary daily payroll"): return

	var scarce := _state_with_crew(["engineer", "engineer"])
	max_hull = float(scarce.ship_stats().max_hull)
	scarce.field_repairs_enabled = true
	scarce.cargo.alloys = 1
	scarce.hull = max_hull - 50.0
	scarce.advance_time(GameState.DAY_SECONDS)
	if not _check(scarce.hull == max_hull - 42.0 and int(scarce.cargo.get("alloys", 0)) == 0, "scarce alloys cap repair units"):
		return

	var partial := _state_with_crew(["engineer"])
	max_hull = float(partial.ship_stats().max_hull)
	partial.field_repairs_enabled = true
	partial.cargo.alloys = 1
	partial.hull = max_hull - 3.0
	partial.advance_time(GameState.DAY_SECONDS)
	if not _check(partial.hull == max_hull and int(partial.cargo.get("alloys", 0)) == 0, "partial final repair still consumes one full alloy"): return

	var full := _state_with_crew(["engineer"])
	full.field_repairs_enabled = true
	full.cargo.alloys = 2
	full.advance_time(GameState.DAY_SECONDS)
	if not _check(full.hull == full.ship_stats().max_hull and int(full.cargo.get("alloys", 0)) == 2, "full hull consumes no repair alloys"): return

	var destroyed := _state_with_crew(["engineer"])
	destroyed.field_repairs_enabled = true
	destroyed.cargo.alloys = 2
	destroyed.hull = 0.0
	destroyed.advance_time(GameState.DAY_SECONDS)
	if not _check(destroyed.hull == 0.0 and int(destroyed.cargo.get("alloys", 0)) == 2, "destroyed hull cannot receive field repairs"): return

	var empty_crew := GameState.new()
	empty_crew.field_repairs_enabled = true
	empty_crew.cargo.alloys = 2
	empty_crew.hull -= 16.0
	var empty_hull: float = empty_crew.hull
	empty_crew.advance_time(GameState.DAY_SECONDS)
	if not _check(empty_crew.hull == empty_hull and int(empty_crew.cargo.get("alloys", 0)) == 2, "no engineers means no repair or alloy consumption"): return

	var unpaid := _state_with_crew(["engineer"])
	unpaid.field_repairs_enabled = true
	unpaid.cargo.alloys = 2
	unpaid.hull -= 16.0
	var unpaid_hull: float = unpaid.hull
	unpaid.credits = 0
	unpaid.advance_time(GameState.DAY_SECONDS)
	if not _check(not unpaid.crew_paid and unpaid.hull == unpaid_hull and int(unpaid.cargo.get("alloys", 0)) == 2, "unpaid crew cannot perform field repairs"): return

	var assigned := _state_with_crew(["engineer", "trader"])
	assigned.field_repairs_enabled = true
	assigned.cargo.alloys = 2
	assigned.hull -= 16.0
	var assigned_engineer: String = str(assigned.crew[0].id)
	var assigned_cash: int = assigned.credits
	assigned.crew_orders[assigned_engineer] = {"kind": "assigned"}
	assigned.advance_time(GameState.DAY_SECONDS)
	if not _check(assigned.crew_paid and assigned.hull == assigned.ship_stats().max_hull - 16.0 and int(assigned.cargo.get("alloys", 0)) == 2, "assigned engineer is excluded while passive trader remains paid"): return
	if not _check(assigned.credits == assigned_cash - 75 + 20, "assigned engineer is excluded from wages and passive trader income remains"): return

	var save_state := _state_with_crew(["engineer"])
	save_state.field_repairs_enabled = true
	save_state.cargo.alloys = 4
	var save_path := "user://field-repairs-%d.json" % OS.get_process_id()
	save_paths.append(save_path)
	if not _check(save_state.save(save_path).is_empty(), "enabled repair preference saves"): return
	var restored := GameState.new()
	if not _check(restored.load_save(save_path).is_empty() and restored.field_repairs_enabled, "repair preference round-trips through save"): return

	var valid_data: Dictionary = save_state._save_data().duplicate(true)
	var old_data: Dictionary = valid_data.duplicate(true)
	old_data.erase("field_repairs_enabled")
	if not _check(_write_save(save_path, old_data), "write legacy save fixture"): return
	var old_loaded := GameState.new()
	if not _check(old_loaded.load_save(save_path).is_empty() and not old_loaded.field_repairs_enabled, "old saves without repair preference default disabled"): return
	var stable: Dictionary = old_loaded._save_data().duplicate(true)
	var malformed: Dictionary = valid_data.duplicate(true)
	malformed.field_repairs_enabled = "true"
	if not _check(_write_save(save_path, malformed), "write malformed preference fixture"): return
	if not _check(not old_loaded.load_save(save_path).is_empty() and old_loaded._save_data() == stable, "malformed optional boolean is rejected atomically"): return

	var single := _state_with_crew(["engineer", "engineer"])
	single.field_repairs_enabled = true
	single.cargo.alloys = 3
	single.hull -= 80.0
	var split_path := "user://field-repairs-split-%d.json" % OS.get_process_id()
	save_paths.append(split_path)
	if not _check(single.save(split_path).is_empty(), "split-time fixture saves"): return
	var split := GameState.new()
	if not _check(split.load_save(split_path).is_empty(), "split-time fixture reloads"): return
	if not _check(single.advance_time(GameState.DAY_SECONDS * 2.0) == 2, "single advance crosses two days"): return
	if not _check(split.advance_time(GameState.DAY_SECONDS) == 1 and split.advance_time(GameState.DAY_SECONDS) == 1, "split advances cross one day each"): return
	if not _check(_daily_result(single) == _daily_result(split), "split and single day advances produce equivalent repairs/payroll"): return

	_cleanup()
	print("FIELD_REPAIRS_OK: opt-in alloys, payroll, guards, schema migration, atomic rejection and split-time equivalence")
	quit()

func _state_with_crew(roles: Array[String]) -> GameState:
	var state := GameState.new()
	state.credits = 100000
	for role in roles:
		var issue: String = state.hire(role)
		if not issue.is_empty():
			push_error("FIELD_REPAIRS_FAIL: crew fixture hire failed: " + issue)
			quit(1)
			return state
	return state

func _daily_result(state: GameState) -> Dictionary:
	return {"day": state.day, "day_progress": state.day_progress, "credits": state.credits, "alloys": int(state.cargo.get("alloys", 0)), "hull": state.hull, "crew_paid": state.crew_paid, "repairs": state.field_repairs_enabled}

func _write_save(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func _check(ok: bool, message: String) -> bool:
	if ok: return true
	push_error("FIELD_REPAIRS_FAIL: " + message)
	_cleanup()
	quit(1)
	return false

func _cleanup() -> void:
	for path in save_paths:
		for suffix in ["", ".bak"]:
			var full_path: String = ProjectSettings.globalize_path(path + suffix)
			if FileAccess.file_exists(full_path): DirAccess.remove_absolute(full_path)
	save_paths.clear()
