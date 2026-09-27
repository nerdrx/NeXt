extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("090f16")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("82909a")
	world.environment.ambient_light_energy = 0.65
	scene.add_child(world)
	var visual := ShipVisual.new()
	scene.add_child(visual)
	visual.build([{"kind": "radiator", "cell": Vector3i.ZERO}])
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -28, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(4.8, 4.4, 6.0)
	camera.fov = 43.0
	scene.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	root.size = Vector2i(1440, 900)
	for _frame in range(8):
		await process_frame
	var error := root.get_texture().get_image().save_png("user://radiator-visual.png")
	assert(error == OK, "radiator visual screenshot should save")
	print("RADIATOR_VISUAL_CAPTURE_OK: ", ProjectSettings.globalize_path("user://radiator-visual.png"))
	quit()
