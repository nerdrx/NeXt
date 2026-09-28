class_name ShipVisual
extends Node3D

const CELL_SIZE: float = ShipBlueprint.CELL_SIZE

var _systems_online := true
var _thrust := 0.0

var _engines: Array[MeshInstance3D] = []
var _engine_glow: Array[StandardMaterial3D] = []


func build(modules: Array, faction: String = "player", layout: Dictionary = {}) -> void:
	for child in get_children():
		child.queue_free()
	_engines.clear()
	_engine_glow.clear()
	var active_layout: Dictionary = layout if ShipLayout.validate_data(layout, modules) else ShipLayout.empty_data()
	var accent := Color("46e5da") if faction in ["player", "player_fleet"] else (Color("ff6b58") if faction == "pirate" else Color("65aaff"))
	var hull_mat := _surface_material(Color("26394c"), 0.46, 0.03)
	var plate_mat := _surface_material(Color("64788a"), 0.34, 0.03)
	var inset_mat := _surface_material(Color("34495c"), 0.55, 0.03)
	var dark_mat := _material(Color("111e2b"), 0.8, 0.0)
	var accent_mat := _material(accent.darkened(0.3), 0.52, 0.0)
	var warm_mat := _material(Color("ffbd74"), 0.25, 2.5)
	# Exhaust must not share emission state with navigation lights or weapon fittings.
	var exhaust_mat := _material(Color("ffbd74"), 0.25, 0.45)
	var canopy_mat := _material(Color("12252c"), 0.16, 0.0)
	var glass_trim := _surface_material(Color("758189"), 0.27, 0.85)
	var armor_panel := _surface_material(Color("86949c"), 0.4, 0.03)
	var panel_glass := _material(Color(0.06, 0.23, 0.3, 0.8), 0.14, 0.0)
	var radiator_body := _surface_material(Color("202b34"), 0.65, 0.12)
	var radiator_fin := _surface_material(Color("53616a"), 0.32, 0.85)
	var radiator_channel := _surface_material(Color("303d45"), 0.44, 0.7)
	var nozzle_metal := _surface_material(Color("626b72"), 0.31, 0.85)
	var nozzle_lining := _surface_material(Color("29282a"), 0.66, 0.45)
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
	var center := ShipBlueprint.center(cells)
	var bounds := (Vector3(high - low) + Vector3.ONE) * CELL_SIZE
	var hull_family := ShipBlueprint.family_for_cells(cells)
	var outline := ShipBlueprint.pressure_outline(cells)
	var joined_hull := not outline.is_empty()
	var hull_faces := PackedVector3Array()
	if joined_hull:
		var shell := MeshInstance3D.new()
		shell.name = "FamilyPressureHull"
		shell.mesh = ShipBlueprint.outer_hull(cells)
		hull_faces = shell.mesh.get_faces()
		var paint := ShaderMaterial.new()
		paint.shader = preload("res://shaders/fleet_surface.gdshader")
		var family_id := ShipBlueprint.family_for_cells(cells)
		paint.set_shader_parameter("paint", {"pathfinder": Color("4d5960"), "merchant": Color("645e51"), "ranger": Color("697077")}.get(family_id, Color("4d5960")))
		paint.set_shader_parameter("base_roughness",0.38)
		paint.set_shader_parameter("metalness",0.04)
		paint.set_shader_parameter("coating",0.22)
		paint.set_shader_parameter("panel_strength",1.0)
		paint.set_shader_parameter("industrial_detail",1.0)
		paint.set_shader_parameter("panel_origin",center)
		paint.set_shader_parameter("livery_strength", 1.0)
		paint.set_shader_parameter("hull_extent", bounds)
		paint.set_shader_parameter("livery_paint", {"pathfinder": Color("89958f"), "merchant": Color("957946"), "ranger": Color("9b5b38")}.get(family_id, Color("89958f")))
		shell.material_override = paint
		add_child(shell)
	var exhaust_columns: Dictionary = {}
	# Connected pressure modules form the hull; avoid a broad hidden keel that reads as a wing.
	for cell in cells:
		var kind: String = kinds.get(cell, "hull")
		var p: Vector3 = Vector3(cell) * CELL_SIZE - center
		var deck := p + Vector3.UP * (ShipBlueprint.PRESSURE_SIZE.y * 0.5 + 0.035)
		if not joined_hull: _add_bevelled_plate(p, ShipBlueprint.PRESSURE_SIZE, plate_mat, 0.03)
		# Only exposed faces receive inset service panels; shared cell faces are internal.
		for face: String in ShipLayout.FACES:
			var normal := Vector3(ShipLayout.FACE_STEPS[face])
			if joined_hull or cells.has(cell + ShipLayout.FACE_STEPS[face]): continue
			var size := Vector3(1.82, 1.42, 0.035)
			if normal.x != 0: size = Vector3(0.035, 1.42, 1.82)
			elif normal.y != 0: continue
			_add_box(p + normal * _surface_depth(normal, 0.012), size, inset_mat)
		var panel_data: Dictionary = active_layout.panels.get(ShipLayout.cell_key(cell), {})
		for face: String in ShipLayout.FACES:
			if panel_data.has(face):
				var first_fitting := get_child_count()
				_build_hull_panel(p, face, str(panel_data[face]), plate_mat, armor_panel, dark_mat, panel_glass)
				if joined_hull: _fit_surface_fittings(first_fitting, p, face, hull_faces)
		if kind == "radiator":
			for face: String in ShipLayout.exposed_radiator_faces(cell, kinds, panel_data):
				var first_fitting := get_child_count()
				_build_radiator_face(p, face, radiator_body, radiator_fin, radiator_channel)
				if joined_hull: _fit_surface_fittings(first_fitting, p, face, hull_faces)
		# Family shells need a little service structure on their broad exposed flanks.
		# Keep it off authored panels, radiator faces, and cockpit modules.
		if joined_hull and kind != "cockpit":
			var radiator_faces: Array[String] = []
			if kind == "radiator": radiator_faces = ShipLayout.exposed_radiator_faces(cell, kinds, panel_data)
			for face: String in ["+x", "-x"]:
				if cells.has(cell + ShipLayout.FACE_STEPS[face]) or panel_data.has(face) or face in radiator_faces: continue
				var first_fitting := get_child_count()
				var service_center := p + Vector3.UP * 0.35
				_add_flank_service_strip(service_center, face, dark_mat, hull_mat, glass_trim)
				_fit_surface_fittings(first_fitting, service_center, face, hull_faces)
		var coordinate := cell
		for neighbor: Vector3i in [coordinate + Vector3i.RIGHT, coordinate + Vector3i.UP, coordinate + Vector3i(0, 0, 1)]:
			if joined_hull or not cells.has(neighbor):
				continue
			var bridge_center := p + Vector3(neighbor - coordinate) * CELL_SIZE * 0.5
			if neighbor.x != coordinate.x:
				_add_box(bridge_center, Vector3(0.3, 2.2, 2.45), hull_mat)
			elif neighbor.y != coordinate.y:
				# Pressure collar closes the cell seam; exposed struts read as scaffolding.
				_add_bevelled_plate(bridge_center, Vector3(2.48, 0.46, 2.48), hull_mat)
			else:
				_add_box(bridge_center, Vector3(2.45, 2.2, 0.3), hull_mat)
		if kind == "core" and not hull_family.is_empty() and not cells.has(cell + Vector3i.UP):
			_add_stencil(hull_family.to_upper(), deck + Vector3(0, 0.016, -0.45), 0.0038)
			_add_stencil("NX / " + {"pathfinder": "EXPLORATION", "merchant": "FREIGHT", "ranger": "PATROL"}.get(hull_family, "UTILITY"), deck + Vector3(0, 0.017, -0.16), 0.0017)
		match kind:
			"cockpit":
				var first_glazing := get_child_count()
				var glazing_tilt := Vector3.ZERO if joined_hull else Vector3(-0.16, 0, 0)
				# Forward glazing belongs on the bow face, not as a rooftop console.
				_add_box(p + Vector3(0, 0.45, -1.505), Vector3(1.42, 0.66, 0.045), dark_mat, glazing_tilt)
				var glazing := _add_box(p + Vector3(0, 0.45, -1.535), Vector3(1.22, 0.48, 0.03), canopy_mat, glazing_tilt)
				glazing.name = "CockpitGlazing"
				_add_box(p + Vector3(0, 0.81, -1.50), Vector3(1.62, 0.06, 0.09), plate_mat)
				_add_box(p + Vector3(-0.72, 0.44, -1.53), Vector3(0.06, 0.62, 0.08), plate_mat, glazing_tilt)
				_add_box(p + Vector3(0.72, 0.44, -1.53), Vector3(0.06, 0.62, 0.08), plate_mat, glazing_tilt)
				_add_box(p + Vector3(0, 0.44, -1.56), Vector3(0.035, 0.46, 0.04), glass_trim, glazing_tilt)
				if joined_hull: _fit_surface_fittings(first_glazing, p + Vector3.UP * 0.45, "-z", hull_faces)
			"engine":
				if joined_hull:
					_add_family_engine_housing(p, hull_mat, dark_mat)
				# Engines feed aft outlets at the end of their occupied column.
				# A covered engine face must not extrude a bell into another room.
				var outlet := cell
				while cells.has(outlet + Vector3i(0, 0, 1)): outlet += Vector3i(0, 0, 1)
				if not exhaust_columns.has(outlet):
					exhaust_columns[outlet] = true
					var outlet_center := Vector3(outlet) * CELL_SIZE - center
					var first_nozzle := get_child_count()
					for side in [-1, 1]:
						_add_engine_nozzle(outlet_center + Vector3(float(side) * 0.67, 0.2, 1.5), nozzle_metal, nozzle_lining, dark_mat, exhaust_mat)
					if joined_hull: _fit_surface_fittings(first_nozzle, outlet_center + Vector3.UP * 0.2, "+z", hull_faces)
			"reactor":
				# Shielded service cover and heat-exchanger louvers, not an exposed glowing core.
				_add_bevelled_plate(deck + Vector3(0, 0.12, 0), Vector3(1.55, 0.22, 1.9), plate_mat, 0.055)
				_add_box(deck + Vector3(0, 0.236, 0), Vector3(1.2, 0.025, 1.45), dark_mat)
				for z in range(8):
					_add_box(deck + Vector3(0, 0.258, -0.59 + z * 0.17), Vector3(1.08, 0.04, 0.07), hull_mat)
				_add_stencil("THERMAL / KEEP CLEAR", deck + Vector3(0, 0.235, -0.84), 0.0015, Color("d9b468"))
			"cargo":
				# Paired access leaves with visible seals, hinges and painted latch tabs.
				_add_box(deck + Vector3(0, 0.035, 0), Vector3(1.98, 0.055, 1.96), dark_mat)
				for side in [-1, 1]:
					_add_bevelled_plate(deck + Vector3(float(side) * 0.475, 0.076, 0), Vector3(0.92, 0.065, 1.82), plate_mat, 0.025)
					for z in [-0.58, 0.58]:
						_add_box(deck + Vector3(float(side) * 0.95, 0.098, z), Vector3(0.14, 0.065, 0.22), hull_mat)
					_add_box(deck + Vector3(float(side) * 0.12, 0.12, 0), Vector3(0.08, 0.02, 0.21), accent_mat)
				_add_stencil("CARGO / %02d" % (cells.find(cell) + 1), deck + Vector3(-0.46, 0.111, -0.55), 0.00155)
				_add_stencil("LIFT HERE", deck + Vector3(0.47, 0.111, 0.57), 0.00135, Color("d9b468"))
			"weapon":
				_add_box(deck + Vector3(0, 0.09, -0.2), Vector3(0.52, 0.16, 1.9), hull_mat, Vector3(-0.06, 0, 0))
				for side in [-1, 1]:
					_add_cylinder(deck + Vector3(float(side) * 0.4, 0.17, -0.7), 0.09, 1.4, plate_mat)
					_add_cylinder(deck + Vector3(float(side) * 0.4, 0.17, -1.39), 0.05, 0.04, warm_mat)
			"shield":
				_add_bevelled_plate(deck + Vector3(0, 0.13, 0), Vector3(1.25, 0.25, 1.35), plate_mat, 0.09)
				_add_bevelled_plate(deck + Vector3(0, 0.28, 0), Vector3(0.92, 0.08, 1.02), dark_mat, 0.025)
				for side in [-1, 1]:
					_add_box(deck + Vector3(float(side) * 0.51, 0.32, 0.15), Vector3(0.07, 0.26, 0.15), hull_mat)
			"habitat":
				for side in [-1, 1]:
					var vent := deck + Vector3(float(side) * 0.48, 0.07, 0)
					_add_bevelled_plate(vent, Vector3(0.72, 0.12, 1.42), plate_mat, 0.04)
					_add_box(vent + Vector3(0, 0.072, 0), Vector3(0.53, 0.02, 1.17), dark_mat)
					for z in range(6):
						_add_box(vent + Vector3(0, 0.09, -0.47 + z * 0.19), Vector3(0.51, 0.03, 0.04), hull_mat)
			"radiator":
				pass
			_:
				for side in [-1, 1]:
					_add_box(deck + Vector3(float(side) * 0.82, 0.0, -0.1), Vector3(0.055, 0.03, 1.55), hull_mat)
	# Mark the bow and stern independently of module layout.
	_add_box(Vector3(-0.52, 0.05, -bounds.z * 0.49), Vector3(0.065, 0.04, 0.13), warm_mat)
	_add_box(Vector3(0.52, 0.05, -bounds.z * 0.49), Vector3(0.065, 0.04, 0.13), warm_mat)
	_add_box(Vector3(0, -0.12, bounds.z * 0.49), Vector3(bounds.x * 0.34, 0.09, 0.12), dark_mat)
	_apply_engine_glow()


# Painted identification remains attached to physical panels and responds to light.
func _add_stencil(text: String, at: Vector3, pixel: float, ink: Color = Color("d6d7c9")) -> Label3D:
	var label := Label3D.new()
	label.name = "HullStencil"
	label.text = text
	label.font_size = 48
	label.pixel_size = pixel
	label.outline_size = 0
	label.shaded = true
	label.modulate = ink
	label.basis = Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI * 0.5)
	label.position = at
	add_child(label)
	return label


# Deployed only on the parked display. Four broad pads replace a skid per module.
func add_landing_gear(modules: Array) -> void:
	var cells: Array[Vector3i] = []
	for module: Dictionary in modules:
		cells.append(Vector3i(int(module.x), int(module.y), int(module.z)))
	if cells.is_empty(): return
	var center := ShipBlueprint.center(cells)
	var lowest := cells[0].y
	for cell in cells: lowest = mini(lowest, cell.y)
	var gear := Node3D.new()
	gear.name = "LandingGear"
	add_child(gear)
	var steel := _surface_material(Color("707880"), 0.28, 0.88)
	var casing := _surface_material(Color("303b43"), 0.52, 0.06)
	var sole := _material(Color("161a1d"), 0.85, 0.0)
	for corner: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
		var selected := cells[0]
		var best := -INF
		for cell in cells:
			if cell.y != lowest: continue
			var score := float(cell.x)*corner.x + float(cell.z)*corner.y
			if score > best:
				best = score
				selected = cell
		var leg := Node3D.new()
		leg.name = "Gear%d" % gear.get_child_count()
		gear.add_child(leg)
		leg.position = Vector3(selected)*CELL_SIZE - center + Vector3(corner.x*0.85, -1.98, corner.y*0.85)
		# Helpers build origin-local meshes, then attach them to the contact frame.
		var foot := _add_bevelled_plate(Vector3(0,0.08,0), Vector3(0.72,0.16,0.92), sole, 0.045)
		foot.reparent(leg, false)
		foot.name = "Foot"
		var piston := _add_cylinder(Vector3(0,0.34,0), 0.085, 0.40, steel)
		piston.reparent(leg, false)
		var sleeve := _add_cylinder(Vector3(0,0.56,0), 0.14, 0.32, casing)
		sleeve.reparent(leg, false)
		var collar := _add_box(Vector3(0,0.64,0), Vector3(0.46,0.18,0.42), casing)
		collar.reparent(leg, false)


# Mount configurable fittings onto the actual armor triangle instead of the grid face.
func _fit_surface_fittings(first: int, center: Vector3, face: String, faces: PackedVector3Array) -> void:
	var direction := Vector3(ShipLayout.FACE_STEPS[face])
	var nearest := INF
	var surface := Vector3.ZERO
	var normal := direction
	for i in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(center,direction,faces[i],faces[i+1],faces[i+2])
		if hit == null: continue
		var distance := center.distance_to(hit)
		if distance >= nearest: continue
		nearest = distance
		surface = hit
		normal = (faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
	if not is_finite(nearest): return
	var rotation_basis := Basis(Quaternion(direction,normal))
	var previous_surface := center + direction * _surface_depth(direction,0.0)
	for i in range(first,get_child_count()):
		var fitting := get_child(i) as Node3D
		fitting.transform = Transform3D(rotation_basis * fitting.basis, surface + rotation_basis * (fitting.position-previous_surface))


# Parked service access: closed hatch plus a physical ramp. F still transitions
# into the cabin; this is not yet an opening, pressure-cycling airlock.
func add_boarding_access(modules: Array) -> void:
	var cells: Array[Vector3i] = []
	for module: Dictionary in modules:
		cells.append(Vector3i(int(module.x), int(module.y), int(module.z)))
	if ShipBlueprint.family_for_cells(cells).is_empty(): return
	var existing := get_node_or_null("BoardingAccess")
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var selected := cells[0]
	for cell in cells:
		if cell.y < selected.y or (cell.y == selected.y and (cell.x > selected.x or (cell.x == selected.x and cell.z > selected.z))):
			selected = cell
	var center := Vector3(selected) * CELL_SIZE - ShipBlueprint.center(cells)
	var threshold := center + Vector3(ShipBlueprint.collision_size(cells).x * 0.5 + 0.04, -ShipBlueprint.FLOOR_OFFSET, 0)
	var access := BoardingAccess.new()
	access.name = "BoardingAccess"
	access.set_meta("entry_cell", selected)
	add_child(access)
	access.position = threshold
	# Parked hull floor is 0.75 m above the landing plane, including multi-deck hulls.
	access.build(1.5, 0.75, 2.8)
	var first := get_child_count()
	var frame := _surface_material(Color("606b70"), 0.4, 0.5)
	var door := _surface_material(Color("29353d"), 0.58, 0.04)
	_add_box(threshold + Vector3(-0.18, 1.06, 0), Vector3(0.4, 2.12, 1.6), frame)
	_add_box(threshold + Vector3(0.035, 1.03, 0), Vector3(0.035, 1.94, 1.34), door)
	_add_box(threshold + Vector3(0.06, 1.03, 0), Vector3(0.02, 1.9, 0.025), frame)
	for side in [-1.0, 1.0]:
		_add_box(threshold + Vector3(0.07, 1.05, side * 0.53), Vector3(0.055, 0.28, 0.04), frame)
	# Reparent parked-only fittings with the ramp so repeated builds replace them.
	var fittings: Array[Node] = []
	for index in range(first, get_child_count()): fittings.append(get_child(index))
	for fitting: Node3D in fittings:
		fitting.reparent(access)
	var label := Label3D.new()
	label.text = "CREW ACCESS / F"
	label.font_size = 36
	label.pixel_size = 0.002
	label.outline_size = 0
	label.position = Vector3(0.07, 1.73, 0)
	label.rotation.y = PI * 0.5
	label.modulate = Color("d5dccc")
	access.add_child(label)


func _add_flank_service_strip(center: Vector3, face: String, inset: Material, plate: Material, structure: Material) -> void:
	var normal: Vector3 = Vector3(ShipLayout.FACE_STEPS[face])
	var mount := center + normal * _surface_depth(normal, 0.035)
	_add_box(mount - normal * 0.01, Vector3(0.035, 0.56, 1.88), inset)
	# The beveled hatch is turned onto the x-facing plane; rails frame its service seam.
	var hatch := _add_bevelled_plate(mount + normal * 0.035, Vector3(0.48, 0.045, 1.48), plate, 0.035)
	hatch.rotation.z = PI * 0.5
	for z in [-0.91, 0.91]:
		_add_box(mount + normal * 0.052 + Vector3(0, 0, z), Vector3(0.055, 0.62, 0.08), structure)


# Face-mounted equipment follows the pressure envelope, independent of grid pitch.
func _surface_depth(normal: Vector3, clearance: float) -> float:
	return normal.abs().dot(ShipBlueprint.PRESSURE_SIZE) * 0.5 + clearance


func _build_hull_panel(center: Vector3, face: String, panel_type: String, standard: Material, armor: Material, dark: Material, glass: Material) -> void:
	var normal: Vector3 = Vector3(ShipLayout.FACE_STEPS[face])
	var horizontal_size := 2.32
	var vertical_size := 1.42
	var position := center + normal * _surface_depth(normal, 0.04)
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
	var face_depth := _surface_depth(normal, 0.025)
	if face in ["+x", "-x"]:
		u = Vector3(0, 0, 1)
		v = Vector3(0, 1, 0)
	elif face in ["+y", "-y"]:
		u = Vector3(1, 0, 0)
		v = Vector3(0, 0, 1)
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


func set_systems_online(online: bool) -> void:
	if _systems_online == online: return
	_systems_online = online
	_apply_engine_glow()


func set_thrust(amount: float) -> void:
	_thrust = clampf(amount, 0.0, 1.0) if is_finite(amount) else 0.0
	_apply_engine_glow()


func _apply_engine_glow() -> void:
	var level := _thrust if _systems_online else 0.0
	for index in range(_engines.size()):
		_engine_glow[index].emission_energy_multiplier = (0.45 + level * 3.0) if _systems_online else 0.0
		_engine_glow[index].albedo_color = Color("ffbd74") if _systems_online else Color("20252a")
		_engines[index].scale = Vector3(1.0, 1.0 + level * 0.35, 1.0)


func _add_bevelled_plate(pos: Vector3, size: Vector3, material: Material, bevel_limit: float = INF) -> MeshInstance3D:
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5
	var bevel := minf(bevel_limit, minf(minf(size.x, size.z) * 0.1, size.y * 0.32))
	var half_y := size.y * 0.5
	var rings: Array[PackedVector3Array] = [
		_octagon(half_x - bevel, half_z - bevel, bevel * 0.4, -half_y),
		_octagon(half_x, half_z, bevel, -half_y + bevel),
		_octagon(half_x, half_z, bevel, half_y - bevel),
		_octagon(half_x - bevel, half_z - bevel, bevel * 0.4, half_y),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
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
	return mesh


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


func _add_box(pos: Vector3, size: Vector3, material: Material, angles: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	add_child(mesh)
	mesh.position = pos
	mesh.rotation = angles
	return mesh


func _add_engine_nozzle(origin: Vector3, metal: Material, lining: Material, dark: Material, glow: StandardMaterial3D) -> void:
	# Open, thick-walled bell: the luminous throat is behind the flared mouth.
	var shell := MeshInstance3D.new()
	shell.name = "EngineBell%d" % get_child_count()
	shell.mesh = HullGeometry.lathe_z(PackedVector2Array([
		Vector2(0.35, 0.0), Vector2(0.41, 0.16), Vector2(0.45, 0.48),
		Vector2(0.55, 0.76), Vector2(0.55, 0.82), Vector2(0.48, 0.82)]), 32)
	shell.material_override = metal
	add_child(shell)
	shell.position = origin
	var liner := MeshInstance3D.new()
	liner.name = "EngineLining%d" % get_child_count()
	liner.mesh = HullGeometry.lathe_z(PackedVector2Array([
		Vector2(0.48, 0.82), Vector2(0.39, 0.51), Vector2(0.24, 0.22), Vector2(0.16, 0.13)]), 32)
	liner.material_override = lining
	add_child(liner)
	liner.position = origin
	var backing := _add_cylinder(origin + Vector3(0, 0, 0.10), 0.33, 0.045, dark)
	backing.rotation.x = PI * 0.5
	var core := _add_cylinder(origin + Vector3(0, 0, 0.15), 0.16, 0.035, glow)
	core.name = "EngineThroat%d" % get_child_count()
	core.rotation.x = PI * 0.5
	var collar := _add_torus(origin + Vector3(0, 0, 0.08), 0.34, 0.40, metal)
	collar.rotation.x = PI * 0.5
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var radial := Vector3(cos(angle), sin(angle), 0)
		var rib := _add_box(origin + radial * 0.445 + Vector3(0, 0, 0.36), Vector3(0.075, 0.055, 0.43), metal)
		rib.rotation.z = angle
	_engines.append(core)
	_engine_glow.append(glow)


func _add_family_engine_housing(cell_pos: Vector3, material: Material, vent_material: Material) -> void:
	# One continuous fairing covers each twin-nozzle engine bay above its pressure roof.
	var housing := MeshInstance3D.new()
	housing.name = "FamilyEngineHousing%d" % get_child_count()
	housing.mesh = HullGeometry.profile(PackedVector2Array([
		Vector2(-0.68, -1.8), Vector2(0.68, -1.8), Vector2(1.24, -0.9),
		Vector2(1.24, 1.5), Vector2(1.0, 1.8), Vector2(-1.0, 1.8),
		Vector2(-1.24, 1.5), Vector2(-1.24, -0.9),
	]), [Vector3(1.0, 1.335, 1.0), Vector3(0.92, 1.54, 0.96), Vector3(0.76, 1.82, 0.82)])
	housing.material_override = material
	add_child(housing)
	housing.position = cell_pos + Vector3(0, 0, 0.45)
	# Shallow inset service grille breaks up the broad upper fairing without
	# turning it into a bright, oversized rooftop feature.
	var vent_center := cell_pos + Vector3(0, 1.82, 0.45)
	_add_box(vent_center, Vector3(0.62, 0.028, 1.42), vent_material)
	_add_box(vent_center + Vector3(-0.35, 0.016, 0), Vector3(0.07, 0.035, 1.54), material)
	_add_box(vent_center + Vector3(0.35, 0.016, 0), Vector3(0.07, 0.035, 1.54), material)
	for z in [-0.48, -0.16, 0.16, 0.48]:
		_add_box(vent_center + Vector3(0, 0.025, z), Vector3(0.54, 0.035, 0.065), material)
	# Twin raised shoulders add a stepped, armored edge to the nozzle fairing.
	for side in [-1, 1]:
		_add_box(cell_pos + Vector3(float(side) * 0.72, 1.846, 0.45), Vector3(0.075, 0.045, 1.48), material)


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


# Share the hull finish shader with opaque equipment; no artificial panel grid on
# small fittings. Bare metal and painted covers keep distinct physical responses.
func _surface_material(color: Color, roughness: float, metallic: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/fleet_surface.gdshader")
	material.set_shader_parameter("paint", color)
	material.set_shader_parameter("base_roughness", roughness)
	material.set_shader_parameter("metalness", metallic)
	material.set_shader_parameter("coating", 0.18 if metallic < 0.5 else 0.0)
	material.set_shader_parameter("roughness_variation", 0.28)
	return material


func _material(color: Color, roughness: float, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.08
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


static func preview_environment() -> Environment:
	# A neutral studio gradient supplies reflected light even behind a solid backdrop.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101820")
	var sky := Sky.new()
	var studio := ProceduralSkyMaterial.new()
	studio.sky_top_color = Color("8896a5")
	studio.sky_horizon_color = Color("d9dedf")
	studio.ground_bottom_color = Color("10151b")
	studio.ground_horizon_color = Color("687784")
	studio.sky_curve = 0.2
	studio.ground_curve = 0.15
	sky.sky_material = studio
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b0bdc8")
	environment.ambient_light_energy = 0.18
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.ssao_enabled = true
	environment.ssao_radius = 0.6
	environment.ssao_intensity = 1.4
	return environment
