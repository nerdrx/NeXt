extends SceneTree

class Walker:
	extends CharacterBody3D
	func _ready() -> void:
		collision_layer = 2
		collision_mask = 1
		var collider := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.38
		capsule.height = 1.8
		collider.shape = capsule
		collider.position.y = 0.9
		add_child(collider)
	func _physics_process(delta: float) -> void:
		velocity.y -= 18 * delta
		move_and_slide()

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var room := ShipInterior.new()
	scene.add_child(room)
	var modules: Array[Dictionary] = [{"kind": "habitat", "x": 0, "y": 0, "z": 0}]
	room.build(modules, {"version": 1, "rooms": {}, "panels": {"0,0,0": {"-y": "window", "+y": "window"}}})
	assert(not room.get_node("FloorWindowBarrier").visible)
	assert(not room.get_node("CeilingWindowBarrier").visible)
	for name in ["FloorWindowGlass", "CeilingWindowGlass"]:
		var pane: MeshInstance3D = room.get_node(name)
		assert(pane.visible and pane.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)
	var walker := Walker.new()
	scene.add_child(walker)
	walker.position = Vector3(0, 0.3, 0)
	await create_timer(0.4).timeout
	assert(walker.is_on_floor() and absf(walker.position.y) < 0.05)
	var space := scene.get_world_3d().direct_space_state
	for end: Vector3 in [Vector3(0, -3, 0), Vector3(0, 5, 0)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1.2, 0), end, 1))
		assert(not hit.is_empty(), "transparent panes retain physical floor and ceiling")
	walker.velocity.y = 8
	var highest := 0.0
	for frame in 45:
		await physics_frame
		highest = maxf(highest, walker.position.y)
	assert(highest > 0.2 and highest < 0.7 and walker.is_on_floor())
	if DisplayServer.get_name() != "headless":
		_target(scene, Vector3(0, -3, 0), Color(1, 0, 0))
		_target(scene, Vector3(0, 5, 0), Color(0, 0, 1))
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.position = Vector3(0, 1.2, 0)
		camera.fov = 70
		camera.current = true
		for direction in [-1, 1]:
			camera.look_at(Vector3(0, direction * 5, 0), Vector3.FORWARD)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			# Sample around the aperture center, away from the ceiling lamp's specular glint.
			var color := Color(0, 0, 0, 0)
			for offset: Vector2 in [Vector2(0.4, 0.4), Vector2(0.6, 0.4), Vector2(0.4, 0.6), Vector2(0.6, 0.6)]:
				color += image.get_pixel(int(image.get_width() * offset.x), int(image.get_height() * offset.y)) * 0.25
			image.save_png("res://build/interior-glass-%s.png" % ("floor" if direction < 0 else "ceiling"))
			print("GLASS_SAMPLE ", direction, " ", color)
			if direction < 0:
				assert(color.r > color.g * 2 and color.r > color.b * 2, "outside red target visible through floor")
			else:
				assert(color.b > color.r * 2 and color.b > color.g * 2, "outside blue target visible through ceiling")

	scene.queue_free()
	await process_frame
	await process_frame
	print("INTERIOR_GLASS_OK: transparent apertures, retained floor/ceiling collision and capsule support")
	quit()

func _target(parent: Node3D, at: Vector3, color: Color) -> void:
	var target := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8, 0.2, 8)
	target.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target.material_override = material
	parent.add_child(target)
	target.position = at
