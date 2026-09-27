extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var material := StandardMaterial3D.new()
	var rectangle := FleetShipVisual.new()
	root.add_child(rectangle)
	rectangle._poly_prism([Vector2(-2, -1), Vector2(2, -1), Vector2(2, 1), Vector2(-2, 1)], 0.0, 0.4, material)
	var rectangle_mesh := (rectangle.get_child(0) as MeshInstance3D).mesh
	var rectangle_arrays := rectangle_mesh.surface_get_arrays(0)
	var rectangle_vertices: PackedVector3Array = rectangle_arrays[Mesh.ARRAY_VERTEX]
	var rect_top_area := _top_area(rectangle_arrays)
	var rect_bottom_area := _bottom_area(rectangle_arrays)
	assert(rectangle_vertices.size() == 60, "rectangle should receive a four-edge top bevel")
	assert(rectangle_mesh.get_aabb().size.is_equal_approx(Vector3(4, 0.4, 2)), "bevel must preserve outer dimensions")
	assert(absf(rect_top_area - 7.8209) < 0.001, "rectangle top should be inset only by its small bevel")
	assert(absf(rect_bottom_area - 8.0) < 0.001, "rectangle bottom must retain its full footprint")

	var concave := FleetShipVisual.new()
	root.add_child(concave)
	concave._poly_prism([
		Vector2(0, 0), Vector2(3, 0), Vector2(3, 1),
		Vector2(1, 1), Vector2(1, 3), Vector2(0, 3)], 0.0, 0.4, material)
	var concave_mesh := (concave.get_child(0) as MeshInstance3D).mesh
	var concave_arrays := concave_mesh.surface_get_arrays(0)
	var concave_vertices: PackedVector3Array = concave_arrays[Mesh.ARRAY_VERTEX]
	var concave_top_area := _top_area(concave_arrays)
	var concave_bottom_area := _bottom_area(concave_arrays)
	assert(concave_mesh.get_aabb().size.is_equal_approx(Vector3(3, 0.4, 3)), "concave panel bounds must stay exact")
	assert(concave_vertices.size() in [60, 96], "concave offset must bevel safely or use the flat-prism fallback")
	assert(concave_top_area > 4.5 and concave_top_area <= 5.001, "concave notch must remain open after beveling")
	assert(absf(concave_bottom_area - 5.0) < 0.001, "concave bottom must preserve its full footprint")
	print("FLEET_PANEL_BEVEL_OK")
	quit()


func _top_area(arrays: Array) -> float:
	return _projected_area(arrays, true)


func _bottom_area(arrays: Array) -> float:
	return _projected_area(arrays, false)


func _projected_area(arrays: Array, top: bool) -> float:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var area := 0.0
	for i in range(0, vertices.size(), 3):
		if absf(vertices[i].y - vertices[i + 1].y) > 0.00001 or absf(vertices[i].y - vertices[i + 2].y) > 0.00001:
			continue
		if (normals[i].y < 0.99) if top else (normals[i].y > -0.99): continue
		var a := vertices[i]
		var b := vertices[i + 1]
		var c := vertices[i + 2]
		area += absf((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)) * 0.5
	return area
