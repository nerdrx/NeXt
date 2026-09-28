extends SceneTree

const SpaceWorldScript = preload("res://scripts/space_world.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var system_index := -1
	for candidate in 128:
		if Universe.system_data(candidate).planets.size() >= 3:
			system_index = candidate
			break
	assert(system_index >= 0, "test catalog contains a multi-planet system")
	var world := SpaceWorldScript.new()
	root.add_child(world)
	world.build(system_index)
	for index in world.planets.size():
		var planet: Dictionary = world.planets[index]
		var surface := world.get_node(str(planet.name)) as MeshInstance3D
		_assert_eclipse_buffer(surface.material_override as ShaderMaterial, world.planets, index)
		if bool(planet.atmosphere):
			var atmosphere := world.get_node(str(planet.name) + " atmosphere") as MeshInstance3D
			_assert_eclipse_buffer(atmosphere.material_override as ShaderMaterial, world.planets, index)
		if bool(planet.atmosphere) and bool(planet.has_ocean):
			var clouds := world.get_node(str(planet.name) + " clouds") as MeshInstance3D
			_assert_eclipse_buffer(clouds.material_override as ShaderMaterial, world.planets, index)
	var first_surface := (world.get_node(str(world.planets[0].name)) as MeshInstance3D).material_override as ShaderMaterial
	var before_count := int(first_surface.get_shader_parameter("eclipse_count"))
	var before_bodies: PackedVector4Array = first_surface.get_shader_parameter("eclipse_bodies")
	world.configure_planet_eclipse(null, 0)
	world.configure_planet_eclipse(first_surface, -1)
	world.configure_planet_eclipse(first_surface, world.planets.size())
	assert(int(first_surface.get_shader_parameter("eclipse_count")) == before_count)
	assert(first_surface.get_shader_parameter("eclipse_bodies") == before_bodies, "invalid requests leave material state unchanged")
	world.position = Vector3(1200, -450, 870)
	for index in world.planets.size():
		var planet: Dictionary = world.planets[index]
		var surface := world.get_node(str(planet.name)) as MeshInstance3D
		_assert_eclipse_buffer(surface.material_override as ShaderMaterial, world.planets, index)
		if bool(planet.atmosphere):
			var atmosphere := world.get_node(str(planet.name) + " atmosphere") as MeshInstance3D
			_assert_eclipse_buffer(atmosphere.material_override as ShaderMaterial, world.planets, index)
		if bool(planet.atmosphere) and bool(planet.has_ocean):
			var clouds := world.get_node(str(planet.name) + " clouds") as MeshInstance3D
			_assert_eclipse_buffer(clouds.material_override as ShaderMaterial, world.planets, index)
	# Exercise the actual truncation path beyond the current catalog maximum.
	for extra in 12:
		world.planets.append({"position": Vector3(5000 + extra * 100, 300, 200), "visual_radius": 20.0})
	world.configure_planet_eclipse(first_surface, 0)
	_assert_eclipse_buffer(first_surface, world.planets, 0)
	assert(int(first_surface.get_shader_parameter("eclipse_count")) == 8)
	world.queue_free()
	await process_frame
	print("PLANET_ECLIPSE_OK: capped per-layer buffers, self exclusion, invalid calls, and translation invariance")
	quit()

func _assert_eclipse_buffer(material: ShaderMaterial, planets: Array, source_index: int) -> void:
	var expected := PackedVector4Array()
	var source: Dictionary = planets[source_index]
	for index in planets.size():
		if index == source_index: continue
		var body: Dictionary = planets[index]
		var relative_position: Vector3 = body.position - source.position
		expected.append(Vector4(relative_position.x, relative_position.y, relative_position.z, float(body.visual_radius)))
		if expected.size() == 8: break
	var actual: Variant = material.get_shader_parameter("eclipse_bodies")
	assert(actual is PackedVector4Array, "eclipse shader buffer has expected type")
	var buffer: PackedVector4Array = actual
	var count := int(material.get_shader_parameter("eclipse_count"))
	assert(count == expected.size() and count <= 8, "eclipse count matches capped number of other planets")
	assert(buffer.size() == 8, "eclipse buffer always contains eight entries")
	for slot in 8:
		if slot < count:
			assert(buffer[slot].distance_to(expected[slot]) < 0.001, "slot holds another body's target-relative center and visual radius")
			assert(buffer[slot].w > 0.0, "eclipse body has positive visual radius")
		else:
			assert(buffer[slot] == Vector4.ZERO, "unused eclipse slots are cleared")
