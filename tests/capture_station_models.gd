extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	var station := OwnedStation.new()
	station.build({"name": "NEW HORIZON", "level": 24, "rooms": ["market", "company", "shipyard", "contracts"]})
	root.add_child(station)
	var environment_node := WorldEnvironment.new()
	var environment := ShipVisual.preview_environment()
	environment_node.environment = environment
	root.add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -38, 0)
	key.light_color = Color("fff0dc")
	key.light_energy = 1.2
	key.shadow_enabled = true
	root.add_child(key)
	await _save_view("front", Vector3(410, 235, 535), Vector3(20, 0, 35))
	await _save_view("rear", Vector3(-350, 220, -420), Vector3(20, 0, 35))
	print("STATION_CAPTURE_OK: user://station-front.png user://station-rear.png")
	quit()

func _save_view(label: String, position: Vector3, target: Vector3) -> void:
	var camera := Camera3D.new()
	camera.fov = 36.0
	root.add_child(camera)
	camera.position = position
	camera.look_at(target)
	camera.make_current()
	for frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("user://station-%s.png" % label)
	assert(error == OK, "Could not save station capture: " + label)
	camera.queue_free()
