class_name ShipVisual
extends Node3D

const CELL_SIZE: float = 2.8

var _engines: Array[MeshInstance3D] = []
var _engine_glow: Array[StandardMaterial3D] = []


func build(modules: Array, faction: String = "player", layout: Dictionary = {}) -> void:
	for child in get_children():
		child.queue_free()
	_engines.clear()
	_engine_glow.clear()
	var active_layout: Dictionary = layout if ShipLayout.validate_data(layout, modules) else ShipLayout.empty_data()
	var accent := Color("46e5da") if faction in ["player", "player_fleet"] else (Color("ff6b58") if faction == "pirate" else Color("65aaff"))
	var hull_mat := _material(Color("26394c"), 0.5, 0.0)
	var plate_mat := _material(Color("64788a"), 0.42, 0.0)
	var inset_mat := _material(Color("34495c"), 0.62, 0.0)
	var dark_mat := _material(Color("111e2b"), 0.8, 0.0)
	var accent_mat := _material(accent, 0.28, 0.85)
	var warm_mat := _material(Color("ffbd74"), 0.25, 2.5)
	var canopy_mat := _material(Color("168195"), 0.12, 0.15)
	var glass_trim := _material(Color("9ceeff"), 0.18, 0.7)
	var armor_panel := _material(Color("86949c"), 0.38, 0.0)
	var panel_glass := _material(Color(0.06, 0.23, 0.3, 0.8), 0.14, 0.0)
	var radiator_body := _material(Color("202b34"), 0.72, 0.0)
	var radiator_fin := _material(Color("53616a"), 0.58, 0.0)
	var radiator_channel := _material(Color("303d45"), 0.48, 0.0)
	var cells: Array[Vector3i] = []
	var kinds: Dictionary = {}
	for item in modules:
		var cell := Vector3i.ZERO
		var kind := "hull"
		if item is Dictionary:
			var raw: Variant = item.get("cell", item.get("position", Vector3i(int(item.get("x", 0)), int(item.get("y", 0)), int(item.get("z", 0)))))
			if raw is Vector3i:
				cell = raw
			elif raw is Vector3:
				cell = Vector3i(raw)
			kind = str(item.get("kind", "hull"))
		elif item is Vector3i:
			cell = item
		elif item is Vector3:
			cell = Vector3i(item)
		if cell not in cells:
			cells.append(cell)
		kinds[cell] = kind
	if cells.is_empty():
		cells.append(Vector3i.ZERO)
	var low := Vector3i(99999, 99999, 99999)
	var high := Vector3i(-99999, -99999, -99999)
	for cell in cells:
		low = Vector3i(mini(low.x, cell.x), mini(low.y, cell.y), mini(low.z, cell.z))
		high = Vector3i(maxi(high.x, cell.x), maxi(high.y, cell.y), maxi(high.z, cell.z))
	var center := (Vector3(low) + Vector3(high)) * 0.5 * CELL_SIZE
	var bounds := (Vector3(high - low) + Vector3.ONE) * CELL_SIZE
	# Connected pressure modules form the hull; avoid a broad hidden keel that reads as a wing.
	for cell in cells:
		var kind: String = kinds.get(cell, "hull")
		var p: Vector3 = Vector3(cell) * CELL_SIZE - center
		var deck := p + Vector3(0, 1.23, 0)
		_add_bevelled_plate(p, Vector3(2.66, 2.4, 2.66), plate_mat)
		_add_box(p + Vector3(0, -1.24, 0), Vector3(2.48, 0.08, 2.48), dark_mat)
		_add_box(p + Vector3(0, 0, -1.34), Vector3(1.82, 1.42, 0.035), inset_mat)
		_add_box(p + Vector3(0, 0, 1.34), Vector3(1.82, 1.42, 0.035), inset_mat)
		_add_box(p + Vector3(-1.34, 0, 0), Vector3(0.035, 1.42, 1.82), inset_mat)
		_add_box(p + Vector3(1.34, 0, 0), Vector3(0.035, 1.42, 1.82), inset_mat)
		var panel_data: Dictionary = active_layout.panels.get(ShipLayout.cell_key(cell), {})
		for face: String in ShipLayout.FACES:
			if panel_data.has(face):
				_build_hull_panel(p, face, str(panel_data[face]), plate_mat, armor_panel, dark_mat, panel_glass)
		if kind == "radiator":
			for face: String in ShipLayout.exposed_radiator_faces(cell, kinds, panel_data):
				_build_radiator_face(p, face, radiator_body, radiator_fin, radiator_channel)
		var coordinate := cell
		for neighbor: Vector3i in [coordinate + Vector3i.RIGHT, coordinate + Vector3i.UP, coordinate + Vector3i(0, 0, 1)]:
			if not cells.has(neighbor):
				continue
			var bridge_center := p + Vector3(neighbor - coordinate) * CELL_SIZE * 0.5
			if neighbor.x != coordinate.x:
				_add_box(bridge_center, Vector3(0.3, 2.2, 2.45), hull_mat)
			elif neighbor.y != coordinate.y:
				# Pressure collar closes the cell seam; exposed struts read as scaffolding.
				_add_bevelled_plate(bridge_center, Vector3(2.48, 0.46, 2.48), hull_mat)
			else:
				_add_box(bridge_center, Vector3(2.45, 2.2, 0.3), hull_mat)
		match kind:
			"cockpit":
				# Forward glazing belongs on the bow face, not as a rooftop console.
				_add_box(p + Vector3(0, 0.45, -1.345), Vector3(1.42, 0.66, 0.045), dark_mat, Vector3(-0.16, 0, 0))
				_add_box(p + Vector3(0, 0.45, -1.375), Vector3(1.22, 0.48, 0.03), canopy_mat, Vector3(-0.16, 0, 0))
				_add_box(p + Vector3(0, 0.81, -1.34), Vector3(1.62, 0.06, 0.09), plate_mat)
				_add_box(p + Vector3(-0.72, 0.44, -1.37), Vector3(0.06, 0.62, 0.08), plate_mat, Vector3(-0.16, 0, 0))
				_add_box(p + Vector3(0.72, 0.44, -1.37), Vector3(0.06, 0.62, 0.08), plate_mat, Vector3(-0.16, 0, 0))
				_add_box(p + Vector3(0, 0.44, -1.4), Vector3(0.035, 0.46, 0.04), glass_trim, Vector3(-0.16, 0, 0))
			"engine":
				for side in [-1, 1]:
					_add_box(deck + Vector3(float(side) * 0.72, -0.12, 0.18), Vector3(0.62, 0.26, 1.7), hull_mat, Vector3(-0.05, 0, 0))
					var mount := _add_cylinder(deck + Vector3(float(side) * 0.72, -0.3, 0.98), 0.43, 0.76, dark_mat)
					mount.rotation.x = PI * 0.5
					var nozzle := _add_cylinder(deck + Vector3(float(side) * 0.72, -0.3, 1.04), 0.3, 0.1, plate_mat)
					nozzle.rotation.x = PI * 0.5
					var core := _add_cylinder(deck + Vector3(float(side) * 0.72, -0.3, 1.1), 0.2, 0.045, warm_mat)
					core.rotation.x = PI * 0.5
					var ring := _add_torus(deck + Vector3(float(side) * 0.72, -0.3, 1.09), 0.23, 0.29, accent_mat)
					ring.rotation.x = PI * 0.5
					_engines.append(core)
					_engine_glow.append(warm_mat)
			"reactor":
				_add_cylinder(deck + Vector3(0, 0.08, 0), 0.56, 0.12, dark_mat)
				_add_torus(deck + Vector3(0, 0.15, 0), 0.43, 0.5, plate_mat)
				_add_torus(deck + Vector3(0, 0.18, 0), 0.25, 0.29, accent_mat)
				_add_sphere(deck + Vector3(0, 0.15, 0), 0.12, warm_mat)
			"cargo":
				_add_box(deck + Vector3(0, 0.06, 0), Vector3(1.8, 0.08, 1.8), dark_mat)
				for side in [-1, 1]:
					_add_box(deck + Vector3(float(side) * 0.91, 0.08, 0), Vector3(0.075, 0.12, 1.7), plate_mat)
					_add_box(deck + Vector3(float(side) * 0.91, 0.09, 0), Vector3(0.035, 0.025, 1.2), accent_mat)
			"weapon":
				_add_box(deck + Vector3(0, 0.09, -0.2), Vector3(0.52, 0.16, 1.9), hull_mat, Vector3(-0.06, 0, 0))
				for side in [-1, 1]:
					_add_cylinder(deck + Vector3(float(side) * 0.4, 0.17, -0.7), 0.09, 1.4, plate_mat)
					_add_cylinder(deck + Vector3(float(side) * 0.4, 0.17, -1.39), 0.05, 0.04, warm_mat)
			"shield":
				_add_cylinder(deck + Vector3(0, 0.08, 0), 0.58, 0.12, dark_mat)
				_add_torus(deck + Vector3(0, 0.15, 0), 0.26, 0.34, accent_mat)
				for side in [-1, 1]:
					_add_box(deck + Vector3(float(side) * 0.7, 0.12, 0), Vector3(0.09, 0.2, 0.32), plate_mat)
			"habitat":
				_add_cylinder(deck + Vector3(0, 0.04, 0), 0.7, 0.12, dark_mat)
				_add_torus(deck + Vector3(0, 0.14, 0), 0.25, 0.32, accent_mat)
				_add_box(deck + Vector3(0, 0.12, 0), Vector3(1.05, 0.1, 0.045), canopy_mat)
			"radiator":
				pass
			_:
				for side in [-1, 1]:
					_add_box(deck + Vector3(float(side) * 0.82, 0.0, -0.1), Vector3(0.035, 0.025, 1.55), accent_mat)
	# Mark the bow and stern independently of module layout.
	_add_box(Vector3(-0.52, 0.05, -bounds.z * 0.49), Vector3(0.065, 0.04, 0.13), warm_mat)
	_add_box(Vector3(0.52, 0.05, -bounds.z * 0.49), Vector3(0.065, 0.04, 0.13), warm_mat)
	_add_box(Vector3(0, -0.12, bounds.z * 0.49), Vector3(bounds.x * 0.34, 0.09, 0.12), dark_mat)


func _build_hull_panel(center: Vector3, face: String, panel_type: String, standard: Material, armor: Material, dark: Material, glass: Material) -> void:
	var normal: Vector3 = Vector3(ShipLayout.FACE_STEPS[face])
	var horizontal_size := 2.32
	var vertical_size := 1.42
	var position := center + normal * (1.36 if face in ["+x", "-x", "+z", "-z"] else 1.23)
	var size: Vector3
	if face in ["+x", "-x"]:
		size = Vector3(0.045, vertical_size, horizontal_size)
	elif face in ["+y", "-y"]:
		size = Vector3(horizontal_size, 0.045, horizontal_size)
	else:
		size = Vector3(horizontal_size, vertical_size, 0.045)
	if panel_type == "armored":
		_add_box(position, size, armor)
		if face in ["+x", "-x"]:
			for z in [-0.68, 0.0, 0.68]:
				_add_box(position + Vector3(0, 0, z), Vector3(0.055, 1.22, 0.07), dark)
		elif face in ["+y", "-y"]:
			for x in [-0.68, 0.0, 0.68]:
				_add_box(position + Vector3(x, 0, 0), Vector3(0.07, 0.055, 1.22), dark)
		else:
			for x in [-0.68, 0.0, 0.68]:
				_add_box(position + Vector3(x, 0, 0), Vector3(0.07, 1.22, 0.055), dark)
	elif panel_type == "window":
		_add_box(position, size, dark)
		var pane_size := size
		if face in ["+x", "-x"]:
			pane_size = Vector3(0.025, 1.08, 1.84)
		elif face in ["+y", "-y"]:
			pane_size = Vector3(1.84, 0.025, 1.84)
		else:
			pane_size = Vector3(1.84, 1.08, 0.025)
		_add_box(position + normal * 0.025, pane_size, glass)
		if face in ["+x", "-x"]:
			_add_box(position + Vector3(0, 0, -0.98), Vector3(0.07, 1.2, 0.07), standard)
			_add_box(position + Vector3(0, 0, 0.98), Vector3(0.07, 1.2, 0.07), standard)
		elif face in ["+y", "-y"]:
			_add_box(position + Vector3(-0.98, 0, 0), Vector3(0.07, 0.055, 1.95), standard)
			_add_box(position + Vector3(0.98, 0, 0), Vector3(0.07, 0.055, 1.95), standard)
		else:
			_add_box(position + Vector3(-0.98, 0, 0), Vector3(0.07, 1.2, 0.07), standard)
			_add_box(position + Vector3(0.98, 0, 0), Vector3(0.07, 1.2, 0.07), standard)


func _build_radiator_face(center: Vector3, face: String, body: Material, fin: Material, channel: Material) -> void:
	var normal: Vector3 = Vector3(ShipLayout.FACE_STEPS[face])
	var u: Vector3
	var v: Vector3
	var face_depth := 1.32
	if face in ["+x", "-x"]:
		u = Vector3(0, 0, 1)
		v = Vector3(0, 1, 0)
	elif face in ["+y", "-y"]:
		u = Vector3(1, 0, 0)
		v = Vector3(0, 0, 1)
		face_depth = 1.19
	else:
		u = Vector3(1, 0, 0)
		v = Vector3(0, 1, 0)
	var face_center := center + normal * face_depth
	var panel_size := Vector3(2.28, 1.78, 0.055)
	if face in ["+x", "-x"]:
		panel_size = Vector3(0.055, 1.78, 2.28)
	elif face in ["+y", "-y"]:
		panel_size = Vector3(2.28, 0.055, 2.28)
	_add_box(face_center, panel_size, body)
	# Seven close-spaced cooling vanes sit inside a restrained structural frame.
	for index in range(7):
		var across := (float(index) - 3.0) * 0.29
		var rib_size := _face_box_size(u, v, normal, 0.055, 1.46, 0.035)
		_add_box(face_center + u * across + normal * 0.046, rib_size, fin)
	for across in [-1.08, 1.08]:
		_add_box(face_center + u * across + normal * 0.042, _face_box_size(u, v, normal, 0.065, 1.7, 0.055), channel)
	for along in [-0.81, 0.81]:
		_add_box(face_center + v * along + normal * 0.042, _face_box_size(u, v, normal, 2.22, 0.055, 0.055), channel)
	# Narrow cross manifolds read as serviceable coolant runs, not luminous trim.
	for along in [-0.5, 0.5]:
		_add_box(face_center + v * along + normal * 0.035, _face_box_size(u, v, normal, 1.92, 0.035, 0.025), body)


func _face_box_size(u: Vector3, v: Vector3, normal: Vector3, width: float, height: float, depth: float) -> Vector3:
	return Vector3(absf(u.x) * width + absf(v.x) * height + absf(normal.x) * depth,
		absf(u.y) * width + absf(v.y) * height + absf(normal.y) * depth,
		absf(u.z) * width + absf(v.z) * height + absf(normal.z) * depth)


func set_thrust(amount: float) -> void:
	var level := clampf(amount, 0.0, 1.0)
	for index in range(_engines.size()):
		_engine_glow[index].emission_energy_multiplier = 0.45 + level * 3.0
		_engines[index].scale = Vector3(1.0, 1.0 + level * 0.35, 1.0)


func _add_bevelled_plate(pos: Vector3, size: Vector3, material: Material) -> void:
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5
	var bevel := minf(minf(size.x, size.z) * 0.1, size.y * 0.32)
	var half_y := size.y * 0.5
	var rings: Array[PackedVector3Array] = [
		_octagon(half_x - bevel, half_z - bevel, bevel * 0.4, -half_y),
		_octagon(half_x, half_z, bevel, -half_y + bevel),
		_octagon(half_x, half_z, bevel, half_y - bevel),
		_octagon(half_x - bevel, half_z - bevel, bevel * 0.4, half_y),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(rings.size() - 1):
		for edge in range(8):
			var next := (edge + 1) % 8
			_add_triangle(st, rings[layer][edge], rings[layer + 1][edge], rings[layer + 1][next])
			_add_triangle(st, rings[layer][edge], rings[layer + 1][next], rings[layer][next])
	var top_center := Vector3(0, half_y, 0)
	var bottom_center := Vector3(0, -half_y, 0)
	for edge in range(8):
		var next := (edge + 1) % 8
		_add_triangle(st, top_center, rings[3][next], rings[3][edge])
		_add_triangle(st, bottom_center, rings[0][edge], rings[0][next])
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = material
	add_child(mesh)
	mesh.position = pos


func _octagon(half_x: float, half_z: float, corner: float, y: float) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-half_x + corner, y, -half_z), Vector3(half_x - corner, y, -half_z),
		Vector3(half_x, y, -half_z + corner), Vector3(half_x, y, half_z - corner),
		Vector3(half_x - corner, y, half_z), Vector3(-half_x + corner, y, half_z),
		Vector3(-half_x, y, half_z - corner), Vector3(-half_x, y, -half_z + corner),
	])


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


func _add_box(pos: Vector3, size: Vector3, material: Material, angles: Vector3 = Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	add_child(mesh)
	mesh.position = pos
	mesh.rotation = angles


func _add_cylinder(pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius * 0.82
	cylinder.height = height
	cylinder.radial_segments = 12
	mesh.mesh = cylinder
	mesh.material_override = material
	add_child(mesh)
	mesh.position = pos
	return mesh


func _add_sphere(pos: Vector3, radius: float, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.material_override = material
	add_child(mesh)
	mesh.position = pos


func _add_torus(pos: Vector3, inner_radius: float, outer_radius: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner_radius
	torus.outer_radius = outer_radius
	torus.rings = 20
	torus.ring_segments = 8
	mesh.mesh = torus
	mesh.material_override = material
	add_child(mesh)
	mesh.position = pos
	return mesh


func _material(color: Color, roughness: float, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.62
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material
