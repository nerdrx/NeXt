extends SceneTree

const MAX_EXTENT := Vector3(0.20, 0.23, 0.23)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var shell := StandardMaterial3D.new()
	var visor := StandardMaterial3D.new()
	var trim := StandardMaterial3D.new()
	var helmet: Node3D = CrewHelmet.build(shell, visor, trim)
	var surfaces := 0
	var vertices_checked := 0
	var faceplate: MeshInstance3D
	for child in helmet.get_children():
		if child is MeshInstance3D and child.mesh is ArrayMesh:
			surfaces += 1
			if child.name == "Faceplate":
				faceplate = child
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			assert(not vertices.is_empty() and vertices.size() == normals.size())
			assert(indices.size() > 0 and indices.size() % 3 == 0)
			for index in vertices.size():
				var vertex := vertices[index]
				assert(vertex.is_finite() and normals[index].is_finite())
				assert(absf(vertex.x) <= MAX_EXTENT.x and absf(vertex.y) <= MAX_EXTENT.y and absf(vertex.z) <= MAX_EXTENT.z, "helmet exceeded intended envelope")
				vertices_checked += 1
			for i in range(0, indices.size(), 3):
				var a: int = indices[i]
				var b: int = indices[i + 1]
				var c: int = indices[i + 2]
				var cross: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
				assert(cross.length_squared() > 0.0000000001, "degenerate helmet triangle")
				var outward := (normals[a] + normals[b] + normals[c]).normalized()
				assert(cross.dot(outward) < 0.0, "triangle winding must be clockwise from outside")
	assert(surfaces == 4 and faceplate != null)
	var face_arrays: Array = faceplate.mesh.surface_get_arrays(0)
	var face_vertices: PackedVector3Array = face_arrays[Mesh.ARRAY_VERTEX]
	var max_shell_gap := 0.0
	for point in face_vertices:
		max_shell_gap = maxf(max_shell_gap, _ellipsoid_surface_gap(point))
	assert(max_shell_gap <= 0.005, "faceplate is not flush to shell")
	print("CREW_HELMET_TEST_OK surfaces=", surfaces, " vertices=", vertices_checked, " faceplate_gap=", max_shell_gap)
	_free_helmet(helmet)
	await process_frame
	quit()

func _free_helmet(helmet: Node3D) -> void:
	helmet.free()

func _ellipsoid_surface_gap(point: Vector3) -> float:
	var surface_point := point
	for _iteration in 8:
		var gradient := Vector3(surface_point.x / (0.19 * 0.19), surface_point.y / (0.225 * 0.225), surface_point.z / (0.22 * 0.22))
		var implicit := surface_point.x * surface_point.x / (0.19 * 0.19) + surface_point.y * surface_point.y / (0.225 * 0.225) + surface_point.z * surface_point.z / (0.22 * 0.22) - 1.0
		surface_point -= gradient.normalized() * implicit / (2.0 * gradient.length())
	return point.distance_to(surface_point)
