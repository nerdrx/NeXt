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
	save_path = "user://flight-impact-%d.json" % OS.get_process_id()
	game.save_path = save_path
	var origin := Vector3(1500, 1500, 1500)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 100, 1)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.position = origin + Vector3(0, 0, -5)
	game.pilot.set_flight(true)
	game.pilot.teleport(origin)
	game.state.shield = 10.0
	game.state.hull = 100.0
	await physics_frame
	await physics_frame
	game.cruise_system_to(origin + Vector3(0, 0, -30))
	for frame in 60:
		await physics_frame
	if not _check(not game.pilot.autopilot_active and game.cruise_address == null and game.cruise_waypoints.is_empty(), "blocked cruise clears the full route"): return
	if not _check(game.pilot.flight_velocity().is_zero_approx() and game.state.shield == 10.0 and game.state.hull == 100.0 and "Obstacle ahead" in game.hud.message, "cruise obstruction brakes to a stop without damage and explains manual recovery"): return
	game.pilot._flight_velocity = Vector3(0, 0, -150)
	for frame in 12:
		await physics_frame
		if game.state.hull < 100: break
	if not _check(game.state.shield == 0 and game.state.hull > 0 and game.state.hull < 100, "physical impact depletes shield then hull"): return
	if not _check(game.shield_delay == 6 and "Collision!" in game.hud.message, "impact feedback and recharge delay"): return
	var hull: float = game.state.hull
	game._flight_impact(NAN)
	game._flight_impact(25.0)
	if not _check(game.state.hull == hull, "invalid and gentle impacts have no damage"): return
	await create_timer(0.8).timeout
	var wrecks: int = game.state.recovery.wrecks.size()
	game.state.credits = 50000
	game.state.hull = 1.0
	game.state.shield = 0.0
	game.pilot.teleport(origin)
	game.pilot._flight_velocity = Vector3(0, 0, -200)
	for frame in 15:
		await physics_frame
		if not game.pilot.flying: break
	if not _check(not game.pilot.flying and game.state.hull > 0 and game.state.recovery.wrecks.size() == wrecks + 1, "fatal collision invokes insured rescue and creates a wreck"): return
	var restored := GameState.new()
	if not _check(restored.load_save(save_path).is_empty() and restored.recovery.wrecks.size() == game.state.recovery.wrecks.size(), "collision rescue is persisted"): return
	wall.queue_free()
	_cleanup()
	game.queue_free()
	await process_frame
	await process_frame
	print("FLIGHT_IMPACT_GAMEPLAY_OK: shields, hull, impact feedback, rescue and saved wreck")
	quit()

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		_cleanup()
		quit(1)
	return ok

func _cleanup() -> void:
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
