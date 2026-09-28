extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("PLANET_ECLIPSE_CAPTURE_SKIPPED: headless display")
		quit()
		return
	root.size = Vector2i(1440, 900)
	var world := SpaceWorld.new()
	root.add_child(world)
	world.build(0)
	var body: Dictionary = world.planets[0]
	var sun := world.planet_sun_direction(0)
	var materials: Array[ShaderMaterial] = []
	for name: String in [str(body.name), str(body.name) + " clouds", str(body.name) + " atmosphere"]:
		if world.has_node(name): materials.append((world.get_node(name) as MeshInstance3D).material_override)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 55.0
	camera.far = 30000.0
	camera.position = Vector3(body.position) + sun * float(body.visual_radius) * 2.6
	camera.look_at(world.to_global(body.position), Vector3.UP)
	camera.make_current()
	var clear := await _capture("clear")
	var original_count := world.planets.size()
	var blocker_position := SpaceWorld.PRIMARY_POSITION - sun * 350.0
	world.planets.append({"position": blocker_position, "visual_radius": 100.0})
	var blocker := world._sphere("Eclipse fixture", 100.0, blocker_position, Color("202020"), 0.0, 1.0)
	for material: ShaderMaterial in materials: world.configure_planet_eclipse(material, 0)
	var shadow := await _capture("shadow")
	assert(clear > 0.08 and shadow < clear * 0.25, "intervening sphere darkens the sunlit surface and clouds")
	# A body beyond the point source must not cast a shadow onto this globe.
	world.planets[-1].position = SpaceWorld.PRIMARY_POSITION + sun * 350.0
	blocker.position = world.planets[-1].position
	for material: ShaderMaterial in materials: world.configure_planet_eclipse(material, 0)
	var beyond := await _capture("beyond")
	assert(beyond > clear * 0.8, "occluder beyond the primary does not eclipse the target")
	world.planets.resize(original_count)
	for material: ShaderMaterial in materials: world.configure_planet_eclipse(material, 0)
	print("PLANET_ECLIPSE_CAPTURE_OK: visible darkening, cloud response and beyond-primary exclusion")
	quit()

func _capture(label: String) -> float:
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	assert(capture.save_png("user://planet-eclipse-%s.png" % label) == OK)
	var luminance := 0.0
	for x in range(700, 740, 4):
		for y in range(430, 470, 4):
			luminance += capture.get_pixel(x, y).get_luminance() / 100.0
	return luminance
