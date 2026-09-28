extends SceneTree

var game: Node

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	print("SHIP_CREW_STAGE: loading main scene")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	print("SHIP_CREW_STAGE: main scene ready")
	game.set_process(false)
	game._clear_actors()
	var path := "user://ship-crew-%d.json" % OS.get_process_id()
	game.save_path = path
	game.state.credits = 50000
	if not _check(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty()): return
	for role in ["gunner", "engineer", "trader"]:
		if not _check(game.state.hire(role).is_empty()): return
	game.apply_ship_stats()
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(4090, 1800, 1000))
	game.pilot.restore_flight_velocity(Vector3(90, 0, 0))
	game.close_menu()
	print("SHIP_CREW_STAGE: boarding")
	game.enter_interior()
	await create_timer(0.5).timeout
	if not _check(game.ship_crew.size() == 3, "hired crew materialize aboard"): return
	if not _check(game.pilot.get_collision_layer_value(4) and game.pilot.get_collision_mask_value(3), "aboard player collides with crew on its dedicated occupant layer"): return
	print("SHIP_CREW_STAGE: crew spawned")
	var member: ShipCrew = game.ship_crew[0]
	var member_id: String = member.actor_id
	if not _check(member.display_name == game.state.crew[0].name and member.role == "gunner"): return
	if not _check(member.is_on_floor() and game.flight_origin.sector.x == 1, "crew stand on coasting rebased ship"): return
	var local: Vector3 = member.position
	game.aboard_cruise = true
	game.aboard_cruise_target = game.coasting_hull.position + Vector3(180, 70, -100)
	await create_timer(0.8).timeout
	if not _check(member.is_on_floor() and member.position.distance_to(local) < 0.06, "rotating deck carries stationed crew"): return
	var engineer: ShipCrew = _crew_role("engineer")
	var trader: ShipCrew = _crew_role("trader")
	var engineer_target: Vector3 = _force_reachable_stop(engineer)
	var trader_target: Vector3 = _force_reachable_stop(trader)
	if not _check(engineer_target.is_finite() and trader_target.is_finite(), "engineer and trader have reachable local stops"): return
	var engineer_start: Vector3 = engineer.position
	var trader_start: Vector3 = trader.position
	var heading_before: Vector3 = game.interior.global_basis.z
	game.aboard_cruise = true
	game.aboard_cruise_target = game.coasting_hull.position + Vector3(180, 70, -100)
	var engineer_moved := false
	var trader_moved := false
	var cabin_turned := false
	for _frame: int in 240:
		game._process(1.0 / 60.0)
		await physics_frame
		engineer_moved = engineer_moved or engineer.position.distance_to(engineer_start) > 0.2
		trader_moved = trader_moved or trader.position.distance_to(trader_start) > 0.2
		cabin_turned = cabin_turned or game.interior.global_basis.z.dot(heading_before) < 0.999
		if engineer_moved and trader_moved and cabin_turned: break
	if not _check(engineer_moved and trader_moved, "engineer and trader follow reachable cabin paths while moving"): return
	if not _check(cabin_turned and engineer.is_on_floor() and trader.is_on_floor(), "roaming crew stay supported through coasting and cabin turns"): return
	for _frame: int in 18:
		game._process(1.0 / 60.0)
		await physics_frame
	print("SHIP_CREW_STAGE: walking verified; capturing")
	await _capture_walking_crew(engineer)
	print("SHIP_CREW_STAGE: capture complete")
	game.open_menu("overview")
	game._process(1.0 / 60.0)
	var engineer_paused: Vector3 = engineer.position
	var trader_paused: Vector3 = trader.position
	for _frame: int in 12: await physics_frame
	if not _check(not engineer.active and not trader.active, "main process pauses crew with command menu open"): return
	if not _check(engineer.position.distance_to(engineer_paused) < 0.03 and trader.position.distance_to(trader_paused) < 0.03, "paused crew hold local position while cabin coasts"): return
	game.close_menu()
	game._process(1.0 / 60.0)
	game.stop_cruise()
	game.pilot.teleport(member.global_position + game.interior.global_basis * Vector3(0.5, 0.1, 0.0))
	game.pilot.set_walk_up(game.interior.global_basis.y)
	game.pilot.camera.look_at(member.global_position + member.global_basis.y * 1.3, game.interior.global_basis.y)
	await physics_frame
	if not _check(game._near_ship_crew() == member and "Talk to" in game.interaction_hint()): return
	var talk := InputEventKey.new()
	talk.pressed = true
	talk.keycode = KEY_F
	game._unhandled_key_input(talk)
	if not _check(game.ui_open and game.deck.page == "fleet" and game.crew_focus_id == member_id, "nearby crew interaction opens their operations"): return
	game.close_menu()
	if DisplayServer.get_name() != "headless":
		var capture_camera := Camera3D.new()
		game.interior.add_child(capture_camera)
		capture_camera.position = (member.position / ShipInterior.CELL).round() * ShipInterior.CELL + Vector3(0.6, 1.65, 0.9)
		capture_camera.look_at(member.global_position + member.global_basis.y * 1.2, game.interior.global_basis.y)
		capture_camera.make_current()
		# Review identification after transient HUD notifications expire.
		game.hud._process(6.0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/ship-crew-aboard.png")
		game.pilot.camera.make_current()
		capture_camera.queue_free()
	if not _check(game.crew_operations().assign_ship_defense(member_id).is_empty()): return
	game._process(0)
	if not _check("Defending ship" in member.get_node("DutyLabel").text): return
	member.take_damage(1000)
	await create_timer(0.2).timeout
	if not _check(game.state.crew.size() == 2 and not game.state.crew_orders.has(member_id), "crew casualty removes their duty and roster entry"): return
	var saved := GameState.new()
	if not _check(saved.load_save(path).is_empty() and saved.crew.size() == 2): return
	game.exit_interior()
	if not _check(game.ship_crew.is_empty()): return
	if not _check(not game.pilot.get_collision_layer_value(4) and not game.pilot.get_collision_mask_value(3), "cabin collision rules are removed on exit"): return
	game.enter_interior()
	game.exit_interior()
	await physics_frame
	await physics_frame
	if not _check(game.ship_crew.is_empty(), "delayed spawn cannot recreate crew after exit"): return
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	for filename in [path, path + ".bak"]:
		if FileAccess.file_exists(filename): DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
	print("SHIP_CREW_GAMEPLAY_OK: named bodies, engineer/trader roaming, cabin-turn support, menu pause, interaction, casualty save and exit cleanup")
	quit()

func _crew_role(role: String) -> ShipCrew:
	for member: ShipCrew in game.ship_crew:
		if member.role == role: return member
	return null

func _force_reachable_stop(member: ShipCrew) -> Vector3:
	for index: int in member._stops.size():
		var destination: Vector3 = member._stops[index]
		if absf(destination.y - member.position.y) > 0.5 or destination.distance_to(member.position) < 1.0: continue
		if game.interior.crew_path(member.position, destination).is_empty(): continue
		member._next_stop = index
		member._room_wait = 0.0
		member._local_path.clear()
		return destination
	return Vector3.INF

func _capture_walking_crew(member: ShipCrew) -> void:
	if DisplayServer.get_name() == "headless": return
	var capture_camera := Camera3D.new()
	game.interior.add_child(capture_camera)
	capture_camera.position = (member.position / ShipInterior.CELL).round() * ShipInterior.CELL + Vector3(0.6, 1.65, 0.9)
	capture_camera.look_at(member.global_position + member.global_basis.y * 1.2, game.interior.global_basis.y)
	capture_camera.make_current()
	# Review identification after transient HUD notifications expire.
	game.hud._process(6.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/ship-crew-walking.png")
	game.pilot.camera.make_current()
	capture_camera.queue_free()

# Keep setup and failure gates active in exported release builds.
func _check(condition: bool, message: String = "Crew gameplay check failed") -> bool:
	if condition: return true
	push_error(message)
	quit(1)
	return false
