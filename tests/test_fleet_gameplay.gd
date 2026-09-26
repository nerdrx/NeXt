extends SceneTree

var game: Node
var save_path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.close_menu()
	game._clear_actors()
	save_path = "user://fleet-scene-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.state.credits = 50000
	if not _check(game.state.hire("gunner").is_empty(), "hire gunner"): return
	var operations := CrewOrders.new(game.state)
	operations.purchase_ship("Guardian")
	var ship: Dictionary = game.state.fleet_ships[0]
	var crew: Dictionary = game.state.crew[0]
	operations.assign_patrol(crew.id, ship.id, game.state.system_index)
	var ids: Array[String] = game._sync_fleet_actors()
	if not _check(ids == [str(ship.id)], "local patrol materializes"): return
	var fleet: ShipActor = game.fleet_actors[ship.id]
	fleet.position = Vector3(1200, 300, -1200)
	fleet.set_physics_process(false)
	var pirate := ShipActor.new()
	pirate.actor_id = "fleet-test-pirate"
	pirate.position = fleet.position + Vector3(0, 0, -50)
	pirate.shields = 0
	pirate.hp = 9
	game.add_child(pirate)
	game.actors.append(pirate)
	pirate.set_physics_process(false)
	pirate.destroyed.connect(game._actor_destroyed)
	game._update_combat_targets()
	if not _check(fleet.target == pirate and pirate.target == fleet, "patrol and pirate acquire each other"): return
	await physics_frame
	await physics_frame
	var before: int = game.state.credits
	game.state.crew_orders[crew.id].paused = true
	game._update_combat_targets()
	if not _check(fleet.target == null and pirate.target == fleet, "unpaid patrol stops engaging without gaining invulnerability"): return
	game._enemy_fire(pirate, pirate.position, Vector3.BACK)
	if not _check(ship.hull == 91 and fleet.hp == 91, "pirate weapon ray persists fleet hull damage"): return
	game.state.crew_orders[crew.id].paused = false
	game._update_combat_targets()
	game._enemy_fire(fleet, fleet.position, Vector3.FORWARD)
	if not _check(game.state.credits == before + 250, "physical pirate destruction awards one bounty"): return
	if not _check(game.state.crew_orders[crew.id].encounters == 1, "physical kill records patrol encounter"): return
	await physics_frame
	game._enemy_fire(fleet, fleet.position, Vector3.FORWARD)
	if not _check(game.state.credits == before + 250, "destroyed pirate cannot reward twice"): return
	operations.tick(CrewOrders.TRIP_SECONDS, ids)
	if not _check(game.state.credits == before + 250 - int(crew.salary) and ship.hull == 91, "loaded payroll cannot simulate another battle"): return
	fleet.take_damage(1000)
	if not _check(ship.hull == 0 and not game.fleet_actors.has(ship.id), "disabled ship leaves local actors and persists zero hull"): return
	if not _check(game.save_commander(false), "save damaged fleet"): return
	var restored := GameState.new()
	if not _check(restored.load_save(save_path).is_empty() and restored.fleet_ships[0].hull == 0, "disabled hull survives reload"): return
	operations.repair_fleet_ship(ship.id)
	game._sync_fleet_actors()
	if not _check(game.fleet_actors.has(ship.id) and game.fleet_actors[ship.id].hp == 100, "repaired patrol returns to local scene"): return
	var repaired: ShipActor = game.fleet_actors[ship.id]
	repaired.position = Vector3(1200, 300, -1200)
	repaired.set_patrol_center(repaired.position)
	var live_pirate := ShipActor.new()
	live_pirate.actor_id = "fleet-autonomous-pirate"
	live_pirate.position = repaired.position + Vector3(0, 0, -80)
	live_pirate.shields = 0
	live_pirate.hp = 9
	live_pirate.speed = 0
	live_pirate.destroyed.connect(game._actor_destroyed)
	live_pirate.fired.connect(game._enemy_fire)
	game.add_child(live_pirate)
	game.actors.append(live_pirate)
	var paid_before: int = game.state.credits
	game.set_process(true)
	await create_timer(2.5).timeout
	game.set_process(false)
	if not _check(game.state.credits == paid_before + 250 and not is_instance_valid(live_pirate), "autonomous actor fire resolves a real battle through main signals"): return
	operations.cancel(crew.id)
	game._sync_fleet_actors()
	if not _check(game.fleet_actors.is_empty(), "cancel removes tactical patrol"): return
	_cleanup()
	game.queue_free()
	await process_frame
	print("FLEET_GAMEPLAY_OK: target acquisition, real weapon damage, one bounty, local payroll, persistent disable/repair")
	quit()

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("FLEET_GAMEPLAY_FAILED: " + message)
		_cleanup()
		quit(1)
	return ok

func _cleanup() -> void:
	game.sound.shutdown()
	game.session.leave()
	for path: String in [save_path, save_path + ".bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
