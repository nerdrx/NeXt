extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1440, 900)
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = ShipVisual.preview_environment()
	scene.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -24, 0)
	key.light_color = Color("fff0dc")
	key.light_energy = 1.4
	scene.add_child(key)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 100.0
	scene.add_child(camera)
	var panel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(12.0, 8.0)
	panel.mesh = quad
	var shader := load("res://shaders/fleet_surface.gdshader") as Shader
	assert(shader != null, "could not load fleet_surface.gdshader")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("paint", Color("77838b"))
	material.set_shader_parameter("panel_strength", 1.0)
	material.set_shader_parameter("industrial_detail", 1.0)
	panel.material_override = material
	scene.add_child(panel)

	for capture: Dictionary in [
		{"name": "close", "size": 2.5, "angle": 0.0},
		{"name": "mid", "size": 8.0, "angle": 0.0},
		{"name": "far", "size": 24.0, "angle": 0.0},
		{"name": "distant", "size": 160.0, "angle": 0.0},
		{"name": "grazing", "size": 8.0, "angle": 72.0},
	]:
		camera.size = capture.size
		var angle: float = deg_to_rad(capture.angle)
		var target := Vector3(1.4, 1.4, 0.0) if capture.name == "close" else Vector3.ZERO
		camera.position = target + Vector3(0.0, sin(angle) * 20.0, cos(angle) * 20.0)
		camera.look_at(target, Vector3.UP)
		camera.make_current()
		await _save_capture("user://surface-%s.png" % capture.name)
	quit()


func _save_capture(path: String) -> void:
	for _frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty(), "surface capture rendered no image: " + path)
	var error: Error = image.save_png(path)
	assert(error == OK, "could not save surface capture: %s (%s)" % [path, error])
	print("SURFACE_CAPTURE_FILE: ", ProjectSettings.globalize_path(path))
