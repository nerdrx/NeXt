class_name CoastingHull
extends CharacterBody3D

var _module_shapes: Array[CollisionShape3D] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1


func configure(modules: Array) -> void:
	for shape in _module_shapes:
		remove_child(shape)
		shape.queue_free()
	_module_shapes.clear()
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
