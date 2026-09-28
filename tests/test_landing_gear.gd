extends SceneTree

const FAMILIES := ["pathfinder", "merchant", "ranger"]


func _initialize() -> void:
	for family_id: String in FAMILIES:
		var modules: Array = ShipBlueprint.family(family_id).modules
		_check_modules(modules, family_id)

	var multi_deck: Array = [
		{"kind": "cockpit", "x": -1, "y": -2, "z": -1},
		{"kind": "cargo", "x": 1, "y": -2, "z": -1},
		{"kind": "reactor", "x": -1, "y": -2, "z": 1},
		{"kind": "engine", "x": 1, "y": -2, "z": 1},
		{"kind": "habitat", "x": 0, "y": -1, "z": 0},
		{"kind": "cargo", "x": 0, "y": 0, "z": 0},
	]
	_check_modules(multi_deck, "multi-deck")
	print("LANDING_GEAR_OK")
	quit()


func _check_modules(modules: Array, label: String) -> void:
	var visual := ShipVisual.new()
	visual.build(modules)
	assert(visual.get_node_or_null("LandingGear") == null, "%s: gear waits for explicit request" % label)
	visual.add_landing_gear(modules)
	var gear := visual.get_node_or_null("LandingGear") as Node3D
	assert(gear != null, "%s: LandingGear exists after request" % label)
	assert(gear.get_child_count() == 4, "%s: four support legs" % label)

	var lowest_y := 2147483647
	var cells: Array[Vector3i] = []
	for module: Variant in modules:
		var cell := Vector3i(int(module.x), int(module.y), int(module.z))
		cells.append(cell)
		lowest_y = mini(lowest_y, cell.y)
	var plane_y := float(lowest_y) * ShipBlueprint.CELL_SIZE - ShipBlueprint.center(cells).y - 1.98
	var low_cells: Array[Vector3i] = []
	for cell: Vector3i in cells:
		if cell.y == lowest_y:
			low_cells.append(cell)

	var expected_names: Array[String] = ["Gear0", "Gear1", "Gear2", "Gear3"]
	for index in 4:
		var leg := gear.get_node_or_null(expected_names[index]) as Node3D
		assert(leg != null, "%s: expected named leg %s" % [label, expected_names[index]])
		assert(leg.position.is_finite() and leg.transform.basis.x.is_finite()
			and leg.transform.basis.y.is_finite() and leg.transform.basis.z.is_finite(),
			"%s: %s transform is finite" % [label, leg.name])
		assert(leg.position.y == plane_y or is_equal_approx(leg.position.y, plane_y),
			"%s: %s starts at lowest contact plane" % [label, leg.name])
		var foot := leg.get_node_or_null("Foot") as MeshInstance3D
		assert(foot != null and foot.mesh != null, "%s: %s has mesh foot" % [label, leg.name])
		var foot_bottom := foot.position.y + foot.mesh.get_aabb().position.y
		assert(is_equal_approx(foot_bottom, 0.0), "%s: %s foot bottom meets contact plane" % [label, leg.name])

		var supported := false
		for cell: Vector3i in low_cells:
			var module_x := float(cell.x) * ShipBlueprint.CELL_SIZE - ShipBlueprint.center(cells).x
			var module_z := float(cell.z) * ShipBlueprint.CELL_SIZE - ShipBlueprint.center(cells).z
			if absf(leg.position.x - module_x) <= ShipBlueprint.PRESSURE_SIZE.x * 0.5 \
			and absf(leg.position.z - module_z) <= ShipBlueprint.PRESSURE_SIZE.z * 0.5:
				supported = true
				break
		assert(supported, "%s: %s stays within a lowest module footprint" % [label, leg.name])
	visual.free()
