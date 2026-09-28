extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		print("CREW_MODEL_CAPTURE_SKIPPED: headless display")
		quit()
		return

	var studio := Node3D.new()
	root.add_child(studio)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("182129")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c6cf")
	environment.ambient_light_energy = 0.65
	environment_node.environment = environment
	studio.add_child(environment_node)

	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(14, 0.1, 14)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("343d42")
	floor_material.roughness = 0.92
	floor.material_override = floor_material
	floor.position.y = -0.05
	studio.add_child(floor)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, -28, 0)
	key.light_color = Color("ffe4c4")
	key.light_energy = 1.25
	key.shadow_enabled = true
	studio.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 145, 0)
	fill.light_color = Color("b8d8eb")
	fill.light_energy = 0.7
	fill.shadow_enabled = false
	studio.add_child(fill)

	var actors: Array[Dictionary] = [
		{"faction": "company", "role": "engineer", "name": "Engineer", "x": -1.2},
		{"faction": "police", "role": "guard", "name": "Police", "x": 0.0},
		{"faction": "pirate", "role": "guard", "name": "Pirate", "x": 1.2},
	]
	for config: Dictionary in actors:
		var actor := GroundActor.new()
		actor.faction = str(config.faction)
		actor.role = str(config.role)
		actor.display_name = str(config.name)
		actor.hostile = config.faction != "company"
		actor.hold_position = true
		actor.active = false
		actor.position = Vector3(float(config.x), 0, 0)
		studio.add_child(actor)

	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.position = Vector3(1.8, 1.65, -5.2)
	studio.add_child(camera)
	camera.look_at(Vector3(0, 0.95, 0))
	camera.make_current()
	# Give the shared procedural normal texture time to finish generating.
	await create_timer(0.3).timeout
	for _frame: int in 4:
		await process_frame
		await RenderingServer.frame_post_draw

	var output_dir := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("res://build/crew-models.png"))
	if error != OK:
		push_error("Could not save crew model capture: %s" % error)
		quit(1)
		return
	print("CREW_MODEL_CAPTURE_OK: res://build/crew-models.png")
	quit()
