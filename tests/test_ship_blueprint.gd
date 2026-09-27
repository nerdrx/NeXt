extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for family_id in ShipBlueprint.FAMILIES:
		var blueprint := ShipBlueprint.family(family_id)
		var state := GameState.new()
		state.ship_modules.assign(blueprint.modules)
		state.ship_layout = blueprint.layout
		assert(state._connected(state.ship_modules) and state._has_required_modules(state.ship_modules))
		assert(ShipLayout.validate_data(state.ship_layout, state.ship_modules))
		assert(state.ship_stats().walkable, "larger families must support a walkable interior")
		var cells: Array[Vector3i] = []
		for module in state.ship_modules: cells.append(Vector3i(module.x,module.y,module.z))
		var center := ShipBlueprint.center(cells)
		var visual := ShipVisual.new()
		root.add_child(visual)
		visual.build(state.ship_modules, "player", state.ship_layout)
		var shell := visual.get_node_or_null("FamilyPressureHull") as MeshInstance3D
		assert(shell != null, "family cells produce one connected pressure skin")
		var outline := ShipBlueprint.pressure_outline(cells)
		var reordered := cells.duplicate()
		reordered.reverse()
		assert(ShipBlueprint.pressure_outline(reordered) == outline, "save/module ordering cannot change the hull")
		for vertex: Vector3 in shell.mesh.get_faces():
			var within_collision := false
			for cell in cells:
				var bounds := AABB(Vector3(cell)*ShipBlueprint.CELL_SIZE-center-ShipBlueprint.COLLISION_SIZE*0.5,ShipBlueprint.COLLISION_SIZE)
				if bounds.grow(0.001).has_point(vertex): within_collision = true
			assert(within_collision,"pressure skin must not protrude outside collision")
		var interior := ShipInterior.new()
		root.add_child(interior)
		interior.position = ShipBlueprint.interior_offset(cells)
		interior.build(state.ship_modules, state.ship_layout)
		for shape: CollisionShape3D in interior.find_children("*", "CollisionShape3D", true, false):
			assert(shape.shape is BoxShape3D)
			var half := (shape.shape as BoxShape3D).size * 0.5
			for x in [-half.x, half.x]:
				for y in [-half.y, half.y]:
					for z in [-half.z, half.z]:
						var point := shape.to_global(Vector3(x,y,z))
						assert(absf(point.y) < ShipBlueprint.PRESSURE_SIZE.y*0.5, "interior fits vertical pressure bounds")
						assert(Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),outline), "interior fits the connected pressure outline")
		var hull := CoastingHull.new()
		root.add_child(hull)
		hull.configure(state.ship_modules)
		assert(hull._module_shapes.size() == cells.size())
		for i in cells.size():
			assert(hull._module_shapes[i].position.is_equal_approx(Vector3(cells[i])*ShipBlueprint.CELL_SIZE-center))
			assert((hull._module_shapes[i].shape as BoxShape3D).size == ShipBlueprint.COLLISION_SIZE)
		visual.queue_free()
		interior.queue_free()
		hull.queue_free()
		await process_frame
	# Surface fittings must remain visible after pressure-envelope dimensions change.
	var material := StandardMaterial3D.new()
	var armor_probe := ShipVisual.new()
	root.add_child(armor_probe)
	armor_probe._add_bevelled_plate(Vector3.ZERO, Vector3(0.92, 0.065, 1.82), material, 0.025)
	var armor_mesh := armor_probe.get_child(0) as MeshInstance3D
	var arrays := armor_mesh.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for triangle in range(0, normals.size(), 3):
		assert(normals[triangle].is_equal_approx(normals[triangle+1]) and normals[triangle].is_equal_approx(normals[triangle+2]), "armor triangles retain flat normals without warped specular shading")
	armor_probe.free()
	for face: String in ShipLayout.FACES:
		for fitting in ["armored", "window", "radiator"]:
			var visual := ShipVisual.new()
			root.add_child(visual)
			if fitting == "radiator":
				visual._build_radiator_face(Vector3.ZERO, face, material, material, material)
			else:
				visual._build_hull_panel(Vector3.ZERO, face, fitting, material, material, material, material)
			var normal := Vector3(ShipLayout.FACE_STEPS[face])
			var surface := normal.abs().dot(ShipBlueprint.PRESSURE_SIZE) * 0.5
			for mesh: MeshInstance3D in visual.get_children():
				for vertex: Vector3 in mesh.mesh.get_faces():
					assert((mesh.transform * vertex).dot(normal) > surface - 0.004, "surface fitting must not be buried in pressure hull")
			visual.free()
	assert(ShipBlueprint.family("unknown").is_empty())
	print("SHIP_BLUEPRINT_OK: families, rooms, exterior containment and collision share one spatial contract")
	quit()
