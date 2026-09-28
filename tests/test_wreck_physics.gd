extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _ray(game, point: Vector3) -> Dictionary:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 30.0, point - Vector3.UP * 30.0, 1))

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.state.recovery = ShipRecovery.empty_data()
	game.state.cargo = {"ore": 3}
	game.state.hull = 0.0
	var point := Vector3(10000, 5000, 0)
	var report := ShipRecovery.destroy_ship(game.state, point, game.surface_index, game.flight_origin.to_save())
	assert(report.ok)
	game.rebuild_wrecks()
	await physics_frame
	await physics_frame
	var hit := _ray(game, point)
	assert(not hit.is_empty() and game.wreck_root.is_ancestor_of(hit.collider), "wreck blocks physics rays")
	assert(game.pilot.test_move(Transform3D(Basis.IDENTITY, point + Vector3.UP * 30.0), Vector3.DOWN * 60.0), "player movement sweep collides with wreck")
	var hull: ShipVisual
	for node in game.wreck_root.get_children():
		if node is ShipVisual: hull = node
	assert(hull != null and not hull._engine_glow.is_empty())
	for material in hull._engine_glow:
		assert(material.emission_energy_multiplier == 0.0, "wreck engines are unpowered")
	game.pilot.set_flight(true)
	game.pilot.teleport(point + Vector3(0, 0, 20))
	assert(game.recover_wreck(report.wreck_id, true).is_empty())
	await physics_frame
	await physics_frame
	hit = _ray(game, point)
	assert(not hit.is_empty() and game.wreck_root.is_ancestor_of(hit.collider), "remaining freight cache stays solid")
	for node in game.wreck_root.get_children():
		assert(not node is ShipVisual, "salvaged hull is removed even when freight remains")
	assert(game.recover_wreck(report.wreck_id).is_empty() and game.state.cargo.ore == 3)
	await physics_frame
	await physics_frame
	assert(_ray(game, point).is_empty(), "completed recovery removes stale collision")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	print("WRECK_PHYSICS_OK: solid hull, dark engines, solid freight after salvage, complete removal")
	quit()
