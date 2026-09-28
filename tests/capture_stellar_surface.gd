extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("STELLAR_CAPTURE_SKIPPED: headless display")
		quit()
		return
	root.size = Vector2i(1440, 900)
	var world := SpaceWorld.new()
	root.add_child(world)
	world.build(0)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 55.0
	camera.far = 30000.0
	camera.make_current()
	for item: Dictionary in [{"name": "near", "distance": 560.0}, {"name": "far", "distance": 5000.0}]:
		camera.position = SpaceWorld.PRIMARY_POSITION + Vector3(0, 0, item.distance)
		camera.look_at(world.to_global(SpaceWorld.PRIMARY_POSITION), Vector3.UP)
		for frame in 8:
			await process_frame
			await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://stellar-surface-%s.png" % item.name) == OK)
	var planet: Dictionary = world.planets[0]
	var away := (Vector3(planet.position) - SpaceWorld.PRIMARY_POSITION).normalized()
	camera.position = Vector3(planet.position) + away * (float(planet.visual_radius) + 800.0)
	camera.look_at(world.to_global(SpaceWorld.PRIMARY_POSITION), Vector3.UP)
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("user://stellar-surface-eclipse.png") == OK)
	print("STELLAR_SURFACE_CAPTURE_OK: near, far and eclipsed primary")
	quit()
