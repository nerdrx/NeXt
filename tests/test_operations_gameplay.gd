extends SceneTree

var main: Node
var save_path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	save_path = "user://operations-gameplay-%d.json" % OS.get_process_id()
	if FileAccess.file_exists(save_path):
		push_error("Test path already exists")
		quit(1)
		return
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.save_path = save_path
	main.state.credits = 30000
	if not check(main.state.hire("trader").is_empty(), "hire named trader"): return
	if not check(main.crew_operations().purchase_ship("Wayfarer").is_empty(), "commission fleet vessel"): return
	var member_id: String = main.state.crew[0].id
	var ship_id: String = main.state.fleet_ships[0].id
	if not check(main.crew_operations().assign_trade_route(member_id, ship_id, "food", 7919, 5).is_empty(), "assign crew trade route"): return
	main._process(10.0)
	if not check(is_equal_approx(float(main.state.crew_orders[member_id].progress), 10.0), "real game loop advances crew orders"): return
	if not check(main.save_commander(false), "save persistent work progress"): return
	var wallet: int = main.state.credits
	main.load_commander()
	if not check(is_equal_approx(float(main.state.crew_orders[member_id].progress), 10.0) and main.state.credits == wallet, "load causes no offline simulation or duplicate reward"): return
	main.state.cargo.ore = 12
	main.state.cargo.medicine = 2
	if not check(main.purchase_insurance().is_empty(), "arrange insurance through dock service"): return
	main.pilot.set_flight(true)
	main.pilot.teleport(Vector3(100, 80, -300))
	main.state.hull = 0
	main._rescue()
	main.open_menu("recovery")
	if not check(main.state.recovery.wrecks.size() == 1 and main.state.cargo_total() == 0 and main.state.hull > 0, "destruction creates wreck and rescues without duplicating cargo"): return
	var wreck: Dictionary = main.state.recovery.wrecks[0]
	var credits_after_rescue: int = main.state.credits
	main._rescue()
	if not check(main.state.recovery.wrecks.size() == 1 and main.state.credits == credits_after_rescue, "duplicate rescue callback has no effect"): return
	if not check(not main.recover_wreck(str(wreck.id)).is_empty(), "remote cargo recovery blocked"): return
	main.pilot.set_flight(true)
	main.pilot.teleport(main._wreck_position(wreck))
	if not check(main.recover_wreck(str(wreck.id)).is_empty() and main.state.cargo.ore == 12 and main.state.cargo.medicine == 2, "recover actual lost cargo at beacon"): return
	if not check(main.recover_wreck(str(wreck.id), true).is_empty(), "salvage wreck once"): return
	var after_salvage: int = main.state.credits
	if not check(not main.recover_wreck(str(wreck.id), true).is_empty() and main.state.credits == after_salvage, "duplicate salvage rejected"): return
	if not check(main.save_commander(false), "save recovered wreck state"): return
	main.load_commander()
	if not check(main.state.recovery.wrecks[0].salvaged and main.state.cargo.ore == 12, "wreck outcome survives load"): return
	main.pilot.set_flight(false)
	main.suit_health = 0
	var hull_before: float = main.state.hull
	main._rescue()
	if not check(main.state.recovery.wrecks.size() == 1 and main.state.hull == hull_before and main.state.cargo.ore == 12, "medical rescue preserves docked ship and cargo"): return
	var before_menus: int = main.state.credits
	for page in ["fleet", "recovery", "company", "market", "navigation"]:
		main.deck.show_page(page)
		await process_frame
	if not check(main.state.credits == before_menus, "opening operations pages does not transact"): return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	main.sound.shutdown()
	main.queue_free()
	await process_frame
	print("OPERATIONS_GAMEPLAY_OK: real tick, persistent orders, rescue, recovery, duplicate guards, menu safety")
	quit()

func check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("OPERATIONS_GAMEPLAY_FAILED: " + message)
	if main != null: main.sound.shutdown()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit(1)
	return false
