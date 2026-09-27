extends SceneTree

const Colony = preload("res://scripts/surface_colony.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for radius in [170.0, 850.0]:
		var colony = Colony.new()
		root.add_child(colony)
		colony.build(radius, 314, "Copernicus")
		# Exercise the same sideways placement used on a spherical world.
		colony.transform = Transform3D(Basis(Quaternion(Vector3.UP, Vector3.RIGHT)), Vector3(radius + 14, 0, 0))
		await physics_frame
		await physics_frame
		for local_point in [Vector3.ZERO, Vector3(12, 0, 0), Vector3(0, 0, -30), Vector3(18, 0, -42)]:
			var hit := _ray(colony, local_point + Vector3.UP * 2, local_point + Vector3.DOWN * 2)
			assert(not hit.is_empty(), "pad, disembarkation point and streets have solid floors")
			assert(absf(colony.to_local(hit.position).y) < 0.01, "all walking floors have top y=0")
			assert(hit.normal.dot(Vector3.RIGHT) > 0.99, "floor follows planet normal")
		var ramp_end_z: float = 62 * colony.footprint
		var ramp_end := Vector3(15, 0, ramp_end_z)
		ramp_end.y = sqrt(radius * radius - 225 - ramp_end_z * ramp_end_z) - radius - 16
		var ramp_mid := (Vector3(15, 0, 22) + ramp_end) / 2
		var ramp_hit := _ray(colony, ramp_mid + Vector3.UP * 3, ramp_mid + Vector3.DOWN * 3)
		assert(not ramp_hit.is_empty() and colony.to_local(ramp_hit.position).distance_to(ramp_mid) < 0.01, "ramp top matches endpoints without a lip")
		assert(colony.door_positions.size() == 4 and colony.interior_services.size() == 4)
		for i in colony.door_positions.size():
			var door: Vector3 = colony.door_positions[i]
			var room: Vector3 = colony.interior_positions[i]
			assert(_ray(colony, door + Vector3.UP * 1.5, room + Vector3.UP * 1.5).is_empty(), "doorway opens into room")
			var facade := _ray(colony, door + Vector3(3, 1.5, 0), door + Vector3(3, 1.5, -3))
			assert(not facade.is_empty(), "walls beside doorway remain solid")
			var floor_hit := _ray(colony, room + Vector3.UP * 2, room + Vector3.DOWN)
			assert(not floor_hit.is_empty() and absf(colony.to_local(floor_hit.position).y) < 0.01, "interior floor has no raised threshold")
			assert(not _ray(colony, room + Vector3.UP, room + Vector3(8, 1, 0)).is_empty(), "room side wall is solid")
			assert(not _ray(colony, room + Vector3.UP, room + Vector3.UP * 5).is_empty(), "room ceiling is solid")
		var count: int = colony.get_child_count()
		colony.build(radius, 314, "Copernicus")
		assert(colony.get_child_count() == count, "rebuild removes old geometry")
		colony.queue_free()
		await process_frame
	print("Surface colony tests passed: radial deck, streets, ramp, four open doorways and enclosed room collision at both radii")
	quit()

func _ray(colony: Node3D, start: Vector3, end: Vector3) -> Dictionary:
	return colony.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(colony.to_global(start), colony.to_global(end)))
