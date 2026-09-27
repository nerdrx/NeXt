extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")
const ShipActorScript = preload("res://scripts/ship_actor.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_actor_thermal_dynamics()
	_test_fleet_temperature_save_validation()
	print("NPC thermal tests passed")
	quit()


func _test_actor_thermal_dynamics() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var actor: ShipActor = ShipActorScript.new()
	actor.hostile = false
	scene.add_child(actor)
	await physics_frame
	assert(is_equal_approx(float(actor.get("drive_temperature_k")), 450.0), "NPC drive starts at nominal temperature")
	assert(is_equal_approx(float(actor.get("radiator_area_m2")), 40.0), "NPC radiator starts at baseline area")
	var initial_temperature: float = float(actor.get("drive_temperature_k"))
	actor.set_travel_target(Vector3(10000, 0, 0))
	for _frame in range(30): await physics_frame
	var warmed_temperature: float = float(actor.get("drive_temperature_k"))
	assert(actor.velocity.length() > 1.0 and warmed_temperature > initial_temperature, "actual AI thrust warms its drive")
	assert(is_finite(warmed_temperature) and warmed_temperature <= 700.0, "drive temperature remains bounded")

	# Match commanded velocity to current cruise speed: negligible thrust lets the radiator cool.
	actor.restore_flight_velocity(Vector3(actor.speed, 0, 0))
	actor.set_travel_target(Vector3(10000, 0, 0))
	var before_coast_temperature: float = float(actor.get("drive_temperature_k"))
	var before_coast_speed: float = actor.velocity.length()
	for _frame in range(30): await physics_frame
	assert(float(actor.get("drive_temperature_k")) < before_coast_temperature, "coasting radiates accumulated heat")
	assert(actor.velocity.length() > before_coast_speed * 0.75, "cooling does not delete inertial velocity")

	var cold: ShipActor = ShipActorScript.new()
	cold.hostile = false
	cold.position = Vector3(0, 0, 100)
	cold.speed = 65.0
	cold.set_travel_target(Vector3(10000, 0, 100))
	scene.add_child(cold)
	var hot: ShipActor = ShipActorScript.new()
	hot.hostile = false
	hot.position = Vector3(0, 0, 200)
	hot.speed = 65.0
	hot.set("drive_temperature_k", 700.0)
	hot.set_travel_target(Vector3(10000, 0, 200))
	scene.add_child(hot)
	await physics_frame
	for _frame in range(12): await physics_frame
	assert(cold.velocity.length() > hot.velocity.length() + 0.25, "hot drive limits thrust compared with cold drive")
	assert(cold.velocity.is_finite() and hot.velocity.is_finite(), "temperature-limited velocity remains finite")

	actor.restore_flight_velocity(Vector3(65, 0, 0))
	actor.set_travel_target(Vector3(10000, 0, 0))
	actor.set("drive_temperature_k", 300.0)
	var cold_power: float = float(actor.call("thermal_emission_w"))
	actor.set("drive_temperature_k", 650.0)
	var hot_power: float = float(actor.call("thermal_emission_w"))
	assert(is_finite(cold_power) and is_finite(hot_power) and cold_power > 0.0 and hot_power > cold_power, "emitted thermal power rises with temperature")
	actor.set("active", false)
	var paused_temperature: float = float(actor.get("drive_temperature_k"))
	var paused_velocity: Vector3 = actor.velocity
	for _frame in range(12): await physics_frame
	assert(is_equal_approx(float(actor.get("drive_temperature_k")), paused_temperature) and actor.velocity.distance_to(paused_velocity) < 0.001, "inactive passive NPC simulation pauses")
	scene.queue_free()
	await process_frame


func _test_fleet_temperature_save_validation() -> void:
	var state := GameStateScript.new()
	state.credits = 50000
	assert(state.hire("trader").is_empty(), "hire trader through normal economy")
	assert(CrewOrdersScript.new(state).purchase_ship("Thermal Courier").is_empty(), "commission ship through normal fleet path")
	state.fleet_ships[0].drive_temperature_k = 612.5
	var path := "user://npc-thermal-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty(), "fleet temperature saves")
	var loaded = GameStateScript.new()
	assert(loaded.load_save(path).is_empty() and is_equal_approx(float(loaded.fleet_ships[0].drive_temperature_k), 612.5), "fleet temperature round-trips")

	var document: Dictionary = _read_save(path)
	document.fleet_ships[0].erase("drive_temperature_k")
	_write_save(path, document)
	loaded = GameStateScript.new()
	assert(loaded.load_save(path).is_empty() and not loaded.fleet_ships[0].has("drive_temperature_k"), "older fleet records without temperature still load")
	var default_actor: ShipActor = ShipActorScript.new()
	assert(is_equal_approx(float(default_actor.get("drive_temperature_k")), 450.0), "legacy fleet actor receives nominal thermal default")
	default_actor.free()

	for invalid_temperature: Variant in [299.0, 701.0, "hot"]:
		document = _read_save(path)
		document.fleet_ships[0].drive_temperature_k = invalid_temperature
		_write_save(path, document)
		var guarded = GameStateScript.new()
		guarded.credits = 12345
		var error: String = guarded.load_save(path)
		assert(not error.is_empty() and guarded.credits == 12345, "malformed temperature rejects load transactionally: %s" % str(invalid_temperature))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _read_save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "saved state can be read")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert(parsed is Dictionary, "save is valid JSON")
	return parsed


func _write_save(path: String, document: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "save fixture can be written")
	file.store_string(JSON.stringify(document))
	file.close()
