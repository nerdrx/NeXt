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
	save_path = "user://coasting-interior-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.state.credits = 50000
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	game.apply_ship_stats()
	game.pilot.set_flight(true)
	var anchor := Vector3(4090, 1800, 1000)
	game.pilot.teleport(anchor)
	game.pilot.restore_view(Vector3(0.2, 0.3, 0.15))
	var motion := Vector3(180, 0, 0)
	game.pilot.restore_flight_velocity(motion)
	game.open_menu("overview")
	await physics_frame
	await physics_frame
	assert(game.pilot.velocity.is_zero_approx() and game.pilot.flight_velocity() == motion)
	var board: Button = _button(game.deck, "WALK YOUR SHIP")
	assert(board != null)
	board.pressed.emit()
	assert(game.aboard and is_instance_valid(game.coasting_hull))
	await create_timer(0.4).timeout
	assert(game.pilot.is_on_floor())
	assert(game.flight_origin.sector.x == 1, "moving hull rebases the walking frame")
	var local_start: Vector3 = game.interior.to_local(game.pilot.position)
	await create_timer(0.2).timeout
	assert(game.interior.to_local(game.pilot.position).distance_to(local_start) < 0.05, "passenger stays fixed relative to coasting deck")
	Input.action_press("move_forward")
	await create_timer(0.4).timeout
	Input.action_release("move_forward")
	assert(game.interior.to_local(game.pilot.position).z < local_start.z - 1, "passenger walks relative to moving frame")
	var address := SectorPosition.new(game.flight_origin.sector, game.coasting_hull.position)
	assert(address.relative_to(SectorPosition.new(), 60000).x > anchor.x + 100)
	assert(game.save_commander(false))
	var saved := GameState.new()
	assert(saved.load_save(save_path).is_empty())
	var saved_address: SectorPosition = SectorPosition.from_save(saved.location.address)
	assert(saved_address.relative_to(game.flight_origin, 60000).distance_to(game.coasting_hull.position) < 0.01)
	var position: Vector3 = game.coasting_hull.position
	game.exit_interior()
	assert(game.pilot.flying and game.pilot.position.distance_to(position) < 0.01)
	assert(game.pilot.velocity.is_equal_approx(motion) and game.pilot._flight_velocity.is_equal_approx(motion))
	game.enter_interior()
	game.load_commander()
	assert(not game.aboard and game.pilot.flying and not is_instance_valid(game.coasting_hull))
	assert(game.pilot.position.distance_to(position) < 0.01 and game.pilot.flight_velocity() == motion, "loading while aboard restores the saved moving helm")
	game.open_menu("overview")
	await physics_frame
	await physics_frame
	assert(game.pilot.velocity.is_zero_approx())
	assert(game.save_commander(false))
	game.load_commander()
	assert(game.pilot.flight_velocity() == motion, "menu saving retains stored flight momentum")
	game.state.location.erase("velocity")
	game._build_system()
	game._restore_flight_location()
	assert(game.pilot.flight_velocity().is_zero_approx(), "legacy flight saves start at rest")
	game.close_menu()
	var wall := StaticBody3D.new()
	game.add_child(wall)
	wall.position = position + Vector3(25, 0, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 100, 100)
	shape.shape = box
	wall.add_child(shape)
	game.pilot.restore_flight_velocity(Vector3(80, 0, 0))
	var health: float = game.state.hull + game.state.shield
	game.enter_interior()
	await create_timer(0.6).timeout
	assert(not game.aboard and game.pilot.flying, "hull impact returns commander to helm")
	assert(game.state.hull + game.state.shield < health, "coasting collision uses ship damage")
	assert(game.pilot.position.x < wall.position.x - 1 and game.pilot.velocity.length() < 0.1)
	game.state.shield = 0
	game.state.hull = 1
	game.pilot.teleport(wall.position - Vector3(20, 0, 0))
	game.pilot.restore_flight_velocity(Vector3(100, 0, 0))
	game.enter_interior()
	await create_timer(0.5).timeout
	assert(not game.aboard and not game.pilot.flying and not is_instance_valid(game.coasting_hull))
	assert(game.state.hull > 0 and game.state.recovery.wrecks.size() == 1, "fatal coasting collision follows insured wreck recovery")
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game.queue_free()
	await process_frame
	await process_frame
	print("COASTING_INTERIOR_OK: relative walking, stationary passenger, origin rebase, save address, momentum return, collision damage and insured wreck recovery")
	quit()

func _button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child: Node in node.get_children():
		var found := _button(child, title)
		if found != null: return found
	return null
