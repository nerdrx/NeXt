extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for radius in [170.0, 850.0]:
		var colony := SurfaceColony.new()
		root.add_child(colony)
		colony.build(radius, 314, "Navigation")
		await physics_frame
		await physics_frame
		for destination in colony.interior_positions:
			var start := Vector3(-12, 0, 12)
			var path := colony.navigation_path(start, destination)
			assert(path.size() > 1, "each room reachable from apron")
			assert(path[-1].distance_to(destination) < 0.3)
			for i in range(1, path.size()):
				_check_segment(colony, path[i - 1], path[i])
			colony.transform = Transform3D(Basis(Quaternion(Vector3.UP, Vector3.RIGHT)), Vector3(321, 73, -501))
			var shifted := colony.navigation_path(colony.to_global(start), colony.to_global(destination))
			assert(shifted.size() == path.size(), "origin shift preserves path topology")
			for i in path.size():
				assert(colony.to_local(shifted[i]).distance_to(path[i]) < 0.001)
			colony.transform = Transform3D.IDENTITY
			# Reaching staff behind a counter must route around its solid ends.
			var behind_counter := destination + Vector3(0, 0, -4.5)
			var counter_path := colony.navigation_path(start, behind_counter)
			assert(counter_path.size() > 2)
			for i in range(1, counter_path.size()):
				_check_segment(colony, counter_path[i - 1], counter_path[i])
		assert(colony.navigation_path(Vector3(-12, 0, 12), Vector3(500, 0, 500)).is_empty(), "offdeck destination rejected")
		assert(colony.navigation_path(Vector3(-12, 0, 12), Vector3(0, 12, 0)).is_empty(), "elevated destination rejected")
		colony.build(radius, 314, "Rebuilt")
		assert(not colony.navigation_path(Vector3(-12, 0, 12), colony.interior_positions[0]).is_empty())
		colony.queue_free()
		await process_frame
	print("Port navigation passed: all rooms, swept wall clearance, offdeck rejection, radial origin shifts and rebuild")
	quit()

func _check_segment(colony: SurfaceColony, start: Vector3, end: Vector3) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, start + Vector3.UP * 0.9)
	query.motion = end - start
	query.collision_mask = 1
	var result := colony.get_world_3d().direct_space_state.cast_motion(query)
	assert(result[0] >= 0.999, "path capsule clears walls and counters: %s -> %s fraction %s" % [start, end, result])
