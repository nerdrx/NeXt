extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	game.pilot.set_flight(false)
	game.state.wanted = 0
	var guard := GroundActor.new()
	guard.faction = "police"
	guard.hostile = false
	guard.target = game.pilot
	guard.position = Vector3(10000, 10000, 10000)
	game.add_child(guard)
	guard.set_physics_process(false)
	var origin := guard.position + Vector3(0, 0.9, 10)
	await physics_frame
	await physics_frame
	assert(not guard._in_sight_cone(origin))
	game._player_fire(origin, Vector3.FORWARD)
	assert(guard.hp == 66 and game.state.wanted == 1, "real player ray damages guard and reports assault")
	assert(guard.hostile and guard.contact_remaining == GroundActor.SEARCH_SECONDS, "first assault enables police awareness immediately")
	assert(guard.last_seen_position == origin and guard._in_sight_cone(origin), "rear hit turns newly hostile guard toward shot origin")
	guard.queue_free()
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("GROUND_ATTACK_OK: real rear hit reports assault and immediately alerts previously neutral police")
	quit()
