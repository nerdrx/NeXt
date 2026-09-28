class_name OwnedStation
extends Node3D

const FREIGHT_APPROACH := Vector3(0, 22, 150)
const STATION_LAYOUT = preload("res://scripts/station_layout.gd")

var dock_position := Vector3(0, 0, 70)
var stand_position := Vector3(18, 0.15, 70)
var launch_position := Vector3(0, 22, 108)
var large_dock_position := Vector3(0, 0, 220)
var large_stand_position := Vector3(54, 0.15, 220)
var large_launch_position := Vector3(0, 112, 220)
var interior_services: Array[Dictionary] = []
var interior_route: Array[Vector3] = []
var walkable_regions: Array[AABB] = []

func build(station: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	interior_services.clear()
	interior_route.clear()
	walkable_regions.clear()
	var hull := _material(Color("34414c"), 0.7)
	var trim := _material(Color("a2a9ab"), 0.55)
	var dark := _material(Color("141d25"), 0.3)
	var light := _material(Color("61e3d8"), 0.0, 3.0)
	var amber := _material(Color("ffb65c"), 0.0, 2.0)
	var blue := _material(Color("1e3a50"), 0.7)
	var structure := _material(Color("52636b"), 0.75)
	var signal_material := _material(Color("60bac8"), 0.25, 1.1)
	var glass := _material(Color(0.28, 0.42, 0.48, 0.1), 0.0)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var level: int = clampi(int(station.get("level", 1)), 1, 100)
	var rooms: Array[String] = STATION_LAYOUT.rooms_for(station)
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
			# Recessed freight throat makes each repeated module read as a working dock.
			_box(Vector3(side * 52, -4, z + 7.72), Vector3(13, 7.5, 0.3), dark)
			for frame in [-1, 1]:
				_box(Vector3(side * 52 + frame * 7, -4, z + 7.95), Vector3(0.65, 8.2, 0.35), structure)
				_box(Vector3(side * 52, -4 + frame * 4.2, z + 7.95), Vector3(14.5, 0.65, 0.35), structure)
			_box(Vector3(side * 52, -4, z + 8.16), Vector3(1.0, 5.8, 0.18), signal_material)
			_box(Vector3(side * 52 + side * 9, 2.4, z + 8.0), Vector3(1.2, 0.5, 0.4), amber)
			_box(Vector3(side * 89, -7, z), Vector3(37, 0.7, 14), blue)
			for rib in 7:
				_box(Vector3(side * 89 - 15 + rib * 5, -6.5, z), Vector3(0.25, 0.3, 14), trim)
	_box(Vector3(0, 12, -32), Vector3(17, 28, 20), hull, true)
	_box(Vector3(0, 27, -32), Vector3(23, 4, 26), trim, true)
	_box(Vector3(0, 25, -18.8), Vector3(17, 2, 0.3), light)
	_box(Vector3(0, 42, -32), Vector3(0.5, 25, 0.5), trim)
	_box(Vector3(0, 55, -32), Vector3(1, 1, 1), amber)
	_build_orbital_superstructure(structure, trim, signal_material, amber)
	# Solid landing apron, open flight path to +Z and a sheltered service gallery.
	_box(Vector3(0, -1, 68), Vector3(76, 2, 80), hull, true)
	_add_walk_region(Vector3(-38, 0, 28), Vector3(76, 0, 80))
	_box(Vector3(0, 0.025, 70), Vector3(38, 0.05, 38), dark)
	for side in [-1, 1]:
		_box(Vector3(side * 20, 0.09, 70), Vector3(0.35, 0.08, 40), light)
		_box(Vector3(0, 0.09, 70 + side * 20), Vector3(40, 0.08, 0.35), light)
		if side < 0:
			_box(Vector3(side * 37, 1.5, 62), Vector3(0.6, 3, 61), trim, true)
		else:
			# Leave the z=40 service bridge opening in the apron rail.
			_box(Vector3(37, 1.5, 33.75), Vector3(0.6, 3, 4.5), trim, true)
			_box(Vector3(37, 1.5, 68.25), Vector3(0.6, 3, 48.5), trim, true)
		for lamp in 9:
			_box(Vector3(side * 34, 0.2, 34 + lamp * 8), Vector3(1.2, 0.15, 2.2), amber)
		_box(Vector3(side * 31, 5, 27), Vector3(1.5, 10, 1.5), trim, true)
	_box(Vector3(0, 10, 27), Vector3(64, 1.4, 16), hull, true)
	_box(Vector3(0, -0.5, 29), Vector3(74, 1, 10), hull, true)
	_box(Vector3(25, 1, 30), Vector3(4, 2, 2), dark, true)
	_box(Vector3(25, 2.1, 30), Vector3(3.5, 0.2, 1.7), light)
	_build_large_berth(hull, trim, dark, light, amber)
	var title := Label3D.new()
	title.text = "%s\nDOCK 01  /  LEVEL %d  /  %d ROOMS" % [str(station.get("name", "Outpost")).to_upper(), level, rooms.size()]
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
	_build_concourse(rooms, level, hull, trim, dark, light, amber, glass)

func _build_orbital_superstructure(structure: Material, trim: Material, signal_material: Material, amber: Material) -> void:
	# Two vertical orbital hoops frame the habitat spine while leaving the +Z docking corridor open.
	_box(Vector3(0, 12, -54), Vector3(24, 24, 16), structure, true)
	_box(Vector3(0, 12, -44), Vector3(12, 12, 8), structure, true)
	for spec: Dictionary in [
		{"center": Vector3(0, 12, -54), "radius": 112.0, "tube": 4.2},
		{"center": Vector3(0, 12, -75), "radius": 76.0, "tube": 2.4},
	]:
		var hoop := TorusMesh.new()
		hoop.inner_radius = float(spec.radius) - float(spec.tube)
		hoop.outer_radius = float(spec.radius) + float(spec.tube)
		var ring := MeshInstance3D.new()
		ring.name = "OrbitalRing"
		ring.mesh = hoop
		ring.position = spec.center
		ring.rotation.x = PI / 2.0
		ring.material_override = structure
		add_child(ring, true)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		collision.shape = hoop.create_trimesh_shape()
		body.add_child(collision)
		ring.add_child(body)
	# Radial girders share the hoops' XY plane; axial braces join the rear hoop.
	for spoke in 8:
		var angle := TAU * float(spoke) / 8.0
		var direction := Vector3(sin(angle), cos(angle), 0)
		var center := Vector3(0, 12, -54) + direction * 62.0
		var girder := _visual_box(center, Vector3(3.0, 100.0, 4.0), structure, true)
		girder.rotation.z = -angle
		var inset := _visual_box(center + Vector3(0, 0, 2.1), Vector3(0.5, 90.0, 0.2), trim)
		inset.rotation.z = -angle
		_visual_box(Vector3(0, 12, -64.5) + direction * 76.0, Vector3(3.0, 3.0, 25.0), structure, true)
	# A small cyan service beacon crowns the orbital frame; amber marks the freight axis.
	for side in [-1, 1]:
		var beacon := _visual_box(Vector3(side * 111, 12, -54), Vector3(2.0, 4.5, 3.5), signal_material)
		beacon.rotation.y = float(side) * PI / 4.0
	_visual_box(Vector3(0, -9, -135), Vector3(18, 15, 110), structure, true)
	_visual_box(Vector3(0, -1, -135), Vector3(1.2, 0.8, 102), amber)

func _visual_box(at: Vector3, size: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
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
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

func _build_large_berth(hull: Material, trim: Material, dark: Material, light: Material, amber: Material) -> void:
	# Open 120 m apron supports a 92.4 m hull with clearance around its full span.
	_box(Vector3(0, -1, 220), Vector3(120, 2, 120), hull, true)
	_add_walk_region(Vector3(-60, 0, 160), Vector3(120, 0, 120))
	# Ground-level connector joins the small apron to the large apron at z=160.
	_box(Vector3(45, -0.5, 134), Vector3(26, 1, 52), hull, true)
	_add_walk_region(Vector3(32, 0, 108), Vector3(26, 0, 52))
	# Mark the ship envelope and keep the east-side boarding lane clear of the hull.
	for side in [-1, 1]:
		_box(Vector3(side * 48, 0.025, 220), Vector3(0.25, 0.05, 104), light)
		_box(Vector3(0, 0.025, 220 + side * 48), Vector3(104, 0.05, 0.25), light)
		_box(Vector3(side * 58, 0.04, 220), Vector3(0.35, 0.08, 116), amber if side > 0 else dark)
		for rib in range(7):
			_box(Vector3(side * 56, 0.08, 172 + rib * 16), Vector3(2.4, 0.16, 0.55), amber)
	# Low perimeter equipment stays outside the clear pad and walking lane.
	for side in [-1, 1]:
		_box(Vector3(side * 59, 1.5, 220), Vector3(0.5, 3, 120), trim, true)
		for lamp in range(9):
			_box(Vector3(side * 55, 0.2, 166 + lamp * 13.5), Vector3(1.1, 0.15, 2), amber)
	_box(Vector3(-15, 1.5, 161), Vector3(90, 3, 0.5), trim, true)
	_box(Vector3(0, 1.5, 279), Vector3(120, 3, 0.5), trim, true)
	for z in [161.0, 279.0]:
		for x in [-48.0, -24.0, 0.0, 24.0, 48.0]:
			_box(Vector3(x, 0.15, z), Vector3(2.2, 0.12, 1.0), amber)
	_box(Vector3(54, 0.03, 220), Vector3(9, 0.06, 116), dark)
	_label("LARGE BERTH  /  SERVICE LANE", Vector3(54, 3.6, 220), 0.018, Color("61e3d8"))

func _build_concourse(rooms: Array[String], level: int, hull: Material, trim: Material, dark: Material, light: Material, amber: Material, glass: Material) -> void:
	var room_count := rooms.size()
	var corridor_start := 44.0
	var room_zs: Array[float] = []
	for room_index in room_count:
		room_zs.append(35.0 - room_index * 18.0)
	var corridor_end: float = room_zs[-1] - 10.0
	# Enclosed, eight-metre covered transfer bridge enters the spine at z=40.
	_box(Vector3(78.25, -0.125, 40), Vector3(83.5, 0.25, 8), dark, true)
	_box(Vector3(78.25, 4.75, 40), Vector3(83.5, 0.3, 8), hull, true)
	for z in [36.0, 44.0]:
		_box(Vector3(78.25, 0.55, z), Vector3(83.5, 1.1, 0.3), hull, true)
		_box(Vector3(78.25, 3.95, z), Vector3(83.5, 1.1, 0.3), hull, true)
		_box(Vector3(78.25, 2.25, z), Vector3(83.2, 2.3, 0.12), glass, true)
		for post_x in [37.0, 48.0, 59.0, 70.0, 81.0, 92.0, 103.0, 114.0, 119.5]:
			_box(Vector3(post_x, 2.25, z), Vector3(0.32, 4.5, 0.3), trim, true)
		_box(Vector3(78.25, 0.08, z), Vector3(83.5, 0.12, 0.24), light)
	_box(Vector3(78.25, 0.04, 40), Vector3(83.5, 0.08, 0.22), amber)
	for x in [48.0, 70.0, 92.0, 114.0]:
		_box(Vector3(x, 4.52, 40), Vector3(0.18, 0.18, 7.4), trim)
		var bridge_light := OmniLight3D.new()
		bridge_light.position = Vector3(x, 3.8, 40)
		bridge_light.light_color = Color("e7c994")
		bridge_light.light_energy = 1.4
		bridge_light.omni_range = 18
		add_child(bridge_light)
	# Continuous corridor floor and roof; its z=44 end is open to the bridge.
	var corridor_mid := (corridor_start + corridor_end) / 2.0
	var corridor_length := corridor_start - corridor_end
	_box(Vector3(124, -0.125, corridor_mid), Vector3(8, 0.25, corridor_length), dark, true)
	_box(Vector3(124, 4.75, corridor_mid), Vector3(8, 0.3, corridor_length), hull, true)
	# Open the west corridor wall across z=36..44 for the transfer bridge.
	var west_wall_length := corridor_length - 8.0
	var west_wall_mid := (corridor_end + 36.0) / 2.0
	_box(Vector3(120, 2.25, west_wall_mid), Vector3(0.3, 4.5, west_wall_length), hull, true)
	# Match the room door gaps in the corridor wall so no hidden panel blocks them.
	var wall_cursor := corridor_end
	var sorted_rooms := room_zs.duplicate()
	sorted_rooms.reverse()
	for z in sorted_rooms:
		var wall_end: float = z - 2.0
		if wall_end > wall_cursor:
			_box(Vector3(128, 2.25, (wall_cursor + wall_end) / 2.0), Vector3(0.3, 4.5, wall_end - wall_cursor), hull, true)
		wall_cursor = z + 2.0
	if corridor_start > wall_cursor:
		_box(Vector3(128, 2.25, (wall_cursor + corridor_start) / 2.0), Vector3(0.3, 4.5, corridor_start - wall_cursor), hull, true)
	_box(Vector3(124, 2.25, corridor_start), Vector3(8, 4.5, 0.3), hull, true)
	_box(Vector3(124, 2.25, corridor_end), Vector3(8, 4.5, 0.3), hull, true)
	for room_index in room_count:
		_build_service_room(room_zs[room_index], room_index + 1, rooms[room_index], level, hull, trim, dark, light, amber, glass)
	_box(Vector3(124, 0.05, corridor_mid), Vector3(0.16, 0.08, corridor_length), light)
	_box(Vector3(120.2, 0.05, corridor_mid), Vector3(0.14, 0.08, corridor_length), amber)
	_box(Vector3(127.8, 0.05, corridor_mid), Vector3(0.14, 0.08, corridor_length), amber)
	_label("CONCOURSE  /  SERVICES", Vector3(124, 3.45, 39), 0.018, Color("61e3d8"))
	var stand := Vector3(18, 0.1, 70)
	var bridge_gate := Vector3(37, 0.1, 40)
	var spine_entry := Vector3(124, 0.1, 40)
	for service: Dictionary in interior_services:
		var target: Vector3 = service.position
		var door := Vector3(127.6, 0.1, target.z)
		var spine := Vector3(124, 0.1, target.z)
		# Each leg is a continuous intended walk route from apron, to service, and back.
		for point in [stand, Vector3(18, 0.1, 40), bridge_gate, spine_entry, spine, door, target, door, spine, spine_entry, bridge_gate, Vector3(18, 0.1, 40), stand]:
			interior_route.append(point)
	_add_walk_region(Vector3(36.5, 0, 36), Vector3(83.5, 0, 8))
	_add_walk_region(Vector3(120, 0, corridor_end), Vector3(8, 0, 44 - corridor_end))

func _build_service_room(z: float, room_number: int, page: String, level: int, hull: Material, trim: Material, dark: Material, light: Material, amber: Material, glass: Material) -> void:
	var room_center := Vector3(138, 0, z)
	var room_width := 20.0
	var room_depth := 18.0
	_box(room_center + Vector3(0, -0.125, 0), Vector3(room_width, 0.25, room_depth), dark, true)
	_box(room_center + Vector3(0, 4.75, 0), Vector3(room_width, 0.3, room_depth), hull, true)
	# East wall has two glazed openings framed by collision-backed sill, lintel and posts.
	_box(room_center + Vector3(10, 0.65, 0), Vector3(0.3, 1.3, room_depth), hull, true)
	_box(room_center + Vector3(10, 4.0, 0), Vector3(0.3, 1.0, room_depth), hull, true)
	for post_z in [-8.0, -3.0, 0.0, 3.0, 8.0]:
		_box(room_center + Vector3(10, 2.25, post_z), Vector3(0.3, 3.5, 0.4), trim, true)
	_box(room_center + Vector3(10, 2.4, 0), Vector3(0.12, 2.2, room_depth), glass, true)
	_box(room_center + Vector3(0, 2.25, -9), Vector3(room_width, 4.5, 0.3), hull, true)
	_box(room_center + Vector3(0, 2.25, 9), Vector3(room_width, 4.5, 0.3), hull, true)
	# Four-metre corridor-side doorway at x=128; solid wall segments remain on both sides.
	_box(Vector3(128, 2.25, z - 5.5), Vector3(0.3, 4.5, 7), hull, true)
	_box(Vector3(128, 2.25, z + 5.5), Vector3(0.3, 4.5, 7), hull, true)
	_box(Vector3(128, 4.4, z), Vector3(0.3, 0.2, 4), hull, true)
	for x in [133.0, 143.0]:
		_box(Vector3(x, 0.08, z - 8.7), Vector3(0.16, 0.12, 0.16), light)
		_box(Vector3(x, 0.08, z + 8.7), Vector3(0.16, 0.12, 0.16), light)
	var labels := {"market": "MARKET", "company": "COMPANY", "shipyard": "SHIPYARD", "contracts": "CONTRACTS", "factions": "FACTIONS", "stations": "STATIONS"}
	var label: String = labels.get(page, page.to_upper())
	var target := Vector3(144, 0.1, z)
	interior_services.append({"position": target, "page": page, "label": label, "room": room_number})
	_add_walk_region(Vector3(128, 0, z - 9), Vector3(20, 0, 18))
	# Console and seating stay against the room edges, clear of the central walk lane.
	_box(Vector3(146, 0.65, z), Vector3(1.6, 1.3, 1), dark, true)
	_box(Vector3(145.9, 1.35, z), Vector3(1.4, 0.1, 0.85), amber)
	for side in [-1, 1]:
		_box(Vector3(145.8, 0.48, z + side * 6), Vector3(1, 0.9, 1), trim, true)
	_box(Vector3(138, 1.55, z - 8.7), Vector3(4, 2.8, 0.12), dark)
	_label("ROOM %02d  /  %s  /  LEVEL %d" % [room_number, label, level], Vector3(138, 2.05, z - 8.6), 0.009, Color("61e3d8"))
	_label("ROOM %02d\n%s ACCESS" % [room_number, label], Vector3(124, 3.6, z), 0.015, Color("ffb65c"))
	var task_light := _material(Color("d2c4a4"), 0.0, 1.2)
	for x in [133.0, 143.0]:
		_box(Vector3(x, 4.52, z), Vector3(0.7, 0.06, 10), task_light)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(138, 3.8, z)
	lamp.light_color = Color("d2c4a4")
	lamp.light_energy = 4.8
	lamp.omni_range = 16
	add_child(lamp)

func _add_walk_region(origin: Vector3, size: Vector3) -> void:
	walkable_regions.append(AABB(Vector3(origin.x, -0.5, origin.z), Vector3(size.x, 3.0, size.z)))

func contains_walk_position(point: Vector3) -> bool:
	if point.y < -0.5 or point.y > 2.5:
		return false
	for region in walkable_regions:
		if region.has_point(point):
			return true
	return false

func _label(text: String, at: Vector3, pixel_size: float, color: Color = Color("c4eae7")) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 48
	label.pixel_size = pixel_size
	label.modulate = color
	add_child(label)

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
