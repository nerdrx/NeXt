extends SceneTree

const Defense = preload("res://scripts/ship_defense.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var shooter := ShipActor.new()
	shooter.set_physics_process(false)
	world.add_child(shooter)
	shooter.position = Vector3.ZERO
	var modules: Array = [
		{"kind": "hull", "cell": Vector3i.ZERO},
		{"kind": "weapon", "cell": Vector3i(3, 0, 0)},
	]
	var hull := Transform3D(Basis.IDENTITY, shooter.global_position)
	var mount_local := Vector3(4.2, 1.6, 0)
	var target := _ship(world, Vector3(4.2, 1.6, -100), "pirate")
	await physics_frame
	var exclusions: Array[RID] = [shooter.get_rid()]
	var shot := Defense.find_shot(modules, hull, [target], world.get_world_3d().direct_space_state, exclusions)
	assert(shot.target == target and shot.origin.is_equal_approx(mount_local), "sparse mount uses ShipVisual bounds midpoint and raised turret origin")
	assert(shot.direction.is_equal_approx((target.global_position - shot.origin).normalized()))

	var closer := _ship(world, Vector3(4.2, 1.6, -45), "pirate")
	var cover := StaticBody3D.new()
	var cover_shape := CollisionShape3D.new()
	var cover_box := BoxShape3D.new()
	cover_box.size = Vector3(1, 5, 1)
	cover_shape.shape = cover_box
	cover.position = Vector3(4.2, 1.6, -25)
	cover.add_child(cover_shape)
	world.add_child(cover)
	await physics_frame
	var farther := _ship(world, Vector3(20, 1.6, -100), "pirate")
	await physics_frame
	shot = Defense.find_shot(modules, hull, [closer, farther], world.get_world_3d().direct_space_state, exclusions)
	assert(shot.get("target") == farther, "cover blocks nearest target but helper selects next clear hostile")

	var neutral := _ship(world, Vector3(4.2, 1.6, -35), "civilian")
	await physics_frame
	shot = Defense.find_shot(modules, hull, [neutral], world.get_world_3d().direct_space_state, exclusions)
	assert(shot.is_empty(), "neutral ships are ineligible")
	neutral.queue_free()
	cover.queue_free()
	closer.queue_free()
	farther.queue_free()
	await physics_frame

	var no_weapon := [{"kind": "hull", "cell": Vector3i.ZERO}]
	assert(Defense.find_shot(no_weapon, hull, [target], world.get_world_3d().direct_space_state, exclusions).is_empty(), "ships without weapon modules cannot fire")
	assert(Defense.find_shot(modules, hull, [_ship(world, Vector3(4.2, 1.6, -721), "pirate")], world.get_world_3d().direct_space_state, exclusions).is_empty(), "targets beyond 720m are out of range")

	# A steep downhill ray would enter a different occupied module before leaving the hull.
	var blocked_modules: Array = [
		{"kind": "weapon", "cell": Vector3i.ZERO},
		{"kind": "hull", "cell": Vector3i(0, 0, -1)},
	]
	var low_target := _ship(world, Vector3(0, -20, -100), "pirate")
	var blocked_hull := Transform3D.IDENTITY
	var low_exclusions: Array[RID] = [shooter.get_rid()]
	await physics_frame
	assert(Defense.find_shot(blocked_modules, blocked_hull, [low_target], world.get_world_3d().direct_space_state, low_exclusions).is_empty(), "own occupied hull boxes block shots even when shooter body is excluded")

	print("ShipDefense tests passed: hostile selection, cover, hull obstruction, weapon range and sparse mounts")
	quit()


func _ship(parent: Node3D, position: Vector3, faction: String) -> ShipActor:
	var actor := ShipActor.new()
	actor.faction = faction
	actor.hostile = faction == "pirate"
	actor.set_physics_process(false)
	actor.position = position
	parent.add_child(actor)
	return actor
