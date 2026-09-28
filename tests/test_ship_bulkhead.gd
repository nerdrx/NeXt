extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _frames(count: int) -> void:
	for index in range(count): await physics_frame

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var cabin := ShipInterior.new()
	cabin.position.x = 20.0
	scene.add_child(cabin)
	var modules: Array[Dictionary] = [{"kind":"cockpit", "x":0, "y":0, "z":0}, {"kind":"habitat", "x":0, "y":0, "z":1}]
	cabin.build(modules)
	assert(cabin.find_children("*", "ShipBulkhead", true, false).size() == 1, "shared room boundary creates exactly one bulkhead")
	var door := ShipBulkhead.new()
	scene.add_child(door)
	var walker := CharacterBody3D.new()
	walker.collision_layer = 8
	walker.collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.88
	walker.add_child(collision)
	walker.position = Vector3(0, 0, -2.5)
	scene.add_child(walker)
	await _frames(3)
	assert(not cabin.crew_path(Vector3(0, 0.1, 0), Vector3(0, 0.1, 2.8)).is_empty(), "closed automatic door remains routable for crew")
	assert(door.open_fraction == 0.0, "unoccupied door starts closed")
	assert(walker.move_and_collide(Vector3(0, 0, 4)) != null, "closed panels physically stop the capsule")
	await _frames(40)
	assert(door.open_fraction > 0.99, "approaching character opens the bulkhead")
	assert(walker.move_and_collide(Vector3(0, 0, 1.2)) == null, "open panels leave capsule clearance")
	walker.position.z = 0.0
	await _frames(100)
	assert(door.open_fraction > 0.99, "occupant in doorway prevents closing")
	walker.position.z = 4.0
	await _frames(100)
	assert(door.open_fraction < 0.01, "door closes after occupant leaves and hold expires")
	walker.position.z = 1.2
	await _frames(40)
	assert(door.open_fraction > 0.99, "opposite side also opens the door")
	scene.queue_free()
	await process_frame
	print("SHIP_BULKHEAD_OK: closed collision, two-sided approach, capsule clearance and occupancy hold")
	quit()
