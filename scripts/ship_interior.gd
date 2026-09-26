class_name ShipInterior
extends Node3D

const CELL := Vector3(2.8, 3.1, 2.8)
var modules: Array[Dictionary] = []
var decks: Array[int] = []
var cockpit_position := Vector3.ZERO
var lift_positions: Dictionary = {}
var _layout: Dictionary = ShipLayout.empty_data()

func build(blueprint: Array[Dictionary], layout: Dictionary = {}) -> void:
	modules = blueprint.duplicate(true)
	_layout = layout if ShipLayout.validate_data(layout, modules) else ShipLayout.empty_data()
	for module: Dictionary in modules:
		var deck: int = int(module.y)
		if deck not in decks: decks.append(deck)
	decks.sort()
	for module: Dictionary in modules:
		var center := Vector3(module.x, module.y, module.z) * CELL
		var kind: String = str(module.kind)
		var cell := Vector3i(int(module.x), int(module.y), int(module.z))
		var cell_key := ShipLayout.cell_key(cell)
		var room_type: String = str(_layout.rooms.get(cell_key, ShipLayout.default_room(kind)))
		var panels: Dictionary = _layout.panels.get(cell_key, {})
		if not lift_positions.has(int(module.y)): lift_positions[int(module.y)] = center + Vector3(0, 0.1, 0)
		_floor(center, room_type, panels)
		for axis: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := Vector3i(int(module.x), int(module.y), int(module.z)) + axis
			var adjacent: bool = _has_cell(neighbor)
			var offset := Vector3(axis) * Vector3(1.4, 0, 1.4)
			var size := Vector3(0.1, 2.7, 2.8) if axis.x != 0 else Vector3(2.8, 2.7, 0.1)
			if not adjacent:
				var face := _face_for_axis(axis)
				_outer_wall(center, offset, size, face, str(panels.get(face, "standard")))
			else:
				var side := Vector3(0, 0, 1) if axis.x != 0 else Vector3(1, 0, 0)
				for direction in [-1, 1]:
					_box(center + offset + side * direction * 1.12 + Vector3(0, 1.35, 0), Vector3(0.18, 2.7, 0.38) if axis.x != 0 else Vector3(0.38, 2.7, 0.18), Color("4a606d"), true)
				_box(center + offset + Vector3(0, 2.55, 0), Vector3(0.2, 0.3, 2.8) if axis.x != 0 else Vector3(2.8, 0.3, 0.2), Color("4a606d"), true)
		_equipment(center, kind, room_type)
		_room_furnishing(center, room_type)
		var lamp := OmniLight3D.new()
		lamp.position = center + Vector3(0, 2.4, 0)
		lamp.light_color = Color("b9d9eb")
		lamp.light_energy = 0.65
		lamp.omni_range = 4.3
		add_child(lamp)

func _floor(center: Vector3, room_type: String, panels: Dictionary) -> void:
	var floor_type: String = str(panels.get("-y", "standard"))
	var ceiling_type: String = str(panels.get("+y", "standard"))
	var floor_color := Color("23313c") if floor_type == "standard" else (Color("39464d") if floor_type == "armored" else Color("174c60"))
	var ceiling_color := Color("314451") if ceiling_type == "standard" else (Color("465158") if ceiling_type == "armored" else Color("174c60"))
	_box(center + Vector3(0, -0.12, 0), Vector3(2.8, 0.24, 2.8), floor_color, true)
	_box(center + Vector3(0, 2.8, 0), Vector3(2.8, 0.18, 2.8), ceiling_color, true)
	if floor_type == "window":
		_box(center + Vector3(0, 0.014, 0), Vector3(1.85, 0.025, 1.85), Color(0.08, 0.27, 0.35, 0.7))
	if ceiling_type == "window":
		_box(center + Vector3(0, 2.69, 0), Vector3(1.85, 0.025, 1.85), Color(0.08, 0.27, 0.35, 0.7))
	for x in [-0.8, 0.8]:
		_box(center + Vector3(x, 0.014, 0), Vector3(0.022, 0.018, 2.5), Color("587c83"))
	_box(center + Vector3(0, 2.68, 0), Vector3(0.13, 0.04, 1.9), Color("bce7e5"), false, true)
	var label := Label3D.new()
	label.text = room_type.to_upper() + "  /  DECK " + str(int(round(center.y / CELL.y)))
	label.font_size = 40
	label.pixel_size = 0.003
	label.position = center + Vector3(0, 2.3, -1.22)
	label.modulate = Color("89d5dc")
	add_child(label)
	if floor_type == "armored" or ceiling_type == "armored":
		for x in [-1.1, 1.1]:
			_box(center + Vector3(x, 0.025, 0), Vector3(0.045, 0.035, 2.35), Color("78858a"))


func _outer_wall(center: Vector3, offset: Vector3, size: Vector3, face: String, panel_type: String) -> void:
	var wall_color := Color("253745") if panel_type == "standard" else (Color("4b5559") if panel_type == "armored" else Color("101d24"))
	var wall := _box(center + offset + Vector3(0, 1.35, 0), size, wall_color, true)
	if panel_type == "window":
		# Keep the solid collision wall behind the pane: windows never make pressure gaps.
		wall.visible = false
		var window_center := center + offset * 0.985 + Vector3(0, 1.35, 0)
		var pane_size := Vector3(0.035, 1.28, 1.78) if face in ["+x", "-x"] else Vector3(1.78, 1.28, 0.035)
		_box(window_center, pane_size, Color(0.08, 0.27, 0.35, 0.58))
		var frame := Color("78898b")
		if face in ["+x", "-x"]:
			# Opaque side panels and sill/lintel close all wall area outside the window frame.
			for side in [-1.0, 1.0]:
				_box(window_center + Vector3(0, 0, side * 1.19), Vector3(0.1, 2.7, 0.42), wall_color)
				_box(window_center + Vector3(0, side * 1.03, 0), Vector3(0.1, 0.64, 1.98), wall_color)
				_box(window_center + Vector3(0, 0, side * 0.935), Vector3(0.12, 1.5, 0.11), frame)
				_box(window_center + Vector3(0, side * 0.655, 0), Vector3(0.12, 0.11, 1.9), frame)
		else:
			for side in [-1.0, 1.0]:
				_box(window_center + Vector3(side * 1.19, 0, 0), Vector3(0.42, 2.7, 0.1), wall_color)
				_box(window_center + Vector3(side * 1.03, 0, 0), Vector3(1.98, 0.64, 0.1), wall_color)
				_box(window_center + Vector3(side * 0.935, 0, 0), Vector3(0.11, 1.5, 0.12), frame)
				_box(window_center + Vector3(side * 0.655, 0, 0), Vector3(1.9, 0.11, 0.12), frame)
	elif panel_type == "armored":
		if face in ["+x", "-x"]:
			for z in [-0.82, 0.82]:
				_box(center + offset * 0.96 + Vector3(0, 1.35, z), Vector3(0.1, 2.5, 0.09), Color("718087"))
		else:
			for x in [-0.82, 0.82]:
				_box(center + offset * 0.96 + Vector3(x, 1.35, 0), Vector3(0.09, 2.5, 0.1), Color("718087"))
	else:
		_box(center + offset * 0.96 + Vector3(0, 1.9, 0), Vector3(0.025, 0.025, 2.4) if face in ["+x", "-x"] else Vector3(2.4, 0.025, 0.025), Color("55c6d0"), false, true)


func _face_for_axis(axis: Vector3i) -> String:
	if axis.x > 0: return "+x"
	if axis.x < 0: return "-x"
	if axis.y > 0: return "+y"
	if axis.y < 0: return "-y"
	if axis.z > 0: return "+z"
	return "-z"

func _equipment(center: Vector3, kind: String, room_type: String) -> void:
	match kind:
		"cockpit":
			cockpit_position = center + Vector3(0, 0.2, 0.2)
			_box(center + Vector3(0, 0.78, -0.86), Vector3(2.1, 0.28, 0.6), Color("172a35"), true)
			for x in [-0.65, 0.0, 0.65]:
				var screen := _box(center + Vector3(x, 1.0, -0.94), Vector3(0.5, 0.32, 0.04), Color("39818c"), false, true)
				screen.rotation.x = -0.3
			_box(center + Vector3(0, 0.35, 0.85), Vector3(0.6, 0.55, 0.6), Color("385263"), true)
		"habitat":
			if room_type != "quarters": return
			_box(center + Vector3(-0.98, 0.32, 0), Vector3(0.65, 0.55, 2.1), Color("374c5a"), true)
			_box(center + Vector3(-0.98, 0.63, 0), Vector3(0.6, 0.13, 1.9), Color("80929b"))
			_box(center + Vector3(1.07, 0.8, 0.9), Vector3(0.4, 1.6, 0.5), Color("4b606a"), true)
		"cargo":
			if room_type != "cargo": return
			for z in [-0.75, 0.75]:
				_box(center + Vector3(-0.95, 0.5, z), Vector3(0.65, 1.0, 0.6), Color("807052"), true)
				_box(center + Vector3(-0.95, 0.75, z - 0.31), Vector3(0.4, 0.04, 0.02), Color("e3bb75"), false, true)
		"reactor", "engine", "shield":
			_box(center + Vector3(0.99, 1.1, 0), Vector3(0.48, 2.2, 1.4), Color("2e4553"), true)
			for y in [0.5, 1.0, 1.5]:
				_box(center + Vector3(0.72, y, 0), Vector3(0.03, 0.17, 0.85), Color("58becd"), false, true)
		"weapon":
			_box(center + Vector3(-1.0, 1.0, 0), Vector3(0.5, 2.0, 1.2), Color("4c4850"), true)


func _room_furnishing(center: Vector3, room_type: String) -> void:
	match room_type:
		"lounge":
			for z in [-0.75, 0.75]:
				_box(center + Vector3(-0.88, 0.38, z), Vector3(0.48, 0.72, 0.94), Color("46535a"), true)
				_box(center + Vector3(-0.88, 0.77, z), Vector3(0.47, 0.12, 0.9), Color("74827e"))
			_box(center + Vector3(0.38, 0.42, 0), Vector3(0.85, 0.12, 1.2), Color("384951"), true)
		"medical":
			_box(center + Vector3(-0.82, 0.46, 0), Vector3(0.74, 0.16, 1.85), Color("9aa5a0"), true)
			_box(center + Vector3(-0.82, 0.56, 0), Vector3(0.68, 0.08, 1.32), Color("607b7c"))
			_box(center + Vector3(0.92, 0.95, -0.78), Vector3(0.48, 1.9, 0.44), Color("42565d"), true)
			_box(center + Vector3(0.66, 1.72, -0.78), Vector3(0.12, 0.18, 0.035), Color("93d5d5"), false, true)
		"workshop":
			_box(center + Vector3(-0.82, 0.72, 0), Vector3(0.7, 0.16, 1.9), Color("52616a"), true)
			_box(center + Vector3(-0.82, 1.23, 0), Vector3(0.62, 0.82, 0.16), Color("36474e"), true)
			for z in [-0.55, 0.0, 0.55]:
				_box(center + Vector3(-0.48, 0.84, z), Vector3(0.03, 0.05, 0.18), Color("c4a16c"))
		"bridge":
			_box(center + Vector3(0.0, 0.38, 0.77), Vector3(0.58, 0.72, 0.58), Color("344953"), true)
			_box(center + Vector3(0.0, 0.76, 0.7), Vector3(0.66, 0.12, 0.42), Color("819398"))
		"engineering":
			_box(center + Vector3(1.0, 0.78, 0.82), Vector3(0.44, 1.52, 0.42), Color("354951"), true)
			for y in [0.4, 0.8, 1.2]:
				_box(center + Vector3(0.77, y, 0.59), Vector3(0.025, 0.11, 0.28), Color("69b9ba"), false, true)

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
	if emissive or color.a < 1.0:
		if color.a < 1.0 and not emissive:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.metallic = 0.25
			material.roughness = 0.2
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
