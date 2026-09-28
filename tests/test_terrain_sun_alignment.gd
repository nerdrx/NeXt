extends SceneTree

const SpaceWorldScript = preload("res://scripts/space_world.gd")
const PlanetTerrainScript = preload("res://scripts/planet_terrain.gd")

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
	var terrain := PlanetTerrainScript.new()
	world.add_child(terrain)
	var index := 0
	var planet: Dictionary = world.planets[index]
	var radius := float(planet.visual_radius)
	terrain.build(radius, Vector3.FORWARD, 341, Color.WHITE, bool(planet.has_ocean))
	world.configure_planet_weather(terrain.terrain_material, index)
	_assert_target_frame(world, terrain, index)
	var first_anchor: Vector3 = terrain.terrain_material.get_shader_parameter("planet_anchor")
	terrain.build(radius, Vector3.RIGHT, 341, Color.WHITE, bool(planet.has_ocean))
	world.configure_planet_weather(terrain.terrain_material, index)
	var second_anchor: Vector3 = terrain.terrain_material.get_shader_parameter("planet_anchor")
	assert(first_anchor.distance_to(second_anchor) > radius, "moving terrain patch changes its planet-relative anchor")
	_assert_target_frame(world, terrain, index)
	world.position = Vector3(1200, -450, 870)
	_assert_target_frame(world, terrain, index)
	world.queue_free()
	await process_frame
	print("TERRAIN_SUN_ALIGNMENT_OK: terrain and globe share primary direction, eclipse frame, and anchor-independent target")
	quit()

func _assert_target_frame(world: Node, terrain: PlanetTerrainScript, index: int) -> void:
	var planet: Dictionary = world.planets[index]
	var origin := Vector3(planet.position)
	var expected_sun := SpaceWorldScript.PRIMARY_POSITION - origin
	var globe := world.get_node(str(planet.name)) as MeshInstance3D
	var globe_material := globe.material_override as ShaderMaterial
	var terrain_material := terrain.terrain_material
	assert(_near(globe_material.get_shader_parameter("planet_sun_position"), expected_sun), "globe sun position is primary-relative to target planet")
	assert(_near(terrain_material.get_shader_parameter("planet_sun_position"), expected_sun), "terrain sun position stays primary-relative when its patch anchor changes")
	assert(_near(terrain_material.get_shader_parameter("weather_sun_direction"), world.planet_sun_direction(index)), "terrain weather direction matches the globe's target-relative sun")
	assert(terrain_material.get_shader_parameter("eclipse_count") == globe_material.get_shader_parameter("eclipse_count"), "terrain eclipse count matches globe")
	assert(terrain_material.get_shader_parameter("eclipse_bodies") == globe_material.get_shader_parameter("eclipse_bodies"), "terrain eclipse bodies stay in the globe's target-relative frame")
	assert(_near(terrain_material.get_shader_parameter("planet_anchor"), terrain.anchor), "terrain shader anchor follows its generated patch")

func _near(actual: Variant, expected: Vector3) -> bool:
	return actual is Vector3 and (actual as Vector3).distance_to(expected) < 0.00001
