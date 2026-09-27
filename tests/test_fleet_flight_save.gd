extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

var game: Node
var path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state = GameStateScript.new()
	state.credits = 50000
	assert(state.hire("trader").is_empty())
	var orders = CrewOrdersScript.new(state)
	assert(orders.purchase_ship("Local Mule").is_empty())
	var ship: Dictionary = state.fleet_ships[0]
	ship.id = "saved-trader"
	var crew_id: String = str(state.crew[0].id)
	assert(orders.assign_trade_route(crew_id, ship.id, "ore", 17, 5).is_empty())
	path = "user://fleet-flight-%d.json" % OS.get_process_id()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.close_menu()
	game._clear_actors()
	game.save_path = path
	game.state = state
	game.flight_origin = SectorPosition.new(Vector3i(2, -1, 3), Vector3(80, 20, -45))
	game._sync_fleet_actors()
	var actor: ShipActor = game.fleet_actors[ship.id]
	actor.position = Vector3(137, 88, -211)
	actor.velocity = Vector3(3.5, -1.25, 6.0)
	var fixed_target_address := SectorPosition.new(Vector3i.ZERO, Vector3(-420, 100, -2000))
	assert(game.save_commander(false), "save moving trader flight")

	var restored = GameStateScript.new()
	assert(restored.load_save(path).is_empty(), "load moving trader")
	var valid_saved: Dictionary = restored._save_data().duplicate(true)
	game.state = restored
	game._clear_actors()
	game.flight_origin = SectorPosition.new(Vector3i(4, 2, -2), Vector3(-150, 30, 90))
	game._sync_fleet_actors()
	var resumed: ShipActor = game.fleet_actors[ship.id]
	var flight: Dictionary = restored.fleet_ships[0].flight
	var saved_address: SectorPosition = SectorPosition.from_save(flight.address)
	assert(resumed.position.distance_to(saved_address.relative_to(game.flight_origin, 60000)) < 0.01,
		"restored trader position rebases from its saved address")
	assert(resumed.velocity.distance_to(Vector3(3.5, -1.25, 6.0)) < 0.01, "restored trader velocity resumes")
	assert(resumed.travel_target.distance_to(fixed_target_address.relative_to(game.flight_origin, 60000)) < 0.01,
		"restoring flight preserves the phase endpoint across origin changes")
	assert(str(flight.phase) == "outbound", "flight phase accompanies position and velocity")
	resumed.set_physics_process(false)
	resumed._physics_process(0.01)
	assert(resumed.velocity.normalized().dot(Vector3(3.5, -1.25, 6.0).normalized()) > 0.95,
		"first resumed physics step preserves the saved velocity direction")
	var before_cull: SectorPosition = game.flight_frame.address_for(resumed, game.flight_origin)
	var far_origin := SectorPosition.new(Vector3i(12, 0, 0))
	game.flight_frame.rebase(game.flight_origin, far_origin)
	assert(bool(resumed.get_meta("spatial_culled", false)), "distant restored trader is culled")
	assert(game.flight_frame.address_for(resumed, far_origin).to_save() == before_cull.to_save(),
		"culled trader retains its absolute flight address")
	game._capture_fleet_flights()
	assert(restored.fleet_ships[0].flight.address == before_cull.to_save(), "culling preserves saved trader address")
	game.flight_frame.rebase(far_origin, game.flight_origin)

	var old_save: Dictionary = restored._save_data().duplicate(true)
	old_save.fleet_ships[0].erase("flight")
	_write_save(old_save)
	assert(restored.load_save(path).is_empty() and not restored.fleet_ships[0].has("flight"), "old fleet saves without flight remain valid")
	var stable: Dictionary = restored._save_data().duplicate(true)
	for bad: Variant in ["invalid", {}, {"phase": "outbound", "address": {}, "velocity": [1, 2, 3]}, {"phase": "orbit", "address": SectorPosition.new().to_save(), "velocity": [1, 2, 3]}, {"phase": "outbound", "address": SectorPosition.new().to_save(), "velocity": [1, 2]}, {"phase": "inbound", "address": SectorPosition.new().to_save(), "velocity": [INF, 0, 0]}, {"phase": "inbound", "address": SectorPosition.new().to_save(), "velocity": [1001, 0, 0]}, {"phase": "outbound", "address": SectorPosition.new(Vector3i(201, 0, 0)).to_save(), "velocity": [0, 0, 0]}]:
		var malformed: Dictionary = valid_saved.duplicate(true)
		malformed.fleet_ships[0].flight = bad
		_write_save(malformed)
		assert(not restored.load_save(path).is_empty() and restored._save_data() == stable,
			"malformed fleet flight rejected atomically: %s" % str(bad))
	for mismatch: String in ["phase", "system"]:
		var invalid_route: Dictionary = valid_saved.duplicate(true)
		if mismatch == "phase":
			invalid_route.crew_orders[crew_id].phase = "inbound"
			invalid_route.fleet_ships[0].system = int(invalid_route.crew_orders[crew_id].destination)
		else:
			invalid_route.fleet_ships[0].system = int(invalid_route.crew_orders[crew_id].destination)
		_write_save(invalid_route)
		assert(not restored.load_save(path).is_empty() and restored._save_data() == stable,
			"reject flight/route %s mismatch transactionally" % mismatch)

	# Restore the valid moving save before checking order cancellation cleanup.
	_write_save(valid_saved)
	assert(restored.load_save(path).is_empty())
	game.state = restored
	game._clear_actors()
	game._sync_fleet_actors()
	var ops = CrewOrdersScript.new(restored)
	assert(ops.tick(600, [], {ship.id: true}).size() == 1, "trader completes an arrived outbound leg")
	assert(not restored.fleet_ships[0].has("flight"), "trade phase transition clears stale flight")
	_write_save(valid_saved)
	assert(restored.load_save(path).is_empty())
	game.state = restored
	game._clear_actors()
	game._sync_fleet_actors()
	ops = CrewOrdersScript.new(restored)
	assert(ops.cancel(crew_id).is_empty())
	assert(not restored.fleet_ships[0].has("flight"), "cancel clears persisted trader flight")
	assert(ops.assign_trade_route(crew_id, ship.id, "ore", 17, 5).is_empty(), "reassign route immediately after cancel")
	game._sync_fleet_actors()
	var reassigned: ShipActor = game.fleet_actors[ship.id]
	assert(reassigned.velocity.is_zero_approx(), "same-frame reassignment does not revive the cancelled flight")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	for file_path: String in [path, path + ".bak"]:
		if FileAccess.file_exists(file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	print("FLEET_FLIGHT_SAVE_OK: moving trader roundtrip, rebasing, legacy and malformed data")
	quit()

func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
