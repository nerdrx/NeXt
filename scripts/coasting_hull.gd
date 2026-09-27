class_name CoastingHull
extends CharacterBody3D

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
	var low := cells[0]
	var high := cells[0]
	for cell in cells:
		low = Vector3i(mini(low.x, cell.x), mini(low.y, cell.y), mini(low.z, cell.z))
		high = Vector3i(maxi(high.x, cell.x), maxi(high.y, cell.y), maxi(high.z, cell.z))
	var center := (Vector3(low) + Vector3(high)) * 0.5 * ShipVisual.CELL_SIZE
	for cell in cells:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3.ONE * ShipVisual.CELL_SIZE
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
	var result := {"displacement": Vector3.ZERO, "impact_speed": 0.0, "arrived": false, "blocked": false}
	if not is_finite(delta) or delta < 0.0 or delta > 1.0 or not target.is_finite() or not is_finite(speed) or speed < 0.0 or not velocity.is_finite():
		return result
	var offset := target - global_position
	var distance := offset.length()
	if not is_finite(distance):
		return result
	if distance <= 2.0:
		velocity = Vector3.ZERO
		result.arrived = true
		return result
	var direction := offset / distance
	var approach := clampf(distance / 50.0, 0.0, 1.0)
	approach = approach * approach * (3.0 - 2.0 * approach)
	var desired := direction * speed * approach
	velocity = velocity.lerp(desired, minf(1.0, 1.8 * delta))
	if not velocity.is_finite():
		velocity = Vector3.ZERO
	if delta == 0.0:
		return result
	if not _rotation_clear():
		velocity = Vector3.ZERO
		result.blocked = true
		return result
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var wanted := Basis.looking_at(direction, up)
	global_basis = global_basis.orthonormalized().slerp(wanted, minf(1.0, delta * 0.85)).orthonormalized()
	var lookahead := minf(maxf(5.0, velocity.length() * 0.8), distance)
	if velocity.length_squared() > 0.0 and test_move(global_transform, velocity.normalized() * lookahead):
		velocity = Vector3.ZERO
		result.blocked = true
		return result
	var movement := advance(delta)
	result.displacement = movement.displacement
	result.impact_speed = movement.impact_speed
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
	var result := {"displacement": Vector3.ZERO, "impact_speed": 0.0}
	if not is_finite(delta) or delta < 0.0 or delta > 1.0 or not velocity.is_finite():
		return result
	if delta == 0.0:
		return result
	var incoming := velocity
	var start := global_position
	var collision := move_and_collide(incoming * delta)
	result.displacement = global_position - start
	if collision != null:
		result.impact_speed = maxf(0.0, -incoming.dot(collision.get_normal()))
		velocity = Vector3.ZERO
	return result
