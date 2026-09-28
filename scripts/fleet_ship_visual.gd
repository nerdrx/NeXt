class_name FleetShipVisual
extends Node3D

const FREIGHTER := "trade"
var _engines: Array[MeshInstance3D] = []
var _glows: Array[StandardMaterial3D] = []


func build(kind: String, faction: String) -> void:
	for child in get_children(): child.queue_free()
	_engines.clear()
	_glows.clear()
	var freighter := kind == FREIGHTER
	var accent := Color("c5904b") if freighter else (Color("dc7048") if faction == "pirate" else Color("77b9ca"))
	var hull := _surface(Color("7d817e") if freighter else Color("27343c"), 0.58, 0.08, 0.3)
	var armor := _surface(Color("99958a") if freighter else Color("979c9e"), 0.43, 0.04, 0.12)
	var dark_armor := _surface(Color("3d4a4f") if freighter else Color("56616a"), 0.62, 0.45, 0.08)
	var inset := _surface(Color("101a20"), 0.74, 0.5, 0.0)
	var black := _surface(Color("080f14"), 0.66, 0.1, 0.0)
	var accent_mat := _surface(accent.darkened(0.22), 0.48, 0.04, 0.12)
	var navigation_light := _mat(accent, 0.3, 1.2)
	var glass := _mat(Color("111c21"), 0.12)
	glass.metallic = 0.0
	glass.clearcoat_enabled = true
	glass.clearcoat = 1.0
	glass.clearcoat_roughness = 0.05
	var engine_glow := _mat(Color("ffb56b") if freighter else Color("ff7854"), 0.25, 2.2)
	var frame := _surface(Color("879094") if freighter else Color("757b80"), 0.36, 0.85, 0.05)
	# Pressure hull is an angular keel beneath broad, hard-edged armor plates.
	var keel: Array[Vector3] = [
		Vector3(0.22, 0.28, -5.65), Vector3(0.84, 0.58, -4.55),
		Vector3(1.34, 0.68, -2.7), Vector3(1.46, 0.72, 0.2),
		Vector3(1.25, 0.67, 3.1), Vector3(0.88, 0.54, 5.05)]
	if not freighter:
		# The fighter's armor wing is the dominant body; this dark keel stays low and narrow.
		keel = [Vector3(0.18, 0.24, -5.5), Vector3(0.66, 0.34, -4.2), Vector3(0.92, 0.39, -2.0), Vector3(0.98, 0.42, 0.8), Vector3(0.78, 0.36, 3.2), Vector3(0.60, 0.32, 5.05)]
	_loft(keel, hull)
	_box(Vector3(0, -0.5, 0.0), Vector3(0.92, 0.32, 8.9), black)
	_box(Vector3(0, -0.61, 0.1), Vector3(1.85, 0.20, 6.3), dark_armor)
	_build_cockpit(armor, frame, inset, glass, accent_mat)
	if freighter:
		_build_freighter(armor, dark_armor, inset, frame, accent_mat)
	else:
		_build_fighter(armor, dark_armor, inset, frame, accent_mat, black)
	# Matched nacelles keep both roles recognizable as powered spacecraft.
	for side in [-1.0, 1.0]:
		var x: float = side * (2.0 if freighter else 1.42)
		var y: float = -0.02 if freighter else 0.08
		if freighter:
			_box(Vector3(side * 1.1, -0.28, 3.5), Vector3(0.65, 0.34, 1.85), dark_armor, Vector3(0, side * -0.18, 0))
		else:
			_box(Vector3(side * 1.12, -0.30, 3.38), Vector3(0.46, 0.34, 1.9), dark_armor, Vector3(0, side * -0.08, 0))
		var engine := _build_engine(Vector3(x, y, 3.05), armor, dark_armor, inset, black, accent_mat, engine_glow, freighter)
		_engines.append(engine)
		_glows.append(engine_glow)
	# Bow and stern lamps mark orientation without turning the hull into neon trim.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.26, 0.13, -4.50), Vector3(0.18, 0.08, 0.08), navigation_light)
		_box(Vector3(side * 0.72, -0.04, 5.22), Vector3(0.16, 0.07, 0.07), engine_glow)


func _build_cockpit(armor: Material, frame: Material, inset: Material, glass: Material, accent: Material) -> void:
	# Low swept bridge grows out of the keel instead of sitting above it as a block.
	_side_prism([
		Vector2(0.27, -4.92), Vector2(0.76, -4.30),
		Vector2(0.82, -3.38), Vector2(0.62, -2.83),
		Vector2(0.34, -2.22)], -0.58, 0.58, armor)
	# Slanted forward windscreen: a true four-sided pane nested inside the swept frame.
	var windshield := SurfaceTool.new()
	windshield.begin(Mesh.PRIMITIVE_TRIANGLES)
	windshield.set_smooth_group(-1)
	var front_left := Vector3(-0.39, 0.36, -4.84)
	var front_right := Vector3(0.39, 0.36, -4.84)
	var rear_right := Vector3(0.52, 0.79, -4.30)
	var rear_left := Vector3(-0.52, 0.79, -4.30)
	_add_oriented_triangle(windshield, front_left, front_right, rear_right, Vector3(0, 1, -1))
	_add_oriented_triangle(windshield, front_left, rear_right, rear_left, Vector3(0, 1, -1))
	windshield.generate_normals()
	_mesh(windshield.commit(), glass)
	# Side panes follow the cabin profile and taper toward the rear shoulder.
	var side_window := [
		Vector2(0.39, -4.60), Vector2(0.67, -4.21), Vector2(0.72, -3.67),
		Vector2(0.57, -3.48), Vector2(0.42, -3.71)]
	var rear_window := [
		Vector2(0.69, -3.40), Vector2(0.72, -3.17), Vector2(0.53, -2.70),
		Vector2(0.36, -2.46), Vector2(0.43, -3.06)]
	for side in [-1.0, 1.0]:
		var pane_x: float = side * 0.585
		_side_prism(side_window, pane_x - 0.012, pane_x + 0.012, inset)
		_side_prism(side_window, pane_x + side * 0.018 - 0.003, pane_x + side * 0.018 + 0.003, glass)
		_side_prism(rear_window, pane_x - 0.012, pane_x + 0.012, inset)
		_side_prism(rear_window, pane_x + side * 0.018 - 0.003, pane_x + side * 0.018 + 0.003, glass)
		# Thin uprights and swept rails divide glass from the surrounding armor.
		_box(Vector3(side * 0.58, 0.51, -4.38), Vector3(0.055, 0.045, 0.76), frame, Vector3(-0.65, 0, 0))
		_box(Vector3(side * 0.59, 0.58, -3.85), Vector3(0.035, 0.075, 0.055), frame)
		_box(Vector3(side * 0.59, 0.56, -3.28), Vector3(0.035, 0.075, 0.055), frame)
		_box(Vector3(side * 0.57, 0.38, -2.72), Vector3(0.05, 0.04, 0.58), frame, Vector3(0.34, 0, 0))
	# Narrow crown and cheek strips tie the pane frame into the hull without a roof slab.
	_box(Vector3(0, 0.77, -3.91), Vector3(0.92, 0.055, 0.10), frame, Vector3(-0.17, 0, 0))
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.57, 0.30, -3.04), Vector3(0.09, 0.12, 1.10), inset, Vector3(0, side * -0.12, 0))
		_box(Vector3(side * 0.61, 0.34, -2.57), Vector3(0.035, 0.045, 0.32), accent)


func _build_fighter(armor: Material, dark_armor: Material, inset: Material, frame: Material, accent: Material, black: Material) -> void:
	# Broad swept delta plate sets the fighter silhouette, with angular, raised armor islands.
	var delta := [Vector2(0, -5.55), Vector2(1.15, -4.12), Vector2(4.55, 0.65), Vector2(4.12, 2.42), Vector2(2.5, 2.05), Vector2(1.65, 4.38), Vector2(0, 3.52), Vector2(-1.65, 4.38), Vector2(-2.5, 2.05), Vector2(-4.12, 2.42), Vector2(-4.55, 0.65), Vector2(-1.15, -4.12)]
	_poly_prism(delta, -0.42, -0.08, dark_armor)
	var upper := [Vector2(0, -5.40), Vector2(1.04, -4.05), Vector2(4.30, 0.63), Vector2(3.92, 2.08), Vector2(2.43, 1.76), Vector2(1.42, 3.92), Vector2(0, 3.24), Vector2(-1.42, 3.92), Vector2(-2.43, 1.76), Vector2(-3.92, 2.08), Vector2(-4.30, 0.63), Vector2(-1.04, -4.05)]
	_poly_prism(upper, -0.06, 0.14, armor)
	# Inset dark dorsal machinery and longitudinal armored rails echo the reference fighter spine.
	_box(Vector3(0, 0.24, 0.55), Vector3(1.45, 0.16, 5.50), inset)
	_box(Vector3(0, 0.36, 1.38), Vector3(0.92, 0.12, 3.35), black)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.72, 0.34, 0.55), Vector3(0.16, 0.13, 5.35), frame, Vector3(0, side * -0.07, 0))
		_box(Vector3(side * 0.37, 0.45, 1.20), Vector3(0.10, 0.10, 3.65), dark_armor)
		# Separate wing plates and dark seams create visible panel structure at ship scale.
		_mirrored_plate([Vector2(1.20, -3.30), Vector2(2.00, -2.55), Vector2(4.23, 0.68), Vector2(3.76, 1.73), Vector2(2.45, 1.42), Vector2(1.42, -0.10)], side, 0.145, 0.19, dark_armor)
		# Narrow joints separate replaceable forward, hardpoint and aft service covers.
		for panel in [
			[Vector2(1.31, -3.15), Vector2(1.95, -2.45), Vector2(2.66, -1.40), Vector2(1.45, -1.24)],
			[Vector2(1.45, -1.24), Vector2(2.66, -1.40), Vector2(3.48, -0.20), Vector2(2.17, 0.61), Vector2(1.53, -0.18)],
			[Vector2(2.17, 0.61), Vector2(3.48, -0.20), Vector2(3.98, 0.55), Vector2(3.61, 1.43), Vector2(2.55, 1.16)]]:
			var center := Vector2.ZERO
			for point: Vector2 in panel: center += point
			center /= panel.size()
			var inset_panel: Array = []
			for point: Vector2 in panel: inset_panel.append(point.move_toward(center, 0.014))
			_mirrored_plate(inset_panel, side, 0.195, 0.23, armor)
		# Hardpoint barrels protrude past the leading edge and sit inside armored mounts.
		_box(Vector3(side * 2.60, 0.30, -0.95), Vector3(0.74, 0.28, 1.70), dark_armor, Vector3(0, side * -0.15, 0))
		for offset in [-0.20, 0.20]:
			var barrel := _cylinder(Vector3(side * 2.60 + offset, 0.38, -2.03), 0.072, 1.10, black)
			barrel.rotation.x = PI * 0.5
			var muzzle := _cylinder(Vector3(side * 2.60 + offset, 0.38, -2.60), 0.078, 0.08, black)
			muzzle.rotation.x = PI * 0.5
		# Service vents, diagonal cover seams and edge lights are placed on the wing plates.
		for z in [0.08, 0.30, 0.52]:
			_box(Vector3(side * 3.28, 0.245, z), Vector3(0.64, 0.025, 0.075), inset, Vector3(0, side * -0.48, 0))
		_box(Vector3(side * 3.90, 0.25, 1.22), Vector3(0.12, 0.06, 0.54), accent)
		# Short dorsal fins break the otherwise flat wing plane near the engine mounts.
		_vertical_prism([Vector2(0.12, 2.25), Vector2(0.86, 2.82), Vector2(0.70, 4.28), Vector2(0.20, 3.86)], side * 1.90, side * 2.16, dark_armor)
		_box(Vector3(side * 1.66, -0.12, 2.30), Vector3(0.30, 0.32, 1.60), frame, Vector3(0, side * -0.22, 0))
	# Exposed ram-air/heat exchanger grilles sit either side of the inset dorsal spine.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.38, 0.20, 1.20), Vector3(0.48, 0.045, 2.18), inset, Vector3(0, side * -0.14, 0))
		for z in [0.40, 0.72, 1.04, 1.36, 1.68, 2.0]:
			_box(Vector3(side * 1.38, 0.24, z), Vector3(0.42, 0.07, 0.07), frame, Vector3(0, side * -0.14, 0))
	# Raised twin engine pods attach through visible bridge trusses.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.16, -0.06, 3.58), Vector3(0.58, 0.42, 1.40), inset, Vector3(0, side * -0.12, 0))
		_box(Vector3(side * 1.14, 0.22, 3.60), Vector3(0.20, 0.18, 1.56), frame, Vector3(0, side * -0.12, 0))
		_box(Vector3(side * 1.55, 0.10, 3.52), Vector3(0.17, 0.16, 1.48), dark_armor, Vector3(0, side * -0.1, 0))
		# Flush optical package sits behind a slanted protective brow.
		_side_prism([Vector2(0.24,0.70), Vector2(0.39,0.83), Vector2(0.40,1.15), Vector2(0.24,1.28)], side*3.55-0.16, side*3.55+0.16, dark_armor)
		var lens := _cylinder(Vector3(side*3.55,0.31,0.73), 0.065, 0.025, black)
		lens.rotation.x = PI*0.5
		# Recessed access fasteners and painted service stencils establish equipment scale.
		for dz in [-0.22, 0.22]:
			for dx in [-0.21, 0.21]:
				_cylinder(Vector3(side*3.28+dx,0.237,0.30+dz),0.016,0.008,frame)
		_stencil("RCS / KEEP CLEAR", Vector3(side*3.34,0.24,1.02),0.00125,Color("252a2b"))
		_stencil("NX-07", Vector3(side*1.78,0.242,-1.66),0.0021,Color("303638"))


func _build_freighter(armor: Material, dark_armor: Material, inset: Material, frame: Material, accent: Material) -> void:
	# Civilian hull keeps a low swept planform and an uninterrupted cargo spine.
	_poly_prism([Vector2(0, -5.55), Vector2(1.26, -4.25), Vector2(3.72, -0.05), Vector2(3.46, 2.45), Vector2(2.45, 3.72), Vector2(-2.45, 3.72), Vector2(-3.46, 2.45), Vector2(-3.72, -0.05), Vector2(-1.26, -4.25)], -0.38, -0.02, dark_armor)
	_poly_prism([Vector2(0, -5.36), Vector2(1.15, -4.14), Vector2(3.48, -0.02), Vector2(3.20, 2.26), Vector2(2.32, 3.45), Vector2(-2.32, 3.45), Vector2(-3.20, 2.26), Vector2(-3.48, -0.02), Vector2(-1.15, -4.14)], -0.01, 0.16, armor)
	# Raised cargo deck includes three protected standardized bays with clamped hatch frames.
	_box(Vector3(0, 0.30, 0.25), Vector3(2.35, 0.30, 5.25), dark_armor)
	for z in [-1.28, 0.34, 1.96]:
		_box(Vector3(0, 0.56, z), Vector3(2.08, 0.24, 1.46), armor)
		_box(Vector3(0, 0.69, z), Vector3(1.84, 0.05, 1.20), inset)
		for side in [-1.0, 1.0]:
			_box(Vector3(side * 1.02, 0.72, z), Vector3(0.12, 0.12, 1.44), frame)
		_box(Vector3(0, 0.73, z - 0.63), Vector3(2.04, 0.12, 0.12), frame)
		_box(Vector3(0, 0.73, z + 0.63), Vector3(2.04, 0.12, 0.12), frame)
	# Cargo pods ride below the wingline on paired angled pylons, leaving visible machinery.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.80, -0.05, 0.10), Vector3(0.26, 0.48, 1.8), frame, Vector3(0, side * -0.22, 0))
		_box(Vector3(side * 2.34, -0.24, 0.70), Vector3(1.14, 0.90, 3.72), dark_armor, Vector3(0, side * -0.06, 0))
		_box(Vector3(side * 2.34, 0.24, 0.70), Vector3(0.94, 0.12, 3.35), armor)
		_box(Vector3(side * 2.34, 0.31, 0.70), Vector3(0.70, 0.035, 3.04), inset)
		for z in [-0.78, 0.0, 0.78, 1.56, 2.32]:
			_box(Vector3(side * 2.34, 0.38, z), Vector3(1.03, 0.14, 0.14), frame)
		# A segmented side loading door gives the nacelle an obvious freight function.
		for z in [-0.55, 0.55, 1.65]:
			_box(Vector3(side * 2.93, -0.26, z), Vector3(0.055, 0.52, 0.84), inset)
		_box(Vector3(side * 2.97, -0.26, 0.55), Vector3(0.035, 0.035, 2.65), accent)
	# Chin sensor and forward docking lights.
	_box(Vector3(0, -0.24, -4.58), Vector3(0.62, 0.22, 0.55), dark_armor)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.22, 0.2, -4.34), Vector3(0.26, 0.075, 0.12), accent)


func _build_engine(origin: Vector3, armor: Material, dark_armor: Material, inset: Material, black: Material, accent: Material, glow: StandardMaterial3D, freighter: bool) -> MeshInstance3D:
	# A turned engine barrel ends in a separate open bell and a recessed, dark inner funnel.
	var pod_radius := 0.60 if freighter else 0.55
	var pod := _lathe_z(origin, PackedVector2Array([
		Vector2(pod_radius * 0.65, -2.55), Vector2(pod_radius, -2.18),
		Vector2(pod_radius, 1.55), Vector2(pod_radius * 1.08, 2.15),
		Vector2(pod_radius * 0.88, 2.52)]), armor, 16)
	var shoulder := _lathe_z(origin, PackedVector2Array([
		Vector2(pod_radius * 1.02, 1.22), Vector2(pod_radius * 1.16, 1.52),
		Vector2(pod_radius * 1.12, 1.88), Vector2(pod_radius * 0.94, 2.17)]), dark_armor, 16)
	var inner := _lathe_z(origin, PackedVector2Array([
		Vector2(pod_radius * 0.86, 2.48), Vector2(pod_radius * 0.72, 2.12),
		Vector2(pod_radius * 0.51, 1.66), Vector2(pod_radius * 0.29, 1.44),
		Vector2(pod_radius * 0.18, 1.40)]), inset, 16)
	var lip := _torus(origin + Vector3(0, 0, 2.48), pod_radius * 0.62, pod_radius * 0.94, dark_armor)
	lip.rotation.x = PI * 0.5
	# Close the forward nacelle so the aft exhaust core cannot read as a second nose light.
	var intake := _cylinder(origin + Vector3(0, 0, -2.42), pod_radius * 0.74, 0.08, dark_armor)
	intake.rotation.x = PI * 0.5
	var intake_hub := _cylinder(origin + Vector3(0, 0, -2.48), pod_radius * 0.24, 0.10, inset)
	intake_hub.rotation.x = PI * 0.5
	var core := _cylinder(origin + Vector3(0, 0, 1.48), pod_radius * 0.22, 0.045, glow)
	core.rotation.x = PI * 0.5
	var backing := _cylinder(origin + Vector3(0, 0, 1.40), pod_radius * 0.46, 0.045, black)
	backing.rotation.x = PI * 0.5
	var vents_mat: Material = accent if freighter else dark_armor
	for angle in range(0, 360, 60):
		var rad := deg_to_rad(float(angle))
		var vent := _box(origin + Vector3(cos(rad) * pod_radius * 0.9, sin(rad) * pod_radius * 0.9, 0.0), Vector3(0.11, 0.07, 2.1), vents_mat)
		vent.rotation.z = rad
		vent.rotation.y = 0.05
	return core


func set_thrust(amount: float) -> void:
	var level := clampf(amount, 0.0, 1.0)
	for i in _engines.size():
		_glows[i].emission_energy_multiplier = 0.45 + level * 3.0
		_engines[i].scale = Vector3(1.0, 1.0 + level * 0.35, 1.0)


func _loft(sections: Array[Vector3], material: Material, origin: Vector3 = Vector3.ZERO) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var rings: Array[PackedVector3Array] = []
	for section in sections:
		var w := section.x
		var h := section.y
		rings.append(PackedVector3Array([
			origin + Vector3(-w * 0.68, -h, section.z), origin + Vector3(w * 0.68, -h, section.z),
			origin + Vector3(w, -h * 0.52, section.z), origin + Vector3(w, h * 0.52, section.z),
			origin + Vector3(w * 0.68, h, section.z), origin + Vector3(-w * 0.68, h, section.z),
			origin + Vector3(-w, h * 0.52, section.z), origin + Vector3(-w, -h * 0.52, section.z)]))
	for layer in rings.size() - 1:
		for edge in 8:
			var next := (edge + 1) % 8
			_add_tri(st, rings[layer][edge], rings[layer][next], rings[layer + 1][next])
			_add_tri(st, rings[layer][edge], rings[layer + 1][next], rings[layer + 1][edge])
	for edge in range(1, 7):
		_add_tri(st, rings[0][0], rings[0][edge + 1], rings[0][edge])
		var last := rings[rings.size() - 1]
		_add_tri(st, last[0], last[edge], last[edge + 1])
	st.generate_normals()
	_mesh(st.commit(), material)


func _poly_prism(points: Array, y0: float, y1: float, material: Material) -> void:
	_mesh(HullGeometry.prism(points, y0, y1), material)


func _mirrored_plate(points: Array, side: float, y0: float, y1: float, material: Material) -> void:
	var transformed: Array = []
	if side > 0.0:
		for point: Vector2 in points:
			transformed.append(point)
	else:
		for index in range(points.size() - 1, -1, -1):
			var point: Vector2 = points[index]
			transformed.append(Vector2(-point.x, point.y))
	_poly_prism(transformed, y0, y1, material)


func _side_prism(points: Array, x0: float, x1: float, material: Material) -> void:
	var vertices := PackedVector2Array(points)
	if Geometry2D.is_polygon_clockwise(vertices): vertices.reverse()
	var low := minf(x0, x1)
	var high := maxf(x0, x1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var triangles := Geometry2D.triangulate_polygon(vertices)
	for i in range(0, triangles.size(), 3):
		var a := vertices[triangles[i]]
		var b := vertices[triangles[i+1]]
		var c := vertices[triangles[i+2]]
		_add_oriented_triangle(st, Vector3(high,a.x,a.y), Vector3(high,b.x,b.y), Vector3(high,c.x,c.y), Vector3.RIGHT)
		_add_oriented_triangle(st, Vector3(low,a.x,a.y), Vector3(low,b.x,b.y), Vector3(low,c.x,c.y), Vector3.LEFT)
	for i in vertices.size():
		var j := (i+1) % vertices.size()
		var edge := vertices[j] - vertices[i]
		var outward := Vector3(0,edge.y,-edge.x)
		var a := Vector3(low,vertices[i].x,vertices[i].y)
		var b := Vector3(low,vertices[j].x,vertices[j].y)
		var c := Vector3(high,vertices[j].x,vertices[j].y)
		var d := Vector3(high,vertices[i].x,vertices[i].y)
		_add_oriented_triangle(st,a,b,c,outward)
		_add_oriented_triangle(st,a,c,d,outward)
	st.generate_normals()
	_mesh(st.commit(), material)


func _vertical_prism(points: Array, x0: float, x1: float, material: Material) -> void:
	_side_prism(points, x0, x1, material)


func _lathe_z(origin: Vector3, profile: PackedVector2Array, material: Material, segments: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = HullGeometry.lathe_z(profile, segments)
	instance.material_override = material
	add_child(instance)
	instance.position = origin
	return instance


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


func _box(pos: Vector3, size: Vector3, material: Material, angles: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var smallest := minf(size.x, minf(size.y, size.z))
	if smallest >= 0.1:
		mesh.mesh = _bevelled_box_mesh(size, minf(0.025, smallest * 0.1))
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
	mesh.material_override = material
	add_child(mesh)
	mesh.position = pos
	mesh.rotation = angles
	return mesh


func _bevelled_box_mesh(size: Vector3, bevel: float) -> ArrayMesh:
	var half := size * 0.5
	var extents := PackedFloat32Array([half.x, half.y, half.z])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# Six inset rectangular faces keep broad planes separate from the edge chamfers.
	for axis in 3:
		var b := (axis + 1) % 3
		var c := (axis + 2) % 3
		for face_sign in [-1.0, 1.0]:
			var center := Vector3.ZERO
			center[axis] = face_sign * extents[axis]
			var n := Vector3.ZERO
			n[axis] = face_sign
			var outline := [
				Vector2(-extents[b] + bevel, -extents[c] + bevel),
				Vector2(extents[b] - bevel, -extents[c] + bevel),
				Vector2(extents[b] - bevel, extents[c] - bevel),
				Vector2(-extents[b] + bevel, extents[c] - bevel)]
			var corners: Array[Vector3] = []
			for point: Vector2 in outline:
				var vertex := Vector3.ZERO
				vertex[axis] = center[axis]
				vertex[b] = point.x
				vertex[c] = point.y
				corners.append(vertex)
			for i in corners.size():
				_add_oriented_triangle(st, center, corners[i], corners[(i + 1) % corners.size()], n)
	# Twelve narrow chamfer planes bridge the inset faces along each original edge.
	for axis in 3:
		var b := (axis + 1) % 3
		var c := (axis + 2) % 3
		for sign_b in [-1.0, 1.0]:
			for sign_c in [-1.0, 1.0]:
				var p0 := Vector3.ZERO
				var p1 := Vector3.ZERO
				var p2 := Vector3.ZERO
				var p3 := Vector3.ZERO
				p0[axis] = -extents[axis] + bevel
				p1[axis] = extents[axis] - bevel
				p2[axis] = p1[axis]
				p3[axis] = p0[axis]
				p0[b] = sign_b * extents[b]
				p1[b] = sign_b * extents[b]
				p2[b] = sign_b * (extents[b] - bevel)
				p3[b] = p2[b]
				p0[c] = sign_c * (extents[c] - bevel)
				p1[c] = p0[c]
				p2[c] = sign_c * extents[c]
				p3[c] = p2[c]
				var n := Vector3.ZERO
				n[b] = sign_b
				n[c] = sign_c
				n = n.normalized()
				_add_oriented_triangle(st, p0, p1, p2, n)
				_add_oriented_triangle(st, p0, p2, p3, n)
	# Eight corner triangles close the chamfers without extending the box bounds.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var p0 := Vector3(sx * half.x, sy * (half.y - bevel), sz * (half.z - bevel))
				var p1 := Vector3(sx * (half.x - bevel), sy * half.y, sz * (half.z - bevel))
				var p2 := Vector3(sx * (half.x - bevel), sy * (half.y - bevel), sz * half.z)
				_add_oriented_triangle(st, p0, p1, p2, Vector3(sx, sy, sz).normalized())
	st.generate_normals()
	return st.commit()


func _add_oriented_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


func _cylinder(pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius * 0.82
	cylinder.height = height
	cylinder.radial_segments = 16
	mesh.mesh = cylinder
	mesh.material_override = material
	add_child(mesh)
	mesh.position = pos
	return mesh


func _torus(pos: Vector3, inner_radius: float, outer_radius: float, material: Material) -> MeshInstance3D:
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


func _stencil(text: String, pos: Vector3, pixel_scale: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = pixel_scale
	label.outline_size = 0
	label.modulate = color
	label.shaded = true
	label.no_depth_test = false
	label.rotation.x = -PI*0.5
	label.position = pos
	add_child(label)


func _sphere(pos: Vector3, radius: float, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.material_override = material
	add_child(mesh)
	mesh.position = pos


func _mesh(mesh: Mesh, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)


func _mat(color: Color, roughness: float, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.22
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func _surface(color: Color, roughness: float, metalness: float, coating: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/fleet_surface.gdshader")
	material.set_shader_parameter("paint", color)
	material.set_shader_parameter("base_roughness", roughness)
	material.set_shader_parameter("metalness", metalness)
	material.set_shader_parameter("coating", coating)
	return material
