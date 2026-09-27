class_name CoastingHull
extends CharacterBody3D

var braking: bool = false
var thrust_g: float = 0.0
var acceleration_mps2: float = FlightDynamics.STANDARD_GRAVITY * FlightDynamics.CRUISE_G
var propulsion_limiter: Callable
var _module_shapes: Array[CollisionShape3D] = []
var _navigation_radius := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1


func configure(modules: Array) -> void:
	for shape in _module_shapes:
		remove_child(shape)
		shape.queue_free()
	_module_shapes.clear()
	_navigation_radius = 0.0
	var cells: Array[Vector3i] = []
	for item in modules:
		var cell := Vector3i.ZERO
		if item is Dictionary:
			var raw: Variant = item.get("cell", item.get("position", Vector3i(int(item.get("x", 0)), int(item.get("y", 0)), int(item.get("z", 0)))))
			if raw is Vector3i:
				cell = raw
			elif raw is Vector3:
				cell = Vector3i(raw)
		elif item is Vector3i:
			cell = item
		elif item is Vector3:
			cell = Vector3i(item)
		if cell not in cells:
			cells.append(cell)
	if cells.is_empty():
		return
	var center := ShipBlueprint.center(cells)
	for cell in cells:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = ShipBlueprint.COLLISION_SIZE
		shape.shape = box
		shape.position = Vector3(cell) * ShipVisual.CELL_SIZE - center
		add_child(shape)
		_module_shapes.append(shape)
		_navigation_radius = maxf(_navigation_radius, shape.position.length() + box.size.length() * 0.5)


func aim_point() -> Vector3:
	for shape in _module_shapes:
		if is_instance_valid(shape) and shape.shape != null:
			return shape.global_position
	return global_position


func navigate(delta: float, target: Vector3, speed: float) -> Dictionary:
	thrust_g = 0.0
	var result := {"displacement": Vector3.ZERO, "impact_speed": 0.0, "arrived": false, "blocked": false}
	if not is_finite(delta) or delta < 0.0 or delta > 1.0 or not target.is_finite() or not is_finite(speed) or speed < 0.0 or not velocity.is_finite():
		return result
	braking = false
	var offset := target - global_position
	var distance := offset.length()
	if not is_finite(distance):
		return result
	var provisional_arrival := distance <= 2.0 and velocity.length() <= FlightDynamics.usable_acceleration(acceleration_mps2) * delta
	var direction := offset / distance if distance > 0.000001 else -velocity.normalized()
	var desired := Vector3.ZERO if provisional_arrival else direction * FlightDynamics.approach_speed(distance, speed, acceleration_mps2)
	var incoming_thrust := velocity
	var commanded := FlightDynamics.command_velocity(incoming_thrust, desired, delta, false, acceleration_mps2)
	if delta == 0.0:
		return result
	if not provisional_arrival:
		if not _rotation_clear():
			velocity = incoming_thrust
			return _blocked_advance(delta)
		var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		var wanted := Basis.looking_at(direction, up)
		global_basis = global_basis.orthonormalized().slerp(wanted, minf(1.0, delta * 0.85)).orthonormalized()
		var lookahead := maxf(5.0, FlightDynamics.braking_distance(incoming_thrust.length(), acceleration_mps2) + incoming_thrust.length() * delta + 2.0)
		if commanded.length_squared() > 0.0 and test_move(global_transform, commanded.normalized() * lookahead):
			velocity = incoming_thrust
			return _blocked_advance(delta)
	velocity = _limit_propulsion(incoming_thrust, commanded)
	var commanded_g := FlightDynamics.thrust_load(incoming_thrust, velocity, delta)
	if provisional_arrival and velocity.is_zero_approx():
		thrust_g = commanded_g
		result.arrived = true
		return result
	var movement := advance(delta)
	thrust_g = commanded_g
	result.displacement = movement.displacement
	result.impact_speed = movement.impact_speed
	return result


func request_brake() -> void:
	braking = not velocity.is_zero_approx()


func _limit_propulsion(before: Vector3, commanded: Vector3) -> Vector3:
	if not propulsion_limiter.is_valid():
		return commanded if commanded.is_finite() else before
	var limited: Variant = propulsion_limiter.call(before, commanded)
	return limited if limited is Vector3 and limited.is_finite() else before


func _blocked_advance(delta: float) -> Dictionary:
	request_brake()
	var result := advance(delta)
	result["blocked"] = true
	result["arrived"] = false
	return result


func _rotation_clear() -> bool:
	if _navigation_radius <= 0.0 or not is_inside_tree():
		return true
	var shape := SphereShape3D.new()
	shape.radius = _navigation_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excluded: Array[RID] = [get_rid()]
	for exception in get_collision_exceptions():
		excluded.append(exception.get_rid())
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func advance(delta: float) -> Dictionary:
	thrust_g = 0.0
	var result := {"displacement": Vector3.ZERO, "impact_speed": 0.0}
	if not is_finite(delta) or delta < 0.0 or delta > 1.0 or not velocity.is_finite():
		return result
	if delta == 0.0:
		return result
	if braking:
		var before := velocity
		var commanded := FlightDynamics.command_velocity(velocity, Vector3.ZERO, delta, false, acceleration_mps2)
		velocity = _limit_propulsion(before, commanded)
		thrust_g = FlightDynamics.thrust_load(before, velocity, delta)
		if velocity.is_zero_approx(): braking = false
	var incoming := velocity
	var start := global_position
	var collision := move_and_collide(incoming * delta)
	result.displacement = global_position - start
	if collision != null:
		result.impact_speed = maxf(0.0, -incoming.dot(collision.get_normal()))
		velocity = Vector3.ZERO
		braking = false
	return result
