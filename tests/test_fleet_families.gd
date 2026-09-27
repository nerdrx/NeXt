extends SceneTree

const CrewOrdersScript = preload("res://scripts/crew_orders.gd")
const GameStateScript = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var blank := CrewOrdersScript.new(GameStateScript.new())
	var blank_quote: Dictionary = blank.commission_quote()
	assert(blank_quote.error.is_empty() and blank_quote.price == 4000 and blank_quote.capacity == 25)
	assert(not blank.commission_quote("badfamily").error.is_empty())

	var state = GameStateScript.new()
	state.credits = 100000
	var orders := CrewOrdersScript.new(state)
	for family_id: String in ShipBlueprint.FAMILIES:
		var blueprint: Dictionary = ShipBlueprint.family(family_id)
		var expected_price := 0
		var expected_capacity: int = GameStateScript.new()._stats_for(blueprint.modules).cargo_capacity
		for module: Dictionary in blueprint.modules:
			var specs: Dictionary = GameStateScript.MODULES[module.kind]
			expected_price += int(specs.cost)
		var quote: Dictionary = orders.commission_quote(family_id)
		assert(quote.error.is_empty() and quote.price == expected_price and quote.capacity == expected_capacity,
			"quote sums the actual %s blueprint" % family_id)
		var credits_before: int = state.credits
		assert(orders.purchase_ship(family_id.capitalize(), family_id).is_empty())
		var ship: Dictionary = state.fleet_ships.back()
		assert(state.credits == credits_before - expected_price and ship.hull_family == family_id and ship.capacity == expected_capacity)

	var snapshot: Dictionary = state._save_data().duplicate(true)
	assert(not orders.purchase_ship("Unknown Hull", "badfamily").is_empty())
	assert(state._save_data() == snapshot, "unknown family purchase is atomic")
	state.credits = 0
	snapshot = state._save_data().duplicate(true)
	assert(not orders.purchase_ship("No Cash", "pathfinder").is_empty())
	assert(state._save_data() == snapshot, "unaffordable family purchase is atomic")

	var path := "user://fleet-families-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty())
	var restored = GameStateScript.new()
	assert(restored.load_save(path).is_empty())
	assert(restored._save_data() == state._save_data(), "family fleet records round-trip")
	var stable: Dictionary = restored._save_data().duplicate(true)
	for invalid_family: String in ["badfamily", ""]:
		var malformed: Dictionary = stable.duplicate(true)
		malformed.fleet_ships[0].hull_family = invalid_family
		_write(path, malformed)
		assert(not restored.load_save(path).is_empty() and restored._save_data() == stable,
			"invalid optional family is rejected atomically")
	var wrong_capacity: Dictionary = stable.duplicate(true)
	wrong_capacity.fleet_ships[0].capacity += 1
	_write(path, wrong_capacity)
	assert(not restored.load_save(path).is_empty() and restored._save_data() == stable,
		"family capacity mismatch is rejected atomically")
	var legacy: Dictionary = stable.duplicate(true)
	legacy.fleet_ships.clear()
	var old_orders := CrewOrdersScript.new(GameStateScript.new())
	assert(old_orders.purchase_ship("Legacy Ship").is_empty())
	legacy.fleet_ships = old_orders.state.fleet_ships.duplicate(true)
	_write(path, legacy)
	assert(restored.load_save(path).is_empty(), "legacy fleet records without hull_family remain valid")
	assert(not restored.fleet_ships[0].has("hull_family"))

	for family_id: String in ShipBlueprint.FAMILIES:
		var actor := ShipActor.new()
		actor.hull_family = family_id
		root.add_child(actor)
		await process_frame
		var visual: Node3D = actor._visual
		assert(visual.get_node_or_null("FamilyPressureHull") != null,
			"%s fleet actor uses family pressure hull visual" % family_id)
		actor.queue_free()
		await process_frame

	var merchant_blueprint: Dictionary = ShipBlueprint.family("merchant")
	var merchant_model = GameStateScript.new()
	merchant_model.ship_modules.assign(merchant_blueprint.modules)
	merchant_model.ship_layout = merchant_blueprint.layout
	var merchant_stats: Dictionary = merchant_model.ship_stats()
	var empty_merchant: ShipActor = await _motion_probe(merchant_blueprint, 0.0, 0.0)
	var loaded_merchant: ShipActor = await _motion_probe(merchant_blueprint, 160000.0, 1000.0)
	assert(loaded_merchant.velocity.length() < empty_merchant.velocity.length(),
		"160 t cargo reduces real merchant acceleration")
	for probe: ShipActor in [empty_merchant, loaded_merchant]:
		var dry_mass := float(merchant_stats.dry_mass_kg)
		var thrust := float(merchant_stats.thrust_newtons)
		var radiator_area := float(merchant_stats.radiator_area_m2)
		assert(probe.dry_mass_kg == dry_mass and probe.thrust_newtons == thrust and probe.radiator_area_m2 == radiator_area,
			"merchant actor drive stats come from family blueprint")
		var mass := dry_mass + probe.cargo_mass_kg
		var expected_acceleration := minf(3.0 * 9.80665, thrust / mass)
		assert(is_equal_approx(probe.velocity.length(), expected_acceleration),
			"merchant motion uses blueprint thrust and loaded mass: %s vs %s" % [probe.velocity.length(), expected_acceleration])
		var heat_input := mass * probe.velocity.length() / 5000000.0 * 20.0
		var cooling := maxf(0.0, ThermalSignature.emitted_power_w(450.0, radiator_area)
			- ThermalSignature.emitted_power_w(300.0, radiator_area))
		var expected_heat := maxf(300.0, 450.0 - cooling / 2500000.0) + heat_input
		assert(is_equal_approx(probe.drive_temperature_k, expected_heat),
			"merchant acceleration charges drive heat from mass times delta-v")
		probe.queue_free()
	await process_frame

	var braking_merchant: ShipActor = await _motion_probe(merchant_blueprint, 160000.0, 2000.0, 300.0)
	braking_merchant.set_travel_target(braking_merchant.position + Vector3(100, 0, 0))
	braking_merchant.velocity = Vector3(80, 0, 0)
	braking_merchant._physics_process(0.1)
	assert(braking_merchant.velocity.x < 80.0 and braking_merchant.velocity.x > 0.0,
		"loaded merchant brakes toward a nearby target")
	braking_merchant.queue_free()
	await process_frame

	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.save_path = path
	game.close_menu()
	game._clear_actors()
	var fleet_state = GameStateScript.new()
	fleet_state.credits = 50000
	assert(fleet_state.hire("trader").is_empty())
	var integration_orders := CrewOrdersScript.new(fleet_state)
	assert(integration_orders.purchase_ship("Integrated Merchant", "merchant").is_empty())
	var fleet_ship: Dictionary = fleet_state.fleet_ships[0]
	var trader_id: String = str(fleet_state.crew[0].id)
	assert(integration_orders.assign_trade_route(trader_id, str(fleet_ship.id), "ore", (fleet_state.system_index + 1) % GameStateScript.SYSTEM_LIMIT).is_empty())
	game.state = fleet_state
	game._sync_fleet_actors()
	var integrated: ShipActor = game.fleet_actors[str(fleet_ship.id)]
	assert(integrated.hull_family == "merchant" and integrated._visual.get_node_or_null("FamilyPressureHull") != null,
		"main scene materializes commissioned family hull for its trader order")
	assert(integrated.dry_mass_kg == merchant_stats.dry_mass_kg and integrated.thrust_newtons == merchant_stats.thrust_newtons
		and integrated.speed == merchant_stats.speed and integrated.radiator_area_m2 == merchant_stats.radiator_area_m2,
		"main scene initializes drive stats from merchant blueprint")
	assert(integrated.cargo_mass_kg == 0.0, "new merchant actor starts with empty cargo mass")
	fleet_ship.cargo["ore"] = 160
	game._sync_fleet_actors()
	assert(integrated.cargo_mass_kg == 160000.0, "main sync updates existing actor cargo mass")
	integrated.take_damage(integrated.max_hull * 0.25)
	assert(is_equal_approx(float(fleet_ship.hull), 75.0), "family damage persists as normalized hull condition")
	assert(game.save_commander(false))
	var damaged_save := GameStateScript.new()
	assert(damaged_save.load_save(path).is_empty() and is_equal_approx(float(damaged_save.fleet_ships[0].hull), 75.0))
	integrated._tick_shields(7.0)
	assert(is_equal_approx(integrated.shields, 5.0))
	integrated.take_damage(2.0)
	assert(is_equal_approx(float(fleet_ship.defense.charge), 3.0) and float(fleet_ship.defense.delay) == 6.0)
	assert(game.save_commander(false))
	var shield_save := GameStateScript.new()
	assert(shield_save.load_save(path).is_empty() and float(shield_save.fleet_ships[0].defense.charge) == 3.0 and float(shield_save.fleet_ships[0].defense.delay) == 6.0)
	game._clear_actors()
	game._sync_fleet_actors()
	var respawned: ShipActor = game.fleet_actors[str(fleet_ship.id)]
	assert(respawned.hull_family == "merchant" and respawned._visual.get_node_or_null("FamilyPressureHull") != null
		and respawned.cargo_mass_kg == 160000.0,
		"main scene respawn keeps family hull and cargo mass")
	assert(is_equal_approx(respawned.shields, 3.0) and respawned.shield_delay == 6.0, "actor respawn preserves shield charge and delay")
	assert(is_equal_approx(respawned.hp, 75.0), "actor respawn preserves damaged family condition")
	respawned.set_physics_process(false)
	respawned.shields = 0.0
	respawned.shield_delay = 0.0
	game._process(1.0)
	assert(is_equal_approx(respawned.shields, 5.0) and is_equal_approx(float(fleet_ship.defense.charge), 5.0), "hosted frame recharges and synchronizes fleet shield")
	respawned.active = true
	respawned._physics_process(0.1)
	assert(is_equal_approx(respawned.shields, 5.0), "local actor physics does not double recharge fleet shields")
	game.deck.show_page("fleet")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await create_timer(0.4).timeout
		assert(root.get_texture().get_image().save_png("user://fleet-families.png") == OK)
		print("FLEET_FAMILIES_CAPTURE: ", ProjectSettings.globalize_path("user://fleet-families.png"))
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	print("FLEET_FAMILIES_OK: commission quotes, atomic validation, legacy saves and family visuals")
	quit()

func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()

func _motion_probe(blueprint: Dictionary, cargo_mass: float, x: float, temperature: float = 450.0) -> ShipActor:
	var actor := ShipActor.new()
	actor.hull_family = str(blueprint.family)
	actor.position = Vector3(x, 0, 0)
	actor.cargo_mass_kg = cargo_mass
	root.add_child(actor)
	actor.set_physics_process(false)
	await physics_frame
	actor.position = Vector3(x, 0, 0)
	actor.velocity = Vector3.ZERO
	actor.drive_temperature_k = temperature
	actor.set_travel_target(actor.position + Vector3(10000, 0, 0))
	actor._physics_process(1.0)
	return actor
