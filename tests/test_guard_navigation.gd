extends SceneTree

var colony: SurfaceColony
var pilot: Pilot
var guard: GroundActor
var shots := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Accelerate simulated time without changing the actor's production movement speed.
	Engine.time_scale = 4.0
	colony = SurfaceColony.new()
	root.add_child(colony)
	colony.build(850, 739, "Guard route fixture")
	pilot = Pilot.new()
	root.add_child(pilot)
	pilot.set_physics_process(false)
	pilot.set_process_input(false)
	for room in 4:
		pilot.position = colony.interior_positions[room] + Vector3(4, 0.05, -4)
		guard = GroundActor.new()
		guard.position = Vector3(-12, 0.1, 12)
		guard.faction = "police"
		guard.hostile = true
		guard.target = pilot
		guard.navigation_source = colony
		guard.pursuit_radius = 100
		guard.fired.connect(func(_actor, _origin, _direction): shots += 1)
		root.add_child(guard)
		shots = 0
		var entered := false
		var shifted := false
		for frame in 1000:
			await physics_frame
			var local := colony.to_local(guard.global_position)
			if not _check(local.y > -0.5, "guard stays on supported deck in room %d" % room): return
			if room == 3 and frame == 80:
				var shift := Vector3(4096, 0, -4096)
				colony.position -= shift
				pilot.position -= shift
				guard.position -= shift
				guard.apply_origin_shift(shift)
				shifted = true
			var center: Vector3 = colony.interior_positions[room]
			entered = absf(local.x - center.x) < 6 and local.z < center.z + 6.5 and local.z > center.z - 6.5
			if entered and shots > 0 and guard._has_line_of_sight(): break
		if not _check(entered and shots > 0 and guard._has_line_of_sight(), "guard enters room %d and fires through clear sightline; position %s" % [room, colony.to_local(guard.global_position)]): return
		if room == 3 and not _check(shifted, "origin shift exercised during pursuit"): return
		guard.queue_free()
		await process_frame
	# Inaccessible space must not send a guard walking off the deck.
	guard = GroundActor.new()
	guard.position = colony.to_global(Vector3(-12, 0.1, 12))
	guard.target = pilot
	guard.navigation_source = colony
	guard.pursuit_radius = 100
	pilot.position = colony.to_global(Vector3(60, 0.05, 12))
	root.add_child(guard)
	var start := guard.position
	for frame in 60: await physics_frame
	if not _check(Vector2(guard.position.x - start.x, guard.position.z - start.z).length() < 0.1 and guard.is_on_floor(), "unreachable pursuit stops safely"): return
	guard.queue_free()
	pilot.queue_free()
	colony.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	print("GUARD_NAVIGATION_OK: physical pursuit through four room doors, clear firing sightlines, origin shift, unreachable target safety")
	quit(0)

func _check(value: bool, message: String) -> bool:
	if value: return true
	push_error(message)
	quit(1)
	return false
