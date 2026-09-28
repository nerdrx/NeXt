extends SceneTree

func _initialize() -> void:
	_run()


func _run() -> void:
	var profile := PackedVector2Array([Vector2(0.5, -2.0), Vector2(1.0, 0.0), Vector2(0.75, 2.0)])
	var mesh := HullGeometry.lathe_z(profile, 16)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert(vertices.size() == 2 * 16 * 6, "lathe has side quads only, without end caps")
	var bounds := mesh.get_aabb()
	assert(is_equal_approx(bounds.position.z, -2.0) and is_equal_approx(bounds.end.z, 2.0), "lathe preserves profile depth")
	assert(is_equal_approx(bounds.size.x, 2.0) and is_equal_approx(bounds.size.y, 2.0), "lathe reaches maximum profile radius")
	for i in vertices.size():
		assert(vertices[i].is_finite(), "vertices are finite")
		assert(normals[i].is_finite() and is_equal_approx(normals[i].length(), 1.0), "normals are finite and unit length")
		assert(normals[i].dot(Vector3(vertices[i].x, vertices[i].y, 0.0)) > 0.0, "ascending profile normals face outwards")
	var reversed := HullGeometry.lathe_z(PackedVector2Array([Vector2(0.75, 2), Vector2(1, 0), Vector2(0.5, -2)]), 16)
	var reversed_arrays := reversed.surface_get_arrays(0)
	var reversed_vertices: PackedVector3Array = reversed_arrays[Mesh.ARRAY_VERTEX]
	var reversed_normals: PackedVector3Array = reversed_arrays[Mesh.ARRAY_NORMAL]
	for i in reversed_vertices.size():
		assert(reversed_normals[i].dot(Vector3(reversed_vertices[i].x, reversed_vertices[i].y, 0.0)) < 0.0, "descending profile normals face inwards")
	assert(HullGeometry.lathe_z(PackedVector2Array([Vector2(-1, 0), Vector2(1, 1)])).get_surface_count() == 0, "negative radius returns empty mesh")
	assert(HullGeometry.lathe_z(PackedVector2Array([Vector2(1, 0)])).get_surface_count() == 0, "short profile returns empty mesh")
	assert(HullGeometry.lathe_z(profile, 2).get_surface_count() == 0, "too few segments returns empty mesh")
	assert(HullGeometry.lathe_z(profile, 129).get_surface_count() == 0, "too many segments returns empty mesh")
	var visual := FleetShipVisual.new()
	var origin := Vector3(3, 4, 5)
	var instance := visual._lathe_z(origin, PackedVector2Array([Vector2(1, -1), Vector2(1, 1)]), StandardMaterial3D.new(), 8)
	assert(instance.position == origin, "wrapper positions local mesh at requested origin")
	var local_vertices: PackedVector3Array = instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(is_equal_approx(local_vertices[0].x * local_vertices[0].x + local_vertices[0].y * local_vertices[0].y, 1.0), "wrapper mesh vertices remain origin-local")
	visual.free()
	print("NOZZLE_GEOMETRY_OK: open sides, bounds, normals, winding and wrapper origin")
	quit()
