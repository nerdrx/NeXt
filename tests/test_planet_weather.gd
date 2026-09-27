extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := SpaceWorld.new()
	root.add_child(world)
	world.build(0)
	assert(not SpaceWorld.CLOUD_SHADER.get_shader_uniform_list().is_empty(), "cloud shader must compile")
	assert(not SpaceWorld.PLANET_SHADER.get_shader_uniform_list().is_empty(), "planet shader must compile")
	var expected := 0
	for planet: Dictionary in world.planets:
		if planet.atmosphere and planet.has_ocean: expected += 1
	var cloud_nodes: Array[MeshInstance3D] = []
	var layers := 0
	for child in world.get_children():
		if not child.has_meta("planet_cloud_layer"): continue
		layers += 1
		cloud_nodes.append(child)
		var index: int = child.get_meta("planet_cloud_layer")
		var planet: Dictionary = world.planets[index]
		assert(child.position == planet.position)
		assert(child.mesh.radius > float(planet.visual_radius) + PlanetHeightField.HEIGHT_SCALE)
		assert(child.get_child_count() == 0, "weather shell must not intercept landing or weapon rays")
		assert(child.material_override.shader == SpaceWorld.CLOUD_SHADER)
	assert(layers == expected and layers > 0)
	var patch := PlanetTerrain.new()
	world.add_child(patch)
	patch.build(float(world.planets[0].visual_radius), Vector3.FORWARD, Universe._seed_for(0, 900), Color.WHITE, true)
	world.configure_planet_weather(patch.terrain_material, 0)
	assert(not patch.terrain_material.shader.get_shader_uniform_list().is_empty(), "streamed terrain shader must compile")
	assert(patch.terrain_material.get_shader_parameter("weather_enabled"))
	assert(patch.terrain_material.get_shader_parameter("weather_seed") == world._planet_materials[0].get_shader_parameter("weather_seed"))
	assert(patch.terrain_material.get_shader_parameter("weather_shell_radius") == world._planet_materials[0].get_shader_parameter("weather_shell_radius"))
	patch.hide()
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
		# Hide the cloud geometry so only its ground shadow changes in this comparison.
		for cloud: MeshInstance3D in cloud_nodes: cloud.hide()
		await RenderingServer.frame_post_draw
		var shadowed := root.get_texture().get_image()
		world._planet_materials[0].set_shader_parameter("weather_enabled", false)
		await RenderingServer.frame_post_draw
		var clear := root.get_texture().get_image()
		assert(_center_brightness(clear) > _center_brightness(shadowed) + 0.002, "cloud coverage dims the rendered terrain")
		world.configure_planet_weather(world._planet_materials[0], 0)
		for cloud: MeshInstance3D in cloud_nodes: cloud.show()
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

func _center_brightness(image: Image) -> float:
	var total := 0.0
	var samples := 0
	for y in range(image.get_height() / 2 - 140, image.get_height() / 2 + 140, 4):
		for x in range(image.get_width() / 2 - 140, image.get_width() / 2 + 140, 4):
			var color := image.get_pixel(x, y)
			total += (color.r + color.g + color.b) / 3.0
			samples += 1
	return total / samples
