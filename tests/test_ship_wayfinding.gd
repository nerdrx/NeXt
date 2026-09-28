extends SceneTree

const Blueprint = preload("res://scripts/ship_blueprint.gd")
const Layout = preload("res://scripts/ship_layout.gd")
const DIRECTIONS: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var blueprint: Dictionary = Blueprint.family("ranger")
	assert(Layout.validate_data(blueprint.layout, blueprint.modules), "Ranger supplies a validated destination-room layout")
	var cabin := ShipInterior.new()
	root.add_child(cabin)
	cabin.build(blueprint.modules, blueprint.layout)
	var expected := _expected_links(blueprint.modules)
	assert(_check_signs(cabin, blueprint.modules, blueprint.layout, expected), "Ranger has one correctly named, oriented sign per directed doorway")
	var original_positions := _sign_positions(cabin)
	assert(original_positions.size() == expected.size())
	cabin.position = Vector3(12.0, 3.0, -8.0)
	cabin.rotation = Vector3(0.2, 0.7, -0.15)
	cabin.force_update_transform()
	await process_frame
	for sign: Label3D in _doorway_signs(cabin):
		var key := _link_key(sign.get_meta("source_cell"), sign.get_meta("destination_cell"))
		assert(sign.position.is_equal_approx(original_positions[key]), "transformed cabin preserves doorway sign local placement")
		var local_direction := Vector3(sign.get_meta("destination_cell") - sign.get_meta("source_cell")).normalized()
		assert(sign.global_basis.z.normalized().dot((cabin.global_basis * local_direction).normalized()) < -0.99, "transformed sign still faces its source room")
	var refit: Dictionary = blueprint.layout.duplicate(true)
	refit.rooms["0,0,-3"] = "medical"
	assert(Layout.validate_data(refit, blueprint.modules), "Ranger lounge-to-medical refit remains valid")
	cabin.build(blueprint.modules, refit)
	await process_frame
	assert(_check_signs(cabin, blueprint.modules, refit, expected), "refit updates destination labels without changing doorway links")
	for sign: Label3D in _doorway_signs(cabin): assert(sign.text != "LOUNGE", "refit leaves no stale lounge label")
	cabin.build(blueprint.modules, refit)
	await process_frame
	assert(_check_signs(cabin, blueprint.modules, refit, expected), "rebuild creates no duplicate or stale doorway signs")
	cabin.queue_free()
	await process_frame
	print("SHIP_WAYFINDING_OK: directed doorway labels, destination rooms, refits and cabin transforms")
	quit()


func _expected_links(modules: Array[Dictionary]) -> Dictionary:
	var occupied := {}
	for module: Dictionary in modules:
		occupied[Vector3i(module.x, module.y, module.z)] = module
	var expected := {}
	for module: Dictionary in modules:
		var source := Vector3i(module.x, module.y, module.z)
		for direction in DIRECTIONS:
			var destination := source + direction
			if occupied.has(destination): expected[_link_key(source, destination)] = true
	return expected


func _check_signs(cabin: ShipInterior, modules: Array[Dictionary], layout: Dictionary, expected: Dictionary) -> bool:
	var signs := _doorway_signs(cabin)
	if signs.size() != expected.size(): return false
	var seen := {}
	var occupied := {}
	for module: Dictionary in modules:
		occupied[Vector3i(module.x, module.y, module.z)] = module
	for sign: Label3D in signs:
		if sign.double_sided: return false
		if not sign.has_meta("source_cell") or not sign.has_meta("destination_cell"): return false
		var source: Vector3i = sign.get_meta("source_cell")
		var destination: Vector3i = sign.get_meta("destination_cell")
		var key := _link_key(source, destination)
		if not expected.has(key) or seen.has(key): return false
		seen[key] = true
		var module: Dictionary = occupied[destination]
		var room: String = layout.rooms.get(Layout.cell_key(destination), Layout.default_room(str(module.kind)))
		if sign.text != room.to_upper(): return false
		var direction := Vector3(destination - source).normalized()
		if sign.basis.z.normalized().dot(direction) >= -0.99: return false
		var expected_position := Vector3(source) * ShipInterior.CELL + direction * 1.28 + Vector3.UP * 2.3
		if not sign.position.is_equal_approx(expected_position): return false
		if absf(sign.position.y - (float(source.y) * ShipInterior.CELL.y + 2.3)) > 0.001: return false
		if not sign.find_children("*", "CollisionObject3D", true, false).is_empty(): return false
	return seen.size() == expected.size()


func _doorway_signs(cabin: ShipInterior) -> Array[Label3D]:
	var signs: Array[Label3D] = []
	for child: Node in cabin.get_children():
		if child is Label3D and child.name.begins_with("DoorwaySign"):
			signs.append(child)
	return signs


func _sign_positions(cabin: ShipInterior) -> Dictionary:
	var positions := {}
	for sign: Label3D in _doorway_signs(cabin):
		positions[_link_key(sign.get_meta("source_cell"), sign.get_meta("destination_cell"))] = sign.position
	return positions


func _link_key(source: Vector3i, destination: Vector3i) -> String:
	return "%s>%s" % [str(source), str(destination)]
