extends SceneTree

var game: Node
var path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.close_menu()
	game._clear_actors()
	path = "user://spatial-gameplay-%d.json" % OS.get_process_id()
	game.save_path = path
	game.pilot.set_physics_process(false)
	game.pilot.set_flight(true)
	game.pilot.position = Vector3(5000, 100, 0)
	game.pilot.velocity = Vector3(42, 0, 0)
	game.cruise_to(Vector3(9000, 100, 0))
	var actor := ShipActor.new()
	actor.position = Vector3(5100, 100, 0)
	game.add_child(actor)
	actor.set_physics_process(false)
	game.actors.append(actor)
	game._rebase_flight()
	if not _check(game.flight_origin.sector == Vector3i(1, 0, 0), "crossing selects new sector origin"): return
	if not _check(game.pilot.position == Vector3(-3192, 100, 0) and game.pilot.velocity == Vector3(42, 0, 0), "rebase preserves location and velocity"): return
	if not _check(game.pilot.autopilot_active and game.pilot.autopilot_target == Vector3(808, 100, 0), "cruise destination shifts with origin"): return
	if not _check(actor.position == Vector3(-3092, 100, 0) and actor._home == actor.position, "actor cached patrol home shifts"): return
	if not _check(game.world.to_global(game.world.launch_position) == game.world.launch_position - Vector3(8192, 0, 0), "dock coordinates shift with geometry"): return
	game.pilot.cancel_autopilot()
	game.pilot.position = Vector3(4090, 100, 0)
	game.pilot.set_physics_process(true)
	game.set_process(true)
	Input.action_press("move_right")
	for frame in 120:
		await physics_frame
		if game.flight_origin.sector.x == 2: break
	Input.action_release("move_right")
	game.set_process(false)
	game.pilot.set_physics_process(false)
	if not _check(game.flight_origin.sector.x == 2 and game.pilot.position.x < -4000, "manual flight crosses sector boundary without a dock teleport"): return
	for i in 100:
		game.pilot.position.x += 8192
		game._rebase_flight()
	if not _check(game.flight_origin.sector.x == 102 and absf(game.pilot.position.x) < 4096, "long travel keeps bounded player coordinates"): return
	if not _check(game.world.get_meta("spatial_culled", false) and not game.world.visible, "distant system geometry is culled"): return
	for i in 100:
		game.pilot.position.x -= 8192
		game._rebase_flight()
	if not _check(game.world.visible and not game.world.get_meta("spatial_culled", false), "returning flight restores system geometry"): return
	for i in 100:
		game.pilot.position.x += 8192
		game._rebase_flight()
	if not _check(game.save_commander(false), "save sector flight location"): return
	game.state.credits = 50000
	game.state.add_module("habitat", Vector3i(0, 0, 3))
	if not game.state.ship_stats().walkable: game.state.add_module("cargo", Vector3i(0, 1, 0))
	game.pilot.restore_view(Vector3(0.3, 0.8, 0.2))
	game.enter_interior()
	if not _check(game.aboard, "enter interior during remote flight"): return
	if not _check(game.save_commander(false) and absf(game.state.location.rotation[1] - 0.8) < 0.001, "interior save retains helm orientation"): return
	game.exit_interior()
	if not _check(absf(game.pilot.rotation.y - 0.8) < 0.001, "return to helm restores orientation"): return
	var saved: Dictionary = game.state.location.duplicate(true)
	game.load_commander()
	if not _check(game.pilot.flying and game.flight_origin.sector.x == 102 and SectorPosition.from_save(game.state.location.address).relative_to(SectorPosition.from_save(saved.address), 1.0) == Vector3.ZERO and absf(game.pilot.rotation.y - float(saved.rotation[1])) < 0.0001, "flight reload resumes remote sector"): return
	var remote_address := SectorPosition.new(game.flight_origin.sector, game.pilot.position + Vector3(100, 0, 0))
	game.session.presence[42] = {"ship_modules": game.state.ship_modules, "ship_layout": game.state.ship_layout, "position": Vector3.ZERO, "rotation": Vector3.ZERO, "address": remote_address.to_save()}
	game._sync_visitors()
	game._update_remote_positions()
	if not _check(game.remote_ships[42].position.distance_to(game.pilot.position) == 100, "remote peer uses absolute address in this origin"): return
	game.session.presence.clear()
	game._sync_visitors()
	game.state.cargo.food = 5
	game.state.hull = 0
	var report: Dictionary = ShipRecovery.destroy_ship(game.state, game.pilot.position, -1, game.flight_origin.to_save())
	if not _check(report.ok, "wreck records remote address"): return
	game._build_system()
	if not _check(not game.recover_wreck(str(report.wreck_id)).is_empty(), "same local coordinates cannot recover a remote wreck"): return
	var wreck: Dictionary = game.state.recovery.wrecks[0]
	game.state.location = {"system": game.state.system_index, "surface": -1, "address": wreck.address, "rotation": [0, 0, 0], "flying": true}
	game._restore_flight_location()
	if not _check(game.recover_wreck(str(report.wreck_id)).is_empty() and game.state.cargo.food == 5, "wreck recovery resolves in distant sector"): return
	game._build_system()
	if not _check(game.flight_origin.sector == Vector3i.ZERO and game.world.visible, "system rebuild restores culling and zero origin"): return
	game.pilot.set_flight(true)
	game.land(0)
	game._build_system()
	if not _check(game.world.launch_position == Vector3(0, 12, -110), "return from surface restores orbital launch coordinates"): return
	_cleanup()
	game.queue_free()
	await process_frame
	print("SPATIAL_GAMEPLAY_OK: rebasing, bounded physics, cruise, actor homes, flight saves, peer addresses, distant wrecks")
	quit()

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("SPATIAL_GAMEPLAY_FAILED: " + message)
		_cleanup()
		quit(1)
	return ok

func _cleanup() -> void:
	game.session.leave()
	game.sound.shutdown()
	for filename: String in [path, path + ".bak"]:
		if FileAccess.file_exists(filename): DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
