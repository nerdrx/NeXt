extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := SpaceWorld.new()
	root.add_child(world)
	world.stellar_profile = {"kind": "Black Hole"}
	world.position = Vector3(8192, 0, -8192)
	assert(world.primary_radius() == 245.0)
	assert(world.primary_contact(world.to_global(SpaceWorld.PRIMARY_POSITION + Vector3.RIGHT * 244)))
	assert(not world.primary_contact(world.to_global(SpaceWorld.PRIMARY_POSITION + Vector3.RIGHT * 246)))
	assert(not world.primary_contact(Vector3(NAN, 0, 0)))
	world.hide()
	assert(not world.primary_contact(world.to_global(SpaceWorld.PRIMARY_POSITION)))
	world.show()
	world._surface_mode = true
	assert(not world.primary_contact(world.to_global(SpaceWorld.PRIMARY_POSITION)))
	world.queue_free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game.close_menu()
	game.save_path = "user://primary-contact-%d.json" % OS.get_process_id()
	for actor: Node in game.actors: actor.set_physics_process(false)
	var center: Vector3 = game.world.to_global(SpaceWorld.PRIMARY_POSITION)
	game.pilot.set_flight(true)
	game.pilot.teleport(center + Vector3.RIGHT * 600)
	game.cruise_to(center)
	assert(game.cruise_address == null and not game.pilot.autopilot_active, "autopilot rejects core destination")
	game.cruise_to(center - Vector3.RIGHT * 600)
	assert(game.cruise_address != null and game.cruise_waypoints.size() > 1, "autopilot detours around primary")
	game.stop_cruise()
	var npc: ShipActor
	for actor: Node in game.actors:
		if actor is ShipActor: npc = actor; break
	assert(npc != null and npc.primary_contact_source.is_valid() and npc.primary_obstacle_source.is_valid())
	assert(npc.primary_obstacle_source.call().center.is_equal_approx(center), "spawn binds world obstacle")
	npc.global_position = center
	npc.shields = 1000.0
	var kills: int = game.state.kills
	var wrecks: int = game.state.recovery.wrecks.size()
	npc._physics_process(0.1)
	assert(npc._destroyed and npc.shields == 1000.0 and game.state.kills == kills)
	assert(game.state.recovery.wrecks.size() == wrecks + 1, "unassisted NPC loss records debris without kill reward")
	wrecks = game.state.recovery.wrecks.size()
	game.pilot.teleport(center)
	game.state.shield = 1000.0
	game._physics_process(0.1)
	assert(game.state.hull > 0 and game.state.recovery.wrecks.size() == wrecks + 1, "core destroys shielded player ship and rescues commander")
	var saved := GameState.new()
	assert(saved.load_save(game.save_path) == "" and saved.recovery.wrecks.size() == game.state.recovery.wrecks.size())
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)) == "")
	game.apply_ship_stats()
	game.pilot.set_flight(true)
	game.pilot.teleport(game.world.to_global(SpaceWorld.PRIMARY_POSITION) + Vector3.RIGHT * 600)
	game.enter_interior()
	assert(game.aboard and is_instance_valid(game.coasting_hull))
	game.coasting_hull.global_position = game.world.to_global(SpaceWorld.PRIMARY_POSITION)
	wrecks = game.state.recovery.wrecks.size()
	game._physics_process(0.1)
	assert(not game.aboard and game.state.hull > 0 and game.state.recovery.wrecks.size() == wrecks + 1, "aboard contact uses hull location and exits through rescue")
	for path: String in [game.save_path, game.save_path + ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("PRIMARY_CONTACT_OK: bounds, rebasing, guards, cruise detour, shield bypass, NPC debris, player rescue, persistence and aboard hull")
	quit()
