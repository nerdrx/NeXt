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
	var path := "user://fine-settlement-%d.json" % OS.get_process_id()
	game.save_path = path
	game.pilot.set_flight(false)
	game.pilot.set_physics_process(false)
	game.pilot.teleport(Vector3(1000,1000,1000))
	var guard := GroundActor.new()
	guard.faction = "police"
	guard.hostile = false
	guard.hp = 200
	game.add_child(guard)
	guard.position = Vector3(1000,1000,990)
	guard.set_physics_process(false)
	game.actors.append(guard)
	var patrol := ShipActor.new()
	patrol.faction = "police"
	game.add_child(patrol)
	patrol.position = Vector3(2000,1000,1000)
	patrol.set_physics_process(false)
	game.actors.append(patrol)
	for frame in 2: await physics_frame
	var shot_origin := Vector3(1000,1000.9,1000)
	game._player_fire(shot_origin, Vector3.FORWARD)
	assert(guard.hp < 200 and game.state.wanted == 1 and guard.get_meta("assault_reported", false))
	guard.hostile = true
	patrol.hostile = true
	patrol.target = game.pilot
	patrol.search_seconds_remaining = 10
	var cash: int = game.state.credits
	game.pay_fines()
	assert(game.state.wanted == 0 and game.state.credits == cash - 750)
	assert(not guard.hostile and not patrol.hostile and patrol.target == null and patrol.search_seconds_remaining == 0)
	assert(not guard.has_meta("assault_reported"), "settlement permits a fresh report for a new assault")
	var saved := GameState.new()
	assert(saved.load_save(path).is_empty() and saved.wanted == 0 and saved.credits == game.state.credits)
	cash = game.state.credits
	game.pay_fines()
	assert(game.state.credits == cash, "no second charge without a new crime")
	game.close_menu()
	game._player_fire(shot_origin, Vector3.FORWARD)
	assert(game.state.wanted == 1, "actual ray hit on same surviving victim creates a new criminal alert")
	# Failed payments preserve the outstanding incident and funds.
	game.state.credits = 749
	game.pay_fines()
	assert(game.state.wanted == 1 and game.state.credits == 749 and guard.has_meta("assault_reported"))
	game.state.credits = 5000
	game.pilot.set_flight(true)
	game.pay_fines()
	assert(game.state.wanted == 1 and game.state.credits == 5000)
	game.pilot.set_flight(false)
	game.aboard = true
	game.pay_fines()
	assert(game.state.wanted == 1 and game.state.credits == 5000)
	game.aboard = false
	game.state.faction = {"name":"Test Faction", "treasury":0, "claimed_stations":[], "diplomacy":{str(game.world.data.faction):"hostile"}}
	game.pay_fines()
	assert(game.state.wanted == 0 and guard.hostile and patrol.hostile, "criminal settlement cannot override diplomatic hostility")
	game.open_menu("factions")
	var button := game.deck.find_child("PayFines", true, false) as Button
	assert(button != null and button.disabled and "0 CR" in button.text)
	game.state.wanted = 2
	game.deck.refresh()
	button = game.deck.find_child("PayFines", true, false) as Button
	assert(button != null and not button.disabled and "1500 CR" in button.text)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://fine-settlement.png") == OK)
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	for filename in [path,path+".bak",path+".tmp"]:
		if FileAccess.file_exists(filename): DirAccess.remove_absolute(filename)
	print("FINE_SETTLEMENT_OK: repeat assault, immediate ceasefire, diplomacy, payment guards and saved state")
	quit()
