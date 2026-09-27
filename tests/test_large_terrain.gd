extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var terrain := PlanetTerrain.new()
	root.add_child(terrain)
	var normal := Vector3(1.0, 0.7, 1.0).normalized()
	var radius := 6378100.0
	var height := PlanetTerrain.surface_height(normal, 341)
	terrain.build(radius, normal, 341, Color("8d8877"))
	assert(terrain.anchor_address != null)
	var address: SectorPosition = terrain.anchor_address
	var ax: float = float(address.sector.x) * SectorPosition.SECTOR_SIZE + address.local.x
	var ay: float = float(address.sector.y) * SectorPosition.SECTOR_SIZE + address.local.y
	var az: float = float(address.sector.z) * SectorPosition.SECTOR_SIZE + address.local.z
	assert(absf(sqrt(ax * ax + ay * ay + az * az) - radius) < 0.001, "double-normalized anchor lies on the physical sphere")
	var vertices: PackedVector3Array = terrain.terrain_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var center := vertices[24 * 49 + 24]
	assert(center.distance_to(normal * height) < 0.0001, "center retains sub-millimetre local height at Earth radius")
	for vertex in vertices:
		assert(vertex.is_finite() and vertex.length() < 300.0)
	assert(not terrain.terrain_material.shader.get_shader_uniform_list().is_empty())
	var origins: PackedVector3Array = terrain.terrain_material.get_shader_parameter("noise_origins")
	assert(origins.size() == 7)
	for origin in origins:
		assert(origin.x >= 0 and origin.x < 256 and origin.y >= 0 and origin.y < 256 and origin.z >= 0 and origin.z < 256)
	# Stable formula agrees with analytic curvature without subtracting large vectors.
	var tangent := normal.cross(Vector3.UP).normalized()
	var bitangent := normal.cross(tangent).normalized()
	var flat := PlanetTerrain.patch_vertex(radius, normal, tangent, bitangent, 200, 0, 0)
	var sagitta := -40000.0 / (sqrt(radius * radius + 40000.0) + radius) * radius / sqrt(radius * radius + 40000.0)
	assert(absf(flat.dot(normal) - sagitta) < 0.0001)
	var enormous := PlanetTerrain.patch_vertex(38000000.0, Vector3.UP, Vector3.RIGHT, Vector3.BACK, 200, 0, 0.125)
	assert(enormous.y > 0.124 and enormous.y < 0.125, "small elevation survives at giant-planet radius")
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(normal * (height + 20), normal * (height - 20))
	var hit := terrain.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty() and hit.collider == terrain.terrain_body)
	assert(absf(hit.position.dot(normal) - height) < 0.001, "local collision retains precise surface height")
	var walker := CharacterBody3D.new()
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.8
	capsule.shape = shape
	walker.add_child(capsule)
	root.add_child(walker)
	walker.up_direction = normal
	walker.basis = Basis(Quaternion(Vector3.UP, normal))
	walker.position = normal * (height + 2.0)
	walker.floor_snap_length = 0.3
	for frame in 60:
		await physics_frame
		walker.velocity -= normal * 9.80665 / 60.0
		walker.move_and_slide()
	assert(walker.is_on_floor() and absf(walker.position.dot(normal) - height - 0.9) < 0.02, "walking capsule rests on a precise Earth-radius patch")
	walker.queue_free()
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("708693")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c5d3dc")
	settings.ambient_light_energy = 0.5
	environment.environment = settings
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 2.0
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = normal * (height + 8) + tangent * 18 + bitangent * 24
	camera.look_at(normal * height, normal)
	camera.make_current()
	if DisplayServer.get_name() != "headless":
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/large-planet-terrain.png")
	terrain.queue_free()
	environment.queue_free()
	sun.queue_free()
	camera.queue_free()
	await process_frame
	print("LARGE_TERRAIN_OK: Earth-radius local vertices, giant-radius curvature, precise collision and bounded shader detail coordinates")
	quit()
