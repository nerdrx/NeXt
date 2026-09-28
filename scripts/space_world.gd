class_name SpaceWorld
extends Node3D

const SKY_SHADER: Shader = preload("res://shaders/deep_space_sky.gdshader")
const PLANET_SHADER: Shader = preload("res://shaders/planet_surface.gdshader")
const CLOUD_SHADER: Shader = preload("res://shaders/planet_clouds.gdshader")
const CORONA_SHADER: Shader = preload("res://shaders/stellar_corona.gdshader")
const STAR_SHADER: Shader = preload("res://shaders/star_surface.gdshader")

const PRIMARY_POSITION := Vector3(-1700, 1150, -4100)
var stellar_profile: Dictionary = {}

var data: Dictionary = {}
var planets: Array[Dictionary] = []
var system_index: int = 0
var spawn_position: Vector3 = Vector3(0, 2, 20)
var launch_position: Vector3 = Vector3(0, 12, -110)
var large_dock_position: Vector3 = Vector3(-180, 0, -180)
var large_stand_position: Vector3 = Vector3(-123, 0.15, -180)
var large_launch_position: Vector3 = Vector3(-180, 116, -180)
var large_berth_route: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _world_environment: WorldEnvironment
var _material_cache: Dictionary = {}
var _planet_materials: Array[ShaderMaterial] = []

func build(system_index: int) -> void:
	spawn_position = Vector3(0, 2, 20)
	launch_position = Vector3(0, 12, -110)
	for child in get_children():
		child.queue_free()
	self.system_index = clampi(system_index, 0, Universe.SYSTEM_LIMIT - 1)
	data = Universe.system_data(self.system_index)
	stellar_profile = CelestialSystem.generate(self.system_index).star
	data["system_index"] = self.system_index
	_rng.seed = int(data.station_seed)
	planets.clear()
	_planet_materials.clear()
	var source: Array = data.planets
	for i in source.size():
		var planet: Dictionary = source[i].duplicate()
		# Appearance is derived without consuming the generation RNG or moving saved locations.
		var palette := [Color("68785a"), Color("a38266"), Color("8a8c83"), Color("b39b7a"), Color("778480")]
		var style: int = (int(data.station_seed) + i * 17) % palette.size()
		planet["color"] = palette[style]
		planet["has_ocean"] = bool(planet.atmosphere) and (i == 0 or style == 0 or style == 4)
		planet["visual_radius"] = 850.0 if i == 0 else 170.0 + float(i) * 34.0
		planet["position"] = Vector3(80.0 + float(i) * 500.0, 380.0 - float(i) * 100.0, -2200.0 - float(i) * 850.0)
		planets.append(planet)
	_build_environment()
	_build_hangar()
	_build_large_berth()
	_build_star()
	_build_planets()
	_build_distant_stars()

func stellar_heat(global_point: Vector3, orientation: Basis, dimensions: Vector3) -> float:
	if not is_visible_in_tree() or not global_point.is_finite(): return 0.0
	var point := to_local(global_point)
	var flux := StellarExposure.irradiance(stellar_profile, point, PRIMARY_POSITION, planets)
	var toward_star := orientation.inverse() * (to_global(PRIMARY_POSITION) - global_point)
	# Keep the placeholder photosphere center from becoming a zero-direction cold spot.
	if toward_star.is_zero_approx(): toward_star = Vector3.ONE
	return StellarExposure.absorbed_power(flux, dimensions, toward_star)

static func stellar_display_color(temp_k: float) -> Color:
	# A compact artistic ramp, not a spectral or black-body rendering model.
	var temperature := clampf(temp_k if is_finite(temp_k) else 5772.0, 1800.0, 30000.0)
	var warm_orange := Color("ff743d")
	var warm_white := Color("fff0dc")
	var blue_white := Color("b8d7ff")
	if temperature <= 5772.0:
		return warm_orange.lerp(warm_white, inverse_lerp(1800.0, 5772.0, temperature))
	return warm_white.lerp(blue_white, inverse_lerp(5772.0, 30000.0, temperature))

func _build_environment() -> void:
	_world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("nebula_color", Color(0.16, 0.23, 0.45))
	material.set_shader_parameter("nebula_accent", Color(0.5, 0.15, 0.48))
	sky.sky_material = material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aab2b4")
	environment.ambient_light_energy = 0.2
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 2.0
	environment.ssr_enabled = true
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	_world_environment.environment = environment
	add_child(_world_environment)
	var fill := OmniLight3D.new()
	fill.light_color = Color("b5c4cf")
	fill.light_energy = 0.4
	fill.omni_range = 125.0
	fill.position = Vector3(0, 18, 10)
	add_child(fill)

func _build_hangar() -> void:
	var deck := ShaderMaterial.new()
	deck.shader = preload("res://shaders/deck_plating.gdshader")
	_box("Hangar deck", Vector3(100, 1.4, 120), Vector3(0, -0.7, 0), deck, true)
	_box("Deep service trench", Vector3(9, 0.12, 88), Vector3(0, 0.08, -4), _standard_material(Color("071018"), 0.8, 0.5))
	for side in [-1.0, 1.0]:
		_box("Pressure wall", Vector3(2, 20, 120), Vector3(side * 50, 10, 0), _standard_material(Color("202c35"), 0.8, 0.55), true)
		_box("Raised service walk", Vector3(12, 0.65, 82), Vector3(side * 39, 1.8, -6), deck, true)
		_box("Overhead service duct", Vector3(7, 1.5, 38), Vector3(side * 42, 17.4, 24), _standard_material(Color("414b4e"), 0.72, 0.34))
		for i in 7:
			var z := -48.0 + float(i) * 14.0
			_box("Structural rib", Vector3(2.3, 23, 2.2), Vector3(side * 47, 11.4, z), _standard_material(Color("5a6670"), 0.7, 0.65))
			_box("Rib foot", Vector3(7, 1.8, 3.4), Vector3(side * 43, 1.2, z), deck)
			_box("Amber guide", Vector3(0.16, 0.12, 8), Vector3(side * 34, 2.17, z - 2), _emissive(Color("ffb65d"), 2.1))
		for z in [-36.0, -6.0, 24.0, 46.0]:
			var pod := _cylinder("Cargo pressure pod", 1.8, 7.5, Vector3(side * 42, 4.2, z), _standard_material(Color("59605d"), 0.58, 0.45))
			pod.rotation.x = PI / 2.0
			_box("Cargo clamp", Vector3(3.9, 0.22, 0.4), Vector3(side * 42, 4.2, z), _standard_material(Color("78807b"), 0.48, 0.72))
			_box("Cargo seal indicator", Vector3(0.18, 0.12, 0.16), Vector3(side * 42, 4.2, z - 3.75), _emissive(Color("83a89c"), 0.35))
		_box("Canopy cyan light", Vector3(0.28, 0.32, 94), Vector3(side * 34, 17.1, -4), _emissive(Color("d4dce0"), 0.7))
	# Large opening faces the docking approach at negative Z.
	_box("Rear pressure bulkhead", Vector3(100, 24, 3), Vector3(0, 11, 59), _standard_material(Color("1d2b34"), 0.75, 0.5))
	for x in [-42.0, -28.0, -14.0, 0.0, 14.0, 28.0, 42.0]:
		_box("Ceiling truss", Vector3(1.2, 1.5, 116), Vector3(x, 21.5, 0), _standard_material(Color("46545d"), 0.7, 0.65))
		_box("Ceiling panel", Vector3(9.0, 0.5, 13.0), Vector3(x, 20.5, -6), _standard_material(Color("465050"), 0.78, 0.36))
	_box("Ceiling spine", Vector3(1.4, 1.1, 100), Vector3(-25, 20.4, -2), _standard_material(Color("3d4c56"), 0.62, 0.7))
	for x in [-18.0, 18.0]:
		_box("Runway edge light", Vector3(0.13, 0.08, 76), Vector3(x, 0.13, -5), _emissive(Color("d3c59d"), 0.55))
	for z in range(-51, 48, 12):
		_box("Deck center marker", Vector3(0.22, 0.06, 5.0), Vector3(0, 0.05, z), _standard_material(Color("82919a"), 0.8, 0.25))
	for z in range(-51, 52, 12):
		_box("Deck expansion seam", Vector3(96, 0.025, 0.08), Vector3(0, 0.012, z), _standard_material(Color("222c31"), 0.9, 0.2))
	_add_hangar_lights()
	_build_terminal("TRAFFIC / ATC", Vector3(-37, 2.6, -49), Color("4ad8e8"))
	_build_terminal("FLIGHT SERVICES", Vector3(37, 2.6, -49), Color("ffb65d"))
	_build_terminal("CARGO MANIFEST", Vector3(-37, 2.6, 32), Color("87d8a3"))
	# Exposed dock collar and trusses frame the outside approach.
	var ring := TorusMesh.new()
	ring.inner_radius = 40.0
	ring.outer_radius = 45.0
	var collar := MeshInstance3D.new()
	collar.name = "Outer docking collar"
	collar.mesh = ring
	collar.position = Vector3(0, 30, -340)
	collar.rotation.x = PI / 2.0
	collar.material_override = _standard_material(Color("53646c"), 0.45, 0.75)
	add_child(collar)
	for side in [-1.0, 1.0]:
		_box("Dock approach spar", Vector3(6, 6, 105), Vector3(side * 66, 8, -95), _standard_material(Color("34464f"), 0.68, 0.65))
		_box("Dock signal", Vector3(1.1, 1.1, 22), Vector3(side * 66, 11.6, -99), _emissive(Color("46cae3"), 2.4))
	var probe := ReflectionProbe.new()
	probe.position = Vector3(0, 9, 0)
	probe.size = Vector3(100, 24, 120)
	probe.interior = true
	# Approximate reflected work-light fill without flooding the space outside the bay.
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color("b8c3c9")
	probe.ambient_color_energy = 0.18
	probe.box_projection = true
	probe.max_distance = 150
	add_child(probe)
	for side in [-1.0, 1.0]:
		var sign := Label3D.new()
		sign.text = "BAY 01  /  TRANSIT"
		sign.font_size = 96
		sign.pixel_size = 0.035
		sign.position = Vector3(side * 29, 7, -54)
		sign.modulate = Color("b9c0be")
		add_child(sign)
	_build_external_station()

func _build_large_berth() -> void:
	var deck := ShaderMaterial.new()
	deck.shader = preload("res://shaders/deck_plating.gdshader")
	_box("Large public berth apron", Vector3(120, 1.4, 120), Vector3(-180, -0.7, -180), deck, true)
	# The connector runs beyond the existing approach spars before turning to the hangar mouth.
	_box("Berth connector west leg", Vector3(24, 1.4, 22), Vector3(-112, -0.7, -169), deck, true)
	_box("Berth connector crosswalk", Vector3(124, 1.4, 12), Vector3(-54, -0.7, -158), deck, true)
	_box("Berth connector approach", Vector3(12, 1.4, 116), Vector3(0, -0.7, -100), deck, true)
	for side in [-1.0, 1.0]:
		_box("Berth envelope guide", Vector3(0.22, 0.05, 104), Vector3(-180 + side * 48, 0.04, -180), _emissive(Color("63c9d7"), 0.65))
		_box("Berth service stripe", Vector3(0.3, 0.08, 116), Vector3(-180 + side * 58, 0.04, -180), _standard_material(Color("4c5b60"), 0.8, 0.3))
		if side < 0:
			_box("Berth perimeter rail", Vector3(0.5, 2.4, 120), Vector3(-240, 1.2, -180), _standard_material(Color("39484e"), 0.65, 0.55), true)
		else:
			for rail: Dictionary in [{"z": -215.0, "length": 50.0}, {"z": -135.0, "length": 30.0}]:
				_box("Berth perimeter rail", Vector3(0.5, 2.4, rail.length), Vector3(-120, 1.2, rail.z), _standard_material(Color("39484e"), 0.65, 0.55), true)
	for rib in range(7):
		_box("Berth apron seam", Vector3(108, 0.025, 0.08), Vector3(-180, 0.015, -228 + rib * 16), _standard_material(Color("26333a"), 0.9, 0.25))
	for x in [-228.0, -204.0, -180.0, -156.0, -132.0]:
		_box("Berth edge marker", Vector3(2.4, 0.12, 0.9), Vector3(x, 0.12, -239), _emissive(Color("ffb65d"), 0.7))
	_box("Berth boarding kiosk", Vector3(2.4, 2.2, 1.6), Vector3(-235, 1.1, -220), _standard_material(Color("34474f"), 0.55, 0.65))
	_box("Berth kiosk display", Vector3(1.6, 0.8, 0.08), Vector3(-235, 1.55, -219.16), _emissive(Color("65d8de"), 1.0))
	for sign_spec: Dictionary in [
		{"text": "LARGE BERTH  /  BOARDING", "position": Vector3(-112, 4, -180)},
		{"text": "LARGE BERTH  ←", "position": Vector3(0, 4, -54)},
	]:
		var sign := Label3D.new()
		sign.text = sign_spec.text
		sign.font_size = 72
		sign.pixel_size = 0.025
		sign.modulate = Color("bde4e1")
		sign.position = sign_spec.position
		add_child(sign)
	large_berth_route = [
		large_stand_position,
		Vector3(-112, 0.15, -180),
		Vector3(-112, 0.15, -158),
		Vector3(0, 0.15, -158),
		Vector3(0, 0.15, -42),
		spawn_position,
	]

func _add_hangar_lights() -> void:
	for x in [-24.0, 24.0]:
		for z in [-34.0, -2.0, 30.0]:
			var light := SpotLight3D.new()
			light.light_color = Color("d9e0dd")
			light.light_energy = 3.2
			light.spot_range = 52.0
			light.spot_angle = 68.0
			light.rotation.x = -PI / 2.0
			light.position = Vector3(x, 18.8, z)
			light.shadow_enabled = z == -2.0
			add_child(light)

func _build_external_station() -> void:
	var center := Vector3(900, 280, -720)
	var ring := TorusMesh.new()
	ring.inner_radius = 338.0
	ring.outer_radius = 356.0
	var ring_instance := MeshInstance3D.new()
	ring_instance.name = "Orbital habitat ring"
	ring_instance.mesh = ring
	ring_instance.position = center
	ring_instance.rotation.x = PI / 2.0
	ring_instance.material_override = _standard_material(Color("58656a"), 0.48, 0.78)
	add_child(ring_instance)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var pod_pos := center + Vector3(cos(angle) * 346.0, 0, sin(angle) * 346.0)
		var pod := _cylinder("Ring habitation pod", 16.0, 52.0, pod_pos, _standard_material(Color("32444b"), 0.56, 0.62))
		pod.rotation.z = PI / 2.0
		var window := _box("Habitat viewport band", Vector3(0.18, 5, 45), pod_pos + Vector3(0, 16, 0), _emissive(Color("65cce4"), 0.9))
		window.rotation.y = -angle
		var spoke := _box("Ring radial truss", Vector3(9, 9, 332), center + Vector3(cos(angle) * 166.0, 0, sin(angle) * 166.0), _standard_material(Color("35464d"), 0.7, 0.68))
		spoke.rotation.y = PI / 2.0 - angle
	for y in [-95.0, 95.0]:
		_box("Station elevator mast", Vector3(14, 14, 190), center + Vector3(0, y, 0), _standard_material(Color("48565b"), 0.52, 0.75))
	var hub := _cylinder("Ring central hub", 54.0, 120.0, center, _standard_material(Color("46565d"), 0.48, 0.72))
	hub.rotation.z = PI / 2.0

func _build_terminal(label: String, pos: Vector3, color: Color) -> void:
	_box(label + " pedestal", Vector3(3.8, 3.2, 2.3), pos, _standard_material(Color("263840"), 0.58, 0.55))
	var screen := _box(label + " display", Vector3(3.4, 2.2, 0.18), pos + Vector3(0, 2.15, -1.14), _emissive(color, 1.1))
	var text := Label3D.new()
	text.text = label
	text.font_size = 46
	text.pixel_size = 0.008
	text.modulate = Color(0.84, 0.95, 1.0)
	text.position = pos + Vector3(0, 3.6, -1.24)
	text.rotation.y = PI if pos.x < 0 else 0.0
	text.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(text)

func _build_star() -> void:
	var star_type: String = data.star_type
	var display_kind: String = str(stellar_profile.get("kind", "Yellow Star"))
	var star_color := stellar_display_color(float(stellar_profile.get("temperature_k", 5772.0)))
	var light := DirectionalLight3D.new()
	light.light_color = star_color
	light.light_energy = 1.2 if star_type != "Black Hole" else 0.2
	light.shadow_enabled = true
	light.basis = Basis.looking_at(-PRIMARY_POSITION, Vector3.UP)
	add_child(light)
	if star_type == "Black Hole":
		_sphere("Black hole event horizon", 245, PRIMARY_POSITION, Color("010208"), 0.0, 0.95)
		var disk := TorusMesh.new()
		disk.inner_radius = 270
		disk.outer_radius = 338
		var acc := MeshInstance3D.new()
		acc.name = "Accretion disk"
		acc.mesh = disk
		acc.position = PRIMARY_POSITION
		acc.rotation = Vector3(0.3, 0.2, 0.12)
		acc.material_override = _emissive(Color("ff703d"), 3.2)
		add_child(acc)
		for y in [-430.0, 430.0]:
			_box("Relativistic jet", Vector3(26, 380, 26), Vector3(-1700, 1150 + y, -4100), _emissive(Color("87cfff"), 1.8))
	else:
		var star_material := ShaderMaterial.new()
		star_material.shader = STAR_SHADER
		star_material.set_shader_parameter("star_color", star_color)
		star_material.set_shader_parameter("star_kind", float(Universe.STAR_TYPES.find(display_kind)))
		var primary := _sphere("System primary", 250, PRIMARY_POSITION, star_color, 2.3, 0.15, star_material)
		(primary.mesh as SphereMesh).radial_segments = 128
		(primary.mesh as SphereMesh).rings = 64
		var corona := MeshInstance3D.new()
		corona.name = "Stellar corona"
		var halo_mesh := QuadMesh.new()
		halo_mesh.size = Vector2(1000, 1000)
		corona.mesh = halo_mesh
		corona.position = PRIMARY_POSITION
		corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var halo_material := ShaderMaterial.new()
		halo_material.shader = CORONA_SHADER
		halo_material.set_shader_parameter("star_color", star_color)
		corona.material_override = halo_material
		# Shader rotates the quad toward the camera, so retain a conservative culling box.
		corona.custom_aabb = AABB(Vector3.ONE * -500, Vector3.ONE * 1000)
		add_child(corona)
		if star_type == "Neutron Star":
			for side in [-1.0, 1.0]:
				_box("Pulsar beam", Vector3(20, 1100, 20), Vector3(-1700, 1150 + side * 630, -4100), _emissive(Color("81d8ff"), 1.5))

func _build_planets() -> void:
	for i in planets.size():
		var planet: Dictionary = planets[i]
		var mat := ShaderMaterial.new()
		mat.shader = PLANET_SHADER
		var tint: Color = planet.color
		mat.set_shader_parameter("surface_color", tint)
		mat.set_shader_parameter("planet_radius", float(planet.visual_radius))
		configure_planet_weather(mat, i)
		mat.set_shader_parameter("ocean_color", Color("173747") if i == 0 else Color("102944").lerp(tint, 0.2))
		mat.set_shader_parameter("seed", float(i * 41 + int(data.station_seed % 997)))
		mat.set_shader_parameter("has_ocean", bool(planet.has_ocean))
		mat.set_shader_parameter("height_map", PlanetHeightField.texture_for(Universe._seed_for(system_index, 900 + i)))
		mat.set_shader_parameter("height_scale", PlanetHeightField.HEIGHT_SCALE)
		mat.set_shader_parameter("sea_level", PlanetHeightField.SEA_LEVEL)
		_planet_materials.append(mat)
		var globe := _sphere(str(planet.name), float(planet.visual_radius), planet.position, tint, 0.0, 0.82, mat, true)
		globe.mesh.radial_segments = 128
		globe.mesh.rings = 64
		if planet.atmosphere:
			var sun_direction := planet_sun_direction(i)
			var light_strength := 0.17 if data.star_type == "Black Hole" else 1.0
			if planet.has_ocean:
				var cloud_material := ShaderMaterial.new()
				cloud_material.shader = CLOUD_SHADER
				cloud_material.set_shader_parameter("seed", float(i * 41 + int(data.station_seed % 997)))
				cloud_material.set_shader_parameter("sun_direction", sun_direction)
				cloud_material.set_shader_parameter("light_strength", light_strength)
				var cloud_shell := _sphere(str(planet.name) + " clouds", float(planet.visual_radius) * 1.01 + PlanetHeightField.HEIGHT_SCALE, planet.position, Color.WHITE, 0.0, 1.0, cloud_material, false)
				cloud_shell.mesh.radial_segments = 128
				cloud_shell.mesh.rings = 64
				cloud_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				cloud_shell.set_meta("planet_cloud_layer", i)
			var halo_mat := ShaderMaterial.new()
			halo_mat.shader = load("res://shaders/planet_atmosphere.gdshader")
			halo_mat.set_shader_parameter("atmosphere_color", Color("75a8d6") if planet.has_ocean else Color("b6a18a"))
			halo_mat.set_shader_parameter("sun_direction", sun_direction)
			halo_mat.set_shader_parameter("light_strength", light_strength)
			var halo := _sphere(str(planet.name) + " atmosphere", float(planet.visual_radius) * 1.025 + PlanetHeightField.HEIGHT_SCALE, planet.position, Color.WHITE, 0.0, 1.0, halo_mat, false)
			halo.mesh.radial_segments = 128
			halo.mesh.rings = 64
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func planet_sun_direction(index: int) -> Vector3:
	if index < 0 or index >= planets.size(): return Vector3.ZERO
	return (PRIMARY_POSITION - Vector3(planets[index].position)).normalized()

func configure_planet_weather(material: ShaderMaterial, index: int) -> void:
	if material == null or index < 0 or index >= planets.size(): return
	var planet: Dictionary = planets[index]
	material.set_shader_parameter("weather_enabled", bool(planet.atmosphere) and bool(planet.has_ocean))
	material.set_shader_parameter("weather_seed", float(index * 41 + int(data.station_seed % 997)))
	material.set_shader_parameter("weather_shell_radius", float(planet.visual_radius) * 1.01 + PlanetHeightField.HEIGHT_SCALE)
	material.set_shader_parameter("weather_sun_direction", planet_sun_direction(index))
	if material.shader == PLANET_SHADER:
		material.set_shader_parameter("planet_sun_position", PRIMARY_POSITION - Vector3(planet.position))

func set_fine_terrain_patch(index: int, normal: Vector3, radius: float, extent: float) -> void:
	if index < 0 or index >= _planet_materials.size(): return
	var material := _planet_materials[index]
	var active := normal.is_finite() and normal.length_squared() > 0.000001
	material.set_shader_parameter("fine_patch_active", active)
	if not active: return
	var n := normal.normalized()
	var reference := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var tangent := n.cross(reference).normalized()
	material.set_shader_parameter("fine_patch_normal", n)
	material.set_shader_parameter("fine_patch_tangent", tangent)
	material.set_shader_parameter("fine_patch_bitangent", n.cross(tangent).normalized())
	material.set_shader_parameter("fine_patch_radius", radius)
	material.set_shader_parameter("fine_patch_extent", extent)

func _build_distant_stars() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 3.0
	mesh.height = 6.0
	var material := _emissive(Color("b7d9ff"), 1.4)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = 160
	for i in multimesh.instance_count:
		var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.65, 0.65), _rng.randf_range(-1, 1)).normalized()
		var pos := direction * _rng.randf_range(9000, 26000)
		var scale := _rng.randf_range(0.35, 1.7)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * scale), pos))
	var stars := MultiMeshInstance3D.new()
	stars.name = "Distant starfield"
	stars.multimesh = multimesh
	stars.material_override = material
	add_child(stars)

func build_surface(planet_index: int) -> void:
	for child in get_children():
		child.queue_free()
	if planets.is_empty():
		return
	var planet: Dictionary = planets[clampi(planet_index, 0, planets.size() - 1)]
	var tint: Color = planet.color
	_build_environment()
	_build_surface_environment(tint)
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://shaders/colony_ground.gdshader")
	ground_mat.set_shader_parameter("ground_color", tint.darkened(0.48))
	var terrain := _terrain_mesh(ground_mat, int(data.get("station_seed", 1)))
	add_child(terrain)
	var pad_mat := ShaderMaterial.new()
	pad_mat.shader = preload("res://shaders/deck_plating.gdshader")
	_box("Landing apron", Vector3(64, 1.2, 64), Vector3(0, 0, -6), pad_mat, true)
	_box("Pad center marking", Vector3(1.2, 0.07, 36), Vector3(0, 0.64, -6), _emissive(Color("56cfe1"), 1.2))
	for x in [-27.0, 27.0]:
		for z in [-33.0, 21.0]:
			_box("Pad corner lamp", Vector3(1, 0.8, 1), Vector3(x, 1.1, z), _emissive(Color("ffd285"), 1.5))
	# Low-density generated industrial settlement and road grid.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.get("station_seed", 1)) + planet_index * 101
	for road in [-1.0, 1.0]:
		_box("Colony access road", Vector3(14, 0.25, 190), Vector3(road * 76, 0.1, 0), _standard_material(Color("252e31"), 0.9, 0.05), true)
	for i in 14:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := -87.0 + float(i / 2) * 26.0
		var h := rng.randf_range(13, 31)
		var x := side * rng.randf_range(52, 100)
		var radius := rng.randf_range(7.0, 11.0)
		var tower := _cylinder("Faceted habitat tower", radius, h, Vector3(x, h * 0.5, z), _standard_material(Color.from_hsv(rng.randf_range(0.48, 0.57), 0.2, 0.4), 0.76, 0.24))
		tower.mesh.radial_segments = 8
		var box_collider := _building_collision(Vector3(x, h * 0.5, z), Vector3(radius * 1.8, h, radius * 1.8))
		add_child(box_collider)
		for level in range(2, int(h / 4.0)):
			var band := _cylinder("Habitat viewport ring", radius + 0.1, 0.3, Vector3(x, float(level) * 4.0, z), _emissive(Color("dfa873"), 0.3))
			band.mesh.radial_segments = 8
		_box("Tower crown", Vector3(radius * 1.1, 1.2, radius * 1.1), Vector3(x, h + 0.5, z), _standard_material(Color("384b50"), 0.46, 0.5))
		_box("Tower beacon", Vector3(0.35, 2.0, 0.35), Vector3(x, h + 2.0, z), _emissive(Color("ffc978"), 0.8))
	# Distant pressure domes and refinery stacks establish a visible colony skyline.
	for side in [-1.0, 1.0]:
		var x: float = side * 185.0
		for i in 3:
			var z := -240.0 - float(i) * 110.0
			var stack := _cylinder("Refinery pressure stack", 13.0 + float(i) * 2.0, 64.0 + float(i) * 14.0, Vector3(x, 38 + float(i) * 7.0, z), _standard_material(Color("455154"), 0.82, 0.2))
			stack.mesh.radial_segments = 10
			var crown := _cylinder("Stack emissive crown", 13.8 + float(i) * 2.0, 2.2, Vector3(x, 71 + float(i) * 14.0, z), _emissive(Color("e2a56e"), 0.52))
			crown.mesh.radial_segments = 10
	var path := _box("Apron access path", Vector3(12, 0.18, 42), Vector3(0, 0.68, -58), _standard_material(Color("4d5958"), 0.88, 0.05), true)
	spawn_position = Vector3(0, 2, 20)
	launch_position = Vector3(0, 6, -28)

func _terrain_mesh(material: Material, seed: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	var n := 56
	var size := 1000.0
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for z in n + 1:
		for x in n + 1:
			var px := (float(x) / n - 0.5) * size
			var pz := (float(z) / n - 0.5) * size
			var wave := sin(px * 0.027 + float(seed % 31)) * cos(pz * 0.021) + sin((px + pz) * 0.011)
			var flat_zone := smoothstep(120.0, 170.0, max(absf(px), absf(pz)))
			vertices.append(Vector3(px, wave * 8.0 * flat_zone, pz))
	for z in n:
		for x in n:
			var a := z * (n + 1) + x
			indices.append_array(PackedInt32Array([a, a + n + 1, a + 1, a + 1, a + n + 1, a + n + 2]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		surface.set_uv(Vector2(vertices[index].x, vertices[index].z) / size)
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	return body

func _box(label: String, size: Vector3, pos: Vector3, material: Material, collide: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	add_child(instance)
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		body.collision_layer = 1
		body.collision_mask = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
	return instance

func _sphere(label: String, radius: float, pos: Vector3, color: Color, emission: float, roughness: float, custom: Material = null, collision: bool = false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = custom if custom != null else _standard_material(color, roughness, 0.0, color, emission)
	add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.position = pos
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		shape.shape = sphere
		body.add_child(shape)
		add_child(body)
	return instance

func _cylinder(label: String, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	add_child(instance)
	return instance

func _building_collision(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _build_surface_environment(tint: Color) -> void:
	var env := _world_environment.environment
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("26333b").lerp(tint.darkened(0.45), 0.08)
	sky_material.sky_horizon_color = Color("a4a49a").lerp(tint, 0.12)
	sky_material.ground_bottom_color = Color("171b1f")
	sky_material.ground_horizon_color = tint.darkened(0.35)
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b7b9b2")
	env.ambient_light_energy = 0.3
	var sun := DirectionalLight3D.new()
	sun.name = "Colony daylight"
	sun.light_color = Color("fff3df")
	sun.light_energy = 2.0
	sun.rotation_degrees = Vector3(-38, -24, 0)
	sun.shadow_enabled = true
	add_child(sun)

func _standard_material(color: Color, roughness: float, metallic: float, emission_color: Color = Color.BLACK, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.3f|%.3f|%s|%.2f" % [color.to_html(), roughness, metallic, emission_color.to_html(), emission]
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = emission
	_material_cache[key] = material
	return material

func _emissive(color: Color, strength: float) -> StandardMaterial3D:
	return _standard_material(color, 0.3, 0.15, color, strength)

func set_flight_atmosphere(amount: float, tint: Color) -> void:
	if not is_instance_valid(_world_environment): return
	var env := _world_environment.environment
	var blend := clampf(amount, 0, 1)
	env.fog_enabled = blend > 0.001
	env.fog_density = blend * 0.002
	env.fog_light_color = tint
	env.fog_sky_affect = blend
	env.ambient_light_energy = 0.2 + blend * 0.4
