extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var actor := ShipActor.new()
	actor.hull_family = "pathfinder"
	root.add_child(actor)
	actor.set_physics_process(false)
	await process_frame
	var blueprint: Dictionary = ShipBlueprint.family("pathfinder")
	var model = GameStateScript.new()
	model.ship_modules.assign(blueprint.modules)
	assert(is_equal_approx(actor.max_shields, float(model.ship_stats().max_shield)), "family actor gets max shields from family stats")
	actor.shields = 0.0
	actor.shield_delay = 6.0
	actor._tick_shields(5.0)
	assert(actor.shields == 0.0 and actor.shield_delay == 1.0, "family shields do not recharge before six seconds")
	actor._tick_shields(1.0)
	assert(actor.shields == 0.0, "no shield charge at exact delay boundary")
	actor._tick_shields(1.0)
	assert(is_equal_approx(actor.shields, 5.0), "shields recharge at five units per second after delay")
	actor.shields = actor.max_shields - 2.0
	actor.shield_delay = 0.0
	actor._tick_shields(1.0)
	assert(actor.shields == actor.max_shields, "shield recharge clamps at family capacity")
	actor.shield_delay = 1.0
	actor.take_damage(1.0)
	assert(actor.shield_delay == 6.0, "damage restarts shield delay")
	actor.active = false
	actor.shields = 0.0
	actor.shield_delay = 0.0
	actor._tick_shields(1.0)
	assert(actor.shields == 0.0, "inactive actor does not regenerate shields")
	actor.queue_free()
	await process_frame
	var legacy_actor := ShipActor.new()
	legacy_actor.shields = 40.0
	legacy_actor._tick_shields(20.0)
	assert(legacy_actor.max_shields == 0.0 and legacy_actor.shields == 40.0, "legacy actor without shield capacity stays unchanged")
	legacy_actor.queue_free()
	await process_frame

	var state = GameStateScript.new()
	state.credits = 100000
	var orders := CrewOrdersScript.new(state)
	assert(orders.purchase_ship("Shield Test", "pathfinder").is_empty())
	state.fleet_ships[0].defense = {"charge": 37.5, "delay": 2.25}
	var path := "user://fleet-shields-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty(), "save family shield state")
	var loaded = GameStateScript.new()
	assert(loaded.load_save(path).is_empty(), "load family shield state")
	assert(loaded.fleet_ships[0].defense == {"charge": 37.5, "delay": 2.25}, "family shield charge and delay round-trip")
	var stable: Dictionary = loaded._save_data().duplicate(true)
	for invalid_charge: Variant in [-1.0, INF, 1000000.0, "37.5"]:
		var invalid: Dictionary = state._save_data().duplicate(true)
		invalid.fleet_ships[0].defense.charge = invalid_charge
		_write(path, invalid)
		assert(not loaded.load_save(path).is_empty() and loaded._save_data() == stable, "invalid shield charge is rejected atomically")
	for invalid_delay: Variant in [-0.1, 6.1, INF, "2.25"]:
		var invalid: Dictionary = state._save_data().duplicate(true)
		invalid.fleet_ships[0].defense.delay = invalid_delay
		_write(path, invalid)
		assert(not loaded.load_save(path).is_empty() and loaded._save_data() == stable, "invalid shield delay is rejected atomically")
	var extra_field: Dictionary = state._save_data().duplicate(true)
	extra_field.fleet_ships[0].defense.extra = true
	_write(path, extra_field)
	assert(not loaded.load_save(path).is_empty() and loaded._save_data() == stable, "unknown defense field is rejected atomically")
	var legacy_orders := CrewOrdersScript.new(GameStateScript.new())
	assert(legacy_orders.purchase_ship("Legacy Shield Test").is_empty())
	var legacy_defense: Dictionary = state._save_data().duplicate(true)
	legacy_defense.fleet_ships = legacy_orders.state.fleet_ships.duplicate(true)
	legacy_defense.fleet_ships[0].defense = {"charge": 1.0, "delay": 0.0}
	_write(path, legacy_defense)
	assert(not loaded.load_save(path).is_empty() and loaded._save_data() == stable, "legacy fleet defense is rejected atomically")
	for file_path: String in [path, path + ".bak"]:
		if FileAccess.file_exists(file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	print("FLEET_SHIELDS_OK: family capacity, recharge, delay and save validation")
	quit()

func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
