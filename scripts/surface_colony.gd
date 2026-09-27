class_name SurfaceColony
extends Node3D

# Local +Y is planetary up. The caller mounts this deck 14 m above base radius.
var landing_position := Vector3.ZERO
var stand_position := Vector3(12, 1, 0)
var service_position := Vector3(17, 0, -19)
var footprint: float = 1.0
var _navigation := PortNavigation.new()
var door_positions: Array[Vector3] = []
var interior_positions: Array[Vector3] = []
var interior_services: Array[Dictionary] = []

func build(radius: float, colony_seed: int, colony_name: String) -> void:
	_navigation.dispose()
	_navigation = PortNavigation.new()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	door_positions.clear()
	interior_positions.clear()
	interior_services.clear()
	footprint = clampf(radius / 500.0, 0.72, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = colony_seed
	var hull := _material(Color("424d54"), 0.65)
	var trim := _material(Color("a5a69d"), 0.5)
	var dark := _material(Color("1c252b"), 0.45)
	var cyan := _material(Color("88d4d7"), 0.2, 2.0)
	var amber := _material(Color("e6a364"), 0.1, 2.0)
	var deck := ShaderMaterial.new()
	deck.shader = preload("res://shaders/deck_plating.gdshader")
	# Pad remains full size for ships; only the surrounding settlement contracts.
	_box(Vector3(0, -0.6, 0), Vector3(44, 1.2, 44), deck, true)
	_box(Vector3(0, -0.6, -34), Vector3(16, 1.2, 26), deck, true)
	_box(Vector3(0, -0.6, -42), Vector3(72 * footprint, 1.2, 12), deck, true)
	for side in [-1, 1]:
		_box(Vector3(side * 20, 0.025, 0), Vector3(0.22, 0.05, 39), amber)
		_box(Vector3(0, 0.025, side * 20), Vector3(40, 0.05, 0.22), amber)
		for z in [-16, -8, 0, 8, 16]:
			_box(Vector3(side * 21, 0.08, z), Vector3(0.3, 0.15, 1.2), cyan)
		for row in 2:
			var x: float = side * (18 + row * 10) * footprint
			var z: float = -29.0 - row * 24.0 * footprint
			var height: float = rng.randf_range(8, 14)
			var services := ["market", "company", "shipyard", "contracts"]
			var index := row * 2 + (1 if side > 0 else 0)
			_building(Vector3(x, 0, z), Vector3(13, height, 14), hull, trim, dark, cyan, services[index])
			_box(Vector3(x / 2, -0.025, z + 8.6), Vector3(absf(x) + 3.2, 0.05, 3.2), dark, true)
			_support(Vector3(x, -0.6, z), radius, dark)
		if side < 0:
			_box(Vector3(0, -0.025, -20.4 - 12 * footprint), Vector3(3, 0.05, 24 * footprint + 3.2), dark, true)
		_support(Vector3(side * 18, -0.6, 17), radius, dark)
		_support(Vector3(side * 18, -0.6, -17), radius, dark)
		# Ramps penetrate the base sphere; terrain naturally meets them partway down.
		var start := Vector3(side * 15, 0, 22)
		var end := Vector3(side * 15, 0, 62 * footprint)
		end.y = sqrt(maxf(0, radius * radius - end.x * end.x - end.z * end.z)) - radius - 16
		_ramp(start, end, deck)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(side * 17, 5, -17)
		lamp.light_color = Color("c9e3e0")
		lamp.light_energy = 3.5
		lamp.omni_range = 24
		add_child(lamp)
		_box(Vector3(side * 21, 3, -20), Vector3(0.3, 6, 0.3), trim, true)
		_box(Vector3(side * 20, 6, -20), Vector3(2.5, 0.25, 0.6), cyan)
	# Service point sits outside the clear ship footprint, reachable directly from pad.
	_box(service_position + Vector3(0, 0.8, 0), Vector3(2, 1.6, 1), dark, true)
	_box(service_position + Vector3(0, 1.7, 0), Vector3(1.8, 0.18, 0.9), cyan)
	_label("PORT SERVICES\nE / ACCESS TERMINAL", service_position + Vector3(0, 3, 0.6), 0.012)
	_label(colony_name.to_upper() + "\nSURFACE PORT 01", Vector3(0, 6, -23), 0.025)
	# Low industrial utility spine, tanks and mast provide a distinct skyline.
	_box(Vector3(0, 2, -68 * footprint), Vector3(8, 4, 12), dark, true)
	for x in [-3, 3]:
		var tank := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 2
		cylinder.bottom_radius = 2
		cylinder.height = 7
		tank.mesh = cylinder
		tank.material_override = trim
		tank.position = Vector3(x, 7.5, -68 * footprint)
		add_child(tank)
	_box(Vector3(0, 15, -68 * footprint), Vector3(0.35, 22, 0.35), trim)
	_box(Vector3(0, 26, -68 * footprint), Vector3(0.7, 0.7, 0.7), amber)

func _building(at: Vector3, size: Vector3, hull: Material, trim: Material, dark: Material, light: Material, page: String) -> void:
	# Walkable room: floor top at y=0, ceiling at 4, and a 3.2 x 3.5 m front opening.
	_box(at + Vector3(0, -0.15, 0), Vector3(size.x, 0.3, size.z), dark, true)
	_box(at + Vector3(0, 2, -size.z / 2 + 0.15), Vector3(size.x, 4, 0.3), hull, true)
	_box(at + Vector3(-size.x / 2 + 0.15, 2, 0), Vector3(0.3, 4, size.z), hull, true)
	_box(at + Vector3(size.x / 2 - 0.15, 2, 0), Vector3(0.3, 4, size.z), hull, true)
	var wall_width := (size.x - 3.2) / 2
	_box(at + Vector3(-1.6 - wall_width / 2, 2, size.z / 2 - 0.15), Vector3(wall_width, 4, 0.3), hull, true)
	_box(at + Vector3(1.6 + wall_width / 2, 2, size.z / 2 - 0.15), Vector3(wall_width, 4, 0.3), hull, true)
	_box(at + Vector3(0, 3.75, size.z / 2 - 0.15), Vector3(3.2, 0.5, 0.3), hull, true)
	_box(at + Vector3(0, 4.15, 0), Vector3(size.x, 0.3, size.z), hull, true)
	# Keep the tall exterior silhouette above the occupied room.
	_box(at + Vector3(0, (size.y + 4.3) / 2, 0), Vector3(size.x, size.y - 4.3, size.z), hull, true)
	_box(at + Vector3(0, size.y + 0.25, 0), Vector3(size.x + 1, 0.5, size.z + 1), trim)
	_box(at + Vector3(0, size.y + 1, 0), Vector3(4, 1.5, 5), dark)
	for x in [-4, 0, 4]:
		_box(at + Vector3(x, size.y - 3, size.z / 2 + 0.04), Vector3(2.2, 0.8, 0.1), light)
	for x in [-size.x / 2 + 0.3, size.x / 2 - 0.3]:
		_box(at + Vector3(x, 2, size.z / 2 + 0.1), Vector3(0.4, 4, 0.4), trim)
	var door := at + Vector3(0, 0, size.z / 2 + 1.6)
	var interior := at
	door_positions.append(door)
	interior_positions.append(interior)
	var labels := {"market": "TRADE", "company": "CREW", "shipyard": "SHIP SERVICES", "contracts": "CONTRACTS"}
	var label: String = labels[page]
	interior_services.append({"position": interior + Vector3(0, 0, -1.5), "page": page, "label": label})
	_box(interior + Vector3(0, 0.5, -2.7), Vector3(4.2, 1, 0.8), trim, true)
	for x in [-2.2, 2.2]:
		_box(interior + Vector3(x, 0.55, 1.8), Vector3(0.8, 1.1, 0.8), dark, true)
	_box(interior + Vector3(0, 1.65, -5.9), Vector3(3.2, 3.3, 0.12), dark)
	_label(label, interior + Vector3(0, 2, -5.8), 0.006)
	var lamp := OmniLight3D.new()
	lamp.position = interior + Vector3(0, 3.2, 0)
	lamp.light_color = Color("c9e3e0")
	lamp.light_energy = 1.2
	lamp.omni_range = 10
	add_child(lamp)

func _support(at: Vector3, radius: float, material: Material) -> void:
	var bottom := sqrt(maxf(0, radius * radius - at.x * at.x - at.z * at.z)) - radius - 18
	_box(Vector3(at.x, (at.y + bottom) / 2, at.z), Vector3(2, at.y - bottom, 2), material, true)

func _ramp(start: Vector3, end: Vector3, material: Material) -> void:
	var incline := atan2(start.y - end.y, end.z - start.z)
	var orientation := Basis(Vector3.RIGHT, incline)
	_box((start + end) / 2 - orientation.y * 0.3, Vector3(7, 0.6, start.distance_to(end)), material, true, orientation)

func _material(color: Color, metallic: float, glow: float = 0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.65
	if glow > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

func _label(text: String, at: Vector3, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 48
	label.pixel_size = pixel_size
	label.modulate = Color("c4dbd7")
	add_child(label)

func _box(at: Vector3, size: Vector3, material: Material, solid: bool = false, orientation: Basis = Basis.IDENTITY) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.transform = Transform3D(orientation, at)
	add_child(mesh)
	if solid:
		_navigation.add_box(shape, mesh.transform)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.transform = mesh.transform
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.add_child(collision)
		add_child(body)

func navigation_path(from_world: Vector3, to_world: Vector3) -> PackedVector3Array:
	var local_path := _navigation.path(to_local(from_world), to_local(to_world))
	var result := PackedVector3Array()
	for point in local_path:
		result.append(to_global(point))
	return result

func _exit_tree() -> void:
	_navigation.dispose()
