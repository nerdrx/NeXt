extends SceneTree

const SpaceWorldScript = preload("res://scripts/space_world.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var low := SpaceWorldScript.stellar_display_color(1800.0)
	var solar := SpaceWorldScript.stellar_display_color(5772.0)
	var high := SpaceWorldScript.stellar_display_color(30000.0)
	for color: Color in [low, solar, high, SpaceWorldScript.stellar_display_color(NAN), SpaceWorldScript.stellar_display_color(INF), SpaceWorldScript.stellar_display_color(-INF), SpaceWorldScript.stellar_display_color(-100.0), SpaceWorldScript.stellar_display_color(1.0e30)]:
		assert(is_finite(color.r) and color.r >= 0.0 and color.r <= 1.0 and is_finite(color.g) and color.g >= 0.0 and color.g <= 1.0 and is_finite(color.b) and color.b >= 0.0 and color.b <= 1.0)
	assert(low.r > low.g and low.g > low.b, "cool stars use warm orange")
	assert(solar.r > solar.g and solar.g > solar.b and solar.b > 0.75, "solar temperature uses warm white")
	assert(high.b > high.g and high.g > high.r, "hot stars use blue-white")
	assert(SpaceWorldScript.stellar_display_color(-100.0) == low, "low temperatures clamp to orange endpoint")
	assert(SpaceWorldScript.stellar_display_color(1.0e30) == high, "high temperatures clamp to blue endpoint")
	assert(SpaceWorldScript.stellar_display_color(NAN) == solar and SpaceWorldScript.stellar_display_color(INF) == solar, "nonfinite temperatures use safe solar-white fallback")

	var nebula_index := -1
	for index in 128:
		if Universe.system_data(index).star_type == "Nebula":
			nebula_index = index
			break
	assert(nebula_index >= 0, "representative nebula catalog entry exists")
	var world := SpaceWorldScript.new()
	world.data = Universe.system_data(nebula_index)
	world.stellar_profile = CelestialSystem.generate(nebula_index).star
	root.add_child(world)
	world._build_star()
	var primary := world.get_node("System primary") as MeshInstance3D
	var material := primary.material_override as ShaderMaterial
	var expected := SpaceWorldScript.stellar_display_color(world.stellar_profile.temperature_k)
	assert(world.stellar_profile.kind == "Yellow Star")
	assert(material.get_shader_parameter("star_kind") == float(Universe.STAR_TYPES.find("Yellow Star")), "nebula visuals use the catalog's yellow-star display kind")
	assert(material.get_shader_parameter("star_color") == expected, "nebula primary material uses its physical temperature")
	var lights := world.find_children("*", "DirectionalLight3D", true, false)
	assert(lights.size() == 1 and (lights[0] as DirectionalLight3D).light_color == expected, "directional light matches stellar temperature color")
	world.queue_free()
	await process_frame
	print("STELLAR_APPEARANCE_OK: bounded color ramp and nebula catalog display integration")
	quit()
