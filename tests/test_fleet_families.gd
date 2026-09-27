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
	assert(integration_orders.purchase_ship("Integrated Pathfinder", "pathfinder").is_empty())
	var fleet_ship: Dictionary = fleet_state.fleet_ships[0]
	var trader_id: String = str(fleet_state.crew[0].id)
	assert(integration_orders.assign_trade_route(trader_id, str(fleet_ship.id), "ore", (fleet_state.system_index + 1) % GameStateScript.SYSTEM_LIMIT).is_empty())
	game.state = fleet_state
	game._sync_fleet_actors()
	var integrated: ShipActor = game.fleet_actors[str(fleet_ship.id)]
	assert(integrated.hull_family == "pathfinder" and integrated._visual.get_node_or_null("FamilyPressureHull") != null,
		"main scene materializes commissioned family hull for its trader order")
	game._clear_actors()
	game._sync_fleet_actors()
	var respawned: ShipActor = game.fleet_actors[str(fleet_ship.id)]
	assert(respawned.hull_family == "pathfinder" and respawned._visual.get_node_or_null("FamilyPressureHull") != null,
		"main scene respawn keeps the commissioned family hull")
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
