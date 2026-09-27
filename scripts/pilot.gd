class_name Pilot
extends CharacterBody3D

signal fired(origin: Vector3, direction: Vector3)
signal autopilot_arrived

var flying: bool = false
var enabled: bool = true
var camera: Camera3D
var speed: float = 8.0
var flight_speed: float = 140.0
var mouse_sensitivity: float = 0.0025
var inverted_y: bool = false
var fire_interval: float = 0.16
var autopilot_target: Vector3 = Vector3.ZERO
var autopilot_active: bool = false

var _pitch: float = 0.0
var _fire_cooldown: float = 0.0
var _cockpit: Node3D
var _gun: Node3D
var _flight_velocity: Vector3 = Vector3.ZERO
var _walk_velocity: Vector3 = Vector3.ZERO
var _recoil: float = 0.0
var _shake: float = 0.0
var _roll: float = 0.0
var _look_sway: Vector2 = Vector2.ZERO


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.38
	capsule_shape.height = 1.8
	capsule.shape = capsule_shape
	capsule.position.y = 0.9
	add_child(capsule)

	camera = Camera3D.new()
	camera.position.y = 1.55
	camera.current = true
	camera.far = 30000.0
	camera.near = 0.05
	add_child(camera)
	_cockpit = _make_cockpit()
	camera.add_child(_cockpit)
	_gun = _make_gun()
	camera.add_child(_gun)
	_cockpit.visible = flying
	_gun.visible = not flying
	_gun.position = Vector3(0.46, -0.36, -1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion:
		cancel_autopilot()
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		var motion := event as InputEventMouseMotion
		if flying:
			rotate_y(-motion.relative.x * mouse_sensitivity)
		else:
			rotate_object_local(Vector3.UP, -motion.relative.x * mouse_sensitivity)
		var y_sign := 1.0 if inverted_y else -1.0
		_pitch = clampf(_pitch + motion.relative.y * mouse_sensitivity * y_sign, -1.45, 1.45)
		camera.rotation.x = _pitch
		_look_sway = Vector2(-motion.relative.x, -motion.relative.y).clamp(Vector2(-35, -35), Vector2(35, 35))


func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_recoil = move_toward(_recoil, 0.0, delta * 2.8)
	_shake = move_toward(_shake, 0.0, delta * 5.0)
	_look_sway = _look_sway.lerp(Vector2.ZERO, minf(1.0, delta * 9.0))
	if not enabled:
		velocity = Vector3.ZERO
		return
	if flying:
		_fly(delta)
	else:
		_walk(delta)
	if Input.is_action_pressed("fire") and _fire_cooldown <= 0.0:
		_fire_cooldown = fire_interval
		_recoil = 0.13
		fired.emit(camera.global_position, -camera.global_basis.z)
	_update_view_effects(delta)


func _walk(delta: float) -> void:
	var up: Vector3 = up_direction
	if not is_on_floor():
		_walk_velocity -= up * 18.0 * delta
	elif Input.is_action_just_pressed("move_up"):
		_walk_velocity += up * maxf(0.0, 6.0 - _walk_velocity.dot(up))
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (global_basis * Vector3(input.x, 0.0, input.y)).slide(up).normalized()
	var target_speed := speed * (1.8 if Input.is_action_pressed("boost") else 1.0)
	var tangent_velocity: Vector3 = _walk_velocity.slide(up)
	tangent_velocity = tangent_velocity.move_toward(direction * target_speed, 32.0 * delta)
	_walk_velocity = tangent_velocity + up * _walk_velocity.dot(up)
	velocity = _walk_velocity
	move_and_slide()
	_walk_velocity = velocity


func _fly(delta: float) -> void:
	var forward_back := Input.get_axis("move_back", "move_forward")
	var left_right := Input.get_axis("move_left", "move_right")
	var up_down := Input.get_axis("move_down", "move_up")
	var local_direction := Vector3(left_right, up_down, -forward_back)
	if local_direction.length_squared() > 1.0:
		local_direction = local_direction.normalized()
	var rolling := Input.is_action_pressed("roll_left") or Input.is_action_pressed("roll_right")
	if autopilot_active and (local_direction.length_squared() > 0.001 or rolling):
		cancel_autopilot()
	var desired: Vector3
	var response := 2.8
	if autopilot_active:
		var offset := autopilot_target - global_position
		var distance := offset.length()
		if distance <= 2.0:
			autopilot_active = false
			_flight_velocity = Vector3.ZERO
			desired = Vector3.ZERO
			autopilot_arrived.emit()
		else:
			var direction := offset / distance
			var approach := clampf(distance / 50.0, 0.0, 1.0)
			approach = approach * approach * (3.0 - 2.0 * approach)
			desired = direction * flight_speed * approach
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 0.85)
			_pitch = lerpf(_pitch, asin(clampf(direction.y, -1.0, 1.0)), minf(1.0, delta * 0.85))
			camera.rotation.x = _pitch
		response = 1.8 if distance > 2.0 else 1.15
	else:
		var boost_scale := 3.0 if Input.is_action_pressed("boost") else 1.0
		desired = camera.global_basis * local_direction * flight_speed * boost_scale
		response = 2.8 if local_direction.length_squared() > 0.001 else 1.15
	_flight_velocity = _flight_velocity.lerp(desired, minf(1.0, response * delta))
	velocity = _flight_velocity
	if Input.is_action_pressed("roll_left"):
		_roll += 1.5 * delta
	elif Input.is_action_pressed("roll_right"):
		_roll -= 1.5 * delta
	else:
		_roll = move_toward(_roll, 0.0, delta * 0.8)
	camera.rotation.z = _roll
	move_and_slide()
	_flight_velocity = velocity


func _update_view_effects(delta: float) -> void:
	if camera == null:
		return
	var boost_amount := 1.0 if flying and Input.is_action_pressed("boost") else 0.0
	camera.fov = lerpf(camera.fov, 75.0 + boost_amount * 11.0, minf(1.0, delta * 4.0))
	camera.position.x = _look_sway.x * 0.00035 + randf_range(-_shake, _shake) * 0.004
	camera.position.y = 1.55 + _recoil * 0.08 + _look_sway.y * 0.0002 + randf_range(-_shake, _shake) * 0.004
	if is_instance_valid(_gun):
		_gun.position = Vector3(0.46, -0.36 - _recoil, -1.0)
		_gun.rotation.x = -_recoil * 0.6


func kick(amount: float) -> void:
	_shake = maxf(_shake, clampf(amount, 0.0, 1.0))
	_recoil = maxf(_recoil, clampf(amount * 0.08, 0.0, 0.2))


func autopilot_to(point: Vector3) -> void:
	if not (is_finite(point.x) and is_finite(point.y) and is_finite(point.z)):
		return
	autopilot_target = point
	autopilot_active = flying


func cancel_autopilot() -> void:
	autopilot_active = false


func reset_view() -> void:
	rotation = Vector3.ZERO
	_pitch = 0.0
	_roll = 0.0
	_look_sway = Vector2.ZERO
	if camera != null:
		camera.rotation = Vector3.ZERO


func set_flight(value: bool) -> void:
	if value: set_walk_up(Vector3.UP)
	flying = value
	cancel_autopilot()
	_flight_velocity = Vector3.ZERO
	_walk_velocity = Vector3.ZERO
	if is_instance_valid(_cockpit):
		_cockpit.visible = flying
	if is_instance_valid(_gun):
		_gun.visible = not flying
	if camera != null:
		camera.rotation.x = _pitch


func set_walk_up(up: Vector3) -> void:
	var length: float = up.length()
	if not up.is_finite() or not is_finite(length) or length < 0.001:
		return
	var normal := up / length
	var forward := (-global_basis.z).slide(normal)
	if forward.length_squared() < 0.000001:
		var right := global_basis.x.slide(normal)
		if right.length_squared() < 0.000001:
			var fallback: Vector3 = Vector3.FORWARD if absf(normal.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
			right = fallback.slide(normal)
		forward = normal.cross(right.normalized())
	forward = forward.normalized()
	var right_axis := forward.cross(normal).normalized()
	forward = normal.cross(right_axis).normalized()
	global_basis = Basis(right_axis, normal, -forward)
	up_direction = normal


func teleport(pos: Vector3) -> void:
	global_position = pos
	cancel_autopilot()
	velocity = Vector3.ZERO
	_flight_velocity = Vector3.ZERO
	_walk_velocity = Vector3.ZERO


func _make_cockpit() -> Node3D:
	var cockpit := Node3D.new()
	var frame_mat := _mat(Color("172a3d"), 0.0, 0.0)
	var trim_mat := _mat(Color("43d9dc"), 0.0, 1.8)
	var glass_mat := _mat(Color(0.12, 0.65, 0.82, 0.26), 0.0, 0.5)
	# Keep the windscreen center open; the frame and angled consoles stay low.
	_add_box(cockpit, Vector3(-0.72, -0.14, -1.08), Vector3(0.08, 0.62, 0.09), frame_mat)
	_add_box(cockpit, Vector3(0.72, -0.14, -1.08), Vector3(0.08, 0.62, 0.09), frame_mat)
	_add_box(cockpit, Vector3(0.0, 0.19, -1.08), Vector3(1.42, 0.06, 0.09), frame_mat)
	_add_box(cockpit, Vector3(-0.48, -0.45, -0.82), Vector3(0.68, 0.12, 0.48), frame_mat, Vector3(0, -0.2, -0.16))
	_add_box(cockpit, Vector3(0.48, -0.45, -0.82), Vector3(0.68, 0.12, 0.48), frame_mat, Vector3(0, 0.2, 0.16))
	_add_box(cockpit, Vector3(-0.48, -0.365, -0.82), Vector3(0.5, 0.012, 0.27), trim_mat, Vector3(0, -0.2, -0.16))
	_add_box(cockpit, Vector3(0.48, -0.365, -0.82), Vector3(0.5, 0.012, 0.27), trim_mat, Vector3(0, 0.2, 0.16))
	_add_box(cockpit, Vector3(0, -0.48, -1.0), Vector3(0.32, 0.16, 0.38), frame_mat)
	_add_box(cockpit, Vector3(0, -0.385, -1.0), Vector3(0.22, 0.025, 0.2), glass_mat)
	_add_box(cockpit, Vector3(-0.67, 0.1, -1.0), Vector3(0.055, 0.04, 0.04), trim_mat)
	_add_box(cockpit, Vector3(0.67, 0.1, -1.0), Vector3(0.055, 0.04, 0.04), trim_mat)
	for index in range(5):
		_add_box(cockpit, Vector3(-0.63 + index * 0.07, -0.38, -0.68), Vector3(0.025, 0.014, 0.025), _mat(Color("9ffff0"), 0.0, 2.5))
		_add_box(cockpit, Vector3(0.35 + index * 0.07, -0.38, -0.68), Vector3(0.025, 0.014, 0.025), _mat(Color("ffb45e"), 0.0, 1.8))
	return cockpit


func _make_gun() -> Node3D:
	var gun := Node3D.new()
	gun.scale = Vector3.ONE * 0.68
	var dark := _mat(Color("172434"), 0.4, 0.0)
	var metal := _mat(Color("91a8b9"), 0.28, 0.0)
	var trim := _mat(Color("4e687b"), 0.32, 0.0)
	var glow := _mat(Color("55dccc"), 0.25, 1.9)
	var amber := _mat(Color("ffb45e"), 0.22, 2.1)
	var glove := _mat(Color("202b34"), 0.62, 0.0)
	var sleeve := _mat(Color("34414c"), 0.72, 0.0)
	# Slim receiver, twin barrel rails, iron sights, trigger and angled grip.
	_add_box(gun, Vector3(0, 0, -0.02), Vector3(0.15, 0.13, 0.42), dark)
	_add_box(gun, Vector3(0, 0.075, -0.075), Vector3(0.12, 0.025, 0.36), trim)
	_add_box(gun, Vector3(0, 0.052, -0.08), Vector3(0.035, 0.012, 0.3), metal)
	for side in [-1, 1]:
		var rail := _gun_cylinder(gun, Vector3(float(side) * 0.072, -0.005, -0.16), 0.022, 0.55, metal)
		rail.rotation.x = PI * 0.5
		_add_box(gun, Vector3(float(side) * 0.047, 0.055, -0.27), Vector3(0.025, 0.07, 0.045), trim)
		_add_box(gun, Vector3(float(side) * 0.047, 0.055, 0.12), Vector3(0.025, 0.07, 0.045), trim)
	_add_box(gun, Vector3(0, 0.13, -0.27), Vector3(0.055, 0.025, 0.04), metal)
	_add_box(gun, Vector3(0, 0.13, 0.12), Vector3(0.055, 0.025, 0.04), metal)
	_add_box(gun, Vector3(0, -0.018, 0.21), Vector3(0.1, 0.19, 0.14), dark, Vector3(-0.28, 0, 0))
	_add_box(gun, Vector3(0, -0.12, 0.2), Vector3(0.095, 0.04, 0.13), trim, Vector3(-0.28, 0, 0))
	# Gloved hand and cuff connect the receiver to the player in first person.
	_add_box(gun, Vector3(0.015, -0.09, 0.19), Vector3(0.11, 0.08, 0.1), glove)
	var forearm := _gun_cylinder(gun, Vector3(0.18, -0.24, 0.16), 0.06, 0.25, sleeve)
	forearm.rotation.z = PI * 0.22
	_add_box(gun, Vector3(0.12, -0.12, 0.17), Vector3(0.14, 0.07, 0.06), trim)
	_add_box(gun, Vector3(0.015, -0.025, 0.095), Vector3(0.028, 0.045, 0.035), amber)
	_add_box(gun, Vector3(0, -0.075, 0.05), Vector3(0.1, 0.012, 0.11), metal)
	var muzzle := _gun_cylinder(gun, Vector3(0, 0, -0.35), 0.068, 0.12, trim)
	muzzle.rotation.x = PI * 0.5
	var muzzle_light := _gun_cylinder(gun, Vector3(0, 0, -0.42), 0.037, 0.025, amber)
	muzzle_light.rotation.x = PI * 0.5
	_add_box(gun, Vector3(0.09, 0.025, -0.03), Vector3(0.02, 0.028, 0.12), glow)
	return gun


func _gun_cylinder(parent: Node3D, pos: Vector3, radius: float, length: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.92
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 10
	mesh.mesh = cylinder
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.position = pos
	return mesh


func _add_box(parent: Node3D, pos: Vector3, dimensions: Vector3, material: Material, angles: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.position = pos
	mesh.rotation = angles
	return mesh


func _mat(color: Color, roughness: float, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.58
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func restore_view(angles: Vector3) -> void:
	rotation = Vector3(0, angles.y, 0)
	_pitch = angles.x
	_roll = angles.z
	camera.rotation = Vector3(_pitch, 0, _roll)
