class_name CrewHelmet
extends RefCounted

const _RADII := Vector3(0.19, 0.225, 0.22)

static func build(shell: Material, visor: Material, trim: Material) -> Node3D:
	var helmet := Node3D.new()
	helmet.name = "CrewHelmet"
	_add_surface(helmet, _ellipsoid(), shell, "Shell")
	_add_surface(helmet, _patch(-0.74, 1.05, 0.87, 0.003, 20, 24), visor, "Faceplate")
	_add_surface(helmet, _patch(1.06, 1.27, 0.90, 0.004, 4, 24), trim, "BrowBand")
	_add_surface(helmet, _patch(-0.97, -0.76, 0.90, 0.004, 4, 24), trim, "ChinBand")
	for side: float in [-1.0, 1.0]:
		var hardware := MeshInstance3D.new()
		hardware.name = "SideHardware"
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 16
		sphere.rings = 8
		hardware.mesh = sphere
		hardware.material_override = trim
		hardware.scale = Vector3(0.022, 0.045, 0.028)
		hardware.position = Vector3(side * 0.166, -0.012, -0.096)
		helmet.add_child(hardware)
	return helmet

static func _ellipsoid() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	const RINGS := 14
	const SEGMENTS := 28
	for ring: int in RINGS:
		var phi: float = lerpf(-PI * 0.5 + 0.055, PI * 0.5 - 0.055, float(ring) / float(RINGS - 1))
		for segment: int in SEGMENTS:
			var theta: float = TAU * float(segment) / float(SEGMENTS)
			var point := _point(phi, theta, 0.0)
			vertices.append(point)
			normals.append(_normal(point))
	var bottom: int = vertices.size()
	vertices.append(Vector3(0, -_RADII.y, 0))
	normals.append(Vector3.DOWN)
	var top: int = vertices.size()
	vertices.append(Vector3(0, _RADII.y, 0))
	normals.append(Vector3.UP)
	for ring: int in RINGS - 1:
		for segment: int in SEGMENTS:
			var next: int = (segment + 1) % SEGMENTS
			var a: int = ring * SEGMENTS + segment
			var b: int = ring * SEGMENTS + next
			var c: int = (ring + 1) * SEGMENTS + segment
			var d: int = (ring + 1) * SEGMENTS + next
			_append_triangle(indices, vertices, a, c, b, normals[a] + normals[b] + normals[c])
			_append_triangle(indices, vertices, b, c, d, normals[b] + normals[c] + normals[d])
	for segment: int in SEGMENTS:
		var next: int = (segment + 1) % SEGMENTS
		_append_triangle(indices, vertices, bottom, next, segment, Vector3.DOWN)
		var a: int = (RINGS - 1) * SEGMENTS + segment
		var b: int = (RINGS - 1) * SEGMENTS + next
		_append_triangle(indices, vertices, a, top, b, Vector3.UP)
	return _make_mesh(vertices, normals, indices)

static func _patch(phi_min: float, phi_max: float, half_width: float, offset: float, rows: int, columns: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for row: int in rows + 1:
		var t: float = float(row) / float(rows)
		var phi: float = lerpf(phi_min, phi_max, t)
		var end_t: float = t * 2.0 - 1.0
		var width_scale: float = 0.78 + 0.22 * cos(end_t * PI * 0.5)
		for column: int in columns + 1:
			var u: float = float(column) / float(columns) * 2.0 - 1.0
			var theta: float = u * half_width * width_scale
			var surface_point := _point(phi, theta, 0.0)
			var normal := _normal(surface_point)
			vertices.append(surface_point + normal * offset)
			normals.append(normal)
	for row: int in rows:
		for column: int in columns:
			var a: int = row * (columns + 1) + column
			var b: int = a + 1
			var c: int = a + columns + 1
			var d: int = c + 1
			_append_triangle(indices, vertices, a, c, b, normals[a] + normals[b] + normals[c])
			_append_triangle(indices, vertices, b, c, d, normals[b] + normals[c] + normals[d])
	return _make_mesh(vertices, normals, indices)

static func _point(phi: float, theta: float, offset: float) -> Vector3:
	var ring: float = cos(phi)
	var point := Vector3(_RADII.x * ring * sin(theta), _RADII.y * sin(phi), -_RADII.z * ring * cos(theta))
	return point + _normal(point) * offset if offset != 0.0 else point

static func _normal(point: Vector3) -> Vector3:
	return Vector3(point.x / (_RADII.x * _RADII.x), point.y / (_RADII.y * _RADII.y), point.z / (_RADII.z * _RADII.z)).normalized()

static func _append_triangle(indices: PackedInt32Array, vertices: PackedVector3Array, a: int, b: int, c: int, outward: Vector3) -> void:
	# Godot treats clockwise triangles as front-facing. Keep their geometric
	# normal aligned with the supplied outward normal by reversing positive
	# cross-product winding, matching the project's other procedural meshes.
	if (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(outward) > 0.0:
		indices.append(a)
		indices.append(c)
		indices.append(b)
	else:
		indices.append(a)
		indices.append(b)
		indices.append(c)

static func _make_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _add_surface(parent: Node3D, mesh: ArrayMesh, material: Material, node_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
