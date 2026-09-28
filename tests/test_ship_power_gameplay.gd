extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	game.pilot.set_physics_process(false)
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(10000, 5000, 0))
	game.pilot.restore_flight_velocity(Vector3(20, 0, 0))
	var path := "user://power-gameplay-%d.json" % OS.get_process_id()
	game.save_path = path
	game.open_menu("settings")
	var button: Button = game.deck.find_child("ShipPowerToggle", true, false)
	assert(button != null and button.text == "SHUT DOWN MAIN SYSTEMS")
	button.pressed.emit()
	assert(not game.state.systems_online and game.pilot.acceleration_mps2 == 0.0)
	game.rebuild_player_ship()
	assert(not game.ship_display._engine_glow.is_empty())
	for material: StandardMaterial3D in game.ship_display._engine_glow:
		assert(material.emission_energy_multiplier == 0.0, "shutdown extinguishes local exhaust")
	var saved := GameState.new()
	assert(saved.load_save(path).is_empty() and not saved.systems_online, "menu persists shutdown")
	game.close_menu()
	var fuel: float = game.state.fuel
	game.pilot._fly(0.1)
	assert(game.pilot.flight_velocity() == Vector3(20, 0, 0) and game.state.fuel == fuel, "flight assist cannot brake offline ship")
	var count: int = game.get_child_count()
	game._player_fire(game.pilot.position, Vector3.FORWARD)
	assert(game.get_child_count() == count, "offline ship weapon creates no beam")
	game.request_jump(17)
	assert(game.jump_charge == 0 and game.state.fuel == fuel, "offline hyperdrive cannot begin charging")
	var carried := GameState.new()
	game._copy_carried_ship(game.state, carried)
	assert(not carried.systems_online, "carried ship retains power mode")
	game.jump_charge = 1.0
	assert(not game.set_ship_systems_online(true).is_empty() and not game.state.systems_online)
	game.jump_charge = 0.0
	game.open_menu("settings")
	button = game.deck.find_child("ShipPowerToggle", true, false)
	assert(button.text == "RESTART MAIN SYSTEMS")
	button.pressed.emit()
	assert(game.state.systems_online and game.pilot.acceleration_mps2 > 0.0)
	assert(saved.load_save(path).is_empty() and saved.systems_online)
	for material: StandardMaterial3D in game.ship_display._engine_glow:
		assert(material.emission_energy_multiplier > 0.0, "restart restores exhaust")
	game.close_menu()
	count = game.get_child_count()
	game._player_fire(game.pilot.position, Vector3.FORWARD)
	assert(game.get_child_count() > count, "restart restores ship weapons")
	assert(game.set_ship_systems_online(false).is_empty())
	game.pilot.set_flight(false)
	count = game.get_child_count()
	game._player_fire(game.pilot.position, Vector3.FORWARD)
	assert(game.get_child_count() > count, "suit weapon remains independent of ship power")
	var peer_id := 12345
	var profile: Dictionary = game.session._make_presence(Vector3.ZERO, Vector3.ZERO, game.state.ship_modules, game.state.ship_layout, "Visitor")
	profile.systems_online = false
	game.session.presence[peer_id] = profile
	game._sync_visitors()
	var remote: ShipVisual = game.remote_ships[peer_id]
	assert(not remote._engine_glow.is_empty())
	var independent_lights: Array[StandardMaterial3D] = []
	for child in remote.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var material := child.material_override as StandardMaterial3D
			if material.emission_enabled and material not in remote._engine_glow:
				independent_lights.append(material)
	assert(not independent_lights.is_empty())
	remote.set_thrust(1.0)
	for material: StandardMaterial3D in independent_lights:
		assert(is_equal_approx(material.emission_energy_multiplier, 2.5), "navigation lights retain independent brightness")
	for material: StandardMaterial3D in remote._engine_glow:
		assert(material.emission_energy_multiplier == 0.0, "remote shutdown overrides thrust glow")
	remote.build(game.state.ship_modules, "player", game.state.ship_layout)
	for material: StandardMaterial3D in remote._engine_glow:
		assert(material.emission_energy_multiplier == 0.0, "rebuild preserves shutdown")
	game.session.presence[peer_id].systems_online = true
	game._sync_visitors()
	for material: StandardMaterial3D in remote._engine_glow:
		assert(material.emission_energy_multiplier > 0.0, "remote restart restores exhaust")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	for file: String in [path, path + ".bak"]:
		if FileAccess.file_exists(file): DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("SHIP_POWER_GAMEPLAY_OK: menu persistence, coasting, weapons, jump guard, carried state and restart")
	quit()
