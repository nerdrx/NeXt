class_name ShipBulkhead
extends Node3D

const LEAF_WIDTH := 0.465
const LEAF_HEIGHT := 2.12
const LEAF_DEPTH := 0.06
const CLOSED_CENTERS := [-0.6975, -0.2325, 0.2325, 0.6975]
const OPEN_CENTERS := [-1.2, -1.2, 1.2, 1.2]
const TRAVEL_TIME := 0.4
const HOLD_TIME := 0.8

var open_fraction: float = 0.0

var _leaves: Array[StaticBody3D] = []
var _leaf_centers: Array[Vector3] = []
var _open_centers: Array[Vector3] = []
var _sensor: Area3D
var _sensor_shape: CollisionShape3D
var _hold_remaining := 0.0


func _ready() -> void:
	_build()
	visibility_changed.connect(_update_visibility)
	_update_visibility()


func _physics_process(delta: float) -> void:
	if not _sensor.monitoring: return
	var occupied := false
	for body: Node3D in _sensor.get_overlapping_bodies():
		if body is CharacterBody3D:
			occupied = true
			break
	if occupied:
		_hold_remaining = HOLD_TIME
	else:
		_hold_remaining = maxf(0.0, _hold_remaining - delta)
	var target := 1.0 if occupied or _hold_remaining > 0.0 else 0.0
	open_fraction = move_toward(open_fraction, target, delta / TRAVEL_TIME)
	for index in _leaves.size():
		_leaves[index].position = _leaf_centers[index].lerp(_open_centers[index], open_fraction)


func _build() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.28, 0.34, 0.38)
	steel.metallic = 0.08
	steel.roughness = 0.48
	var grip_material := StandardMaterial3D.new()
	grip_material.albedo_color = Color("87969b")
	grip_material.metallic = 0.8
	grip_material.roughness = 0.3
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.22, 0.035, LEAF_DEPTH + 0.012)
	for index in 4:
		var center := Vector3(CLOSED_CENTERS[index], LEAF_HEIGHT * 0.5, 0.0)
		var stacked_center := Vector3(OPEN_CENTERS[index], LEAF_HEIGHT * 0.5, -0.065 if index % 2 == 0 else 0.065)
		_leaf_centers.append(center)
		_open_centers.append(stacked_center)
		var body := StaticBody3D.new()
		body.name = "BulkheadLeaf%d" % index
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = Vector3(LEAF_WIDTH, LEAF_HEIGHT, LEAF_DEPTH)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		var mesh := BoxMesh.new()
		mesh.size = shape.size - Vector3(0.012, 0, 0)
		var panel := MeshInstance3D.new()
		panel.mesh = mesh
		panel.material_override = steel
		body.add_child(panel)
		var grip := MeshInstance3D.new()
		grip.mesh = grip_mesh
		grip.material_override = grip_material
		grip.position.y = 0.15
		body.add_child(grip)
		body.position = center
		add_child(body)
		_leaves.append(body)
	_sensor = Area3D.new()
	_sensor.name = "OccupancySensor"
	_sensor.collision_layer = 0
	# Layer 2 includes the enclosing coasting ship: it must never trigger doors.
	# Aboard pilots carry layer 8; crew use layer 4.
	_sensor.collision_mask = 4 | 8
	var sensor_shape := BoxShape3D.new()
	sensor_shape.size = Vector3(2.4, 2.2, 3.2)
	_sensor_shape = CollisionShape3D.new()
	_sensor_shape.shape = sensor_shape
	_sensor.add_child(_sensor_shape)
	_sensor.position = Vector3(0.0, 1.15, 0.0)
	add_child(_sensor)


func _update_visibility() -> void:
	var enabled := is_visible_in_tree()
	set_physics_process(enabled)
	if is_instance_valid(_sensor):
		_sensor.set_deferred("monitoring", enabled)
		_sensor_shape.set_deferred("disabled", not enabled)
	for leaf: StaticBody3D in _leaves:
		var collision := leaf.get_child(0) as CollisionShape3D
		collision.set_deferred("disabled", not enabled)
