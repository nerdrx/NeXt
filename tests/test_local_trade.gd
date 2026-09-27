extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

var game: Node
var save_path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Domain gate: local elapsed time cannot settle trade until the actor is ready.
	var state = GameStateScript.new()
	state.credits = 50000
	assert(state.hire("trader").is_empty())
	var orders = CrewOrdersScript.new(state)
	assert(orders.purchase_ship("Local Mule").is_empty())
	var ship: Dictionary = state.fleet_ships[0]
	ship.id = "local-trader-domain"
	var crew_id: String = str(state.crew[0].id)
	assert(orders.assign_trade_route(crew_id, ship.id, "ore", 17, 5).is_empty())
	var order: Dictionary = state.crew_orders[crew_id]
	var credits_after_escrow: int = state.credits
	assert(orders.tick(600, [], {ship.id: false}).is_empty())
	assert(float(order.progress) == 600.0 and state.credits == credits_after_escrow and int(ship.cargo.get("ore", 0)) == 0,
		"unready local trader caps at one leg without wages or trade")
	var save_path: String = "user://local-trade-domain-%d.json" % OS.get_process_id()
	assert(state.save(save_path).is_empty())
	var restored = GameStateScript.new()
	assert(restored.load_save(save_path).is_empty())
	state = restored
	orders = CrewOrdersScript.new(state)
	ship = state.fleet_ships[0]
	order = state.crew_orders[crew_id]
	assert(float(order.progress) == 600.0 and orders.tick(30, [], {ship.id: false}).is_empty(),
		"saved capped progress remains pending while the local trader is unready")
	var local_reports: Array[Dictionary] = orders.tick(99999, [], {ship.id: true})
	assert(local_reports.size() == 1 and local_reports[0].status == "cargo bought",
		"ready local trader completes only the pending leg")
	assert(state.credits == credits_after_escrow - int(state.crew[0].salary) and order.phase == "inbound" and float(order.progress) == 0.0,
		"local readiness charges one wage and cannot settle the second leg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	# Unrepresented/remote traders retain hosted two-leg progression.
	var remote = GameStateScript.new()
	remote.credits = 50000
	assert(remote.hire("trader").is_empty())
	var remote_orders = CrewOrdersScript.new(remote)
	assert(remote_orders.purchase_ship("Remote Mule").is_empty())
	var remote_ship: Dictionary = remote.fleet_ships[0]
	remote_ship.id = "remote-trader-domain"
	var remote_crew: String = str(remote.crew[0].id)
	assert(remote_orders.assign_trade_route(remote_crew, remote_ship.id, "ore", 17, 5).is_empty())
	var remote_reports: Array[Dictionary] = remote_orders.tick(1200)
	assert(remote_reports.size() == 2 and remote_reports[0].status == "cargo bought" and remote_reports[1].status == "cargo sold",
		"remote fallback still completes both 600-second legs")

	await _test_scene()
	print("LOCAL_TRADE_OK: arrival gate, single settlement, save continuity, rebased actor, damage and reassignment")
	quit()

func _test_scene() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.close_menu()
	game._clear_actors()
	game.flight_origin = SectorPosition.new(Vector3i(1, 0, 0), Vector3.ZERO)
	save_path = "user://local-trade-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.state.credits = 50000
	assert(game.state.hire("trader").is_empty())
	var operations := CrewOrders.new(game.state)
	assert(operations.purchase_ship("Local Mule").is_empty())
	var ship: Dictionary = game.state.fleet_ships[0]
	var crew_id: String = str(game.state.crew[0].id)
	ship.id = "local-trader-scene"
	assert(operations.assign_trade_route(crew_id, ship.id, "ore", 17, 5).is_empty())
	var local_ids: Array[String] = game._sync_fleet_actors()
	assert(not local_ids.has(ship.id), "trader does not suppress strategic patrol simulation")
	assert(game.fleet_actors.has(ship.id), "assigned local trader materializes an actor")
	var actor: ShipActor = game.fleet_actors[ship.id]
	var expected_target: Vector3 = SectorPosition.new(Vector3i.ZERO, Vector3(-420, 100, -2000)).relative_to(game.flight_origin, 60000)
	assert(actor.travel_target.distance_to(expected_target) < 0.01, "trader route target is rebased into the current flight sector")
	assert(actor.faction == "player_fleet" and not actor.hostile and actor.target == null,
		"local trader stays passive")
	var readiness: Dictionary = game._local_trade_status()
	assert(readiness.has(ship.id) and not bool(readiness[ship.id]), "travelling trader is unready before arrival")
	assert(actor.travel_active, "local trader receives its next route target")
	actor.set_physics_process(false)
	actor._physics_process(0.1)
	assert(actor.velocity.dot(actor.travel_target - actor.position) > 0.0, "local trader physically accelerates toward route target")
	if DisplayServer.get_name() != "headless":
		game.pilot.set_flight(true)
		game.pilot.teleport(actor.position + Vector3(14, 8, 22))
		game.pilot.camera.look_at(actor.position)
		await game._capture("local-trader")
	actor.position = actor.travel_target
	actor.velocity = Vector3.ZERO
	readiness = game._local_trade_status()
	assert(bool(readiness[ship.id]), "trader is ready at its target while stationary")
	var hull_before: float = float(ship.hull)
	actor.take_damage(9.0)
	assert(float(ship.hull) < hull_before, "local trader damage persists to fleet record")
	ship.hull = 0.0
	game._sync_fleet_actors()
	assert(not game.fleet_actors.has(ship.id), "disabled trader actor is removed")
	ship.hull = 100.0
	game._sync_fleet_actors()
	assert(game.fleet_actors.has(ship.id), "repaired trader actor returns")
	assert(operations.cancel(crew_id).is_empty())
	# Reassign before actor synchronization to cover the same-frame handoff.
	assert(game.state.hire("gunner").is_empty())
	var gunner_id: String = str(game.state.crew[1].id)
	assert(operations.assign_patrol(gunner_id, ship.id, game.state.system_index).is_empty())
	game._sync_fleet_actors()
	var patrol_actor: ShipActor = game.fleet_actors[ship.id]
	assert(not patrol_actor.travel_active and patrol_actor.hostile, "same-frame trade-to-patrol reassignment clears trader travel and restores patrol behavior")
	assert(operations.cancel(gunner_id).is_empty())
	game._sync_fleet_actors()
	assert(not game.fleet_actors.has(ship.id), "cancelling local fleet order removes its actor")
	game.sound.shutdown()
	game.session.leave()
	for path: String in [save_path, save_path + ".bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
