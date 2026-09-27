extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var interior := ShipInterior.new()
	scene.add_child(interior)
	interior.global_transform = Transform3D(Basis.from_euler(Vector3(0.2, 0.7, -0.15)), Vector3(80, 30, -45))
	var modules: Array[Dictionary] = [
		{"kind": "cockpit", "x": 0, "y": 0, "z": 0},
		{"kind": "weapon", "x": 1, "y": 0, "z": 0},
		{"kind": "reactor", "x": 2, "y": 0, "z": 0},
		{"kind": "cargo", "x": 3, "y": 0, "z": 0},
		{"kind": "cargo", "x": 4, "y": 0, "z": 0},
		{"kind": "habitat", "x": 1, "y": 1, "z": 0},
		{"kind": "habitat", "x": 0, "y": 0, "z": 1},
		{"kind": "habitat", "x": 0, "y": 0, "z": -1},
	]
	var layout := {
		"version": 1,
		"rooms": {"2,0,0": "engineering", "4,0,0": "workshop", "1,1,0": "quarters", "0,0,1": "medical", "0,0,-1": "lounge"},
		"panels": {},
	}
	assert(ShipLayout.validate_data(layout, modules), "mixed-room fixture uses valid module and room combinations")
	interior.build(modules, layout)
	await physics_frame
	await physics_frame
	var positions := interior.crew_positions(12)
	assert(not positions.is_empty(), "crew positions exist in a furnished multi-deck layout")
	assert(positions.size() <= 12)
	assert(interior.crew_positions(0).is_empty())
	assert(interior.crew_positions(2).size() <= 2)
	var space := scene.get_world_3d().direct_space_state
	for i in positions.size():
		var foot: Vector3 = positions[i]
		assert(is_equal_approx(foot.y / ShipInterior.CELL.y, roundf(foot.y / ShipInterior.CELL.y)) or is_equal_approx(fposmod(foot.y, ShipInterior.CELL.y), 0.08), "position stays on deck foot plane")
		for j in range(i + 1, positions.size()):
			var other: Vector3 = positions[j]
			assert(foot.distance_to(other) >= 0.9, "crew capsules do not overlap")
		var ray := PhysicsRayQueryParameters3D.create(interior.to_global(foot + Vector3.UP * 0.18), interior.to_global(foot - Vector3.UP * 0.18), 1)
		var hit := space.intersect_ray(ray)
		assert(not hit.is_empty() and hit.collider is StaticBody3D, "each position has a real floor beneath its feet")
	var repeated := interior.crew_positions(12)
	assert(positions == repeated, "crew positions are deterministic")
	var roles: Array[String] = ["gunner", "engineer", "trader"]
	var role_positions := interior.crew_positions(3, roles)
	assert(role_positions.size() == roles.size(), "one position returned per requested role")
	var expected_cells := [Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0)]
	var occupied_cells: Array[Vector3i] = []
	for i in role_positions.size():
		var position: Vector3 = role_positions[i]
		var cell := Vector3i(roundi(position.x / ShipInterior.CELL.x), roundi(position.y / ShipInterior.CELL.y), roundi(position.z / ShipInterior.CELL.z))
		assert(cell == expected_cells[i], "role uses preferred weapon, engineering, or cargo module")
		assert(cell not in occupied_cells, "role positions use distinct module centers")
		occupied_cells.append(cell)
	var repeated_roles: Array[String] = ["engineer", "engineer", "engineer"]
	var spread := interior.crew_positions(3, repeated_roles)
	assert(spread.size() == repeated_roles.size(), "repeated roles receive positions")
	var spread_cells: Array[Vector3i] = []
	for position: Vector3 in spread:
		var cell := Vector3i(roundi(position.x / ShipInterior.CELL.x), roundi(position.y / ShipInterior.CELL.y), roundi(position.z / ShipInterior.CELL.z))
		assert(cell not in spread_cells, "repeated role spreads crew across unoccupied modules")
		spread_cells.append(cell)
	var fallback := ShipInterior.new()
	scene.add_child(fallback)
	fallback.position = Vector3(200, 0, 0)
	var fallback_modules: Array[Dictionary] = [{"kind": "habitat", "x": 0, "y": 0, "z": 0}]
	var fallback_layout := {"version": 1, "rooms": {"0,0,0": "medical"}, "panels": {}}
	assert(ShipLayout.validate_data(fallback_layout, fallback_modules))
	fallback.build(fallback_modules, fallback_layout)
	await physics_frame
	await physics_frame
	var gunner_only: Array[String] = ["gunner"]
	var fallback_positions := fallback.crew_positions(1, gunner_only)
	assert(fallback_positions.size() == 1, "role falls back to a clear module when preferred rooms are absent")
	interior.queue_free()
	fallback.queue_free()
	await process_frame
	print("CREW_POSITIONS_OK: geometry, role preferences, occupancy spread and fallback")
	quit()
