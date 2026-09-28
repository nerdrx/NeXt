class_name PortNavigation
extends RefCounted

# Private local map: planetary rotation and floating-origin shifts never rebake it.
var source := NavigationMeshSourceGeometryData3D.new()
var navigation_mesh: NavigationMesh
var map := RID()
var region := RID()
var bake_bounds := AABB(Vector3(-90, -2, -100), Vector3(180, 5.8, 170))
var cell_size := 0.25

func add_box(mesh: BoxMesh, transform: Transform3D) -> void:
	var h := mesh.size * 0.5
	var corners := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var faces := PackedVector3Array()
	# Clockwise exterior faces, matching Godot's mesh winding.
	for index in [
		0, 1, 2, 0, 2, 3, 5, 4, 7, 5, 7, 6,
		4, 0, 3, 4, 3, 7, 1, 5, 6, 1, 6, 2,
		3, 2, 6, 3, 6, 7, 4, 5, 1, 4, 1, 0,
	]:
		faces.append(transform * corners[index])
	source.add_faces(faces, Transform3D.IDENTITY)

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not from.is_finite() or not to.is_finite():
		return PackedVector3Array()
	if not map.is_valid():
		_bake()
	var start := NavigationServer3D.map_get_closest_point(map, from)
	var end := NavigationServer3D.map_get_closest_point(map, to)
	if start.distance_to(from) > 1.5 or end.distance_to(to) > 1.5:
		return PackedVector3Array()
	var result := NavigationServer3D.map_get_path(map, start, end, true)
	# Godot returns a partial path for disconnected destinations.
	if result.is_empty() or result[-1].distance_to(end) > 0.1:
		return PackedVector3Array()
	return result

func _bake() -> void:
	navigation_mesh = NavigationMesh.new()
	navigation_mesh.cell_size = cell_size
	navigation_mesh.cell_height = 0.1
	navigation_mesh.agent_radius = 0.5
	navigation_mesh.agent_height = 1.8
	navigation_mesh.agent_max_climb = 0.3
	navigation_mesh.filter_baking_aabb = bake_bounds
	NavigationServer3D.bake_from_source_geometry_data(navigation_mesh, source)
	map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_use_async_iterations(map, false)
	NavigationServer3D.map_set_cell_size(map, navigation_mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map, navigation_mesh.cell_height)
	NavigationServer3D.map_set_active(map, true)
	region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_use_async_iterations(region, false)
	NavigationServer3D.region_set_navigation_mesh(region, navigation_mesh)
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.map_force_update(map)

func dispose() -> void:
	if region.is_valid():
		NavigationServer3D.free_rid(region)
		region = RID()
	if map.is_valid():
		NavigationServer3D.free_rid(map)
		map = RID()
