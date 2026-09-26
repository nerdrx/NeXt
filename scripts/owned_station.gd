class_name OwnedStation
extends Node3D

var dock_position := Vector3(0, 0, 70)
var stand_position := Vector3(18, 0.15, 70)
var launch_position := Vector3(0, 22, 108)

func build(station: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var hull := _material(Color("34414c"), 0.7)
	var trim := _material(Color("a2a9ab"), 0.55)
	var dark := _material(Color("141d25"), 0.3)
	var light := _material(Color("61e3d8"), 0.0, 3.0)
	var amber := _material(Color("ffb65c"), 0.0, 2.0)
	var blue := _material(Color("1e3a50"), 0.7)
	var level: int = clampi(int(station.get("level", 1)), 1, 100)
	# Exterior detail is bounded while industrial volume grows with station level.
	var bays: int = mini(8, 2 + level / 3)
	_box(Vector3(0, -9, -10), Vector3(24, 20, 145), hull, true)
	for bay in bays:
		var z: float = 10 - bay * 18
		for side in [-1, 1]:
			_box(Vector3(side * 37, -7, z), Vector3(70, 5, 6), dark, true)
			_box(Vector3(side * 52, -3, z), Vector3(27, 14, 15), hull, true)
			_box(Vector3(side * 52, 4.1, z), Vector3(23, 0.3, 12), trim)
			for pane in 5:
				_box(Vector3(side * 52 - 9 + pane * 4.5, 0, z + 7.6), Vector3(2.5, 1.2, 0.15), light)
			_box(Vector3(side * 89, -7, z), Vector3(37, 0.7, 14), blue)
			for rib in 7:
				_box(Vector3(side * 89 - 15 + rib * 5, -6.5, z), Vector3(0.25, 0.3, 14), trim)
	_box(Vector3(0, 12, -32), Vector3(17, 28, 20), hull, true)
	_box(Vector3(0, 27, -32), Vector3(23, 4, 26), trim, true)
	_box(Vector3(0, 25, -18.8), Vector3(17, 2, 0.3), light)
	_box(Vector3(0, 42, -32), Vector3(0.5, 25, 0.5), trim)
	_box(Vector3(0, 55, -32), Vector3(1, 1, 1), amber)
	# Solid landing apron, open flight path to +Z and a sheltered service gallery.
	_box(Vector3(0, -1, 68), Vector3(76, 2, 80), hull, true)
	_box(Vector3(0, 0.025, 70), Vector3(38, 0.05, 38), dark)
	for side in [-1, 1]:
		_box(Vector3(side * 20, 0.09, 70), Vector3(0.35, 0.08, 40), light)
		_box(Vector3(0, 0.09, 70 + side * 20), Vector3(40, 0.08, 0.35), light)
		_box(Vector3(side * 37, 1.5, 62), Vector3(0.6, 3, 61), trim, true)
		for lamp in 9:
			_box(Vector3(side * 34, 0.2, 34 + lamp * 8), Vector3(1.2, 0.15, 2.2), amber)
		_box(Vector3(side * 31, 5, 27), Vector3(1.5, 10, 1.5), trim, true)
	_box(Vector3(0, 10, 27), Vector3(64, 1.4, 16), hull, true)
	_box(Vector3(0, 0, 29), Vector3(74, 1, 10), hull, true)
	_box(Vector3(25, 1, 30), Vector3(4, 2, 2), dark, true)
	_box(Vector3(25, 2.1, 30), Vector3(3.5, 0.2, 1.7), light)
	var title := Label3D.new()
	title.text = "%s\nDOCK 01  /  LEVEL %d" % [str(station.get("name", "Outpost")).to_upper(), level]
	title.position = Vector3(0, 7, 36)
	title.font_size = 64
	title.pixel_size = 0.035
	title.modulate = Color("c4eae7")
	add_child(title)
	var service := Label3D.new()
	service.text = "STATION SERVICES\nTAB / COMMAND DECK"
	service.position = Vector3(25, 4, 31)
	service.font_size = 40
	service.pixel_size = 0.025
	add_child(service)
	for side in [-1, 1]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(side * 25, 7, 60)
		lamp.light_color = Color("b4e5e4")
		lamp.light_energy = 4
		lamp.omni_range = 55
		add_child(lamp)

func _material(color: Color, metallic: float, glow: float = 0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = 0.45
	if glow > 0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = glow
	return result

func _box(at: Vector3, size: Vector3, material: Material, solid: bool = false) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = at
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.add_child(collision)
		add_child(body)
