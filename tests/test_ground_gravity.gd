extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game.world.planets[0].surface_gravity_mps2 = 3.0
	var found := false
	for actor in game.actors:
		if not actor is GroundActor: continue
		actor.set_physics_process(false)
		if actor.get_meta("colony_index", -1) != 0: continue
		found = true
		var expected: float = game._planet_walking_gravity(actor.global_position, 0, true)
		assert(expected > 0 and expected <= 3.0)
		assert(is_equal_approx(actor.walking_gravity(), expected))
		game.aboard = true
		game.docked_station = 0
		game.manual_planet = 1
		assert(is_equal_approx(actor.walking_gravity(), expected), "NPC field cannot depend on player location or artificial deck state")
	assert(found, "live colony spawn must bind its own field")
	game.aboard = false
	game.docked_station = -1
	game.manual_planet = -1
	game.surface_index = 0
	game._clear_actors()
	game._spawn_people([])
	assert(game.actors.size() == 9)
	for actor in game.actors:
		assert(actor is GroundActor and actor.walking_gravity() == 3.0, "flat colony residents and outlaws use planet gravity")
		actor.set_physics_process(false)
	var npc := GroundActor.new()
	npc.position = Vector3(10000, 10000, 10000)
	npc.hostile = false
	npc.hold_position = true
	root.add_child(npc)
	npc.set_physics_process(false)
	assert(npc.walking_gravity() == Pilot.DEFAULT_WALK_GRAVITY, "ship and station default matches pilot artificial gravity")
	npc.walking_gravity_source = func(_point): return 3.0
	await physics_frame
	npc._physics_process(0.1)
	assert(is_equal_approx(npc.velocity.y, -0.3), "low gravity changes actual airborne velocity")
	npc.walking_gravity_source = func(_point): return 12.0
	npc._physics_process(0.1)
	assert(is_equal_approx(npc.velocity.y, -1.5), "higher gravity accelerates falling faster")
	npc.walking_gravity_source = func(_point): return 0.0
	npc._physics_process(0.1)
	assert(is_equal_approx(npc.velocity.y, -1.5), "zero gravity preserves drift")
	for invalid in [NAN, INF, -1.0, "3", Vector3.ZERO]:
		npc.walking_gravity_source = func(_point): return invalid
		assert(npc.walking_gravity() == Pilot.DEFAULT_WALK_GRAVITY)
	var cabin := Node3D.new()
	root.add_child(cabin)
	var crew := ShipCrew.new()
	crew.position = Vector3(12000, 12000, 12000)
	crew.rotation.z = PI * 0.5
	cabin.add_child(crew)
	crew.set_physics_process(false)
	crew._physics_process(0.1)
	assert(is_equal_approx(crew.velocity.dot(crew.global_basis.y), -Pilot.DEFAULT_WALK_GRAVITY * 0.1), "crew gravity matches artificial deck and follows rotated cabin up")
	cabin.queue_free()
	npc.queue_free()
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("GROUND_GRAVITY_OK: live colony and outlaw bindings, player independence, artificial decks, measured acceleration and invalid fields")
	quit()
