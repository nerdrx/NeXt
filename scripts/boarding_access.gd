class_name BoardingAccess
extends Node3D

const DEFAULT_WIDTH := 1.5
const DEFAULT_RISE := 0.75
const DEFAULT_LENGTH := 2.8
const SLAB_DEPTH := 0.12

var _ramp_collision: CollisionShape3D
var _built_nodes: Array[Node] = []


func _ready() -> void:
	visibility_changed.connect(_update_collision_visibility)
	_update_collision_visibility()


func build(width: float = DEFAULT_WIDTH, rise: float = DEFAULT_RISE, length: float = DEFAULT_LENGTH) -> void:
	_clear_build()
	width = _bounded_dimension(width, DEFAULT_WIDTH, 0.5, 12.0)
	rise = _bounded_dimension(rise, DEFAULT_RISE, 0.1, 4.0)
	length = _bounded_dimension(length, DEFAULT_LENGTH, 0.5, 12.0)
	var half_width := width * 0.5
	var upper_left := Vector3(0.0, 0.0, -half_width)
	var lower_left := Vector3(length, -rise, -half_width)
	var lower_under_left := lower_left + Vector3.DOWN * SLAB_DEPTH
	var upper_under_left := Vector3(0.0, -SLAB_DEPTH, -half_width)
	var upper_right := Vector3(0.0, 0.0, half_width)
	var lower_right := Vector3(length, -rise, half_width)
	var lower_under_right := lower_right + Vector3.DOWN * SLAB_DEPTH
	var upper_under_right := Vector3(0.0, -SLAB_DEPTH, half_width)
	var points := PackedVector3Array([
		upper_left, lower_left, lower_under_left, upper_under_left,
		upper_right, lower_right, lower_under_right, upper_under_right,
	])
	var mesh := _wedge_mesh(points, length, rise)
	var steel := _material(Color(0.28, 0.34, 0.38), 0.72, 0.36)
	var edge := _material(Color(0.72, 0.55, 0.22), 0.48, 0.48)
	var rail_material := _material(Color(0.42, 0.48, 0.51), 0.78, 0.3)
	var slab := MeshInstance3D.new()
	slab.name = "Ramp"
	slab.mesh = mesh
	slab.material_override = steel
	add_child(slab)
	_built_nodes.append(slab)
	var body := StaticBody3D.new()
	body.name = "RampCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	_ramp_collision = CollisionShape3D.new()
	_ramp_collision.name = "RampShape"
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_ramp_collision.shape = shape
	body.add_child(_ramp_collision)
	add_child(body)
	_built_nodes.append(body)
	for side: float in [-1.0, 1.0]:
		_add_beam("EdgeStrip", length, rise, side * (half_width - 0.04), 0.025, 0.055, edge)
		var rail_z := side * (half_width + 0.035)
		_add_beam("Handrail", length, rise, rail_z, 1.0, 0.065, rail_material)
		for post_x: float in [0.0, length * 0.5, length]:
			var surface_y := -rise * post_x / length
			var post := MeshInstance3D.new()
			post.name = "RailPost"
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.055, 0.96, 0.055)
			post.mesh = post_mesh
			post.material_override = rail_material
			post.position = Vector3(post_x, surface_y + 0.52, rail_z)
			add_child(post)
			_built_nodes.append(post)
	_update_collision_visibility()


func _clear_build() -> void:
	for node in _built_nodes:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_built_nodes.clear()
	_ramp_collision = null


func _update_collision_visibility() -> void:
	if is_instance_valid(_ramp_collision):
		_ramp_collision.set_deferred("disabled", not is_visible_in_tree())


func _add_beam(node_name: String, length: float, rise: float, z: float, height: float, thickness: float, material: Material) -> void:
	var beam := MeshInstance3D.new()
	beam.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3(Vector2(length, rise).length(), thickness, 0.055 if node_name == "EdgeStrip" else thickness)
	beam.mesh = box
	beam.material_override = material
	beam.position = Vector3(length * 0.5, -rise * 0.5 + height, z)
	beam.rotation.z = -atan2(rise, length)
	add_child(beam)
	_built_nodes.append(beam)


func _wedge_mesh(points: PackedVector3Array, length: float, rise: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var upper_left: Vector3 = points[0]
	var lower_left: Vector3 = points[1]
	var lower_under_left: Vector3 = points[2]
	var upper_under_left: Vector3 = points[3]
	var upper_right: Vector3 = points[4]
	var lower_right: Vector3 = points[5]
	var lower_under_right: Vector3 = points[6]
	var upper_under_right: Vector3 = points[7]
	var slope_normal := Vector3(rise, length, 0.0).normalized()
	_add_face(st, upper_left, lower_left, lower_right, upper_right, slope_normal)
	_add_face(st, upper_under_left, upper_under_right, lower_under_right, lower_under_left, -slope_normal)
	_add_face(st, upper_left, upper_under_left, upper_under_right, upper_right, Vector3.LEFT)
	_add_face(st, lower_left, lower_right, lower_under_right, lower_under_left, Vector3.RIGHT)
	_add_face(st, upper_left, lower_left, lower_under_left, upper_under_left, Vector3.FORWARD)
	_add_face(st, upper_right, upper_under_right, lower_under_right, lower_right, Vector3.BACK)
	st.generate_normals()
	return st.commit()


func _add_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	HullGeometry._add_oriented_triangle(st, a, b, c, outward)
	HullGeometry._add_oriented_triangle(st, a, c, d, outward)


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _bounded_dimension(value: float, fallback: float, minimum: float, maximum: float) -> float:
	if not is_finite(value) or value <= 0.0:
		return fallback
	return clampf(value, minimum, maximum)
