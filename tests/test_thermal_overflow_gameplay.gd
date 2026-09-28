extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	assert("--capture-only" in OS.get_cmdline_user_args())
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	for actor: Node in game.actors: actor.set_physics_process(false)
	game.close_menu()
	game.world.stellar_profile = {"luminosity_w": CelestialPhysics.SOLAR_LUMINOSITY_W, "radius_m": CelestialPhysics.SOLAR_RADIUS_M}
	game.pilot.set_flight(true)
	game.pilot.teleport(game.world.to_global(SpaceWorld.PRIMARY_POSITION + Vector3.RIGHT * 260.0))
	game.pilot.restore_flight_velocity(Vector3.ZERO)
	game.state.systems_online = false
	game.state.drive_temperature_k = 700.0
	game.state.hull = 50.0
	game.state.shield = 20.0
	game._physics_process(1.0)
	assert(game.state.hull < 50.0 and game.state.shield == 20.0, "external heat bypasses shields with systems offline")
	var npc: ShipActor
	for actor: Node in game.actors:
		if actor is ShipActor: npc = actor; break
	assert(npc != null)
	npc.stellar_heat_source = func(_point: Vector3, _orientation: Basis, _size: Vector3) -> float: return 100000000.0
	npc.drive_temperature_k = 700.0
	npc.hp = 50.0
	npc.shields = 20.0
	npc._physics_process(1.0)
	assert(npc.hp < 50.0 and npc.shields >= 20.0, "NPC hull also absorbs thermal overflow")
	npc.hp = 0.0001
	var kills_before: int = game.state.kills
	var wrecks_before: int = game.state.recovery.wrecks.size()
	npc._physics_process(1.0)
	assert(npc._destroyed and game.state.kills == kills_before, "unassisted thermal casualty grants no player kill")
	assert(game.state.recovery.wrecks.size() == wrecks_before + 1, "thermal casualty creates debris")
	game.state.hull = 0.000001
	game.state.drive_temperature_k = 700.0
	wrecks_before = game.state.recovery.wrecks.size()
	game._physics_process(1.0)
	assert(game.state.recovery.wrecks.size() == wrecks_before + 1, "fatal player exposure records a wreck")
	assert(game.state.hull > 0.0 and game.state.drive_temperature_k == 300.0, "rescue provides a cooled replacement")
	var restored := GameState.new()
	assert(restored.load_save(game.save_path).is_empty())
	assert(restored.recovery.wrecks.size() == game.state.recovery.wrecks.size(), "rescue and wreck are saved")
	# Destruction while the commander is outside must recover the ship, not only the suit.
	game.pilot.set_flight(false)
	game.ship_display.position = Vector3(100, 200, 300)
	game.pilot.position = Vector3(105, 200, 300)
	game.state.hull = 0.0
	wrecks_before = game.state.recovery.wrecks.size()
	game._rescue()
	assert(game.state.recovery.wrecks.size() == wrecks_before + 1 and game.state.hull > 0.0)
	assert(game.state.recovery.wrecks.back().position == [100.0, 200.0, 300.0], "parked ship wreck uses hull position, not pedestrian position")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + ".bak"))
	game.queue_free()
	await process_frame
	print("THERMAL_OVERFLOW_GAMEPLAY_OK: unpowered hull damage, shields, NPC casualty/debris, no free kill, rescue and persistence")
	quit()
