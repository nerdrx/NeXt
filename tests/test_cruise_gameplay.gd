extends SceneTree

var game: Node
var save_path := ""
var deadline := 0
var minimum_clearance := INF

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.time_scale = 5.0
	Engine.physics_ticks_per_second = 300
	deadline = Time.get_ticks_msec() + 55000
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._clear_actors()
	save_path = "user://cruise-gameplay-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.close_menu()
	var planet: Dictionary = game.world.planets[0]
	var center: Vector3 = game._planet_center(0)
	var radius := float(planet.visual_radius)
	game.pilot.set_flight(true)
	game.pilot.teleport(center - Vector3.UP * (radius + 140.0))
	game.approach_colony(0)
	if not _check(game.pilot.autopilot_active and game.cruise_waypoints.size() > 2, "antipodal route creates detour waypoints"): return
	if not await _fly_route(): return
	var colony: Node3D = game.colonies[0]
	var arrival: Vector3 = colony.to_global(colony.landing_position) + colony.basis.y * 25
	if not _check(game.pilot.position.distance_to(arrival) <= 2.5, "actual pilot reaches colony approach"): return
	game._interact()
	if not _check(not game.pilot.flying and game.manual_planet == 0, "arrival allows port docking"): return
	# Lift off, then physically cross a sector boundary while the route remains active.
	game.pilot.teleport(game._ship_pad() + Vector3(12, 1, 0))
	game._interact()
	if not _check(game.pilot.flying, "lift off for sector route"): return
	var previous_sector: Vector3i = game.flight_origin.sector
	var destination := SectorPosition.new(game.flight_origin.sector, game.flight_origin.local)
	destination.move_delta(game.pilot.position + Vector3.UP * 9000)
	game._start_address_cruise(destination)
	if not await _fly_route(): return
	if not _check(game.flight_origin.sector != previous_sector, "actual cruise crosses floating-origin sector"): return
	if not _check(game.pilot.position.distance_to(destination.relative_to(game.flight_origin, 60000)) <= 2.5, "rebased cruise reaches absolute destination"): return
	var next_destination := SectorPosition.new(destination.sector, destination.local)
	next_destination.move_delta(Vector3.UP * 1000)
	game._start_address_cruise(next_destination)
	Input.action_press("move_forward")
	await physics_frame
	await physics_frame
	Input.action_release("move_forward")
	await process_frame
	await process_frame
	if not _check(not game.pilot.autopilot_active and game.cruise_address == null and game.cruise_waypoints.is_empty(), "manual movement cancels route and clears queued destinations"): return
	_cleanup()
	game.queue_free()
	await process_frame
	await process_frame
	print("CRUISE_GAMEPLAY_OK: antipodal flight, %.2f m minimum body clearance, colony docking, sector rebase arrival, manual cancellation" % minimum_clearance)
	quit()

func _fly_route() -> bool:
	while game.pilot.autopilot_active or game.cruise_address != null:
		await physics_frame
		if not _check(Time.get_ticks_msec() < deadline, "cruise completes within wall-clock deadline"): return false
		for index in game.world.planets.size():
			var center: Variant = game._planet_center(index)
			if center == null: continue
			var clearance: float = game.pilot.position.distance_to(center) - float(game.world.planets[index].visual_radius)
			minimum_clearance = minf(minimum_clearance, clearance)
			if not _check(clearance >= 14.0, "actual flight maintains safe body clearance: %.3f" % clearance): return false
	return true

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("CRUISE_GAMEPLAY_FAILED: " + message)
		_cleanup()
		quit(1)
	return ok

func _cleanup() -> void:
	Input.action_release("move_forward")
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	if is_instance_valid(game):
		game.sound.shutdown()
		game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
