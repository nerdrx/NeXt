extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	game.pilot.set_physics_process(false)
	game.save_path = "user://region-gameplay-%d.json" % OS.get_process_id()
	var remote := SectorPosition.new(Vector3i(SectorPosition.HALF_REGION_SECTORS - 1, 0, 0), Vector3(100, 50, 0), Vector3i(5000, -3000, 0))
	game.state.location = {"system": 0, "surface": -1, "address": remote.to_save(), "rotation": [0, 0, 0], "flying": true, "velocity": [20, 0, 0]}
	game._restore_flight_location()
	assert(game.flight_origin.region == remote.region)
	assert(game.pilot.position == remote.local and game.pilot.flight_velocity() == Vector3(20, 0, 0))
	assert(not game.world.visible, "distant world geometry stays culled")
	game.pilot.position.x = 5000
	game._rebase_flight()
	assert(game.flight_origin.region.x == 5001 and game.flight_origin.sector.x == -SectorPosition.HALF_REGION_SECTORS)
	assert(game.pilot.position.x == -3192 and game.pilot.flight_velocity() == Vector3(20, 0, 0), "crossing a region preserves local motion")
	game.cruise_to(game.pilot.position + Vector3(1000, 0, 0))
	assert(game.cruise_address.region == game.flight_origin.region)
	assert(game.cruise_address.relative_to(game.flight_origin, 10000) == game.pilot.position + Vector3(1000, 0, 0))
	game.stop_cruise()
	assert(game.save_commander(false))
	var saved: Dictionary = game.state.location.duplicate(true)
	game.load_commander()
	assert(game.flight_origin.region.x == 5001)
	assert(game.state.location.address == saved.address, "save reload retains far region")
	var peer: SectorPosition = game.flight_origin.clone()
	assert(peer.move_delta(game.pilot.position + Vector3(0.25, 0, -100)))
	game.session.presence[42] = {"ship_modules": game.state.ship_modules, "ship_layout": game.state.ship_layout, "position": Vector3.ZERO, "rotation": Vector3.ZERO, "address": peer.to_save()}
	game._sync_visitors()
	game._update_remote_positions()
	assert(game.remote_ships[42].position - game.pilot.position == Vector3(0.25, 0, -100), "remote ship retains nearby precision far from origin")
	game.session.presence.clear()
	game._sync_visitors()
	game.state.cargo.food = 5
	game.state.hull = 0
	var report: Dictionary = ShipRecovery.destroy_ship(game.state, game.pilot.position, -1, game.flight_origin.to_save())
	assert(report.ok)
	var wreck: Dictionary = game.state.recovery.wrecks[0]
	assert(SectorPosition.from_save(wreck.address).region.x == 5001)
	game._build_system()
	assert(not game.recover_wreck(str(report.wreck_id)).is_empty())
	game.state.location = {"system": 0, "surface": -1, "address": wreck.address, "rotation": [0, 0, 0], "flying": true}
	game._restore_flight_location()
	assert(game.recover_wreck(str(report.wreck_id)).is_empty() and game.state.cargo.food == 5, "wreck recovery uses region-aware distances")
	game.sound.shutdown()
	game.session.leave()
	for suffix in ["", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path + suffix))
	game.queue_free()
	await process_frame
	await process_frame
	print("REGION_GAMEPLAY_OK: far restore, region crossing, cruise, save/load, peer precision and wreck recovery")
	quit()
