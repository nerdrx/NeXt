extends SceneTree

const PlanetGeologyScript = preload("res://scripts/planet_geology.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var radius: float = 500.0
	var extent: float = 175.0
	var normal := Vector3(0.3, 0.9, -0.2).normalized()
	var a: Array[Dictionary] = PlanetGeologyScript.placements(radius, normal, extent, 341)
	var b: Array[Dictionary] = PlanetGeologyScript.placements(radius, normal, extent, 341)
	assert(not a.is_empty() and a == b, "placement list is deterministic")
	var shifted_normal := (normal + Vector3(0.015, 0.0, -0.01)).normalized()
	var shifted: Array[Dictionary] = PlanetGeologyScript.placements(radius, shifted_normal, extent, 341)
	var shifted_by_id: Dictionary = {}
	for descriptor: Dictionary in shifted:
		shifted_by_id[descriptor.id] = descriptor
	var shifted_tangent := shifted_normal.cross(Vector3.UP).normalized()
	var shifted_bitangent := shifted_normal.cross(shifted_tangent).normalized()
	var shared: int = 0
	for descriptor: Dictionary in a:
		var direction := Vector3(descriptor.direction)
		var plane := direction * radius / direction.dot(shifted_normal)
		if absf(plane.dot(shifted_tangent)) < extent - 5.0 and absf(plane.dot(shifted_bitangent)) < extent - 5.0:
			assert(shifted_by_id.has(descriptor.id), "recenter does not lose an interior candidate")
		if shifted_by_id.has(descriptor.id):
			assert(descriptor.position.is_equal_approx(shifted_by_id[descriptor.id].position), "global candidate stays fixed across patch recenter")
			shared += 1
	assert(shared > 0, "overlapping patches retain common global placements")
	for patch_normal: Vector3 in [Vector3.UP, Vector3(0.01, 1.0, 0.0).normalized(), Vector3.RIGHT, Vector3(1.0, 0.01, 0.0).normalized()]:
		for candidate_seed: int in [7, 341]:
			var broad: Array[Dictionary] = PlanetGeologyScript.placements(850.0, patch_normal, 200.0, candidate_seed)
			assert(broad.size() < 1024, "current maximum terrain patch remains below the instance cap")
	for descriptor: Dictionary in a:
		var direction: Vector3 = descriptor.direction
		assert(absf(direction.dot(normal)) > 0.0)
		assert((descriptor.basis.y.normalized()).dot(direction) > 0.999, "rock local up follows the surface radius")
		assert(descriptor.clearance_radius >= descriptor.scale.length() * 0.535, "clearance encloses the convex rock bounds")
	var dry: Array[Dictionary] = PlanetGeologyScript.placements(radius, Vector3.UP, extent, 19)
	var wet: Array[Dictionary] = PlanetGeologyScript.placements(radius, Vector3.UP, extent, 19, true)
	assert(wet.size() < dry.size(), "ocean patches omit underwater rocks")
	for descriptor: Dictionary in wet:
		assert(PlanetHeightField.surface_height(descriptor.direction, 19) >= PlanetHeightField.SEA_LEVEL + 0.3)
	var geology := PlanetGeologyScript.new()
	root.add_child(geology)
	geology.build(radius, Vector3.UP, extent, 341, Color("827a68"))
	assert(not geology.rock_bodies.is_empty() and not geology.rock_multimeshes.is_empty())
	geology.position = Vector3.UP * radius
	await physics_frame
	await physics_frame
	var body: StaticBody3D = geology.rock_bodies[0]
	var collision: CollisionShape3D = body.get_child(0)
	var variant: int = body.get_meta("variant")
	var visual: MultiMeshInstance3D = geology.get_node("Rock variant %d" % variant)
	var visual_transform: Transform3D = visual.global_transform * visual.multimesh.get_instance_transform(body.get_meta("instance_index"))
	var body_id: String = body.get_meta("placement_id")
	var matching_descriptor: Dictionary = {}
	for descriptor: Dictionary in PlanetGeologyScript.placements(radius, Vector3.UP, extent, 341):
		if descriptor.id == body_id:
			matching_descriptor = descriptor
	assert(not matching_descriptor.is_empty())
	var expected := Transform3D(matching_descriptor.basis, matching_descriptor.position - geology.anchor)
	assert(body.transform.is_equal_approx(expected), "collision transform matches the deterministic visual descriptor")
	if DisplayServer.get_name() != "headless":
		assert(body.global_transform.is_equal_approx(visual_transform), "visual and collision transforms match")
	assert(collision.shape is ConvexPolygonShape3D, "rock collision uses a shared convex hull")
	var clearance: float = body.get_meta("clearance_radius")
	for point: Vector3 in collision.shape.points:
		assert((body.global_basis * point).length() <= clearance + 0.001, "clearance encloses actual transformed collision hull")
	var rock_origin: Vector3 = (visual_transform if DisplayServer.get_name() != "headless" else geology.global_transform * expected).origin
	var radial: Vector3 = rock_origin.normalized()
	var query := PhysicsRayQueryParameters3D.create(rock_origin + radial * 3.0, rock_origin - radial * 3.0)
	var hit: Dictionary = geology.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty() and hit.collider == body, "ray hits the matching boulder collision")
	print("Planet geology tests passed")
	quit()
