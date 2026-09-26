class_name Pilot
extends CharacterBody3D

signal fired(origin: Vector3, direction: Vector3)

var flying: bool = false
var enabled: bool = true
var camera: Camera3D
var speed: float = 8.0

var _pitch: float = 0.0
var _fire_cooldown: float = 0.0
var _cockpit: Node3D


func _ready() -> void:
	var capsule: CollisionShape3D = CollisionShape3D.new()
	var capsule_shape: CapsuleShape3D = CapsuleShape3D.new()
	capsule_shape.radius = 0.38
	capsule_shape.height = 1.8
	capsule.shape = capsule_shape
	capsule.position.y = 0.9
	add_child(capsule)

	camera = Camera3D.new()
	camera.position.y = 1.55
	camera.current = true
	camera.far = 20000.0
	add_child(camera)
	_cockpit = _make_cockpit()
	camera.add_child(_cockpit)
	_cockpit.visible = flying


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-motion.relative.x * 0.0025)
		_pitch = clampf(_pitch - motion.relative.y * 0.0025, -1.45, 1.45)
		camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if not enabled:
		velocity = Vector3.ZERO
		return
	if flying:
		_fly()
	else:
		_walk(delta)
	if Input.is_action_pressed("fire") and _fire_cooldown <= 0.0:
		_fire_cooldown = 0.18
		fired.emit(camera.global_position, -camera.global_basis.z)


func _walk(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		if Input.is_action_just_pressed("move_up"):
			velocity.y = 6.0

	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var target_speed: float = speed * (1.8 if Input.is_action_pressed("boost") else 1.0)
	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed
	move_and_slide()


func _fly() -> void:
	var forward_back: float = Input.get_axis("move_back", "move_forward")
	var left_right: float = Input.get_axis("move_left", "move_right")
	var up_down: float = Input.get_axis("move_down", "move_up")
	var local_direction: Vector3 = Vector3(left_right, up_down, -forward_back)
	if local_direction.length_squared() > 1.0:
		local_direction = local_direction.normalized()
	var flight_speed: float = speed * 3.5 * (1.8 if Input.is_action_pressed("boost") else 1.0)
	velocity = camera.global_basis * local_direction * flight_speed
	move_and_slide()


func set_flight(value: bool) -> void:
	flying = value
	if is_instance_valid(_cockpit):
		_cockpit.visible = flying
	if camera != null:
		camera.rotation.x = _pitch


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO


func _make_cockpit() -> Node3D:
	var cockpit: Node3D = Node3D.new()
	var positions: Array[Vector3] = [
		Vector3(-0.62, -0.32, -1.0), Vector3(0.62, -0.32, -1.0),
		Vector3(0.0, -0.52, -1.0), Vector3(0.0, 0.1, -1.0),
	]
	var sizes: Array[Vector3] = [
		Vector3(0.045, 0.42, 0.045), Vector3(0.045, 0.42, 0.045),
		Vector3(1.24, 0.045, 0.045), Vector3(1.24, 0.045, 0.045),
	]
	for index: int in range(positions.size()):
		var bar: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = sizes[index]
		bar.mesh = mesh
		bar.position = positions[index]
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.12, 0.85, 0.92, 0.9)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bar.material_override = material
		cockpit.add_child(bar)
	return cockpit
