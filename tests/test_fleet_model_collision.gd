extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var visual := FleetShipVisual.new()
	var bevel_mesh := visual._bevelled_box_mesh(Vector3(2, 1, 3), 0.025)
	var arrays := bevel_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var edges := {}
	for i in range(0, vertices.size(), 3):
		for j in 3:
			assert(normals[i+j].dot(vertices[i+j]) > 0.0, "bevel normals point outward")
			var a := Vector3i((vertices[i+j] * 100000.0).round())
			var b := Vector3i((vertices[i+(j+1)%3] * 100000.0).round())
			var key := str(a) + ":" + str(b) if str(a) < str(b) else str(b) + ":" + str(a)
			edges[key] = int(edges.get(key, 0)) + 1
	for count in edges.values():
		assert(count == 2, "bevel mesh is closed with two triangles per edge")
	var concave := [Vector2(0,0), Vector2(2,0), Vector2(2,1), Vector2(1,1), Vector2(1,2), Vector2(0,2)]
	visual._poly_prism(concave, -0.1, 0.1, StandardMaterial3D.new())
	var plate := visual.get_child(0) as MeshInstance3D
	var plate_arrays := plate.mesh.surface_get_arrays(0)
	var plate_vertices: PackedVector3Array = plate_arrays[Mesh.ARRAY_VERTEX]
	var plate_normals: PackedVector3Array = plate_arrays[Mesh.ARRAY_NORMAL]
	var area := 0.0
	for i in range(0, plate_vertices.size(), 3):
		if plate_normals[i].y > 0.01:
			assert(plate_vertices[i].y > 0.0, "upward armor faces remain on the top surface")
			area += absf((plate_vertices[i+1]-plate_vertices[i]).cross(plate_vertices[i+2]-plate_vertices[i]).y) * 0.5
	assert(is_equal_approx(area, 3.0), "concave armor is triangulated without covering its cutout")
	var tube := visual._lathe_z(Vector3.ZERO, PackedVector2Array([Vector2(1, -1), Vector2(1, 1)]), StandardMaterial3D.new(), 16)
	var tube_arrays := tube.mesh.surface_get_arrays(0)
	var tube_vertices: PackedVector3Array = tube_arrays[Mesh.ARRAY_VERTEX]
	var tube_normals: PackedVector3Array = tube_arrays[Mesh.ARRAY_NORMAL]
	for i in tube_vertices.size():
		assert(tube_normals[i].dot(Vector3(tube_vertices[i].x, tube_vertices[i].y, 0)) > 0.9, "engine casing normals face outwards")
	visual.free()
	var world := Node3D.new()
	root.add_child(world)
	var ship := ShipActor.new()
	ship.set_physics_process(false)
	world.add_child(ship)
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var wing := PhysicsRayQueryParameters3D.create(Vector3(3.5, 10, 0.8), Vector3(3.5, -10, 0.8), 4)
	var hit := space.intersect_ray(wing)
	assert(not hit.is_empty() and hit.collider == ship, "visible outer wing intercepts weapons beyond the former small sphere")
	var outside := PhysicsRayQueryParameters3D.create(Vector3(8, 10, 0.8), Vector3(8, -10, 0.8), 4)
	assert(space.intersect_ray(outside).is_empty(), "empty space beyond the hull remains clear")
	ship.rotation.y = PI / 2
	await physics_frame
	var turned_wing := PhysicsRayQueryParameters3D.create(Vector3(0.8, 10, -3.5), Vector3(0.8, -10, -3.5), 4)
	assert(not space.intersect_ray(turned_wing).is_empty(), "wing collision rotates with the rendered vessel")
	world.queue_free()
	await process_frame
	print("FLEET_MODEL_COLLISION_OK: wing hits, exterior misses and rotation")
	quit()
