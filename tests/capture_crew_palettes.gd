extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("CREW_PALETTE_CAPTURE_SKIPPED: headless display")
		quit()
		return
	root.size = Vector2i(1440, 900)
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = ShipVisual.preview_environment()
	scene.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 145, 0)
	light.light_energy = 1.3
	scene.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -20, 0)
	fill.light_energy = 0.3
	scene.add_child(fill)
	var roles := ["engineer", "trader", "medic", "gunner"]
	for index in roles.size():
		var actor := ShipCrew.new()
		actor.actor_id = "crew-reference-%d" % index
		actor.role = roles[index]
		actor.display_name = roles[index].capitalize()
		actor.position.x = (float(index) - 1.5) * 1.1
		scene.add_child(actor)
		actor.set_physics_process(false)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	camera.position = Vector3(0, 1.0, -6)
	scene.add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0))
	camera.make_current()
	for _frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("user://crew-identity-palettes.png") == OK)
	print("CREW_MODELS_CAPTURE_OK: user://crew-identity-palettes.png")
	quit()
