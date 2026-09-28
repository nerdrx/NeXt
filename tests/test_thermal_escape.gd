extends SceneTree

var fired_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _track_fired(_actor: ShipActor, _origin: Vector3, _direction: Vector3) -> void:
	fired_count += 1


func _run() -> void:
	assert("--capture-only" in OS.get_cmdline_user_args())
	var world := Node3D.new()
	root.add_child(world)
	var ship := ShipActor.new()
	ship.position = Vector3(1000.0, 0.0, 0.0)
	ship.drive_temperature_k = 600.0
	ship.radiator_area_m2 = 40.0
	ship.systems_heat_w = 0.0
	ship.stellar_heat_w = 1000000.0
	ship.set_travel_target(ship.position + Vector3.LEFT * 500.0)
	var travel_order := ship.travel_target
	var samples := [0]
	ship.stellar_heat_source = func(point: Vector3, _orientation: Basis, _size: Vector3) -> float:
		samples[0] += 1
		return 10000000.0 * exp(-point.x / 500.0)
	world.add_child(ship)
	ship.set_physics_process(false)
	await process_frame
	ship.stellar_heat_w = 10000000.0 * exp(-ship.global_position.x / 500.0)
	ship._update_thermal_escape(0.01)
	assert(ship.thermal_retreat and ship._thermal_escape_direction.is_equal_approx(Vector3.RIGHT), "ship chooses the cooler +X world sample despite its -X travel order")
	assert(samples[0] == 6, "one probe evaluates exactly six world axes")
	assert(ship.travel_target == travel_order and ship.travel_active, "thermal escape preserves the stored travel order")
	ship._update_thermal_escape(0.98)
	assert(samples[0] == 6, "probe work stays bounded before one second")
	ship._update_thermal_escape(0.03)
	assert(samples[0] == 12, "a new six-axis probe runs after one second")

	# A hot hostile ship follows escape steering and does not fire at a target behind it.
	var target := ShipActor.new()
	target.position = ship.position + Vector3.LEFT * 100.0
	world.add_child(target)
	target.set_physics_process(false)
	ship.target = target
	ship.hostile = true
	ship.fired.connect(_track_fired)
	ship._physics_process(0.1)
	assert(ship.velocity.x > 0.0, "active thermal escape overrides the -X destination")
	assert(fired_count == 0, "thermal retreat suspends hostile firing")
	assert(ship.travel_target == travel_order, "escape steering leaves the travel order intact")

	# Heatless exposure releases retreat even while the drive remains above 500 K.
	ship.stellar_heat_w = 0.0
	ship._update_thermal_escape(0.1)
	assert(not ship.thermal_retreat and ship._thermal_escape_direction == Vector3.ZERO, "zero stellar heat clears retreat for radiator cooling")
	ship.drive_temperature_k = 525.0
	ship.stellar_heat_w = 10000000.0 * exp(-ship.global_position.x / 500.0)
	ship._update_thermal_escape(0.1)
	assert(not ship.thermal_retreat, "a hot drive below the 550 K entry threshold does not start retreat")
	ship.thermal_retreat = true
	ship._thermal_escape_direction = Vector3.RIGHT
	ship._thermal_probe_cooldown = 1.0
	ship._update_thermal_escape(0.1)
	assert(ship.thermal_retreat, "retreat hysteresis holds above 500 K while heat remains")
	ship.drive_temperature_k = 500.0
	ship._update_thermal_escape(0.1)
	assert(not ship.thermal_retreat and ship._thermal_escape_direction == Vector3.ZERO, "500 K ends retreat")

	# A flat or unusable field offers no safe steering direction.
	ship.drive_temperature_k = 600.0
	ship.stellar_heat_w = 1000000.0
	ship.stellar_heat_source = func(_point: Vector3, _orientation: Basis, _size: Vector3) -> float: return 1000000.0
	ship._update_thermal_escape(1.0)
	assert(not ship.thermal_retreat and ship._thermal_escape_direction == Vector3.ZERO, "flat heat field does not cause arbitrary steering")
	ship.stellar_heat_source = func(_point: Vector3, _orientation: Basis, _size: Vector3) -> float: return NAN
	ship._update_thermal_escape(1.0)
	assert(not ship.thermal_retreat and ship._thermal_escape_direction == Vector3.ZERO, "non-finite samples do not cause arbitrary steering")
	ship.stellar_heat_source = Callable()
	ship.thermal_retreat = true
	ship._thermal_escape_direction = Vector3.RIGHT
	ship._update_thermal_escape(0.1)
	assert(not ship.thermal_retreat and ship._thermal_escape_direction == Vector3.ZERO, "missing heat source clears retreat safely")

	# Without thermal retreat, hostile firing remains available.
	var cool_ship := ShipActor.new()
	cool_ship.position = Vector3(2000.0, 0.0, 0.0)
	target.position = cool_ship.position + Vector3.LEFT * 100.0
	cool_ship.drive_temperature_k = 450.0
	cool_ship.hostile = true
	cool_ship.target = target
	cool_ship.stellar_heat_source = func(_point: Vector3, _orientation: Basis, _size: Vector3) -> float: return 0.0
	world.add_child(cool_ship)
	cool_ship.set_physics_process(false)
	cool_ship.fired.connect(_track_fired)
	await process_frame
	cool_ship._physics_process(0.1)
	assert(fired_count == 1, "hostile firing continues after cooling clears thermal retreat")

	world.queue_free()
	await process_frame
	print("THERMAL_ESCAPE_OK: cooler-course search, orders, hysteresis, firing and bounded probes")
	quit()
