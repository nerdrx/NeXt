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
	key.rotation_degrees = Vector3(-65, -15, 0)
	key.light_color = Color("fff0dc")
	key.light_energy = 1.0
	key.shadow_enabled = true
	scene.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 145, 0)
	fill.light_color = Color("b7d7ed")
	fill.light_energy = 0.35
	scene.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 300.0
	scene.add_child(camera)

	for family_id: String in ShipBlueprint.FAMILIES:
		var blueprint: Dictionary = ShipBlueprint.family(family_id)
		var modules: Array[Dictionary] = blueprint.modules
		var layout: Dictionary = blueprint.layout
		var cells: Array[Vector3i] = []
		var low := Vector3i(99999, 99999, 99999)
		var high := Vector3i(-99999, -99999, -99999)
		for module: Dictionary in modules:
			var cell := Vector3i(int(module.x), int(module.y), int(module.z))
			cells.append(cell)
			low = Vector3i(mini(low.x, cell.x), mini(low.y, cell.y), mini(low.z, cell.z))
			high = Vector3i(maxi(high.x, cell.x), maxi(high.y, cell.y), maxi(high.z, cell.z))
		var cell_size: float = ShipBlueprint.CELL_SIZE
		var extent := (Vector3(high - low) + Vector3.ONE) * cell_size
		var visual := ShipVisual.new()
		scene.add_child(visual)
		visual.build(modules, "player", layout)
		# Compare the same shell and camera against Godot's native PBR response.
		if "--standard-material" in OS.get_cmdline_user_args():
			var shell := visual.get_node("FamilyPressureHull") as MeshInstance3D
			var source := shell.material_override as ShaderMaterial
			var standard := StandardMaterial3D.new()
			standard.albedo_color = source.get_shader_parameter("paint")
			standard.roughness = source.get_shader_parameter("base_roughness")
			standard.metallic = source.get_shader_parameter("metalness")
			standard.clearcoat_enabled = true
			standard.clearcoat = source.get_shader_parameter("coating")
			standard.clearcoat_roughness = 0.35
			shell.material_override = standard
		var interior := ShipInterior.new()
		interior.position = ShipBlueprint.interior_offset(cells)
		scene.add_child(interior)
		interior.build(modules, layout)
		interior.hide()

		_frame_camera(camera, Vector3.ZERO, extent, Vector3(1.25, 0.9, -1.6))
		camera.make_current()
		await _save_capture("family-%s-exterior.png" % family_id)
		# Close material inspection uses the actual shell rather than a shader swatch.
		var exterior_transform := camera.transform
		var exterior_size := camera.size
		_frame_camera(camera, Vector3(0, extent.y * 0.22, -extent.z * 0.22), Vector3(3, 2, 3), Vector3(1.25, 0.9, -1.6))
		await _save_capture("family-%s-surface-detail.png" % family_id)
		camera.transform = exterior_transform
		camera.size = exterior_size
		# Same angle at twice the distance-equivalent scale checks panel filtering.
		camera.size *= 2.0
		await _save_capture("family-%s-distant.png" % family_id)
		_frame_camera(camera, Vector3.ZERO, extent, Vector3(1.25, 0.9, 1.6))
		camera.make_current()
		await _save_capture("family-%s-rear.png" % family_id)
		var bell := visual.find_child("EngineBell*", false, false) as MeshInstance3D
		if bell != null:
			var bay_center := bell.position + bell.basis.x * 0.67 + bell.basis.z * 0.35
			_frame_camera(camera, bay_center, Vector3(3.4, 2.4, 2.6), Vector3(0.7, 0.4, 1.8))
			await _save_capture("family-%s-engine-detail.png" % family_id)

		visual.add_landing_gear(modules)
		visual.add_boarding_access(modules)
		var floor_mesh := MeshInstance3D.new()
		var floor_box := BoxMesh.new()
		floor_box.size = Vector3(extent.x + 8.0, 0.1, extent.z + 8.0)
		floor_mesh.mesh = floor_box
		var floor_material := StandardMaterial3D.new()
		floor_material.albedo_color = Color("30363c")
		floor_material.roughness = 0.85
		floor_mesh.material_override = floor_material
		floor_mesh.position.y = float(low.y)*cell_size - ShipBlueprint.center(cells).y - 2.03
		scene.add_child(floor_mesh)
		_frame_camera(camera, Vector3.ZERO, extent + Vector3(5, 1, 0), Vector3(1.4, 0.3, -1.5))
		await _save_capture("family-%s-landed.png" % family_id)
		floor_mesh.queue_free()

		visual.hide()
		interior.show()
		_hide_deck_ceilings(interior, modules)
		var room_center_y := (float(low.y + high.y) * cell_size + ShipBlueprint.CLEAR_HEIGHT) * 0.5 + ShipBlueprint.interior_offset(cells).y
		var room_extent := Vector3(extent.x, (float(high.y - low.y) * cell_size) + ShipBlueprint.CLEAR_HEIGHT, extent.z)
		_frame_camera(camera, Vector3(0, room_center_y, 0), room_extent, Vector3(0.6, 1.8, -0.8))
		camera.make_current()
		await _save_capture("family-%s-cutaway.png" % family_id)
		print("HULL_FAMILY_CAPTURE family=", family_id, " exterior=ShipVisual cutaway=ShipInterior source=ShipBlueprint.family")
		visual.queue_free()
		interior.queue_free()
		await process_frame
	quit()


func _hide_deck_ceilings(interior: ShipInterior, modules: Array[Dictionary]) -> void:
	for module: Dictionary in modules:
		var expected_y := float(module.y) * ShipBlueprint.CELL_SIZE + ShipBlueprint.CLEAR_HEIGHT
		var expected_center := Vector3(float(module.x), 0.0, float(module.z)) * ShipBlueprint.CELL_SIZE
		for child: Node in interior.get_children():
			if not child is MeshInstance3D: continue
			var mesh_instance := child as MeshInstance3D
			if not mesh_instance.mesh is BoxMesh: continue
			var box := mesh_instance.mesh as BoxMesh
			if not box.size.is_equal_approx(Vector3(ShipBlueprint.CELL_SIZE, 0.02, ShipBlueprint.CELL_SIZE)): continue
			if not is_equal_approx(mesh_instance.position.y, expected_y): continue
			if not is_equal_approx(mesh_instance.position.x, expected_center.x) or not is_equal_approx(mesh_instance.position.z, expected_center.z): continue
			mesh_instance.hide()


func _frame_camera(camera: Camera3D, target: Vector3, bounds_size: Vector3, direction: Vector3) -> void:
	camera.position = target + direction.normalized() * 70.0
	camera.look_at(target)
	var half := bounds_size * 0.5
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var projected_width := 2.0 * (absf(right.x) * half.x + absf(right.y) * half.y + absf(right.z) * half.z)
	var projected_height := 2.0 * (absf(up.x) * half.x + absf(up.y) * half.y + absf(up.z) * half.z)
	var aspect := float(root.size.x) / float(root.size.y)
	camera.size = maxf(4.0, maxf(projected_height, projected_width / aspect) / 0.66)


func _save_capture(filename: String) -> void:
	for _frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	var prefix := "standard-" if "--standard-material" in OS.get_cmdline_user_args() else ""
	var path := "user://" + prefix + filename
	var error: Error = root.get_texture().get_image().save_png(path)
	assert(error == OK, "could not save ship-family capture: " + path)
	print("HULL_FAMILY_CAPTURE_FILE: ", ProjectSettings.globalize_path(path))
