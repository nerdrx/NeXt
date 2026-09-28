class_name HullGeometry
extends RefCounted


static func lathe_z(profile: PackedVector2Array, segments: int = 32) -> ArrayMesh:
	if profile.size() < 2 or segments < 3 or segments > 128:
		return ArrayMesh.new()
	for point in profile:
		if not point.is_finite() or point.x < 0.0:
			return ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(profile.size() - 1):
		st.set_smooth_group(layer)
		for segment in segments:
			var a0 := TAU * float(segment) / segments
			var a1 := TAU * float(segment + 1) / segments
			var p00 := Vector3(cos(a0) * profile[layer].x, sin(a0) * profile[layer].x, profile[layer].y)
			var p01 := Vector3(cos(a1) * profile[layer].x, sin(a1) * profile[layer].x, profile[layer].y)
			var p10 := Vector3(cos(a0) * profile[layer + 1].x, sin(a0) * profile[layer + 1].x, profile[layer + 1].y)
			var p11 := Vector3(cos(a1) * profile[layer + 1].x, sin(a1) * profile[layer + 1].x, profile[layer + 1].y)
			st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p01)
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p11)
	st.generate_normals()
	return st.commit()

static func prism(points: Array, y0: float, y1: float) -> ArrayMesh:
	var vertices := PackedVector2Array(points)
	if Geometry2D.is_polygon_clockwise(vertices): vertices.reverse()
	var bevel := minf(0.015, maxf(0.0, y1 - y0) * 0.25)
	var inset_parts := Geometry2D.offset_polygon(vertices, -bevel, Geometry2D.JOIN_MITER) if bevel > 0.0 else []
	var inset := PackedVector2Array()
	var inset_triangles := PackedInt32Array()
	if inset_parts.size() == 1:
		inset = inset_parts[0]
		if Geometry2D.is_polygon_clockwise(inset): inset.reverse()
		inset = _align_offset_vertices(vertices, inset, bevel)
		if inset.size() == vertices.size():
			inset_triangles = Geometry2D.triangulate_polygon(inset)
			if inset_triangles.size() != (inset.size() - 2) * 3:
				inset = PackedVector2Array()
		else:
			inset = PackedVector2Array()
	var bevelled := not inset.is_empty()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var top_vertices: PackedVector2Array = inset if bevelled else vertices
	var top_triangles: PackedInt32Array = inset_triangles if bevelled else Geometry2D.triangulate_polygon(vertices)
	var bottom_triangles := Geometry2D.triangulate_polygon(vertices)
	for i in range(0, top_triangles.size(), 3):
		var a := top_vertices[top_triangles[i]]
		var b := top_vertices[top_triangles[i + 1]]
		var c := top_vertices[top_triangles[i + 2]]
		_add_oriented_triangle(st, Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(c.x, y1, c.y), Vector3.UP)
	if bevelled:
		var bevel_y := y1 - bevel
		for i in vertices.size():
			var j := (i + 1) % vertices.size()
			var edge := vertices[j] - vertices[i]
			var outward := Vector3(edge.y, 0, -edge.x).normalized()
			var a := Vector3(vertices[i].x, y0, vertices[i].y)
			var b := Vector3(vertices[j].x, y0, vertices[j].y)
			var c := Vector3(vertices[j].x, bevel_y, vertices[j].y)
			var d := Vector3(vertices[i].x, bevel_y, vertices[i].y)
			_add_oriented_triangle(st, a, b, c, outward)
			_add_oriented_triangle(st, a, c, d, outward)
			var top_a := Vector3(inset[i].x, y1, inset[i].y)
			var top_b := Vector3(inset[j].x, y1, inset[j].y)
			var bevel_normal := (outward + Vector3.UP).normalized()
			_add_oriented_triangle(st, d, c, top_b, bevel_normal)
			_add_oriented_triangle(st, d, top_b, top_a, bevel_normal)
	else:
		for i in vertices.size():
			var j := (i + 1) % vertices.size()
			var edge := vertices[j] - vertices[i]
			var outward := Vector3(edge.y, 0, -edge.x)
			_add_oriented_triangle(st, Vector3(vertices[i].x, y0, vertices[i].y), Vector3(vertices[j].x, y0, vertices[j].y), Vector3(vertices[j].x, y1, vertices[j].y), outward)
			_add_oriented_triangle(st, Vector3(vertices[i].x, y0, vertices[i].y), Vector3(vertices[j].x, y1, vertices[j].y), Vector3(vertices[i].x, y1, vertices[i].y), outward)
	# Original triangulation preserves concave bottom footprints for both paths.
	for i in range(0, bottom_triangles.size(), 3):
		var a := vertices[bottom_triangles[i]]
		var b := vertices[bottom_triangles[i + 1]]
		var c := vertices[bottom_triangles[i + 2]]
		_add_oriented_triangle(st, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(c.x, y0, c.y), Vector3.DOWN)
	st.generate_normals()
	return st.commit()


static func _align_offset_vertices(original: PackedVector2Array, offset: PackedVector2Array, bevel: float) -> PackedVector2Array:
	if offset.size() != original.size(): return PackedVector2Array()
	var best_shift := 0
	var best_cost := INF
	for shift in offset.size():
		var cost := 0.0
		for i in original.size():
			cost += original[i].distance_squared_to(offset[(i + shift) % offset.size()])
		if cost < best_cost:
			best_cost = cost
			best_shift = shift
	var aligned := PackedVector2Array()
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in original:
		min_x = minf(min_x, point.x); min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x); max_y = maxf(max_y, point.y)
	for i in original.size():
		var point := offset[(i + best_shift) % offset.size()]
		if not point.is_finite() or original[i].distance_to(point) > bevel * 4.0:
			return PackedVector2Array()
		if point.x < min_x - 0.0001 or point.x > max_x + 0.0001 or point.y < min_y - 0.0001 or point.y > max_y + 0.0001:
			return PackedVector2Array()
		aligned.append(point)
	return aligned


static func _add_oriented_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)



# Each section stores footprint X scale, height, and footprint Z scale.
static func profile(outline: PackedVector2Array, sections: Array) -> ArrayMesh:
	var points := outline.duplicate()
	if Geometry2D.is_polygon_clockwise(points): points.reverse()
	var triangles := Geometry2D.triangulate_polygon(points)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for section in range(sections.size() - 1):
		var lower: Vector3 = sections[section]
		var upper: Vector3 = sections[section+1]
		for i in points.size():
			var j := (i+1) % points.size()
			var a := Vector3(points[i].x * lower.x, lower.y, points[i].y * lower.z)
			var b := Vector3(points[j].x * lower.x, lower.y, points[j].y * lower.z)
			var c := Vector3(points[j].x * upper.x, upper.y, points[j].y * upper.z)
			var d := Vector3(points[i].x * upper.x, upper.y, points[i].y * upper.z)
			var edge := points[j] - points[i]
			var outward := Vector3(edge.y, 0, -edge.x)
			_add_oriented_triangle(st,a,b,c,outward)
			_add_oriented_triangle(st,a,c,d,outward)
	for cap in [0,sections.size()-1]:
		var section: Vector3 = sections[cap]
		var normal := Vector3.DOWN if cap == 0 else Vector3.UP
		for i in range(0, triangles.size(), 3):
			var a := points[triangles[i]]
			var b := points[triangles[i+1]]
			var c := points[triangles[i+2]]
			_add_oriented_triangle(st,Vector3(a.x*section.x,section.y,a.y*section.z),Vector3(b.x*section.x,section.y,b.y*section.z),Vector3(c.x*section.x,section.y,c.y*section.z),normal)
	st.generate_normals()
	return st.commit()


# Sections are Vector2(height, outward offset). Offset rings must keep original vertex order.
static func profile_offset(outline: PackedVector2Array, sections: Array) -> ArrayMesh:
	var points := outline.duplicate()
	if Geometry2D.is_polygon_clockwise(points): points.reverse()
	points = _remove_collinear_vertices(points)
	var rings: Array[PackedVector2Array] = []
	var caps: Array[PackedInt32Array] = []
	for section: Vector2 in sections:
		if not section.is_finite() or section.y < 0.0 or section.y > 0.600001:
			return _vertical_profile(points, sections)
		var offset_parts := Geometry2D.offset_polygon(points, section.y, Geometry2D.JOIN_MITER)
		if offset_parts.size() != 1:
			return _vertical_profile(points, sections)
		var ring := offset_parts[0]
		if Geometry2D.is_polygon_clockwise(ring): ring.reverse()
		ring = _align_ring_vertices(points, ring, section.y)
		if ring.size() != points.size():
			return _vertical_profile(points, sections)
		var triangles := Geometry2D.triangulate_polygon(ring)
		if triangles.size() != (ring.size() - 2) * 3:
			return _vertical_profile(points, sections)
		rings.append(ring)
		caps.append(triangles)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for section in range(rings.size() - 1):
		var lower: PackedVector2Array = rings[section]
		var upper: PackedVector2Array = rings[section + 1]
		var y0: float = sections[section].x
		var y1: float = sections[section + 1].x
		for i in lower.size():
			var j := (i + 1) % lower.size()
			var edge := lower[j] - lower[i]
			var outward := Vector3(edge.y, 0.0, -edge.x)
			var a := Vector3(lower[i].x, y0, lower[i].y)
			var b := Vector3(lower[j].x, y0, lower[j].y)
			var c := Vector3(upper[j].x, y1, upper[j].y)
			var d := Vector3(upper[i].x, y1, upper[i].y)
			_add_oriented_triangle(st, a, b, c, outward)
			_add_oriented_triangle(st, a, c, d, outward)
	for cap in [0, rings.size() - 1]:
		var ring: PackedVector2Array = rings[cap]
		var y: float = sections[cap].x
		var normal := Vector3.DOWN if cap == 0 else Vector3.UP
		for i in range(0, caps[cap].size(), 3):
			var a := ring[caps[cap][i]]
			var b := ring[caps[cap][i + 1]]
			var c := ring[caps[cap][i + 2]]
			_add_oriented_triangle(st, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), normal)
	st.generate_normals()
	return st.commit()


static func _remove_collinear_vertices(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	var changed := true
	while changed and result.size() > 3:
		changed = false
		for i in result.size():
			var previous := result[(i - 1 + result.size()) % result.size()]
			var current := result[i]
			var next := result[(i + 1) % result.size()]
			var before := current - previous
			var after := next - current
			if absf(before.cross(after)) < 0.0001 and before.dot(after) >= 0.0:
				result.remove_at(i)
				changed = true
				break
	return result


static func _vertical_profile(outline: PackedVector2Array, sections: Array) -> ArrayMesh:
	var fallback: Array[Vector3] = []
	for section: Vector2 in sections:
		fallback.append(Vector3(1.0, section.x, 1.0))
	return profile(outline, fallback)


static func _align_ring_vertices(original: PackedVector2Array, ring: PackedVector2Array, offset: float) -> PackedVector2Array:
	if ring.size() != original.size(): return PackedVector2Array()
	var shift := 0
	var best_cost := INF
	for candidate in ring.size():
		var cost := 0.0
		for i in original.size(): cost += original[i].distance_squared_to(ring[(i + candidate) % ring.size()])
		if cost < best_cost:
			best_cost = cost
			shift = candidate
	var aligned := PackedVector2Array()
	for i in original.size():
		var point := ring[(i + shift) % ring.size()]
		if not point.is_finite() or original[i].distance_to(point) > maxf(0.01, offset * 3.0): return PackedVector2Array()
		aligned.append(point)
	return aligned
