class_name HullGeometry
extends RefCounted

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
