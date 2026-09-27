extends SceneTree

const PlanetTerrainScript = preload("res://scripts/planet_terrain.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var terrain = PlanetTerrainScript.new()
	root.add_child(terrain)
	var normal := Vector3.UP
	var tint := Color("7c8b76")
	terrain.build(500.0, normal, 341, tint)
	assert(terrain.anchor.is_equal_approx(normal * 500.0))
	assert(terrain.normal_at_patch.is_equal_approx(normal) and is_equal_approx(terrain.patch_extent, 175.0))
	var vertices: PackedVector3Array = terrain.terrain_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = terrain.terrain_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert(vertices.size() == 49 * 49, "bounded 48-cell patch generated")
	for index: int in vertices.size():
		var vertex: Vector3 = vertices[index]
		assert(vertex.is_finite())
		var direction: Vector3 = (terrain.anchor + vertex).normalized()
		var radial_height: float = (terrain.anchor + vertex).length() - 500.0
		assert(radial_height >= -0.001 and radial_height <= 12.001)
		assert(absf(radial_height - PlanetTerrainScript.surface_height(direction, 341)) < 0.001, "mesh uses the public deterministic height query")
		assert(normals[index].dot(direction) > 0.0, "terrain mesh normals face outward")
	var duplicate = PlanetTerrainScript.new()
	root.add_child(duplicate)
	duplicate.build(500.0, normal, 341, tint)
	var duplicate_vertices: PackedVector3Array = duplicate.terrain_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(vertices == duplicate_vertices, "same seed builds identical geometry")
	var small = PlanetTerrainScript.new()
	root.add_child(small)
	small.build(100.0, Vector3.RIGHT, 17, tint)
	assert(is_equal_approx(small.patch_extent, 35.0) and small.normal_at_patch.is_equal_approx(Vector3.RIGHT), "patch extent scales down on small planets")
	var faces: PackedVector3Array = terrain.terrain_body.get_child(0).shape.get_faces()
	assert(faces.size() == terrain.terrain_mesh.get_faces().size() and faces.size() > 0 and faces == terrain.terrain_mesh.get_faces(), "collision uses the exact generated terrain triangles")
	terrain.position = terrain.anchor
	await physics_frame
	await physics_frame
	var hit: Dictionary = terrain.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(terrain.anchor + normal * 30.0, terrain.anchor - normal * 20.0))
	assert(not hit.is_empty() and hit.collider == terrain.terrain_body, "external ray from above hits the terrain patch")
	var hit_height: float = (hit.position - terrain.anchor).dot(normal)
	assert(hit_height > 0.0 and absf(hit_height - PlanetTerrainScript.surface_height(normal, 341)) < 0.5, "ray hits the generated positive surface height")
	assert(hit.normal.dot(normal) > 0.0, "external terrain collision normal faces outward")
	print("Planet terrain tests passed")
	quit()
