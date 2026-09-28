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
	var save_path := "user://combat-debris-%d.json" % OS.get_process_id()
	game.save_path = save_path
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
	game.pilot.teleport(point + Vector3(0, 0, 100))
	var far_goal: SectorPosition = game.flight_origin.clone()
	far_goal.move_delta(point - Vector3(0, 0, 100))
	game._start_address_cruise(far_goal)
	assert(game.cruise_waypoints.size() > 1, "autopilot detours around a wreck on the direct route")
	var previous: Vector3 = game.pilot.position
	var obstacle := {"center": point, "radius": ShipRecovery.wreck_radius(game.state.recovery.wrecks[0]) + game.pilot.hull_radius}
	for waypoint: SectorPosition in game.cruise_waypoints:
		var next: Vector3 = waypoint.relative_to(game.flight_origin, 30000.0)
		assert(not CruiseRoute._blocked(previous, next, obstacle), "every planned segment clears wreck and player hull")
		previous = next
	var unsafe_goal: SectorPosition = game.flight_origin.clone()
	unsafe_goal.move_delta(point)
	game._start_address_cruise(unsafe_goal)
	assert(game.cruise_address == null and game.cruise_waypoints.is_empty(), "destination inside wreck is refused")
	game.approach_wreck(report.wreck_id)
	assert(game.cruise_address != null)
	var target: Vector3 = game.cruise_address.relative_to(game.flight_origin, 30000.0)
	var radius := ShipRecovery.wreck_radius(game.state.recovery.wrecks[0])
	assert(is_equal_approx(target.distance_to(point), radius + game.pilot.hull_radius + CruiseRoute.CLEARANCE + 5.0), "approach leaves clearance around wreck and player hull")
	game.pilot.cancel_autopilot()
	game.pilot.teleport(point + Vector3(0, 0, 20))
	assert(game.recover_wreck(report.wreck_id, true).is_empty())
	await physics_frame
	await physics_frame
	hit = _ray(game, point)
	assert(not hit.is_empty() and game.wreck_root.is_ancestor_of(hit.collider), "remaining freight cache stays solid")
	for node in game.wreck_root.get_children():
		assert(not node is ShipVisual, "salvaged hull is removed even when freight remains")
	game.open_menu("recovery")
	var take_one: Button
	for candidate in game.deck.find_children("*", "Button", true, false):
		if candidate.get_meta("recovery_good", "") == "ore" and int(candidate.get_meta("recovery_amount", -1)) == 1:
			take_one = candidate
	assert(take_one != null and not take_one.disabled)
	await process_frame
	var ancestor: Node = take_one.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(take_one)
		ancestor = ancestor.get_parent()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://selective-recovery.png")
	take_one.pressed.emit()
	assert(game.state.cargo.ore == 1 and game.state.recovery.wrecks[0].cargo.ore == 2)
	var selection_save := GameState.new()
	assert(selection_save.load_save(save_path).is_empty() and selection_save.cargo.ore == 1 and selection_save.recovery.wrecks[0].cargo.ore == 2)
	game.close_menu()
	assert(game.recover_wreck(report.wreck_id).is_empty() and game.state.cargo.ore == 3)
	await physics_frame
	await physics_frame
	assert(_ray(game, point).is_empty(), "completed recovery removes stale collision")
	game.pilot.teleport(point + Vector3(0, 0, 100))
	game._start_address_cruise(far_goal)
	assert(game.cruise_waypoints.size() == 1, "fully recovered wreck no longer blocks route")
	# A new combat wreck appears while the direct cruise is already engaged.
	game.state.hull = 0.0
	assert(ShipRecovery.destroy_ship(game.state, point, game.surface_index, game.flight_origin.to_save()).ok)
	game.rebuild_wrecks()
	assert(game.cruise_waypoints.size() > 1 and game.pilot.autopilot_active, "new wreck replans an active route")
	var route_before: Array = game.cruise_waypoints.duplicate()
	game.rebuild_wrecks()
	assert(game.cruise_waypoints == route_before, "unchanged rebuild preserves route objects")
	# An obstruction at the destination makes the route impossible.
	game.pilot.restore_flight_velocity(Vector3(0, 0, -20))
	game.state.hull = 0.0
	assert(ShipRecovery.destroy_ship(game.state, point - Vector3(0, 0, 100), game.surface_index, game.flight_origin.to_save()).ok)
	game.rebuild_wrecks()
	assert(game.cruise_address == null and game.cruise_waypoints.is_empty())
	assert(not game.pilot.autopilot_active and game.pilot.braking, "blocked destination cancels cruise and requests braking")
	var enemy := ShipActor.new()
	enemy.actor_id = "debris-test-pirate"
	enemy.position = point + Vector3(500, 0, 0)
	game.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_meta("player_hit", true)
	enemy.destroyed.connect(game._actor_destroyed)
	var count: int = game.state.recovery.wrecks.size()
	enemy.take_damage(100000.0)
	assert(game.state.recovery.wrecks.size() == count + 1, "actual NPC destruction records debris")
	var debris: Dictionary = game.state.recovery.wrecks.back()
	assert(debris.modules.is_empty() and debris.cargo.alloys == 4 and debris.salvaged)
	var balance: int = game.state.credits
	game._actor_destroyed(enemy)
	assert(game.state.recovery.wrecks.size() == count + 1 and game.state.credits == balance, "duplicate destruction cannot duplicate debris or bounty")
	assert(FileAccess.file_exists(save_path), "NPC death saves the outcome immediately")
	var restored := GameState.new()
	assert(restored.load_save(save_path).is_empty() and restored.recovery.wrecks.back().cargo.alloys == 4)
	assert(restored.world_flags[game._location_key()].has("debris-test-pirate"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var alloys: int = game.state.cargo.get("alloys", 0)
	game.pilot.teleport(point + Vector3(500, 0, 20))
	assert(game.recover_wreck(debris.id).is_empty() and game.state.cargo.alloys == alloys + 4)
	assert(not game.recover_wreck(debris.id).is_empty(), "debris can be collected only once")
	var failing_enemy := ShipActor.new()
	failing_enemy.actor_id = "debris-save-failure"
	failing_enemy.position = point + Vector3(1000, 0, 0)
	game.add_child(failing_enemy)
	failing_enemy.set_physics_process(false)
	failing_enemy.destroyed.connect(game._actor_destroyed)
	game.save_path = ""
	failing_enemy.take_damage(100000.0)
	assert("NOT SAVED" in game.hud.message)
	assert(game.state.world_flags[game._location_key()].has(failing_enemy.actor_id), "save failure retains live combat state for retry")
	game.save_path = save_path
	assert(game.save_commander(false))
	assert(restored.load_save(save_path).is_empty() and restored.world_flags[game._location_key()].has(failing_enemy.actor_id))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	for system in range(100):
		if Universe._rng(system, 1701).randi_range(0, 2) == 0:
			game.state.system_index = system
			break
	game._build_system()
	game._clear_actors()
	game.pilot.set_flight(true)
	game.state.systems_online = false
	assert(not game.scan_salvage_signals().is_empty(), "offline scanner is rejected")
	game.state.systems_online = true
	game.open_menu("recovery")
	var scan_button: Button
	for candidate in game.deck.find_children("*", "Button", true, false):
		if candidate.text == "SCAN SALVAGE SIGNALS": scan_button = candidate
	assert(scan_button != null and not scan_button.disabled)
	count = game.state.recovery.wrecks.size()
	scan_button.pressed.emit()
	assert(game.state.recovery.wrecks.size() == count + 1)
	assert(restored.load_save(save_path).is_empty() and restored.recovery.wrecks.size() == count + 1)
	assert(not ShipRecovery.scan_derelict(restored).is_empty(), "saved discovery marker prevents repeat reward")
	var derelict: Dictionary = game.state.recovery.wrecks.back()
	var derelict_position: Vector3 = game._wreck_position(derelict)
	assert(derelict_position.length() > 18000.0)
	await physics_frame
	await physics_frame
	assert(not _ray(game, derelict_position).is_empty(), "discovered derelict materializes with collision")
	var contacts: Array[Dictionary] = game.recovery_contacts()
	assert(contacts.any(func(contact: Dictionary) -> bool: return contact.id == derelict.id), "surveyed wreck becomes a flight contact")
	var original_wrecks: Array = game.state.recovery.wrecks.duplicate(true)
	game.state.recovery.wrecks.clear()
	for index in range(12):
		var sample: Dictionary = derelict.duplicate(true)
		sample.id = "contact-%02d" % index
		sample.address = SectorPosition.new(Vector3i.ZERO, game.pilot.position + Vector3(100.0 + index * 100, 0, 0)).to_save()
		if index == 0: sample.salvaged = true; sample.cargo_recovered = true
		if index == 1: sample.system = game.state.system_index + 1
		game.state.recovery.wrecks.append(sample)
	contacts = game.recovery_contacts()
	assert(contacts.size() == 8 and contacts[0].id == "contact-02" and contacts[-1].id == "contact-09", "HUD keeps nearest eight active local contacts")
	game.tracked_wreck_id = "contact-11"
	contacts = game.recovery_contacts()
	assert(contacts.size() == 8 and contacts[0].id == "contact-11", "tracked contact remains visible beyond nearest-eight cutoff")
	game.state.recovery.wrecks = original_wrecks
	game.tracked_wreck_id = ""
	game.open_menu("recovery")
	var track_button: Button
	for candidate in game.deck.find_children("*", "Button", true, false):
		if candidate.get_meta("track_wreck", "") == derelict.id: track_button = candidate
	assert(track_button != null and not track_button.disabled)
	track_button.pressed.emit()
	assert(game.tracked_wreck_id == derelict.id and not game.ui_open and not game.pilot.autopilot_active, "tracking returns to manual flight without engaging cruise")
	game.track_wreck(derelict.id)
	assert(game.tracked_wreck_id.is_empty(), "same beacon toggles tracking off")
	game.track_wreck(derelict.id)
	game.close_menu()
	game.pilot.teleport(Vector3(0, 1000, 500))
	game.hud.message_time = 0.0
	game.pilot.camera.look_at(derelict_position, Vector3.UP)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://wreck-navigation.png")
		game.pilot.camera.look_at(game.pilot.camera.global_position * 2.0 - derelict_position, Vector3.UP)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://wreck-tracking-behind.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	print("WRECK_PHYSICS_OK: solid hull, dark engines, solid freight after salvage, complete removal")
	quit()
