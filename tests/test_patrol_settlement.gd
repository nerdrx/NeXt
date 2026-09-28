extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	game.close_menu()
	game.state = GameState.new()
	game.state.credits = 10000
	game.state.wanted = 2
	var path := "user://patrol-settlement-%d.json" % OS.get_process_id()
	game.save_path = path
	game.pilot.set_flight(true)
	game.pilot.set_physics_process(false)
	game.pilot.teleport(Vector3(10000,10000,10000))
	assert(not game.patrol_fine_issue().is_empty(), "no officer cannot settle")
	var patrol := ShipActor.new()
	patrol.faction = "police"
	patrol.hostile = true
	game.add_child(patrol)
	patrol.position = game.pilot.position + Vector3(0,0,-100)
	patrol.set_physics_process(false)
	game.actors.append(patrol)
	for frame in 2: await physics_frame
	assert(game.patrol_fine_issue().is_empty())
	game.pilot.restore_flight_velocity(Vector3(6,0,0))
	game.settle_patrol_fine()
	assert(game.state.wanted == 2 and game.state.credits == 10000)
	game.pilot.restore_flight_velocity(Vector3.ZERO)
	game.jump_charge = 1
	assert(not game.patrol_fine_issue().is_empty())
	game.jump_charge = 0
	game.session.connected = true
	assert(not game.patrol_fine_issue().is_empty())
	game.session.connected = false
	game.state.credits = 1499
	assert(not game.patrol_fine_issue().is_empty())
	game.state.credits = 10000
	patrol.position.z -= 400
	assert(not game.patrol_fine_issue().is_empty())
	patrol.position.z += 400
	patrol.set_meta("spatial_culled", true)
	assert(not game.patrol_fine_issue().is_empty())
	patrol.set_meta("spatial_culled", false)
	patrol.hp = 0
	assert(not game.patrol_fine_issue().is_empty())
	patrol.hp = 100
	game.state.faction = {"name":"Test Faction", "treasury":0, "claimed_stations":[], "diplomacy":{str(game.world.data.faction):"hostile"}}
	assert(not game.patrol_fine_issue().is_empty())
	game.state.faction = PlayerFaction.empty_data()
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20,20,2)
	collision.shape = box
	obstacle.add_child(collision)
	game.add_child(obstacle)
	obstacle.position = game.pilot.position + Vector3(0,0,-50)
	for frame in 2: await physics_frame
	assert(not game.patrol_fine_issue().is_empty(), "solid obstacle prevents a visible patrol contact")
	obstacle.queue_free()
	for frame in 2: await physics_frame
	assert(game.patrol_fine_issue().is_empty())
	game.open_menu("factions")
	var button := game.deck.find_child("PatrolSettlement", true, false) as Button
	assert(button != null and not button.disabled and "1500 CR" in button.text)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://patrol-settlement.png") == OK)
	var position_before: Vector3 = game.pilot.position
	var cargo_before: Dictionary = game.state.cargo.duplicate(true)
	button.pressed.emit()
	assert(game.state.wanted == 0 and game.state.credits == 8500 and not patrol.hostile)
	assert(game.pilot.flying and game.pilot.position == position_before and game.state.cargo == cargo_before, "settlement preserves ship and location")
	var loaded := GameState.new()
	assert(loaded.load_save(path).is_empty() and loaded.wanted == 0 and loaded.credits == 8500)
	game.settle_patrol_fine()
	assert(game.state.credits == 8500, "no repeated charge")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	for filename in [path,path+".bak",path+".tmp"]:
		if FileAccess.file_exists(filename): DirAccess.remove_absolute(filename)
	print("PATROL_SETTLEMENT_OK: physical contact, speed/visibility guards, button transaction and persistence")
	quit()
