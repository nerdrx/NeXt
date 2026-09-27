extends SceneTree

var game: Node
var save_path: String

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	save_path = "user://anchored-interior-%d.json" % OS.get_process_id()
	game.save_path = save_path
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state = GameState.new()
	game._clear_actors()
	game.close_menu()
	save_path = "user://anchored-interior-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.state.credits = 50000
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	assert(game.state.add_module("cargo", Vector3i(0, 1, 2)).is_empty())
	game.apply_ship_stats()
	game.rebuild_player_ship()
	var outside: Vector3 = game.pilot.position
	game.enter_interior()
	assert(game.aboard)
	await create_timer(0.4).timeout
	assert(game.pilot.is_on_floor())
	assert(game.pilot.position.distance_to(game._ship_pad()) < 20)
	game.exit_interior()
	assert(game.pilot.position.is_equal_approx(outside) and game.ship_display.visible)
	game.pilot.set_flight(true)
	var anchor := Vector3(1600, 1800, 1600)
	var view := Vector3(0.4, 0.7, 0.3)
	game.pilot.teleport(anchor)
	game.pilot.restore_view(view)
	game.pilot.velocity = Vector3.ZERO
	var hull_basis: Basis = game.pilot.camera.global_basis
	game.enter_interior()
	assert(game.aboard and game.interior.global_basis.is_equal_approx(hull_basis))
	assert(game.pilot.up_direction.is_equal_approx(hull_basis.y))
	var core_floor := Vector3(0, 0, 2) * ShipInterior.CELL
	var expected_floor := anchor + hull_basis * (core_floor - Vector3(0, 1.4, 4.2) - Vector3.UP * 1.23)
	assert(game.interior.to_global(core_floor).distance_to(expected_floor) < 0.001)
	await create_timer(0.4).timeout
	assert(game.pilot.is_on_floor())
	assert(game.pilot.position.distance_to(anchor) < 20)
	var start: Vector3 = game.interior.to_local(game.pilot.position)
	Input.action_press("move_forward")
	await create_timer(0.4).timeout
	Input.action_release("move_forward")
	assert(game.interior.to_local(game.pilot.position).z < start.z - 1.0, "walk through doorway in rotated hull")
	var lift := InputEventKey.new()
	lift.pressed = true
	lift.keycode = KEY_PAGEUP
	game._unhandled_key_input(lift)
	await create_timer(0.3).timeout
	assert(game.interior_deck == 1 and game.pilot.is_on_floor())
	assert(game.pilot.up_direction.is_equal_approx(hull_basis.y))
	assert(game.save_commander(false))
	var saved := GameState.new()
	assert(saved.load_save(save_path).is_empty())
	var saved_address: SectorPosition = SectorPosition.from_save(saved.location.address)
	assert(saved_address.relative_to(game.flight_origin, 60000).distance_to(anchor) < 0.01)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/anchored-interior.png")
	game.exit_interior()
	assert(game.pilot.flying and game.pilot.position.distance_to(anchor) < 0.01)
	assert(game.pilot.camera.global_basis.is_equal_approx(hull_basis))
	assert(not game.ship_display.visible)
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game.queue_free()
	await process_frame
	await process_frame
	print("ANCHORED_INTERIOR_OK: parked hull, rotated gravity, doorway, lift, saved helm position and return orientation")
	quit()
