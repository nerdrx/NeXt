extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := SpaceWorld.new()
	root.add_child(world)
	world.build(0)
	var expected := 0
	for planet: Dictionary in world.planets:
		if planet.atmosphere and planet.has_ocean: expected += 1
	var layers := 0
	for child in world.get_children():
		if not child.has_meta("planet_cloud_layer"): continue
		layers += 1
		var index: int = child.get_meta("planet_cloud_layer")
		var planet: Dictionary = world.planets[index]
		assert(child.position == planet.position)
		assert(child.mesh.radius > float(planet.visual_radius) + PlanetHeightField.HEIGHT_SCALE)
		assert(child.get_child_count() == 0, "weather shell must not intercept landing or weapon rays")
		assert(child.material_override.shader == SpaceWorld.CLOUD_SHADER)
	assert(layers == expected and layers > 0)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.far = 20000
	camera.fov = 55
	camera.position = world.planets[0].position + Vector3(0, 180, 2300)
	camera.look_at(world.planets[0].position)
	camera.make_current()
	await create_timer(1.0).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/planet-weather-orbit.png")
		camera.position = world.planets[0].position - Basis.from_euler(Vector3(deg_to_rad(-28), deg_to_rad(-34), 0)).z * 2300
		camera.look_at(world.planets[0].position)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/planet-weather-night.png")
		camera.position = world.planets[0].position + Vector3(0, 0, float(world.planets[0].visual_radius) + 14)
		camera.look_at(camera.position + Vector3(0, 0.25, 1))
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/planet-weather-below.png")
	world.queue_free()
	await process_frame
	print("PLANET_WEATHER_OK: ocean-atmosphere shells, altitude and collision isolation")
	quit()
