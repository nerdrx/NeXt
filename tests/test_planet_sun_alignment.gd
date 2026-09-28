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
	var expected_directions: Array[Vector3] = []
	var expected_positions: Array[Vector3] = []
	for index in world.planets.size():
		var planet: Dictionary = world.planets[index]
		var direction: Vector3 = (SpaceWorldScript.PRIMARY_POSITION - planet.position).normalized()
		var relative_position: Vector3 = SpaceWorldScript.PRIMARY_POSITION - planet.position
		expected_directions.append(direction)
		expected_positions.append(relative_position)
		assert(_near(world.planet_sun_direction(index), direction), "helper points from each planet toward the primary")
		var surface := world.get_node(str(planet.name)) as MeshInstance3D
		var surface_material := surface.material_override as ShaderMaterial
		assert(_near(surface_material.get_shader_parameter("planet_sun_position"), relative_position), "surface shader receives its local primary position")
		assert(_near(surface_material.get_shader_parameter("weather_sun_direction"), direction), "surface weather shadow shares the primary direction")
		if bool(planet.atmosphere):
			var atmosphere := world.get_node(str(planet.name) + " atmosphere") as MeshInstance3D
			var atmosphere_material := atmosphere.material_override as ShaderMaterial
			assert(_near(atmosphere_material.get_shader_parameter("sun_direction"), direction), "atmosphere uses per-planet primary direction")
		if bool(planet.has_ocean) and bool(planet.atmosphere):
			var clouds := world.get_node(str(planet.name) + " clouds") as MeshInstance3D
			var cloud_material := clouds.material_override as ShaderMaterial
			assert(_near(cloud_material.get_shader_parameter("sun_direction"), direction), "clouds use per-planet primary direction")
	assert(world.planet_sun_direction(-1) == Vector3.ZERO and world.planet_sun_direction(world.planets.size()) == Vector3.ZERO, "invalid planet indices return zero")
	var directional_lights := world.find_children("*", "DirectionalLight3D", true, false)
	assert(directional_lights.size() == 1)
	var primary_to_origin := (-SpaceWorldScript.PRIMARY_POSITION).normalized()
	assert((-(directional_lights[0] as DirectionalLight3D).global_basis.z).dot(primary_to_origin) > 0.999, "global directional light points from primary toward origin")
	world.position = Vector3(1200, -450, 870)
	for index in world.planets.size():
		assert(_near(world.planet_sun_direction(index), expected_directions[index]), "world translation leaves per-planet direction invariant")
		var material := (world.get_node(str(world.planets[index].name)) as MeshInstance3D).material_override as ShaderMaterial
		assert(_near(material.get_shader_parameter("planet_sun_position"), expected_positions[index]), "world translation leaves local shader position invariant")
		assert(_near(material.get_shader_parameter("weather_sun_direction"), expected_directions[index]))
	world.queue_free()
	await process_frame
	print("PLANET_SUN_ALIGNMENT_OK: per-planet surface, cloud, atmosphere, weather and translated-world directions")
	quit()

func _near(actual: Variant, expected: Vector3) -> bool:
	return actual is Vector3 and (actual as Vector3).distance_to(expected) < 0.00001
