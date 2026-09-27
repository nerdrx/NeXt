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
		var envelope: Array[Dictionary] = []
		for child in visual.get_children():
			if child is MeshInstance3D and child.mesh.get_aabb().size.is_equal_approx(ShipBlueprint.PRESSURE_SIZE):
				envelope.append({"origin":child.position, "faces":child.mesh.get_faces()})
		assert(envelope.size() == cells.size(), "one pressure envelope per occupied cell")
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
						var enclosed := false
						for bounds in envelope:
							if _inside_pressure_mesh(point - bounds.origin, bounds.faces): enclosed = true
						assert(enclosed, "interior collision must fit the visible pressure envelope: " + str(point))
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
	assert(ShipBlueprint.family("unknown").is_empty())
	print("SHIP_BLUEPRINT_OK: families, rooms, exterior containment and collision share one spatial contract")
	quit()

func _inside_pressure_mesh(point: Vector3, faces: PackedVector3Array) -> bool:
	# Pressure cells are convex. Check actual chamfer planes, not only their AABB.
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i+1]
		var c := faces[i+2]
		var normal := (b-a).cross(c-a).normalized()
		if normal.dot((a+b+c)/3.0) < 0: normal = -normal
		if normal.dot(point-a) > 0.001: return false
	return true
