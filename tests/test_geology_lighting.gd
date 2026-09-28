extends SceneTree

const SpaceWorldScript = preload("res://scripts/space_world.gd")
const PlanetTerrainScript = preload("res://scripts/planet_terrain.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := SpaceWorldScript.new()
	root.add_child(world)
	world.build(0)
	var planet: Dictionary = world.planets[0]
	var globe := world.get_node(str(planet.name)) as MeshInstance3D
	var globe_material := globe.material_override as ShaderMaterial
	var terrain := PlanetTerrainScript.new()
	world.add_child(terrain)
	var normal: Vector3 = world.planet_sun_direction(0)
	terrain.build(float(planet.visual_radius), normal, Universe._seed_for(0, 900), planet.color, false)
	var geology := terrain.get_node("Surface geology") as PlanetGeology
	var rock_material: ShaderMaterial = geology.rock_material
	world.configure_planet_weather(rock_material, 0)
	assert(rock_material.get_shader_parameter("planet_anchor") == geology.anchor, "rock shader uses geology's planet-relative anchor")
	assert(rock_material.get_shader_parameter("planet_sun_position") == globe_material.get_shader_parameter("planet_sun_position"), "rocks and globe share the primary position")
	assert(rock_material.get_shader_parameter("eclipse_count") == globe_material.get_shader_parameter("eclipse_count"), "rocks and globe share eclipse count")
	assert(rock_material.get_shader_parameter("eclipse_bodies") == globe_material.get_shader_parameter("eclipse_bodies"), "rocks and globe share eclipse bodies")
	assert(not geology.rock_multimeshes.is_empty(), "sun-facing land patch contains rocks")
	var total := 0
	for visual: MultiMeshInstance3D in geology.rock_multimeshes:
		var multimesh := visual.multimesh
		assert(multimesh.use_custom_data, "rock instances provide patch-local positions")
		assert(multimesh.mesh.surface_get_material(0) == rock_material, "all variants share the weather-configured material")
		total += multimesh.instance_count
		for index in multimesh.instance_count:
			var transform := multimesh.get_instance_transform(index)
			var custom := multimesh.get_instance_custom_data(index)
			var patch_position := Vector3(custom.r, custom.g, custom.b)
			assert(patch_position.distance_to(transform.origin) < 0.001, "custom data encodes each instance's patch-local translation")
			assert(custom.a == 1.0, "custom data keeps alpha at one")
			assert((geology.anchor + patch_position).is_finite(), "reconstructed planet position remains finite")
	assert(total > 0)
	var sun_position: Vector3 = rock_material.get_shader_parameter("planet_sun_position")
	var eclipses: PackedVector4Array = rock_material.get_shader_parameter("eclipse_bodies")
	world.position = Vector3(1200, -450, 870)
	assert(rock_material.get_shader_parameter("planet_anchor") == geology.anchor, "scene translation does not shift the shader anchor")
	assert(rock_material.get_shader_parameter("planet_sun_position") == sun_position, "scene translation preserves local sun position")
	assert(rock_material.get_shader_parameter("eclipse_bodies") == eclipses, "scene translation preserves local eclipses")
	world.queue_free()
	await process_frame
	print("GEOLOGY_LIGHTING_OK: custom patch coordinates, shared weather material, and translation-invariant lighting")
	quit()
