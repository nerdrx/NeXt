extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := SpaceWorld.new()
	root.add_child(world)
	world.stellar_profile = {"kind": "Yellow Star"}
	var center := SpaceWorld.PRIMARY_POSITION
	var sample := world.primary_approach(center + Vector3(1250, 0, 0), Vector3(-100, 0, 0))
	assert(is_equal_approx(sample.impact_seconds, 10.0) and sample.clearance_m == 1000.0)
	assert(world.primary_approach(center + Vector3(1250, 0, 0), Vector3.RIGHT).impact_seconds == -1.0)
	assert(world.primary_approach(center + Vector3(1250, 0, 0), Vector3.ZERO).impact_seconds == -1.0)
	assert(world.primary_approach(center + Vector3(1000, 251, 0), Vector3.LEFT * 100).impact_seconds == -1.0)
	assert(is_equal_approx(world.primary_approach(center + Vector3(1000, 250, 0), Vector3.LEFT * 100).impact_seconds, 10.0), "tangent contact counted")
	assert(world.primary_approach(center, Vector3.ZERO).impact_seconds == 0.0)
	assert(world.primary_approach(center, Vector3(NAN, 0, 0)).is_empty())
	world.position = Vector3(8192, 100, -8192)
	world.rotation.y = 0.5
	sample = world.primary_approach(world.to_global(center + Vector3(1250, 0, 0)), world.global_basis * Vector3(-100, 0, 0))
	assert(absf(sample.impact_seconds - 10.0) < 0.001)
	world.hide()
	assert(world.primary_approach(Vector3.ZERO, Vector3.ZERO).is_empty())
	world.show()
	world._surface_mode = true
	assert(world.primary_approach(Vector3.ZERO, Vector3.ZERO).is_empty())
	world.queue_free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	for actor: Node in game.actors: actor.set_physics_process(false)
	game.close_menu()
	game.pilot.set_flight(true)
	center = game.world.to_global(SpaceWorld.PRIMARY_POSITION)
	game.pilot.teleport(center + Vector3(0, 0, 1250))
	game.pilot.restore_flight_velocity(Vector3(0, 0, -125))
	var warning: Dictionary = game.hud.primary_warning()
	assert(not warning.is_empty() and warning.urgent and "COLLISION COURSE" in str(warning.title))
	game.pilot.camera.look_at(center)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://primary-warning.png")
	game.pilot.restore_flight_velocity(Vector3(0, 0, 125))
	assert(game.hud.primary_warning().is_empty(), "receding distant ship has no collision warning")
	game.pilot.teleport(center + Vector3(0, 0, 400))
	game.pilot.restore_flight_velocity(Vector3.ZERO)
	warning = game.hud.primary_warning()
	assert(not warning.is_empty() and not warning.urgent and "CLEARANCE" in str(warning.title))
	game.open_menu("overview")
	assert(game.hud.primary_warning().is_empty())
	game.close_menu()
	game.pilot.set_flight(false)
	assert(game.hud.primary_warning().is_empty(), "on-foot position is not a flying hull")
	var hull := CoastingHull.new()
	game.add_child(hull)
	hull.global_position = center + Vector3(0, 0, 1250)
	hull.velocity = Vector3(0, 0, -125)
	game.coasting_hull = hull
	game.aboard = true
	assert(game.hud.primary_warning().urgent, "aboard warning samples coasting hull rather than passenger")
	game.aboard = false
	game.coasting_hull = null
	hull.queue_free()
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("PRIMARY_WARNING_OK: contact estimate, misses, tangency, rebasing, guards, helm and coasting HUD")
	quit()
