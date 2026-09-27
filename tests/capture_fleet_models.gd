extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("080e16")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("8295a4")
	world.environment.ambient_light_energy = 0.22
	# Neutral studio reflection environment; background remains black for comparison.
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("344453")
	sky_material.sky_horizon_color = Color("969b9e")
	sky_material.ground_horizon_color = Color("656c72")
	sky_material.ground_bottom_color = Color("10151c")
	sky.sky_material = sky_material
	world.environment.sky = sky
	world.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment.ssao_enabled = true
	world.environment.ssao_radius = 1.0
	world.environment.ssao_intensity = 1.5
	scene.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34, -28, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	scene.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 145, 0)
	fill.light_color = Color("aac3db")
	fill.light_energy = 0.4
	scene.add_child(fill)
	var visual := FleetShipVisual.new()
	scene.add_child(visual)
	var camera := Camera3D.new()
	camera.fov = 32.0
	scene.add_child(camera)
	root.size = Vector2i(1440, 900)
	for kind in ["trade", "patrol"]:
		visual.build(kind, "pirate" if kind == "patrol" else "player_fleet")
		for angle in (["front", "rear", "detail"] if kind == "patrol" else ["front", "rear"]):
			camera.position = Vector3(8, 6, -12) if angle == "front" else Vector3(-8, 6, 12)
			if angle == "detail": camera.position = Vector3(5, 3, -7)
			camera.look_at(Vector3(1, 0.2, -1) if angle == "detail" else Vector3.ZERO)
			camera.current = true
			for _frame in 32: await process_frame
			var path := "user://fleet-%s-%s.png" % [kind, angle]
			var error := root.get_texture().get_image().save_png(path)
			assert(error == OK, "fleet visual screenshot should save: " + path)
			print("FLEET_VISUAL_CAPTURE: ", ProjectSettings.globalize_path(path))
	# Also expose the material to the actual game hangar and space sky.
	world.queue_free()
	light.queue_free()
	fill.queue_free()
	await process_frame
	var game_world := SpaceWorld.new()
	scene.add_child(game_world)
	game_world.build(0)
	visual.position = Vector3(0, 8, 0)
	camera.position = visual.position + Vector3(8, 6, -12)
	camera.look_at(visual.position)
	for _frame in 32: await process_frame
	var hangar_path := "user://fleet-patrol-hangar.png"
	var hangar_error := root.get_texture().get_image().save_png(hangar_path)
	if hangar_error != OK:
		push_error("Failed to save hangar material capture")
		quit(1)
		return
	print("FLEET_VISUAL_CAPTURE: ", ProjectSettings.globalize_path(hangar_path))
	quit()
