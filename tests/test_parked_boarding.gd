extends SceneTree

var game: Node
var save_path: String

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	game.close_menu()
	save_path = "user://parked-boarding-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.state.credits = 100000
	var pad: Vector3 = game._ship_pad()
	game.pilot.set_flight(false)
	game.pilot.teleport(pad)
	await physics_frame
	if not _check(not game.state.ship_stats().walkable, "starter ship has no walkable interior"): return
	if not _check(not game.board_parked_interior() and not game.aboard, "non-walkable ship is rejected"): return
	if not _check(game.interaction_hint() == "E: Launch ship", "non-walkable hint keeps launch on E"): return
	if not _check(game.state.refit_hull_family("pathfinder").is_empty(), "refit pathfinder"): return
	game.apply_ship_stats()
	game.rebuild_player_ship()
	pad = game._ship_pad()
	var access := game.ship_display.get_node_or_null("BoardingAccess") as Node3D
	if not _check(access != null, "family has marked parked access"): return
	var ramp_mesh := access.get_node("Ramp") as MeshInstance3D
	var ramp_normals: PackedVector3Array = ramp_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for index in range(6):
		if not _check(ramp_normals[index].y > 0.9, "ramp walking surface renders outward"): return
	game.pilot.teleport(access.to_global(Vector3(1.4, 0.6, 0)))
	await create_timer(0.6).timeout
	if not _check(game.pilot.is_on_floor(), "walking capsule is supported by the access ramp"): return
	var ramp_point: Vector3 = access.to_local(game.pilot.global_position)
	if not _check(ramp_point.x > 0 and ramp_point.x < 2.8 and absf(ramp_point.z) < 0.75 and ramp_point.y > -0.7,
		"capsule rests above ground on ramp slope"): return
	game.ship_display.hide()
	await process_frame
	await physics_frame
	for shape: CollisionShape3D in access.find_children("*", "CollisionShape3D", true, false):
		if not _check(shape.disabled, "hidden parked access cannot collide during flight or boarding"): return
	game.ship_display.show()
	await process_frame
	await physics_frame
	for shape: CollisionShape3D in access.find_children("*", "CollisionShape3D", true, false):
		if not _check(not shape.disabled, "visible parked access restores collision"): return
	game.pilot.teleport(pad)
	await physics_frame
	if not _check(game._near_ship_boarding(), "pilot stands near parked ship"): return
	if not _check("F: Walk aboard" in game.interaction_hint(), "parked walkable ship offers F hint"): return
	game.pilot.teleport(pad + Vector3(200, 0, 0))
	if not _check(not game.board_parked_interior() and not game.aboard, "200 m distance rejects boarding"): return
	game.pilot.teleport(pad)
	game.pilot.set_flight(true)
	if not _check(not game.board_parked_interior() and not game.aboard, "flying pilot cannot board"): return
	game.pilot.set_flight(false)
	game.open_menu("overview")
	if not _check(not game.board_parked_interior() and not game.aboard, "open UI rejects boarding"): return
	game.close_menu()
	game.jump_charge = 1.0
	if not _check(not game.board_parked_interior() and not game.aboard, "jump charge rejects boarding"): return
	game.jump_charge = 0.0
	game.session.connected = true
	if not _check(game.board_parked_interior() and game.aboard, "connected session permits own parked interior"): return
	game.exit_interior()
	game.session.connected = false

	var outside: Vector3 = game.pilot.position
	var f_key := InputEventKey.new()
	f_key.pressed = true
	f_key.keycode = KEY_F
	game._unhandled_key_input(f_key)
	await create_timer(0.35).timeout
	if not _check(game.aboard and game.pilot.is_on_floor(), "F enters physical parked interior"): return
	var entry_cell: Vector3i = access.get_meta("entry_cell")
	var cabin_position: Vector3 = game.interior.to_local(game.pilot.global_position)
	var expected_position := Vector3(entry_cell) * ShipBlueprint.CELL_SIZE
	if not _check(Vector2(cabin_position.x, cabin_position.z).distance_to(Vector2(expected_position.x, expected_position.z)) < 0.1,
		"F enters the room adjoining the exterior hatch"): return
	if not _check((-game.pilot.global_basis.z).dot(-game.interior.global_basis.x) > 0.99,
		"boarding faces into the ship"): return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png("user://parked-boarding.png") == OK, "capture parked interior"): return
	if not _check(not game.board_parked_interior(), "already aboard pilot cannot board again"): return
	if not _check("E: Return outside" in game.interaction_hint(), "parked interior offers E return hint"): return
	var e_key := InputEventKey.new()
	e_key.pressed = true
	e_key.keycode = KEY_E
	game._unhandled_key_input(e_key)
	# Check restoration before the next physics step can move the walking capsule.
	if not _check(not game.aboard and not game.pilot.flying and game.pilot.position.distance_to(outside) < 0.001,
		"E exits and restores outside position (aboard=%s flying=%s distance=%.3f)" % [game.aboard, game.pilot.flying, game.pilot.position.distance_to(outside)]): return
	for family: String in ["merchant", "ranger"]:
		if not _check(game.state.refit_hull_family(family).is_empty(), "refit " + family): return
		game.apply_ship_stats()
		game.rebuild_player_ship()
		game.pilot.teleport(game._ship_pad())
		var family_access := game.ship_display.get_node("BoardingAccess") as Node3D
		var family_cell: Vector3i = family_access.get_meta("entry_cell")
		if not _check(game.board_parked_interior(), "board " + family): return
		await create_timer(0.35).timeout
		var actual: Vector3 = game.interior.to_local(game.pilot.global_position)
		var target := Vector3(family_cell) * ShipBlueprint.CELL_SIZE
		if not _check(game.pilot.is_on_floor() and Vector2(actual.x, actual.z).distance_to(Vector2(target.x, target.z)) < 0.1,
			family + " hatch arrives in supported adjoining room"): return
		game._unhandled_key_input(e_key)
	game._unhandled_key_input(e_key)
	if not _check(game.pilot.flying, "E still launches ship from pad"): return
	_cleanup()
	game.queue_free()
	await process_frame
	print("PARKED_BOARDING_OK: guards, hints, physical F entry, E exit and launch")
	quit()

func _check(ok: bool, message: String) -> bool:
	if ok: return true
	push_error("PARKED_BOARDING_FAIL: " + message)
	_cleanup()
	quit(1)
	return false

func _cleanup() -> void:
	if game != null:
		game.sound.shutdown()
		game.session.leave()
	for file_path: String in [save_path, save_path + ".bak"]:
		if not save_path.is_empty() and FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
