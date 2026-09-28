extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var station := OwnedStation.new()
	root.add_child(station)
	station.position = Vector3(1000, 500, -600)
	station.rotation = Vector3(0.1, 0.45, -0.08)
	station.build({"level": 1, "name": "Low Orbit Fixture"})
	await physics_frame
	assert(_check_rings(station), "level-one station creates two collision-backed visual rings")
	assert(_outer_rim_hit(station), "outer orbital rim blocks a ray through the ring")
	assert(_gap_clear(station), "ring interior remains open between girders")
	assert(_approaches_clear(station), "level-one station keeps both +Z approach volumes clear")
	var level_one_counts := _collision_counts(station)
	station.build({"level": 1, "name": "Low Orbit Fixture"})
	await physics_frame
	await physics_frame
	assert(_collision_counts(station) == level_one_counts, "level-one rebuild does not accumulate collision shapes")
	assert(_outer_rim_hit(station) and _gap_clear(station) and _approaches_clear(station), "level-one rebuild preserves ring and approach collision")
	station.build({"level": 100, "name": "High Orbit Fixture"})
	await physics_frame
	await physics_frame
	assert(_check_rings(station), "level-one-hundred station creates two collision-backed visual rings")
	assert(_outer_rim_hit(station), "level-one-hundred outer orbital rim blocks a ray through the ring")
	assert(_gap_clear(station), "level-one-hundred ring interior remains open between girders")
	assert(_approaches_clear(station), "level-one-hundred station keeps both +Z approach volumes clear")
	var level_hundred_counts := _collision_counts(station)
	station.build({"level": 100, "name": "High Orbit Fixture"})
	await physics_frame
	await physics_frame
	assert(_collision_counts(station) == level_hundred_counts, "level-one-hundred rebuild does not accumulate collision shapes")
	assert(_outer_rim_hit(station) and _gap_clear(station) and _approaches_clear(station), "level-one-hundred rebuild preserves ring and approach collision")
	station.queue_free()
	await process_frame
	print("STATION_SUPERSTRUCTURE_OK: orbital ring collision, open gaps, +Z approaches and clean rebuilds")
	quit()


func _check_rings(station: OwnedStation) -> bool:
	var rings: Array[MeshInstance3D] = []
	for node: Node in station.find_children("*", "MeshInstance3D", true, false):
		if node.name.begins_with("OrbitalRing"): rings.append(node)
	if rings.size() != 2: return false
	for ring: MeshInstance3D in rings:
		var collision_shapes := ring.find_children("*", "CollisionShape3D", true, false)
		if collision_shapes.size() != 1 or not (collision_shapes[0] as CollisionShape3D).shape is ConcavePolygonShape3D: return false
	return true


func _outer_rim_hit(station: OwnedStation) -> bool:
	var query := PhysicsRayQueryParameters3D.create(station.to_global(Vector3(112, 12, -10)), station.to_global(Vector3(112, 12, -100)), 1)
	var hit: Dictionary = station.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return false
	var collider := hit.collider as Node
	var ring := collider.get_parent() as MeshInstance3D
	return ring != null and ring.name.begins_with("OrbitalRing")


func _gap_clear(station: OwnedStation) -> bool:
	var query := PhysicsRayQueryParameters3D.create(station.to_global(Vector3(40, 82, -10)), station.to_global(Vector3(40, 82, -100)), 1)
	return station.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _approaches_clear(station: OwnedStation) -> bool:
	return _sweep_clear(station, Vector3(30, 12, 45), Vector3(0, 22, 400), Vector3(0, 22, 70)) \
		and _sweep_clear(station, Vector3(94, 25, 94), Vector3(0, 112, 600), Vector3(0, 112, 220))


func _sweep_clear(station: OwnedStation, size: Vector3, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	query.shape = shape
	query.transform = Transform3D(station.global_basis, station.to_global(from))
	query.motion = station.global_basis * (to - from)
	query.collision_mask = 1
	var space := station.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	return space.cast_motion(query)[0] >= 0.9999


func _collision_counts(station: OwnedStation) -> Dictionary:
	return {
		"bodies": station.find_children("*", "StaticBody3D", true, false).size(),
		"shapes": station.find_children("*", "CollisionShape3D", true, false).size(),
	}
