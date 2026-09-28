extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("TERRAIN_ECLIPSE_CAPTURE_SKIPPED: headless display")
		quit()
		return
	root.size = Vector2i(1440, 900)
	var world := SpaceWorld.new()
	root.add_child(world)
	world.build(0)
	var body: Dictionary = world.planets[0]
	var sun := world.planet_sun_direction(0)
	var patch := PlanetTerrain.new()
	world.add_child(patch)
	patch.build(float(body.visual_radius), sun, Universe._seed_for(0, 900), Color.WHITE, true)
	patch.position = Vector3(body.position) + patch.anchor
	world.configure_planet_weather(patch.terrain_material, 0)
	world.set_fine_terrain_patch(0, sun, float(body.visual_radius), patch.patch_extent)
	# Isolate ground lighting from the separately lit rock props and cloud geometry.
	patch.get_node("Surface geology").hide()
	for suffix in [" clouds", " atmosphere"]:
		if world.has_node(str(body.name) + suffix): world.get_node(str(body.name) + suffix).hide()
	var materials: Array[ShaderMaterial] = [patch.terrain_material]
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 55.0
	camera.far = 30000.0
	camera.position = patch.position + sun * 70.0
	camera.look_at(world.to_global(patch.position), sun.cross(Vector3.UP).normalized())
	camera.make_current()
	var clear := await _capture("clear")
	var original_count := world.planets.size()
	var blocker_position := SpaceWorld.PRIMARY_POSITION - sun * 350.0
	world.planets.append({"position": blocker_position, "visual_radius": 100.0})
	var blocker := world._sphere("Eclipse fixture", 100.0, blocker_position, Color("202020"), 0.0, 1.0)
	for material: ShaderMaterial in materials: world.configure_planet_eclipse(material, 0)
	var shadow := await _capture("shadow")
	assert(clear > 0.08 and shadow < clear * 0.7, "intervening sphere darkens the sunlit streamed ground")
	# A body beyond the point source must not cast a shadow onto this globe.
	world.planets[-1].position = SpaceWorld.PRIMARY_POSITION + sun * 350.0
	blocker.position = world.planets[-1].position
	for material: ShaderMaterial in materials: world.configure_planet_eclipse(material, 0)
	var beyond := await _capture("beyond")
	assert(beyond > clear * 0.8, "occluder beyond the primary does not eclipse the target")
	patch.terrain_material.set_shader_parameter("planet_sun_position", -sun * 5000.0)
	patch.terrain_material.set_shader_parameter("eclipse_count", 0)
	var night := await _capture("night")
	assert(night < clear * 0.7, "ground opposite the primary loses direct sunlight")
	world.planets.resize(original_count)
	for material: ShaderMaterial in materials: world.configure_planet_eclipse(material, 0)
	print("TERRAIN_ECLIPSE_CAPTURE_OK: ground eclipse, restored sunlight and night-side response")
	quit()

func _capture(label: String) -> float:
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	assert(capture.save_png("user://terrain-eclipse-%s.png" % label) == OK)
	var luminance := 0.0
	for x in range(700, 740, 4):
		for y in range(430, 470, 4):
			luminance += capture.get_pixel(x, y).get_luminance() / 100.0
	return luminance
