class_name PlanetTerrain
extends Node3D

const GRID: int = 48
const MAX_EXTENT: float = 200.0

var anchor: Vector3 = Vector3.ZERO
var normal_at_patch: Vector3:
	get: return _normal
var patch_extent: float = 0.0
var terrain_mesh: ArrayMesh
var terrain_body: StaticBody3D
var _normal: Vector3 = Vector3.UP


func build(radius: float, normal: Vector3, seed: int, tint: Color) -> void:
	for child: Node in get_children():
		child.queue_free()
	terrain_mesh = null
	terrain_body = null
	var safe_radius: float = maxf(radius, 1.0) if is_finite(radius) else 1.0
	_normal = normal.normalized() if normal.is_finite() and normal.length_squared() > 0.000001 else Vector3.UP
	anchor = _normal * safe_radius
	patch_extent = minf(MAX_EXTENT, safe_radius * 0.35)
	var reference := Vector3.UP if absf(_normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var tangent := _normal.cross(reference).normalized()
	var bitangent := _normal.cross(tangent).normalized()
	var side: int = GRID + 1
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	var vertices := PackedVector3Array()
	vertices.resize(side * side)
	var step: float = patch_extent * 2.0 / GRID
	for z: int in side:
		for x: int in side:
			var u: float = -patch_extent + float(x) * step
			var v: float = -patch_extent + float(z) * step
			var direction := (anchor + tangent * u + bitangent * v).normalized()
			var height: float = PlanetHeightField.surface_height(direction, seed)
			var index: int = z * side + x
			heights[index] = height
			vertices[index] = direction * (safe_radius + height) - anchor
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in side:
		for x: int in side:
			var index: int = z * side + x
			var left: int = z * side + maxi(0, x - 1)
			var right: int = z * side + mini(GRID, x + 1)
			var down: int = maxi(0, z - 1) * side + x
			var up: int = mini(GRID, z + 1) * side + x
			var dx: float = (heights[right] - heights[left]) / (step * (2.0 if x > 0 and x < GRID else 1.0))
			var dz: float = (heights[up] - heights[down]) / (step * (2.0 if z > 0 and z < GRID else 1.0))
			var slope: float = clampf(Vector2(dx, dz).length(), 0.0, 1.0)
			var altitude: float = heights[index] / 12.0
			var color: Color = tint.darkened(0.28 * slope).lerp(tint.lightened(0.18), altitude * 0.42)
			surface.set_color(color)
			surface.add_vertex(vertices[index])
	for z: int in GRID:
		for x: int in GRID:
			var a: int = z * side + x
			var b: int = a + 1
			var c: int = a + side
			var d: int = c + 1
			surface.add_index(a)
			surface.add_index(c)
			surface.add_index(b)
			surface.add_index(b)
			surface.add_index(c)
			surface.add_index(d)
	surface.generate_normals()
	terrain_mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/terrain_rock.gdshader")
	material.set_shader_parameter("planet_anchor", anchor)
	var visual := MeshInstance3D.new()
	visual.name = "Planet terrain patch"
	visual.mesh = terrain_mesh
	visual.material_override = material
	add_child(visual)
	terrain_body = StaticBody3D.new()
	terrain_body.name = "Terrain collision"
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(terrain_mesh.get_faces())
	collision.shape = shape
	terrain_body.add_child(collision)
	add_child(terrain_body)


static func surface_height(direction: Vector3, seed: int) -> float:
	return PlanetHeightField.surface_height(direction, seed)
