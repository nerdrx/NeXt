extends SceneTree

const HEAT_CAPACITY_J_K := 2500000.0

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert("--capture-only" in OS.get_cmdline_user_args())
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.close_menu()
	game.pilot.set_physics_process(false)
	for actor: Node in game.actors: actor.set_physics_process(false)
	game.world.stellar_profile = {}
	game.state.systems_online = false
	game.state.fuel = 0.0
	game.state.drive_temperature_k = 300.0
	var planet: Dictionary = game.world.planets[0]
	planet["atmosphere"] = true
	var local_sea: Vector3 = planet.position + Vector3.RIGHT * float(planet.visual_radius)
	var local_vacuum: Vector3 = planet.position + Vector3.RIGHT * (float(planet.visual_radius) + 220.0)
	var sea: Vector3 = game.world.to_global(local_sea)
	var vacuum: Vector3 = game.world.to_global(local_vacuum)
	var pilot = game.pilot
	pilot.set_flight(true)
	pilot.collision_mask = 0
	pilot.flight_assist_enabled = false
	pilot.teleport(sea)
	pilot.restore_flight_velocity(Vector3(100, 0, 0))
	var shield_before: float = game.state.shield
	var fuel_before: float = game.state.fuel
	var before: Vector3 = pilot.flight_velocity()
	pilot._fly(0.1)
	var pilot_heat_j: float = AtmosphericFlight.drag_heat_j(before, pilot.flight_velocity(), pilot.drag_mass_kg)
	assert(pilot_heat_j > 0.0 and is_equal_approx(game.state.drive_temperature_k, 300.0 + pilot_heat_j / HEAT_CAPACITY_J_K),
		"actual unpowered flight converts drag energy into ship heat")
	assert(game.state.shield == shield_before and game.state.fuel == fuel_before, "drag heat bypasses shield and consumes no fuel")
	var save_path := "user://aerodynamic-heat-%d.json" % OS.get_process_id()
	assert(game.state.save(save_path).is_empty())
	var restored := GameState.new()
	assert(restored.load_save(save_path).is_empty()
		and is_equal_approx(restored.drive_temperature_k, game.state.drive_temperature_k), "aerodynamic heat persists in save data")
	if DisplayServer.get_name() != "headless":
		pilot.camera.look_at(game.world.to_global(planet.position), Vector3.UP)
		game.hud._process(6.0)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://aerodynamic-heat-flight.png") == OK)

	game.state.drive_temperature_k = 300.0
	pilot.teleport(vacuum)
	pilot.restore_flight_velocity(Vector3(100, 0, 0))
	pilot._fly(0.1)
	assert(game.state.drive_temperature_k == 300.0, "vacuum flight produces no aerodynamic heat")

	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	game.apply_ship_stats()
	pilot.teleport(sea)
	pilot.restore_flight_velocity(Vector3(100, 0, 0))
	game.enter_interior()
	assert(game.aboard and is_instance_valid(game.coasting_hull))
	game.state.drive_temperature_k = 300.0
	game.coasting_hull.collision_mask = 0
	game.coasting_hull.advance(0.1)
	assert(game.state.drive_temperature_k > 300.0, "boarded coasting hull signal heats shared ship state")
	game.exit_interior()

	var npc: ShipActor
	for actor: Node in game.actors:
		if actor is ShipActor:
			npc = actor
			break
	assert(npc != null and npc.atmospheric_density_source.is_valid())
	npc.collision_mask = 0
	npc.global_position = sea
	npc.velocity = Vector3(2000, 0, 0)
	npc.thrust_newtons = 0.0
	npc.dry_mass_kg = 40000.0
	npc.hp = 1000.0
	npc.max_hull = 1000.0
	npc.shields = 20.0
	npc.max_shields = 20.0
	npc.drive_temperature_k = 700.0
	var npc_hull_before: float = npc.hp
	var npc_shields_before: float = npc.shields
	var kills_before: int = game.state.kills
	npc._physics_process(0.1)
	assert(npc.hp < npc_hull_before and npc.shields == npc_shields_before,
		"NPC drag overflow damages hull while bypassing shields")
	npc.hp = 0.0001
	npc.global_position = sea
	npc.velocity = Vector3(2000, 0, 0)
	npc.drive_temperature_k = 700.0
	var npc_wrecks_before: int = game.state.recovery.wrecks.size()
	npc.remove_meta("player_hit")
	npc._physics_process(0.1)
	assert(npc._destroyed and game.state.kills == kills_before
		and game.state.recovery.wrecks.size() == npc_wrecks_before + 1,
		"fatal NPC drag heat records debris without granting a player kill")

	pilot.teleport(sea)
	pilot.restore_flight_velocity(Vector3(8000, 0, 0))
	game.state.drive_temperature_k = 700.0
	game.state.hull = 100.0
	var wrecks_before: int = game.state.recovery.wrecks.size()
	pilot._fly(0.1)
	assert(game.state.hull <= 0.0, "saturated player hull takes fatal drag heat overflow")
	await process_frame
	assert(game.state.hull > 0.0 and game.state.drive_temperature_k == 300.0
		and game.state.recovery.wrecks.size() == wrecks_before + 1,
		"deferred rescue records wreck and replaces destroyed ship")
	var commander_save_path: String = game.save_path
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(commander_save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(commander_save_path + ".bak"))
	print("AERODYNAMIC_HEAT_GAMEPLAY_OK: flight absorption, vacuum, aboard hull, NPC bypass, rescue")
	quit()
