class_name Pilot
extends CharacterBody3D

signal fired(origin: Vector3, direction: Vector3)
signal autopilot_arrived
signal autopilot_blocked
signal flight_impact(closing_speed: float)

var braking: bool = false
var thrust_g: float = 0.0
var acceleration_mps2: float = FlightDynamics.STANDARD_GRAVITY * FlightDynamics.CRUISE_G
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
var _flight_impact_cooldown: float = 0.0
var hull_radius: float = 0.9
var _walk_shape: CollisionShape3D
var _module_shapes: Array[CollisionShape3D] = []
var _module_centers: Array[Vector3] = []
var _module_collision_hash: String = ""
var _collision_update_pending: bool = false
var _has_configured_ship: bool = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_walk_shape = CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.38
	capsule_shape.height = 1.8
	_walk_shape.shape = capsule_shape
	_walk_shape.position.y = 0.9
	add_child(_walk_shape)

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
	thrust_g = 0.0
	_flight_impact_cooldown = maxf(0.0, _flight_impact_cooldown - delta)
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_recoil = move_toward(_recoil, 0.0, delta * 2.8)
	_shake = move_toward(_shake, 0.0, delta * 5.0)
	_look_sway = _look_sway.lerp(Vector2.ZERO, minf(1.0, delta * 9.0))
	if not enabled:
		if flying and braking and not _collision_update_pending:
			_update_module_collision_basis()
			_fly(delta)
		else: velocity = Vector3.ZERO
		return
	if _collision_update_pending:
		velocity = Vector3.ZERO
		return
	_update_module_collision_basis()
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
	var forward_back := Input.get_axis("move_back", "move_forward") if enabled else 0.0
	var left_right := Input.get_axis("move_left", "move_right") if enabled else 0.0
	var up_down := Input.get_axis("move_down", "move_up") if enabled else 0.0
	var local_direction := Vector3(left_right, up_down, -forward_back)
	if local_direction.length_squared() > 1.0:
		local_direction = local_direction.normalized()
	var rolling := enabled and (Input.is_action_pressed("roll_left") or Input.is_action_pressed("roll_right"))
	if local_direction.length_squared() > 0.001: braking = false
	if autopilot_active and (local_direction.length_squared() > 0.001 or rolling):
		cancel_autopilot()
	var desired: Vector3
	var incoming_thrust := _flight_velocity
	var boosting := enabled and Input.is_action_pressed("boost") and not autopilot_active and not braking
	if autopilot_active:
		var offset := autopilot_target - global_position
		var distance := offset.length()
		if distance <= 2.0 and _flight_velocity.length() <= FlightDynamics.usable_acceleration(acceleration_mps2) * delta:
			autopilot_active = false
			_flight_velocity = Vector3.ZERO
			desired = Vector3.ZERO
			autopilot_arrived.emit()
		else:
			var direction := offset / distance if distance > 0.000001 else -_flight_velocity.normalized()
			desired = direction * FlightDynamics.approach_speed(distance, flight_speed, acceleration_mps2)
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 0.85)
			_pitch = lerpf(_pitch, asin(clampf(direction.y, -1.0, 1.0)), minf(1.0, delta * 0.85))
			camera.rotation.x = _pitch
	else:
		var boost_scale := 3.0 if boosting else 1.0
		desired = Vector3.ZERO if braking else camera.global_basis * local_direction * flight_speed * boost_scale
	_flight_velocity = FlightDynamics.command_velocity(_flight_velocity, desired, delta, boosting, acceleration_mps2)
	thrust_g = FlightDynamics.thrust_load(incoming_thrust, _flight_velocity, delta)
	if not _flight_velocity.is_finite():
		_flight_velocity = Vector3.ZERO
	if autopilot_active:
		_update_module_collision_basis()
		var lookahead := maxf(5.0, FlightDynamics.braking_distance(incoming_thrust.length(), acceleration_mps2) + incoming_thrust.length() * delta + 2.0)
		if lookahead > 0.0 and _flight_velocity.length_squared() > 0.0 and test_move(global_transform, _flight_velocity.normalized() * lookahead):
			request_brake()
			_flight_velocity = FlightDynamics.command_velocity(incoming_thrust, Vector3.ZERO, delta, false, acceleration_mps2)
			thrust_g = FlightDynamics.thrust_load(incoming_thrust, _flight_velocity, delta)
			autopilot_blocked.emit()
	if braking and _flight_velocity.is_zero_approx(): braking = false
	velocity = _flight_velocity
	if enabled and Input.is_action_pressed("roll_left"):
		_roll += 1.5 * delta
	elif enabled and Input.is_action_pressed("roll_right"):
		_roll -= 1.5 * delta
	else:
		_roll = move_toward(_roll, 0.0, delta * 0.8)
	camera.rotation.z = _roll
	_update_module_collision_basis()
	move_and_slide()
	var incoming := _flight_velocity
	_flight_velocity = velocity
	if incoming.is_finite() and _flight_impact_cooldown <= 0.0:
		var max_closing := 0.0
		for index in get_slide_collision_count():
			var normal := get_slide_collision(index).get_normal()
			if normal.is_finite():
				max_closing = maxf(max_closing, -incoming.dot(normal))
		if is_finite(max_closing) and max_closing > 25.0:
			_flight_impact_cooldown = 0.7
			flight_impact.emit(max_closing)


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
	braking = false
	autopilot_target = point
	autopilot_active = flying


func request_brake() -> void:
	cancel_autopilot()
	braking = flying and not _flight_velocity.is_zero_approx()


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
	braking = false
	thrust_g = 0.0
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
	_sync_collision_mode()


func configure_ship_collision(modules: Array) -> void:
	_has_configured_ship = not modules.is_empty()
	var cells: Array[Vector3i] = []
	for module: Dictionary in modules:
		var cell := Vector3i(int(module.x), int(module.y), int(module.z))
		if cell not in cells:
			cells.append(cell)
	cells.sort()
	var keys: Array[String] = []
	for cell: Vector3i in cells:
		keys.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	keys.sort()
	var signature := ",".join(keys)
	if signature == _module_collision_hash:
		return
	_module_collision_hash = signature
	hull_radius = 0.9
	if not cells.is_empty():
		var low := cells[0]
		var high := cells[0]
		for cell: Vector3i in cells:
			low = Vector3i(mini(low.x, cell.x), mini(low.y, cell.y), mini(low.z, cell.z))
			high = Vector3i(maxi(high.x, cell.x), maxi(high.y, cell.y), maxi(high.z, cell.z))
		var center := (Vector3(low) + Vector3(high)) * 0.5 * ShipVisual.CELL_SIZE
		for cell: Vector3i in cells:
			var p := Vector3(cell) * ShipVisual.CELL_SIZE - center
			var half_cell := ShipVisual.CELL_SIZE * 0.5
			for x in [-half_cell, half_cell]:
				for y in [-half_cell, half_cell]:
					for z in [-half_cell, half_cell]:
						hull_radius = maxf(hull_radius, (p + Vector3(x, y, z)).length())
	_collision_update_pending = true
	_queue_collision_update(cells, cells.is_empty())


func _queue_collision_update(cells: Array[Vector3i], clear: bool) -> void:
	_collision_update_pending = true
	if Engine.is_in_physics_frame():
		_apply_ship_collision.call_deferred(cells, clear)
	else:
		_apply_ship_collision(cells, clear)


func _apply_ship_collision(cells: Array[Vector3i], clear: bool) -> void:
	for shape: CollisionShape3D in _module_shapes:
		remove_child(shape)
		shape.queue_free()
	_module_shapes.clear()
	_module_centers.clear()
	if not clear:
		var low := cells[0]
		var high := cells[0]
		for cell: Vector3i in cells:
			low = Vector3i(mini(low.x, cell.x), mini(low.y, cell.y), mini(low.z, cell.z))
			high = Vector3i(maxi(high.x, cell.x), maxi(high.y, cell.y), maxi(high.z, cell.z))
		var center := (Vector3(low) + Vector3(high)) * 0.5 * ShipVisual.CELL_SIZE
		for cell: Vector3i in cells:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3.ONE * ShipVisual.CELL_SIZE
			shape.shape = box
			_module_centers.append(Vector3(cell) * ShipVisual.CELL_SIZE - center)
			shape.position = _module_centers[-1]
			shape.disabled = not flying
			add_child(shape)
			_module_shapes.append(shape)
	_collision_update_pending = false
	_sync_collision_mode()
	_update_module_collision_basis()


func _sync_collision_mode() -> void:
	if _walk_shape == null:
		return
	if Engine.is_in_physics_frame():
		_collision_update_pending = true
		_sync_collision_mode_deferred.call_deferred()
	else:
		_apply_collision_mode()


func _sync_collision_mode_deferred() -> void:
	_apply_collision_mode()
	_collision_update_pending = false


func _apply_collision_mode() -> void:
	_walk_shape.disabled = flying and _has_configured_ship
	for shape: CollisionShape3D in _module_shapes:
		shape.disabled = not flying


func _update_module_collision_basis() -> void:
	if camera == null:
		return
	var basis := camera.basis
	for index in _module_shapes.size():
		var shape: CollisionShape3D = _module_shapes[index]
		shape.basis = basis
		shape.position = basis * _module_centers[index]


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


func flight_velocity() -> Vector3:
	return _flight_velocity

func carry_with_frame(change: Transform3D) -> void:
	global_transform = change * global_transform
	_walk_velocity = change.basis * _walk_velocity
	velocity = change.basis * velocity
	up_direction = (change.basis * up_direction).normalized()

func restore_flight_velocity(value: Vector3) -> void:
	if not flying or not value.is_finite(): return
	_flight_velocity = value
	velocity = value

func teleport(pos: Vector3) -> void:
	braking = false
	global_position = pos
	cancel_autopilot()
	velocity = Vector3.ZERO
	_flight_velocity = Vector3.ZERO
	_walk_velocity = Vector3.ZERO


func _make_cockpit() -> Node3D:
	var cockpit := Node3D.new()
	var shell := _mat(Color("171b20"), 0.48, 0.0)
	var edge := _mat(Color("39434a"), 0.32, 0.0)
	var inset := _mat(Color("090d10"), 0.26, 0.0)
	var amber := _mat(Color("c07a3c"), 0.38, 0.12)
	# Low instrument cowl and paired consoles leave the forward view open.
	_add_box(cockpit, Vector3(0, -0.56, -0.91), Vector3(1.48, 0.11, 0.4), shell)
	_add_box(cockpit, Vector3(0, -0.495, -1.07), Vector3(1.22, 0.025, 0.055), edge)
	for side: float in [-1.0, 1.0]:
		var x := side * 0.48
		var yaw := -side * 0.12
		_add_box(cockpit, Vector3(x, -0.465, -0.86), Vector3(0.53, 0.11, 0.43), shell, Vector3(-0.14, yaw, -side * 0.08))
		_add_box(cockpit, Vector3(x, -0.405, -0.88), Vector3(0.37, 0.012, 0.29), edge, Vector3(-0.14, yaw, -side * 0.08))
		var display := Node3D.new()
		display.name = "LeftDisplay" if side < 0.0 else "RightDisplay"
		display.position = Vector3(x, -0.29, -0.9)
		display.rotation.y = yaw
		cockpit.add_child(display)
		_add_box(display, Vector3(0, 0, -0.025), Vector3(0.36, 0.18, 0.03), edge)
		_add_box(display, Vector3(0, 0, -0.007), Vector3(0.34, 0.16, 0.012), inset)
		_add_box(cockpit, Vector3(x, -0.41, -0.94), Vector3(0.08, 0.17, 0.065), shell)
	# Slim angled canopy pillars sit at the outer edges; there is no crossbar.
	for side: float in [-1.0, 1.0]:
		_add_box(cockpit, Vector3(side * 1.04, 0.22, -1.12), Vector3(0.055, 1.55, 0.085), shell, Vector3(0, 0, -side * 0.22))
		_add_box(cockpit, Vector3(side * 1.065, 0.22, -1.075), Vector3(0.012, 1.53, 0.012), edge, Vector3(0, 0, -side * 0.22))
	# Recessed warm status lamps add scale without lighting up the whole cockpit.
	for side: float in [-1.0, 1.0]:
		for index in range(3):
			_add_box(cockpit, Vector3(side * (0.67 + index * 0.055), -0.49, -0.68), Vector3(0.018, 0.008, 0.012), amber)
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
