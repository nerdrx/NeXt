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
		_assert_closed_mesh(shell.mesh.get_faces())
		var engine_fittings := visual.find_children("FamilyEngine*", "MeshInstance3D", true, false)
		assert(not engine_fittings.is_empty(), "habitable families have exterior propulsion housings")
		for fitting: MeshInstance3D in engine_fittings:
			for vertex: Vector3 in fitting.mesh.get_faces():
				var point := fitting.transform * vertex
				assert(point.y > ShipBlueprint.PRESSURE_SIZE.y * 0.5, "dorsal propulsion housings cannot intrude into cabins")
				var contained := false
				for cell in cells:
					var collision := AABB(Vector3(cell)*ShipBlueprint.CELL_SIZE-center-ShipBlueprint.collision_size(cells)*0.5,ShipBlueprint.collision_size(cells))
					if collision.grow(0.001).has_point(point): contained = true
				assert(contained, "propulsion housings must stay inside flight collision")
		var outline := ShipBlueprint.pressure_outline(cells)
		var reordered := cells.duplicate()
		reordered.reverse()
		assert(ShipBlueprint.pressure_outline(reordered) == outline, "save/module ordering cannot change the hull")
		for vertex: Vector3 in shell.mesh.get_faces():
			var within_collision := false
			for cell in cells:
				var bounds := AABB(Vector3(cell)*ShipBlueprint.CELL_SIZE-center-ShipBlueprint.collision_size(cells)*0.5,ShipBlueprint.collision_size(cells))
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
						assert(_inside_shell(point, shell.mesh.get_faces()), "interior corners fit inside the sloped outer hull")
		var hull := CoastingHull.new()
		root.add_child(hull)
		hull.configure(state.ship_modules)
		assert(hull._module_shapes.size() == cells.size())
		for i in cells.size():
			assert(hull._module_shapes[i].position.is_equal_approx(Vector3(cells[i])*ShipBlueprint.CELL_SIZE-center))
			assert((hull._module_shapes[i].shape as BoxShape3D).size == ShipBlueprint.collision_size(cells))
		var pilot := Pilot.new()
		root.add_child(pilot)
		pilot.set_physics_process(false)
		pilot.configure_ship_collision(state.ship_modules)
		await process_frame
		assert(pilot._module_shapes.size() == cells.size())
		for shape: CollisionShape3D in pilot._module_shapes:
			assert((shape.shape as BoxShape3D).size == ShipBlueprint.collision_size(cells), "piloted family uses expanded armor collision")
		pilot.queue_free()
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
			var family_cells: Array[Vector3i] = []
			for module: Dictionary in ShipBlueprint.family("pathfinder").modules:
				family_cells.append(Vector3i(module.x,module.y,module.z))
			var outer_faces := ShipBlueprint.outer_hull(family_cells).get_faces()
			visual._fit_surface_fittings(0,Vector3.ZERO,face,outer_faces)
			for mesh: MeshInstance3D in visual.get_children():
				for vertex: Vector3 in mesh.mesh.get_faces():
					var point := mesh.transform * vertex + mesh.basis * normal * 0.005
					assert(not _inside_shell(point,outer_faces), "projected fitting must remain outside sloped armor")
			visual.free()
	var custom_cells: Array[Vector3i] = [Vector3i.ZERO]
	assert(ShipBlueprint.collision_size(custom_cells) == ShipBlueprint.COLLISION_SIZE, "custom modular hulls keep their existing collision")
	var custom_visual := ShipVisual.new()
	root.add_child(custom_visual)
	custom_visual.build([{"kind":"engine", "x":0, "y":0, "z":0}])
	assert(custom_visual.find_children("FamilyEngine*", "MeshInstance3D", true, false).is_empty(), "family propulsion housings do not appear on custom assemblies")
	custom_visual.free()
	assert(ShipBlueprint.family("unknown").is_empty())
	print("SHIP_BLUEPRINT_OK: families, rooms, exterior containment and collision share one spatial contract")
	quit()


func _inside_shell(point: Vector3, faces: PackedVector3Array) -> bool:
	var direction := Vector3(0.37,0.61,0.71).normalized()
	var distances: Array[float] = []
	for i in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(point,direction,faces[i],faces[i+1],faces[i+2])
		if hit == null: continue
		var distance := point.distance_to(hit)
		var duplicate := false
		for previous in distances:
			if absf(previous-distance) < 0.0001: duplicate = true
		if not duplicate: distances.append(distance)
	return distances.size() % 2 == 1


func _assert_closed_mesh(faces: PackedVector3Array) -> void:
	var edges := {}
	for i in range(0,faces.size(),3):
		for corner in range(3):
			var a := str(faces[i+corner].snapped(Vector3.ONE*0.00001))
			var b := str(faces[i+(corner+1)%3].snapped(Vector3.ONE*0.00001))
			var key := a+"/"+b if a < b else b+"/"+a
			edges[key] = int(edges.get(key,0))+1
	for count in edges.values(): assert(count == 2, "profile mesh has no open or duplicate edges")
