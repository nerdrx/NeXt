class_name ShipInterior
extends Node3D

const CELL := Vector3(2.8, 3.1, 2.8)
var modules: Array[Dictionary] = []
var decks: Array[int] = []
var cockpit_position := Vector3.ZERO
var lift_positions: Dictionary = {}

func build(blueprint: Array[Dictionary]) -> void:
	modules = blueprint.duplicate(true)
	for module: Dictionary in modules:
		var deck: int = int(module.y)
		if deck not in decks: decks.append(deck)
	decks.sort()
	for module: Dictionary in modules:
		var center := Vector3(module.x, module.y, module.z) * CELL
		var kind: String = str(module.kind)
		if not lift_positions.has(int(module.y)): lift_positions[int(module.y)] = center + Vector3(0, 0.1, 0)
		_floor(center, kind)
		for axis: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := Vector3i(int(module.x), int(module.y), int(module.z)) + axis
			var adjacent: bool = _has_cell(neighbor)
			var offset := Vector3(axis) * Vector3(1.4, 0, 1.4)
			var size := Vector3(0.1, 2.7, 2.8) if axis.x != 0 else Vector3(2.8, 2.7, 0.1)
			if not adjacent:
				_box(center + offset + Vector3(0, 1.35, 0), size, Color("253745"), true)
				_box(center + offset * 0.96 + Vector3(0, 1.9, 0), Vector3(0.025, 0.025, 2.4) if axis.x != 0 else Vector3(2.4, 0.025, 0.025), Color("55c6d0"), false, true)
			else:
				var side := Vector3(0, 0, 1) if axis.x != 0 else Vector3(1, 0, 0)
				for direction in [-1, 1]:
					_box(center + offset + side * direction * 1.12 + Vector3(0, 1.35, 0), Vector3(0.18, 2.7, 0.38) if axis.x != 0 else Vector3(0.38, 2.7, 0.18), Color("4a606d"), true)
				_box(center + offset + Vector3(0, 2.55, 0), Vector3(0.2, 0.3, 2.8) if axis.x != 0 else Vector3(2.8, 0.3, 0.2), Color("4a606d"), true)
		_equipment(center, kind)
		var lamp := OmniLight3D.new()
		lamp.position = center + Vector3(0, 2.4, 0)
		lamp.light_color = Color("b9d9eb")
		lamp.light_energy = 0.65
		lamp.omni_range = 4.3
		add_child(lamp)

func _floor(center: Vector3, kind: String) -> void:
	_box(center + Vector3(0, -0.12, 0), Vector3(2.8, 0.24, 2.8), Color("23313c"), true)
	_box(center + Vector3(0, 2.8, 0), Vector3(2.8, 0.18, 2.8), Color("314451"), true)
	for x in [-0.8, 0.8]:
		_box(center + Vector3(x, 0.014, 0), Vector3(0.022, 0.018, 2.5), Color("587c83"))
	_box(center + Vector3(0, 2.68, 0), Vector3(0.13, 0.04, 1.9), Color("bce7e5"), false, true)
	var label := Label3D.new()
	label.text = kind.to_upper() + "  /  DECK " + str(int(round(center.y / CELL.y)))
	label.font_size = 40
	label.pixel_size = 0.003
	label.position = center + Vector3(0, 2.3, -1.22)
	label.modulate = Color("89d5dc")
	add_child(label)

func _equipment(center: Vector3, kind: String) -> void:
	match kind:
		"cockpit":
			cockpit_position = center + Vector3(0, 0.2, 0.2)
			_box(center + Vector3(0, 0.78, -0.86), Vector3(2.1, 0.28, 0.6), Color("172a35"), true)
			for x in [-0.65, 0.0, 0.65]:
				var screen := _box(center + Vector3(x, 1.0, -0.94), Vector3(0.5, 0.32, 0.04), Color("39818c"), false, true)
				screen.rotation.x = -0.3
			_box(center + Vector3(0, 0.35, 0.85), Vector3(0.6, 0.55, 0.6), Color("385263"), true)
		"habitat":
			_box(center + Vector3(-0.98, 0.32, 0), Vector3(0.65, 0.55, 2.1), Color("374c5a"), true)
			_box(center + Vector3(-0.98, 0.63, 0), Vector3(0.6, 0.13, 1.9), Color("80929b"))
			_box(center + Vector3(1.07, 0.8, 0.9), Vector3(0.4, 1.6, 0.5), Color("4b606a"), true)
		"cargo":
			for z in [-0.75, 0.75]:
				_box(center + Vector3(-0.95, 0.5, z), Vector3(0.65, 1.0, 0.6), Color("807052"), true)
				_box(center + Vector3(-0.95, 0.75, z - 0.31), Vector3(0.4, 0.04, 0.02), Color("e3bb75"), false, true)
		"reactor", "engine", "shield":
			_box(center + Vector3(0.99, 1.1, 0), Vector3(0.48, 2.2, 1.4), Color("2e4553"), true)
			for y in [0.5, 1.0, 1.5]:
				_box(center + Vector3(0.72, y, 0), Vector3(0.03, 0.17, 0.85), Color("58becd"), false, true)
		"weapon":
			_box(center + Vector3(-1.0, 1.0, 0), Vector3(0.5, 2.0, 1.2), Color("4c4850"), true)

func spawn_on_deck(deck: int) -> Vector3:
	var pos: Vector3 = lift_positions.get(deck, cockpit_position)
	return global_position + pos + Vector3(0, 0.15, 0)

func _has_cell(cell: Vector3i) -> bool:
	for item: Dictionary in modules:
		if int(item.x) == cell.x and int(item.y) == cell.y and int(item.z) == cell.z: return true
	return false

func _box(at: Vector3, size: Vector3, color: Color, collide: bool = false, emissive: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.5
	material.roughness = 0.5
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.6
	if emissive:
		instance.material_override = material
	else:
		var panel_material := ShaderMaterial.new()
		panel_material.shader = preload("res://shaders/interior_panel.gdshader")
		panel_material.set_shader_parameter("paint", color)
		instance.material_override = panel_material
	add_child(instance)
	instance.position = at
	if collide:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		instance.add_child(body)
		body.add_child(collision)
	return instance
