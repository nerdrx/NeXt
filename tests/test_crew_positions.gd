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
		{"kind": "habitat", "x": 1, "y": 1, "z": 0},
		{"kind": "cargo", "x": 0, "y": 0, "z": 0},
		{"kind": "habitat", "x": 1, "y": 0, "z": 0},
		{"kind": "habitat", "x": 2, "y": 0, "z": 0},
		{"kind": "habitat", "x": 3, "y": 0, "z": 0},
	]
	var layout := {
		"version": 1,
		"rooms": {"1,0,0": "medical", "2,0,0": "lounge", "3,0,0": "workshop"},
		"panels": {},
	}
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
	interior.queue_free()
	await process_frame
	print("CREW_POSITIONS_OK: rotated multi-deck layout, furnishings, floor clearance, deterministic spacing and limit")
	quit()
