class_name PlanetGeology
extends Node3D

const CELL_ARC: float = 20.0
const PATCH_INSET: float = 2.0
const MAX_EXTENT: float = 200.0
const MAX_INSTANCES: int = 1024
const VARIANT_COUNT: int = 4
const NORTH_PORT_CLEARANCE: float = 90.0
const FULL_LONGITUDE_SCAN_LIMIT: int = 256

var anchor: Vector3 = Vector3.ZERO
var rock_multimeshes: Array[MultiMeshInstance3D] = []
var rock_bodies: Array[StaticBody3D] = []


func build(radius: float, normal: Vector3, extent: float, seed: int, tint: Color, has_ocean: bool = false) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	rock_multimeshes.clear()
	rock_bodies.clear()
	var safe_radius: float = maxf(radius, 1.0) if is_finite(radius) else 1.0
	var up: Vector3 = (normal if normal.is_normalized() else normal.normalized()) if normal.is_finite() and normal.length_squared() > 0.000001 else Vector3.UP
	anchor = up * safe_radius
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.metallic = 0.0
	var meshes: Array[ArrayMesh] = []
	var shapes: Array[ConvexPolygonShape3D] = []
	for variant: int in VARIANT_COUNT:
		var mesh: ArrayMesh = _make_rock_mesh(variant)
		mesh.surface_set_material(0, material)
		meshes.append(mesh)
		var shape := ConvexPolygonShape3D.new()
		shape.points = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		shapes.append(shape)
	var entries := placements(safe_radius, up, minf(MAX_EXTENT, maxf(extent, 0.0)), seed, has_ocean)
	var by_variant: Array[Array] = [[], [], [], []]
	for entry: Dictionary in entries:
		by_variant[int(entry.variant)].append(entry)
	for variant: int in VARIANT_COUNT:
		var rocks: Array = by_variant[variant]
		if rocks.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[variant]
		mm.instance_count = rocks.size()
		var visual := MultiMeshInstance3D.new()
		visual.name = "Rock variant %d" % variant
		rock_multimeshes.append(visual)
		for i: int in rocks.size():
			var entry: Dictionary = rocks[i]
			var local_position: Vector3 = entry.local_position if safe_radius > 10000.0 else entry.position - anchor
			var transform: Transform3D = Transform3D(entry.basis, local_position)
			if float(entry.size) < 0.8:
				continue
			var body := StaticBody3D.new()
			body.name = "Boulder %s" % entry.id
			body.transform = transform
			body.set_meta("variant", variant)
			body.set_meta("instance_index", i)
			body.set_meta("clearance_radius", entry.clearance_radius)
			body.set_meta("placement_id", entry.id)
			var collision := CollisionShape3D.new()
			collision.shape = shapes[variant]
			body.add_child(collision)
			add_child(body)
			rock_bodies.append(body)
		visual.multimesh = mm
		add_child(visual)
		for i: int in rocks.size():
			var entry: Dictionary = rocks[i]
			var local_position: Vector3 = entry.local_position if safe_radius > 10000.0 else entry.position - anchor
			mm.set_instance_transform(i, Transform3D(entry.basis, local_position))


static func placements(radius: float, normal: Vector3, extent: float, seed: int, has_ocean: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_finite(radius) or not is_finite(extent) or radius <= 0.0 or extent <= PATCH_INSET:
		return result
	var up: Vector3 = (normal if normal.is_normalized() else normal.normalized()) if normal.is_finite() and normal.length_squared() > 0.000001 else Vector3.UP
	var up_length: float = sqrt(float(up.x) * up.x + float(up.y) * up.y + float(up.z) * up.z)
	var up_x: float = float(up.x) / up_length
	var up_y: float = float(up.y) / up_length
	var up_z: float = float(up.z) / up_length
	extent = minf(MAX_EXTENT, extent)
	var tangent: Vector3 = up.cross(Vector3.UP if absf(up.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD).normalized()
	var bitangent: Vector3 = up.cross(tangent).normalized()
	var inset_extent: float = extent - PATCH_INSET
	var half_angle: float = atan2(extent * 1.42, radius)
	var center_theta: float = atan2(sqrt(float(up.x) * up.x + float(up.z) * up.z), float(up.y))
	var first_row: int = maxi(0, floori((center_theta - half_angle) * radius / CELL_ARC) - 1)
	var last_row: int = mini(ceili(PI * radius / CELL_ARC), ceili((center_theta + half_angle) * radius / CELL_ARC) + 1)
	var center_phi: float = atan2(up.z, up.x)
	var count: int = 0
	for row: int in range(first_row, last_row + 1):
		var theta: float = minf(PI, float(row) * CELL_ARC / radius)
		if theta + 0.32 * CELL_ARC / radius < 2.0 * asin(clampf((NORTH_PORT_CLEARANCE + 2.0) / (2.0 * radius), 0.0, 1.0)):
			continue
		var row_count: int = maxi(1, roundi(TAU * radius * maxf(sin(theta), 0.02 if radius <= 10000.0 else 0.0) / CELL_ARC))
		var phi_step: float = TAU / row_count
		var first_col: int = 0
		var final_col: int = row_count - 1
		var wrapped_first_col: int = -1
		if radius > 10000.0 and row_count > FULL_LONGITUDE_SCAN_LIMIT:
			var lon_span: float = PI
			if center_theta > half_angle and center_theta < PI - half_angle:
				lon_span = asin(clampf(sin(half_angle) / sin(center_theta), 0.0, 1.0))
			var center_col: float = fposmod(center_phi, TAU) / phi_step
			var padding: int = ceili(lon_span / phi_step + 0.82)
			var raw_first: int = floori(center_col) - padding
			var raw_last: int = ceili(center_col) + padding
			if raw_last - raw_first + 1 < row_count:
				if raw_first < 0:
					wrapped_first_col = row_count + raw_first
					first_col = 0
					final_col = raw_last
				elif raw_last >= row_count:
					wrapped_first_col = raw_first
					first_col = 0
					final_col = raw_last - row_count
				else:
					first_col = raw_first
					final_col = raw_last
			else:
				first_col = 0
				final_col = row_count - 1
		var col_ranges: Array[Vector2i] = [Vector2i(first_col, final_col)]
		if wrapped_first_col >= 0:
			col_ranges.append(Vector2i(wrapped_first_col, row_count - 1))
		for col_range: Vector2i in col_ranges:
			for col: int in range(col_range.x, col_range.y + 1):
				var rng := RandomNumberGenerator.new()
				rng.seed = ("%d:%d:%d" % [seed, row, col]).hash()
				var theta_j: float = clampf(theta + rng.randf_range(-0.32, 0.32) * CELL_ARC / radius, 0.0, PI)
				var phi: float = (float(col) + rng.randf_range(-0.32, 0.32)) * phi_step
				var direction := Vector3(sin(theta_j) * cos(phi), cos(theta_j), sin(theta_j) * sin(phi)).normalized()
				if direction.dot(up) <= 0.0:
					continue
				var plane_scale: float = radius / direction.dot(up)
				var u: float = direction.dot(tangent) * plane_scale
				var v: float = direction.dot(bitangent) * plane_scale
				if radius > 10000.0:
					var direction_length: float = sqrt(float(direction.x) * direction.x + float(direction.y) * direction.y + float(direction.z) * direction.z)
					var dx: float = float(direction.x) / direction_length
					var dy: float = float(direction.y) / direction_length
					var dz: float = float(direction.z) / direction_length
					var up_dot: float = dx * up_x + dy * up_y + dz * up_z
					plane_scale = radius / up_dot
					u = (dx * tangent.x + dy * tangent.y + dz * tangent.z) * plane_scale
					v = (dx * bitangent.x + dy * bitangent.y + dz * bitangent.z) * plane_scale
				if absf(u) > inset_extent or absf(v) > inset_extent:
					continue
				# Reserve the current north-pole port, ramp, and approach footprint.
				if direction.distance_to(Vector3.UP) * radius < NORTH_PORT_CLEARANCE + 2.0:
					continue
				var height: float = PlanetHeightField.surface_height(direction, seed)
				if has_ocean and height < PlanetHeightField.SEA_LEVEL + 0.3:
					continue
				var variant: int = rng.randi_range(0, VARIANT_COUNT - 1)
				var scale := Vector3(rng.randf_range(0.6, 1.0), rng.randf_range(0.62, 1.0), rng.randf_range(0.6, 1.0))
				var size: float = rng.randf_range(0.3, 2.0)
				scale *= size
				var basis := (Basis(Quaternion(Vector3.UP, direction)).rotated(direction, rng.randf_range(0.0, TAU)) * Basis.from_scale(scale))
				var position: Vector3 = direction * (radius + height - scale.y * 0.25)
				var local_height: float = height - scale.y * 0.25
				var direction_length: float = sqrt(float(direction.x) * direction.x + float(direction.y) * direction.y + float(direction.z) * direction.z)
				var radial_distance: float = radius + local_height
				var local_position := Vector3(float(direction.x) / direction_length * radial_distance - up_x * radius, float(direction.y) / direction_length * radial_distance - up_y * radius, float(direction.z) / direction_length * radial_distance - up_z * radius)
				var clearance: float = scale.length() * 0.54
				result.append({"id": "%d:%d:%d" % [row, col, seed], "position": position, "local_position": local_position, "basis": basis, "scale": scale, "size": size, "variant": variant, "clearance_radius": clearance, "direction": direction})
				count += 1
				if count >= MAX_INSTANCES:
					return result
	return result


static func _make_rock_mesh(variant: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 7 + variant
	sphere.rings = 4 + variant % 2
	sphere.radius = 0.5
	sphere.height = 1.0
	var arrays: Array = sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in indices:
		var vertex: Vector3 = vertices[index]
		var wobble: float = sin(vertex.x * 19.0 + variant * 3.1) * cos(vertex.z * 17.0 - variant * 2.4) * 0.07
		surface.set_color(Color(0.72 + wobble, 0.70 + wobble, 0.66 + wobble))
		surface.add_vertex(vertex * (1.0 + wobble))
	surface.generate_normals()
	return surface.commit()
