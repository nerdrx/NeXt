extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")
const ShipBlueprintScript = preload("res://scripts/ship_blueprint.gd")
const ShipLayoutScript = preload("res://scripts/ship_layout.gd")

var save_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	save_path = "user://custom-fleet-%d.json" % OS.get_process_id()
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".tmp"):
		_fail("unique test save path already exists")
		return
	var state := GameStateScript.new()
	state.credits = 100000
	assert(state.add_module("habitat", Vector3i(0, 0, 3)).is_empty(), "custom design accepts a powered habitat")
	assert(ShipLayoutScript.configure_room(state, Vector3i(0, 0, 3), "medical").is_empty(), "custom design has a non-default room layout")
	assert(ShipLayoutScript.set_panel(state, Vector3i(0, 0, 0), "-z", "armored").is_empty(), "custom design has a non-default hull panel")
	assert(ShipBlueprintScript.valid_custom_modules(state.ship_modules), "starter design with the new habitat remains a valid custom blueprint")
	state.cargo.ore = 2
	state.hull = 57.0
	state.shield = maxf(0.0, float(state.ship_stats().max_shield) - 23.0)
	state.fuel = 41.0
	state.drive_temperature_k = 612.0
	var modules_before: Array[Dictionary] = state.ship_modules.duplicate(true)
	var layout_before: Dictionary = state.ship_layout.duplicate(true)
	var cargo_before: Dictionary = state.cargo.duplicate(true)
	var credits_before: int = state.credits
	var orders := CrewOrdersScript.new(state)
	var quote: Dictionary = orders.custom_design_quote()
	var expected_price := 0
	for module: Dictionary in state.ship_modules:
		expected_price += int(GameStateScript.MODULES[module.kind].cost)
	assert(quote.error.is_empty() and int(quote.price) == expected_price and int(quote.capacity) == state.ship_stats().cargo_capacity, "custom quote matches the current design cost and capacity")

	assert(orders.purchase_custom_ship("Custom Copy").is_empty(), "custom design commissions successfully")
	var ship: Dictionary = state.fleet_ships.back()
	assert(ship.hull_family == "custom" and ship.hull == 100.0 and ship.cargo.is_empty(), "commissioned copy starts at full hull with an empty hold")
	assert(ship.modules == modules_before and ship.layout == layout_before, "commissioned copy preserves exact modules and layout")
	assert(state.credits == credits_before - expected_price, "commission charges summed module cost")
	assert(state.ship_modules == modules_before and state.ship_layout == layout_before and state.cargo == cargo_before, "commission leaves player design and cargo untouched")
	assert(state.hull == 57.0 and state.fuel == 41.0 and is_equal_approx(state.shield, float(state.ship_stats().max_shield) - 23.0) and state.drive_temperature_k == 612.0, "commission leaves player condition unchanged")

	var saved_modules: Array[Dictionary] = ship.modules.duplicate(true)
	var saved_layout: Dictionary = ship.layout.duplicate(true)
	ship.modules[0].kind = "cargo"
	ship.layout.rooms["0,0,3"] = "quarters"
	assert(state.ship_modules == modules_before and state.ship_layout == layout_before, "fleet blueprint does not alias the player design")
	ship.modules = saved_modules
	ship.layout = saved_layout
	state.ship_modules[0].kind = "cargo"
	state.ship_layout.rooms["0,0,3"] = "quarters"
	assert(ship.modules == saved_modules and ship.layout == saved_layout, "player edits do not alias the commissioned blueprint")
	state.ship_modules = modules_before.duplicate(true)
	state.ship_layout = layout_before.duplicate(true)

	var stable: Dictionary = state._save_data().duplicate(true)
	assert(not orders.purchase_custom_ship("Custom Copy").is_empty() and state._save_data() == stable, "duplicate fleet name is rejected atomically")
	state.credits = 0
	stable = state._save_data().duplicate(true)
	assert(not orders.purchase_custom_ship("Unaffordable").is_empty() and state._save_data() == stable, "insufficient credits are rejected atomically")
	state.credits = credits_before - expected_price
	var original_modules: Array[Dictionary] = state.ship_modules.duplicate(true)
	state.ship_modules[0].kind = "unknown"
	stable = state._save_data().duplicate(true)
	assert(not orders.custom_design_quote().error.is_empty(), "invalid current design has no commission quote")
	assert(not orders.purchase_custom_ship("Invalid Design").is_empty() and state._save_data() == stable, "invalid design purchase is rejected atomically")
	state.ship_modules = original_modules

	var model := GameStateScript.new()
	model.ship_modules.assign(ship.modules)
	model.ship_layout = ship.layout.duplicate(true)
	var stats: Dictionary = model.ship_stats()
	ship.defense = {"charge": float(stats.max_shield) - 7.0, "delay": 2.5}
	ship.drive_temperature_k = 623.0
	assert(state.save(save_path).is_empty(), "custom fleet save succeeds")
	var restored := GameStateScript.new()
	assert(restored.load_save(save_path).is_empty(), "custom fleet save reloads")
	var restored_ship: Dictionary = restored.fleet_ships.back()
	assert(restored_ship.modules == ship.modules and _layout_matches(restored_ship.layout, ship.layout), "custom blueprint and layout round-trip")
	assert(restored_ship.defense == ship.defense and restored_ship.drive_temperature_k == ship.drive_temperature_k, "custom shields and drive temperature round-trip")

	var valid_data: Dictionary = restored._save_data().duplicate(true)
	var custom: Dictionary = valid_data.fleet_ships.back()
	var invalid_records: Array[Dictionary] = []
	var bad: Dictionary = valid_data.duplicate(true)
	bad.fleet_ships.back().modules[1].x = int(bad.fleet_ships.back().modules[0].x)
	bad.fleet_ships.back().modules[1].y = int(bad.fleet_ships.back().modules[0].y)
	bad.fleet_ships.back().modules[1].z = int(bad.fleet_ships.back().modules[0].z)
	invalid_records.append(bad)
	bad = valid_data.duplicate(true)
	var disconnected := _module_index(bad.fleet_ships.back().modules, "cargo")
	bad.fleet_ships.back().modules[disconnected].x = 8
	bad.fleet_ships.back().modules[disconnected].y = 0
	bad.fleet_ships.back().modules[disconnected].z = 8
	invalid_records.append(bad)
	bad = valid_data.duplicate(true)
	bad.fleet_ships.back().modules[0].kind = "unknown"
	invalid_records.append(bad)
	bad = valid_data.duplicate(true)
	bad.fleet_ships.back().modules[0].x = 999
	invalid_records.append(bad)
	bad = valid_data.duplicate(true)
	bad.fleet_ships.back().erase("modules")
	invalid_records.append(bad)
	bad = valid_data.duplicate(true)
	bad.fleet_ships.back().capacity += 1
	invalid_records.append(bad)
	bad = valid_data.duplicate(true)
	bad.fleet_ships.back().defense.charge = float(stats.max_shield) + 1.0
	invalid_records.append(bad)
	for malformed: Dictionary in invalid_records:
		_write_save(malformed)
		assert(not restored.load_save(save_path).is_empty(), "corrupt custom fleet record is rejected")
		assert(restored._save_data() == valid_data, "rejected custom fleet record leaves state unchanged")

	var actor := ShipActor.new()
	actor.hull_family = "custom"
	actor.hull_modules = restored_ship.modules.duplicate(true)
	actor.hull_layout = restored_ship.layout.duplicate(true)
	actor.actor_id = "custom-fleet-test"
	actor.set_physics_process(false)
	root.add_child(actor)
	await process_frame
	assert(is_equal_approx(actor.max_hull, float(stats.max_hull)) and is_equal_approx(actor.weapon_damage, float(stats.damage)), "custom actor uses the design hull and weapon stats")
	assert(actor._visual is ShipVisual and actor._visual.get_child_count() > 0, "custom actor builds the module visual")
	var collision_nodes := actor.find_children("*", "CollisionShape3D", true, false)
	assert(not collision_nodes.is_empty(), "custom actor creates a collision shape")
	var collision := collision_nodes[0] as CollisionShape3D
	assert(collision.shape is ConvexPolygonShape3D and (collision.shape as ConvexPolygonShape3D).points.size() > 0, "custom actor builds collision from its module visual")
	actor.queue_free()
	await process_frame
	_cleanup()
	print("CUSTOM_FLEET_OK: commissioned custom copy, strict save validation, shield persistence, actor visual and collision")
	quit()


func _module_index(modules: Array, kind: String) -> int:
	for index: int in range(modules.size()):
		if str(modules[index].get("kind", "")) == kind:
			return index
	return 0


func _layout_matches(actual: Dictionary, expected: Dictionary) -> bool:
	return int(actual.get("version", -1)) == ShipLayoutScript.VERSION and actual.get("rooms", {}) == expected.get("rooms", {}) and actual.get("panels", {}) == expected.get("panels", {})


func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	assert(file != null, "test save can be written")
	file.store_string(JSON.stringify(data))
	file.close()


func _cleanup() -> void:
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	push_error("CUSTOM_FLEET_FAILED: " + message)
	quit(1)
