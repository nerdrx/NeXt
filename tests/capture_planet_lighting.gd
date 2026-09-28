extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("PLANET_LIGHT_CAPTURE_SKIPPED: headless display")
		quit()
		return
	root.size = Vector2i(1440, 900)
	var world := SpaceWorld.new()
	root.add_child(world)
	world.build(0)
	var body: Dictionary = world.planets[0]
	var sun := world.planet_sun_direction(0)
	var tangent := sun.cross(Vector3.UP).normalized()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 55.0
	camera.far = 30000.0
	camera.make_current()
	var day_luminance := 0.0
	for item: Dictionary in [{"name": "day", "direction": sun}, {"name": "crescent", "direction": (tangent - sun * 0.5).normalized()}, {"name": "night", "direction": -sun}]:
		camera.position = Vector3(body.position) + Vector3(item.direction) * float(body.visual_radius) * 2.6
		camera.look_at(world.to_global(body.position), Vector3.UP)
		for frame in 8:
			await process_frame
			await RenderingServer.frame_post_draw
		var capture := root.get_texture().get_image()
		assert(capture.save_png("user://planet-light-%s.png" % item.name) == OK)
		var luminance := 0.0
		for x in range(700, 740, 4):
			for y in range(430, 470, 4):
				luminance += capture.get_pixel(x, y).get_luminance() / 100.0
		if item.name == "day":
			day_luminance = luminance
			assert(day_luminance > 0.08, "star-facing hemisphere renders lit")
		elif item.name == "night":
			assert(luminance < day_luminance * 0.25, "opposite hemisphere stays dark")
	print("PLANET_LIGHT_CAPTURE_OK: day/crescent/night renders and day-to-night brightness contrast")
	quit()
