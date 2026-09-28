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
	assert(state.hire("gunner").is_empty())
	var orders = CrewOrdersScript.new(state)
	assert(orders.purchase_ship("Local Mule").is_empty())
	var ship: Dictionary = state.fleet_ships[0]
	ship.id = "saved-patrol"
	var crew_id: String = str(state.crew[0].id)
	assert(orders.assign_patrol(crew_id, ship.id, state.system_index).is_empty())
	path = "user://patrol-flight-%d.json" % OS.get_process_id()
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
	actor.set_physics_process(false)
	actor.set_patrol_center(actor.position + Vector3(80, 12, -90))
	actor._patrol_phase = 127.25
	ship.fuel = 0.0
	var center_address := game.flight_origin.clone() as SectorPosition
	assert(center_address.move_delta(actor._home))
	assert(game.save_commander(false), "save moving patrol")
	var restored = GameStateScript.new()
	assert(restored.load_save(path).is_empty(), "load patrol flight")
	var valid_saved: Dictionary = restored._save_data().duplicate(true)
	game._clear_actors()
	game.state = restored
	game.flight_origin = SectorPosition.new(Vector3i(4, 2, -2), Vector3(-150, 30, 90))
	game._sync_fleet_actors()
	var resumed: ShipActor = game.fleet_actors[ship.id]
	resumed.set_physics_process(false)
	var flight: Dictionary = restored.fleet_ships[0].flight
	var address: SectorPosition = SectorPosition.from_save(flight.address)
	assert(resumed.position.distance_to(address.relative_to(game.flight_origin, 60000)) < 0.01)
	assert(resumed._home.distance_to(center_address.relative_to(game.flight_origin, 60000)) < 0.01,
		"patrol center survives origin change independently of ship position")
	assert(is_equal_approx(resumed._patrol_phase, 127.25), "patrol clock resumes")
	assert(resumed.velocity.distance_to(Vector3(3.5, -1.25, 6)) < 0.01)
	resumed._physics_process(0.01)
	assert(resumed.velocity.distance_to(Vector3(3.5, -1.25, 6)) < 0.01, "empty tank preserves momentum on resumed physics step")
	var far_origin := SectorPosition.new(Vector3i(12, 0, 0))
	game.flight_frame.rebase(game.flight_origin, far_origin)
	game.flight_origin = far_origin
	assert(bool(resumed.get_meta("spatial_culled", false)))
	game._capture_fleet_flights()
	assert(restored.fleet_ships[0].flight.patrol_center == center_address.to_save(),
		"culled patrol center uses the retained actor frame")
	var culled_address: Dictionary = restored.fleet_ships[0].flight.address.duplicate(true)
	game._clear_actors()
	game._sync_fleet_actors()
	assert(bool(game.fleet_actors[ship.id].get_meta("spatial_culled", false)))
	game._capture_fleet_flights()
	assert(restored.fleet_ships[0].flight.address == culled_address)
	assert(restored.fleet_ships[0].flight.patrol_center == center_address.to_save())

	var stable: Dictionary = restored._save_data().duplicate(true)
	for field: String in ["patrol_clock", "nonfinite_clock", "missing_clock", "patrol_center", "distant_center", "extra", "system", "order", "velocity"]:
		var invalid: Dictionary = valid_saved.duplicate(true)
		match field:
			"patrol_clock": invalid.fleet_ships[0].flight.patrol_clock = -1.0
			"nonfinite_clock": invalid.fleet_ships[0].flight.patrol_clock = INF
			"missing_clock": invalid.fleet_ships[0].flight.erase("patrol_clock")
			"distant_center": invalid.fleet_ships[0].flight.patrol_center = SectorPosition.new(Vector3i(201, 0, 0)).to_save()
			"patrol_center": invalid.fleet_ships[0].flight.patrol_center = {}
			"extra": invalid.fleet_ships[0].flight.extra = true
			"system": invalid.fleet_ships[0].system = 17
			"order": invalid.crew_orders.erase(crew_id)
			"velocity": invalid.fleet_ships[0].flight.velocity = [1001, 0, 0]
		_write_save(invalid)
		assert(not restored.load_save(path).is_empty(), "reject malformed patrol " + field)
		assert(restored._save_data() == stable, "malformed patrol load is atomic")
	var legacy: Dictionary = valid_saved.duplicate(true)
	legacy.fleet_ships[0].erase("flight")
	_write_save(legacy)
	assert(restored.load_save(path).is_empty(), "old patrol save remains valid")
	_write_save(valid_saved)
	assert(restored.load_save(path).is_empty())
	game._clear_actors()
	game._sync_fleet_actors()
	var ops = CrewOrdersScript.new(restored)
	assert(ops.cancel(crew_id).is_empty())
	assert(not restored.fleet_ships[0].has("flight"))
	assert(ops.assign_patrol(crew_id, ship.id, restored.system_index).is_empty())
	game._sync_fleet_actors()
	var replacement: ShipActor = game.fleet_actors[ship.id]
	assert(replacement.velocity.is_zero_approx(), "cancel/reassign cannot recapture stale flight")
	assert(is_zero_approx(replacement._patrol_phase))
	game._capture_fleet_flights()
	assert(restored.fleet_ships[0].has("flight"))
	var reassigned_order: Dictionary = restored.crew_orders[crew_id]
	reassigned_order.system = 17
	ops._patrol_leg(reassigned_order)
	assert(int(restored.fleet_ships[0].system) == 17 and not restored.fleet_ships[0].has("flight"),
		"moving patrol to another system clears old coordinates")
	game._capture_fleet_flights()
	assert(not restored.fleet_ships[0].has("flight"), "old actor cannot recapture flight after relocation")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	for file_path: String in [path, path + ".bak"]:
		if FileAccess.file_exists(file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	print("PATROL_FLIGHT_SAVE_OK: rebased and culled course, empty-fuel momentum, atomic load and reassignment")
	quit()

func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
