extends SceneTree

func _initialize() -> void:
	var visual := ShipVisual.new()
	var modules: Array = [
		{"kind": "engine", "x": 0, "y": 0, "z": 0},
		{"kind": "engine", "x": 0, "y": 0, "z": 1},
		{"kind": "cargo", "x": 0, "y": 0, "z": 2},
	]
	visual.build(modules)
	assert(visual._engines.size() == 2, "engines in one column share a twin outlet instead of overlapping")
	var aft_face := ShipVisual.CELL_SIZE + ShipBlueprint.PRESSURE_SIZE.z * 0.5
	var bells := 0
	for child: Node in visual.get_children():
		if not str(child.name).begins_with("EngineBell"): continue
		bells += 1
		var bell := child as MeshInstance3D
		assert(bell.position.z + bell.mesh.get_aabb().position.z >= aft_face, "bell starts outside aft occupied room")
	assert(bells == 2)
	visual.set_thrust(1.0)
	assert(visual._engine_glow[0].emission_energy_multiplier > 0.45)
	visual.set_systems_online(false)
	for material: StandardMaterial3D in visual._engine_glow:
		assert(material.emission_energy_multiplier == 0.0, "recessed throat respects power state")
	visual.free()
	var starter := ShipVisual.new()
	starter.build(GameState.new().ship_modules)
	assert(starter._engines.size() == 2, "starter retains exhaust despite its covered engine cell")
	starter.free()
	print("SHIP_NOZZLES_OK: external shared outlets, starter layout and power state")
	quit()
