extends SceneTree

const GameScene = preload("res://scenes/main.tscn")

var game: Node
var save_path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = GameScene.instantiate()
	save_path = "user://player-lifts-%d.json" % OS.get_process_id()
	game.save_path = save_path
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.state = GameState.new()
	game._clear_actors()
	game.close_menu()
	game.save_path = save_path
	game.state.credits = 50000
	var issue: String = game.state.add_module("habitat", Vector3i(0, 0, 3))
	if not _check(issue.is_empty(), "fixture adds a lower habitat"): return
	issue = game.state.add_module("cargo", Vector3i(0, 1, 2))
	if not _check(issue.is_empty(), "fixture adds a connected upper cargo room"): return
	game.apply_ship_stats()
	game.rebuild_player_ship()

	game.pilot.set_flight(true)
	var anchor := Vector3(1600.0, 1800.0, 1600.0)
	game.pilot.teleport(anchor)
	var view := Vector3(0.4, 0.7, 0.3)
	game.pilot.restore_view(view)
	game.pilot.velocity = Vector3.ZERO
	var expected_up: Vector3 = game.pilot.camera.global_basis.y.normalized()
	game.enter_interior()
	if not _check(game.aboard and game.interior != null and 1 in game.interior.decks, "actual main scene enters a two-deck cabin"): return
	if not _check(game.interior.global_basis.y.normalized().is_equal_approx(expected_up), "cabin preserves the tilted hull up direction"): return
	await create_timer(0.4).timeout
	if not _check(game.pilot.is_on_floor() and game.interior_deck == 0, "pilot settles on the lower deck"): return

	var landing_global: Vector3 = game.interior.spawn_on_deck(1)
	var landing_local: Vector3 = game.interior.to_local(landing_global)
	var crew := ShipCrew.new()
	crew.actor_id = "player-lift-occupant-test"
	crew.display_name = "Landing Occupant"
	crew.role = "engineer"
	crew.position = landing_local
	game.interior.add_child(crew)
	await create_timer(0.3).timeout
	var original_position: Vector3 = game.pilot.global_position
	var original_velocity: Vector3 = game.interior.global_basis.x * 1.7
	game.pilot.velocity = original_velocity
	_press_page(KEY_PAGEUP)
	if not _check(game.interior_deck == 0 and game.pilot.global_position.is_equal_approx(original_position), "layer-4 crew at the landing blocks player transfer atomically"): return
	if not _check(game.pilot.velocity.is_equal_approx(original_velocity), "blocked lift does not clear player velocity"): return

	# Move the body immediately; collision broadphase may conservatively reject once.
	crew.position = Vector3(100.0, landing_local.y, 100.0)
	_press_page(KEY_PAGEUP)
	if game.interior_deck == 0:
		await physics_frame
		await physics_frame
		_press_page(KEY_PAGEUP)
	await create_timer(0.3).timeout
	if not _check(game.interior_deck == 1, "page up succeeds after the occupant leaves the landing"): return
	if not _check(game.pilot.is_on_floor(), "player lands after page up"): return
	if not _check(game.pilot.up_direction.is_equal_approx(expected_up), "page-up landing keeps the tilted cabin up direction"): return
	if not _check(game.pilot.global_position.distance_to(landing_global) < 1.0, "page up lands at the selected deck spawn"): return

	_press_page(KEY_PAGEDOWN)
	await create_timer(0.3).timeout
	if not _check(game.interior_deck == 0 and game.pilot.is_on_floor(), "page down returns to the lower deck"): return
	original_position = game.pilot.global_position
	original_velocity = game.interior.global_basis.x * 1.3 + game.interior.global_basis.z * 0.4
	game.pilot.velocity = original_velocity
	_press_page(KEY_PAGEDOWN)
	if not _check(game.interior_deck == 0 and game.pilot.global_position.is_equal_approx(original_position), "page down at minimum deck leaves position unchanged"): return
	if not _check(game.pilot.velocity.is_equal_approx(original_velocity), "page down at minimum deck preserves velocity"): return

	game.open_menu("overview")
	_press_page(KEY_PAGEUP)
	if not _check(game.interior_deck == 0, "open menu prevents deck transfer"): return
	game.close_menu()
	game.jump_charge = 1.0
	_press_page(KEY_PAGEUP)
	if not _check(game.interior_deck == 0, "jump charging prevents deck transfer"): return
	game.jump_charge = 0.0

	var blocker := StaticBody3D.new()
	blocker.name = "StaticLiftLandingBlocker"
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	blocker.position = landing_local
	var blocker_shape := CollisionShape3D.new()
	var blocker_box := BoxShape3D.new()
	blocker_box.size = Vector3(1.2, 1.8, 1.2)
	blocker_shape.shape = blocker_box
	blocker_shape.position.y = 0.9
	blocker.add_child(blocker_shape)
	game.interior.add_child(blocker)
	await physics_frame
	await physics_frame
	original_position = game.pilot.global_position
	original_velocity = game.interior.global_basis.z * 0.8
	game.pilot.velocity = original_velocity
	_press_page(KEY_PAGEUP)
	if not _check(game.interior_deck == 0 and game.pilot.global_position.is_equal_approx(original_position), "static geometry blocks the destination landing"): return
	if not _check(game.pilot.velocity.is_equal_approx(original_velocity), "blocked static landing preserves player velocity"): return
	blocker.queue_free()
	await physics_frame
	await physics_frame
	_press_page(KEY_PAGEUP)
	await create_timer(0.3).timeout
	if not _check(game.interior_deck == 1 and game.pilot.is_on_floor(), "clear static landing accepts the transfer"): return
	if not _check(game.pilot.up_direction.is_equal_approx(expected_up), "second landing retains cabin gravity"): return

	crew.queue_free()
	game.exit_interior()
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	for filename in [save_path, save_path + ".bak"]:
		if FileAccess.file_exists(filename): DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
	print("PLAYER_LIFTS_OK: blocked crew/static landings, guards, deck bounds and tilted gravity")
	quit()

func _press_page(key: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	game._unhandled_key_input(event)

func _check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("PLAYER_LIFTS_FAIL: " + message)
	quit(1)
	return false
