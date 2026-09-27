extends SceneTree

var game: Node

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	game.close_menu()
	game.state.credits = 50000
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	game.apply_ship_stats()
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(4090, 1800, 1000))
	game.pilot.flight_speed = 220
	var target := Vector3(4370, 1900, 850)
	game.cruise_to(target)
	var intermediate := Vector3(4190, 1850, 850)
	game.cruise_waypoints.push_front(SectorPosition.new(Vector3i.ZERO, intermediate))
	game.pilot.autopilot_to(intermediate)
	assert(game.pilot.autopilot_active)
	game.enter_interior()
	assert(game.aboard and game.aboard_cruise)
	await create_timer(0.5).timeout
	assert(game.pilot.is_on_floor())
	var local: Vector3 = game.interior.to_local(game.pilot.position)
	var forward: Vector3 = -game.coasting_hull.global_basis.z
	await create_timer(0.5).timeout
	assert(game.pilot.is_on_floor() and game.interior.to_local(game.pilot.position).distance_to(local) < 0.05, "turning deck carries idle passenger")
	assert(forward.distance_to(-game.coasting_hull.global_basis.z) > 0.05, "hull actively turns during cruise")
	assert(game.pilot.up_direction.is_equal_approx(game.interior.global_basis.y.normalized()), "passenger gravity follows rotating deck")
	assert(game.flight_origin.sector.x == 1, "aboard cruise crosses origin boundary")
	Input.action_press("move_forward")
	await create_timer(0.35).timeout
	Input.action_release("move_forward")
	assert(game.interior.to_local(game.pilot.position).z < local.z - 0.8 and game.aboard_cruise, "walking input does not cancel ship cruise")
	var helm_basis: Basis = game.coasting_hull.global_basis
	var motion: Vector3 = game.coasting_hull.velocity
	game.exit_interior()
	assert(game.pilot.autopilot_active and game.pilot.flight_velocity().is_equal_approx(motion))
	assert(game.pilot.camera.global_basis.is_equal_approx(helm_basis), "returning helm matches turned hull")
	game.enter_interior()
	for frame in 1800:
		await physics_frame
		if not game.aboard_cruise: break
	var destination: Vector3 = SectorPosition.new(Vector3i.ZERO, target).relative_to(game.flight_origin, 60000)
	assert(game.aboard and not game.aboard_cruise and game.cruise_address == null)
	assert(game.coasting_hull.position.distance_to(destination) <= 2.1 and game.coasting_hull.velocity.is_zero_approx(), "route arrives and holds with passenger aboard")
	game.exit_interior()
	game.cruise_to(game.pilot.position + Vector3(100, 0, 0))
	game.enter_interior()
	game.open_menu("overview")
	var stop: Button = _button(game.deck, "STOP CRUISE")
	assert(stop != null)
	stop.pressed.emit()
	assert(not game.aboard_cruise and game.cruise_address == null and game.coasting_hull.velocity.is_zero_approx(), "menu safely stops cruise while aboard")
	game.close_menu()
	game.exit_interior()
	assert(not game.pilot.autopilot_active)
	var wall := StaticBody3D.new()
	game.add_child(wall)
	wall.position = game.pilot.position + Vector3(0, 0, -4)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 20, 0.2)
	collision.shape = box
	wall.add_child(collision)
	await physics_frame
	game.cruise_to(game.pilot.position + Vector3(0, 0, -100))
	game.enter_interior()
	await create_timer(0.1).timeout
	assert(game.aboard and not game.aboard_cruise and game.cruise_address == null and game.coasting_hull.velocity.is_zero_approx(), "blocked route stops while keeping passenger aboard")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("ABOARD_CRUISE_OK: rotating deck, passenger walking, origin rebase, helm handoff, route arrival and menu stop")
	quit()

func _button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child: Node in node.get_children():
		var found := _button(child, title)
		if found != null: return found
	return null
