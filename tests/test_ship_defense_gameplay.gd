extends SceneTree

var game: Node

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	var path := "user://ship-defense-%d.json" % OS.get_process_id()
	game.save_path = path
	game.state.credits = 50000
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	assert(game.state.hire("gunner").is_empty())
	game.apply_ship_stats()
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(1500, 1800, 1000))
	game.open_menu("fleet")
	var assign: Button = _button(game.deck, "DEFEND MY SHIP")
	assert(assign != null)
	await process_frame
	await process_frame
	assign.grab_focus()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/ship-defense-menu.png")
	assign.pressed.emit()
	var crew_id: String = game.state.crew[0].id
	assert(game.state.crew_orders[crew_id].kind == "defend", "real menu assigns named gunner")
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty() and restored.crew_orders[crew_id].kind == "defend")
	game.close_menu()
	game.enter_interior()
	var pirate := ShipActor.new()
	pirate.actor_id = "defense-fixture"
	pirate.position = game.coasting_hull.position + Vector3(10, 30, -80)
	game.add_child(pirate)
	pirate.set_physics_process(false)
	pirate.destroyed.connect(game._actor_destroyed)
	game.actors.append(pirate)
	pirate.hp = 1000
	var health: float = pirate.hp + pirate.shields
	await create_timer(1).timeout
	assert(game.aboard and pirate.hp + pirate.shields < health, "gunner fires real mounted weapon while commander is aboard")
	assert(game.set_ship_systems_online(false).is_empty())
	health = pirate.hp + pirate.shields
	await create_timer(1).timeout
	assert(pirate.hp + pirate.shields == health, "powered-down ship cannot fire crew weapons")
	assert(game.set_ship_systems_online(true).is_empty())
	await create_timer(1).timeout
	assert(pirate.hp + pirate.shields < health, "restarting systems restores crew defense")
	game.state.credits = 0
	game.crew_operations().tick(CrewOrders.TRIP_SECONDS)
	assert(game.state.crew_orders[crew_id].paused)
	health = pirate.hp + pirate.shields
	await create_timer(1).timeout
	assert(pirate.hp + pirate.shields == health, "unpaid gunner stops firing")
	game.state.credits = 500
	game.crew_operations().tick(1)
	assert(not game.state.crew_orders[crew_id].paused)
	await create_timer(1).timeout
	assert(pirate.hp + pirate.shields < health, "payroll resumes real defense")
	game.state.crew_orders[crew_id].paused = true
	var wall := StaticBody3D.new()
	game.add_child(wall)
	wall.position = game.coasting_hull.position + Vector3(5, 15, -40)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 30, 2)
	shape.shape = box
	wall.add_child(shape)
	await physics_frame
	await physics_frame
	game.state.crew_orders[crew_id].paused = false
	health = pirate.hp + pirate.shields
	await create_timer(1).timeout
	assert(pirate.hp + pirate.shields == health, "gunner respects external cover")
	wall.queue_free()
	pirate.hostile = false
	await create_timer(1).timeout
	assert(pirate.hp + pirate.shields == health, "gunner does not attack neutral ships")
	pirate.hostile = true
	pirate.hp = 1
	pirate.shields = 0
	var kills: int = game.state.kills
	await create_timer(1).timeout
	assert(not is_instance_valid(pirate) and game.state.kills == kills + 1, "crew kill receives player bounty once")
	game.open_menu("fleet")
	var cancel: Button = _button(game.deck, "CANCEL ORDER")
	assert(cancel != null)
	cancel.pressed.emit()
	assert(not game.state.crew_orders.has(crew_id), "real menu cancels ship defense")
	assert(restored.load_save(path).is_empty() and not restored.crew_orders.has(crew_id), "cancellation persists")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	for filename in [path, path + ".bak"]:
		if FileAccess.file_exists(filename): DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
	print("SHIP_DEFENSE_GAMEPLAY_OK: menu assignment, mounted fire, payroll pause/resume, cover, neutral safety, bounty and saved cancellation")
	quit()

func _button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child: Node in node.get_children():
		var found := _button(child, title)
		if found != null: return found
	return null
