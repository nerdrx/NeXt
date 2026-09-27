extends SceneTree

var game: Node
var save_path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	save_path = "user://planet-gameplay-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.close_menu()
	var body: Dictionary = game.world.planets[0]
	var world_id: int = game.world.get_instance_id()
	var center: Vector3 = game._planet_center(0)
	var radius: float = body.visual_radius
	var height: float = PlanetTerrain.surface_height(Vector3.RIGHT, game._terrain_seed(0))
	game.pilot.set_flight(true)
	game.pilot.teleport(center + Vector3.RIGHT * (radius + height + 25.0))
	game._update_planet_terrain()
	if not _check(game.terrain_planet == 0, "approach creates terrain in current world"): return
	game.pilot.velocity = Vector3.UP * 30.0
	game._interact()
	if not _check(game.pilot.flying and game.manual_planet == -1, "high speed landing rejected"): return
	game.pilot.velocity = Vector3.ZERO
	game._interact()
	if not _check(not game.pilot.flying and game.manual_planet == 0, "slow manual landing accepted"): return
	if not _check(game.world.get_instance_id() == world_id and game.surface_index == -1, "landing preserves orbital scene"): return
	if not _check(game.pilot.up_direction.dot(Vector3.RIGHT) > 0.99, "walking follows radial gravity"): return
	if not _check(game.ship_display.basis.y.dot(Vector3.RIGHT) > 0.99, "parked ship follows radial up"): return
	await create_timer(0.7).timeout
	if not _check(game.pilot.is_on_floor(), "terrain supports landed pilot"): return
	var start: Vector3 = game.pilot.position
	Input.action_press("move_forward")
	await create_timer(0.4).timeout
	Input.action_release("move_forward")
	game._update_planet_terrain()
	if not _check(game.pilot.position.distance_to(start) > 1.0, "walk traverses terrain"): return
	await create_timer(0.3).timeout
	if not _check(game.pilot.is_on_floor(), "walking maintains terrain contact"): return
	# Exercise real CharacterBody motion across a streamed patch boundary. Main
	# processing stays disabled for isolation, so perform its terrain update here.
	var first_patch: int = game.planet_terrain.get_instance_id()
	var patch_replaced := false
	var unsupported_time := 0.0
	var longest_unsupported := 0.0
	var previous_position: Vector3 = game.pilot.position
	var walked_distance := 0.0
	Input.action_press("move_forward")
	Input.action_press("boost")
	for frame in 480:
		game._update_planet_terrain()
		await physics_frame
		var step: float = game.pilot.position.distance_to(previous_position)
		walked_distance += step
		if not _check(step < 1.0, "terrain refresh does not teleport walking pilot"): return
		previous_position = game.pilot.position
		patch_replaced = patch_replaced or game.planet_terrain.get_instance_id() != first_patch
		unsupported_time = 0.0 if game.pilot.is_on_floor() else unsupported_time + 1.0 / Engine.physics_ticks_per_second
		longest_unsupported = maxf(longest_unsupported, unsupported_time)
		var offset: Vector3 = game.pilot.position - center
		var expected_height: float = PlanetTerrain.surface_height(offset.normalized(), game._terrain_seed(0))
		if not _check(offset.length() >= radius + expected_height - 1.0, "streamed terrain prevents falling through ground"): return
	Input.action_release("move_forward")
	Input.action_release("boost")
	if not _check(walked_distance > 70.0 and patch_replaced, "walking crosses terrain refresh boundary"): return
	if not _check(longest_unsupported < 0.35, "patch replacement preserves ground contact"): return
	await create_timer(0.3).timeout
	game._update_planet_terrain()
	# Interior transitions must restore radial gravity and heading on the planet.
	game.state.credits = 50000
	if not _check(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty(), "install walkable habitat"): return
	game.apply_ship_stats()
	var outside_position: Vector3 = game.pilot.position
	var outside_basis: Basis = game.pilot.basis
	var outside_up: Vector3 = game.pilot.up_direction
	game.enter_interior()
	if not _check(game.aboard and game.pilot.up_direction.is_equal_approx(Vector3.UP), "interior uses local deck gravity"): return
	await create_timer(0.3).timeout
	game.exit_interior()
	if not _check(not game.aboard and not game.pilot.flying and game.manual_planet == 0, "interior exit restores grounded mode"): return
	if not _check(game.pilot.position.is_equal_approx(outside_position) and game.pilot.basis.is_equal_approx(outside_basis) and game.pilot.up_direction.is_equal_approx(outside_up), "interior exit preserves radial position and orientation"): return
	await create_timer(0.3).timeout
	if not _check(game.pilot.is_on_floor(), "interior exit resumes surface contact"): return
	game._update_planet_terrain()
	game.pilot.rotate_object_local(Vector3.UP, 0.37)
	var saved_basis: Basis = game.pilot.basis
	var ship_address: Dictionary = game.landed_ship_address.to_save()
	if not _check(game.save_commander(false), "grounded save writes"): return
	game.pilot.teleport(Vector3.ZERO)
	game.load_commander()
	if not _check(game.manual_planet == 0 and not game.pilot.flying, "load restores surface walking"): return
	var saved_relative: Vector3 = SectorPosition.from_save(game.state.location.address).relative_to(game.flight_origin, 60000)
	if not _check(game.pilot.position.distance_to(saved_relative) < 0.02, "load restores player address"): return
	if not _check(game.landed_ship_address.to_save() == ship_address, "load preserves separate parked ship address"): return
	if not _check(game.pilot.basis.is_equal_approx(saved_basis), "load preserves radial heading"): return
	var valid_location: Dictionary = game.state.location.duplicate(true)
	var before_position: Vector3 = game.pilot.position
	var before_origin: Dictionary = game.flight_origin.to_save()
	game.state.location.ship_address = SectorPosition.new(Vector3i(1000, 0, 0)).to_save()
	game._restore_flight_location()
	if not _check(game.pilot.position == before_position and game.flight_origin.to_save() == before_origin and game.landed_ship_address.to_save() == ship_address, "distant saved ship rejected before world mutation"): return
	game.state.location = valid_location
	game._clear_actors()
	game.close_menu()
	await create_timer(0.5).timeout
	if not _check(game.pilot.is_on_floor(), "restored terrain supports player"): return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/manual-planet.png")
	world_id = game.world.get_instance_id()
	var pad: Vector3 = game._ship_pad()
	var normal: Vector3 = game.landed_ship_normal
	game.pilot.teleport(pad + normal * 2.0)
	game._interact()
	if not _check(game.pilot.flying and game.manual_planet == -1, "boarding lifts off"): return
	if not _check(game.world.get_instance_id() == world_id, "liftoff preserves orbital scene"): return
	if not _check(game.pilot.position.distance_to(pad + normal * 25.0) < 0.02, "liftoff departs parked ship location"): return
	_cleanup()
	game.queue_free()
	await process_frame
	await process_frame
	print("PLANET_GAMEPLAY_OK: same-scene landing, speed guard, radial terrain streaming and interior return, parked ship, save restore, liftoff")
	quit()

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("PLANET_GAMEPLAY_FAILED: " + message)
		_cleanup()
		quit(1)
	return ok

func _cleanup() -> void:
	Input.action_release("move_forward")
	Input.action_release("boost")
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
