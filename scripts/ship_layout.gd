class_name ShipLayout
extends RefCounted

const VERSION: int = 1
const ROOM_REFIT_COST: int = 600
const PANEL_COSTS: Dictionary = {"standard": 200, "armored": 550, "window": 900}
const FACES: Array[String] = ["+x", "-x", "+y", "-y", "+z", "-z"]
const ROOM_TYPES: Array[String] = ["quarters", "lounge", "medical", "cargo", "workshop", "bridge", "engineering"]
const FACE_STEPS: Dictionary = {
	"+x": Vector3i.RIGHT, "-x": Vector3i.LEFT,
	"+y": Vector3i.UP, "-y": Vector3i.DOWN,
	"+z": Vector3i(0, 0, 1), "-z": Vector3i(0, 0, -1),
}


static func empty_data() -> Dictionary:
	return {"version": VERSION, "rooms": {}, "panels": {}}


static func validate_data(data: Variant, modules: Array) -> bool:
	if not data is Dictionary or data.size() != 3 or not data.has_all(["version", "rooms", "panels"]):
		return false
	if not _integer_equals(data.version, VERSION) or not data.rooms is Dictionary or not data.panels is Dictionary:
		return false
	var cells := _module_map(modules)
	if cells.size() != modules.size():
		return false
	for raw_key: Variant in data.rooms:
		if not raw_key is String or not cells.has(raw_key):
			return false
		var kind: String = str(cells[raw_key])
		var room: Variant = data.rooms[raw_key]
		if not room is String or not _compatible_rooms(kind).has(room):
			return false
	for raw_key: Variant in data.panels:
		if not raw_key is String or not cells.has(raw_key) or not data.panels[raw_key] is Dictionary or data.panels[raw_key].is_empty():
			return false
		var cell: Variant = _cell_from_key(raw_key)
		if cell == null:
			return false
		for raw_face: Variant in data.panels[raw_key]:
			if not raw_face is String or not FACES.has(raw_face) or not PANEL_COSTS.has(data.panels[raw_key][raw_face]):
				return false
			if cells.has(_cell_key(cell + FACE_STEPS[raw_face])):
				return false
	return true


static func prune(data: Dictionary, modules: Array) -> void:
	var cells := _module_map(modules)
	if not data.get("rooms") is Dictionary:
		data["rooms"] = {}
	if not data.get("panels") is Dictionary:
		data["panels"] = {}
	for raw_key: Variant in data.rooms.keys():
		if not raw_key is String or not cells.has(raw_key) or not _compatible_rooms(str(cells.get(raw_key, ""))).has(data.rooms[raw_key]):
			data.rooms.erase(raw_key)
	for raw_key: Variant in data.panels.keys():
		var panel_data: Variant = data.panels[raw_key]
		if not raw_key is String or not cells.has(raw_key) or not panel_data is Dictionary:
			data.panels.erase(raw_key)
			continue
		var cell: Variant = _cell_from_key(raw_key)
		for face: Variant in panel_data.keys():
			if not FACES.has(face) or cells.has(_cell_key(cell + FACE_STEPS[face])) or not PANEL_COSTS.has(panel_data[face]):
				panel_data.erase(face)
		if panel_data.is_empty():
			data.panels.erase(raw_key)
	data["version"] = VERSION


static func configure_room(state: Object, cell: Vector3i, room_type: String) -> String:
	var modules: Variant = state.get("ship_modules")
	var data: Variant = state.get("ship_layout")
	if not modules is Array or not data is Dictionary or not validate_data(data, modules):
		return "Ship layout is invalid."
	var cell_key := _cell_key(cell)
	var module_kind: String = _module_map(modules).get(cell_key, "")
	if module_kind.is_empty():
		return "No ship module at that cell."
	if not _compatible_rooms(module_kind).has(room_type):
		return "That room type does not fit this module."
	var current: String = str(data.rooms.get(cell_key, _default_room_type(module_kind)))
	if current == room_type:
		return ""
	var credits: Variant = state.get("credits")
	if typeof(credits) != TYPE_INT or credits < ROOM_REFIT_COST:
		return "Insufficient credits."
	var updated: Dictionary = data.duplicate(true)
	if room_type == _default_room_type(module_kind):
		updated.rooms.erase(cell_key)
	else:
		updated.rooms[cell_key] = room_type
	state.set("credits", int(credits) - ROOM_REFIT_COST)
	state.set("ship_layout", updated)
	return ""


static func set_panel(state: Object, cell: Vector3i, face: String, panel_type: String) -> String:
	var modules: Variant = state.get("ship_modules")
	var data: Variant = state.get("ship_layout")
	if not modules is Array or not data is Dictionary or not validate_data(data, modules):
		return "Ship layout is invalid."
	if not PANEL_COSTS.has(panel_type):
		return "Unknown hull panel type."
	if not FACES.has(face):
		return "Unknown hull face."
	var cell_key := _cell_key(cell)
	var cells := _module_map(modules)
	if not cells.has(cell_key):
		return "No ship module at that cell."
	if cells.has(_cell_key(cell + FACE_STEPS[face])):
		return "Only exposed hull faces can be refitted."
	var panels: Dictionary = data.panels.get(cell_key, {})
	var current: String = str(panels.get(face, "standard"))
	if current == panel_type:
		return ""
	var cost: int = PANEL_COSTS[panel_type]
	var credits: Variant = state.get("credits")
	if typeof(credits) != TYPE_INT or credits < cost:
		return "Insufficient credits."
	var updated: Dictionary = data.duplicate(true)
	panels = panels.duplicate(true)
	if panel_type == "standard":
		panels.erase(face)
	else:
		panels[face] = panel_type
	if panels.is_empty():
		updated.panels.erase(cell_key)
	else:
		updated.panels[cell_key] = panels
	state.set("credits", int(credits) - cost)
	state.set("ship_layout", updated)
	return ""


static func cell_key(cell: Vector3i) -> String:
	return _cell_key(cell)


static func default_room(module_kind: String) -> String:
	return _default_room_type(module_kind)


static func _module_map(modules: Array) -> Dictionary:
	var result: Dictionary = {}
	for module: Variant in modules:
		if not module is Dictionary:
			continue
		var cell: Variant = module.get("cell", module.get("position"))
		if cell is Vector3i:
			result[_cell_key(cell)] = str(module.get("kind", ""))
		elif module.has_all(["x", "y", "z"]):
			if typeof(module.x) == TYPE_INT and typeof(module.y) == TYPE_INT and typeof(module.z) == TYPE_INT:
				result[_cell_key(Vector3i(module.x, module.y, module.z))] = str(module.get("kind", ""))
	return result


static func _compatible_rooms(module_kind: String) -> Array[String]:
	match module_kind:
		"habitat": return ["quarters", "lounge", "medical"]
		"cargo": return ["cargo", "workshop"]
		"cockpit": return ["bridge"]
		_: return ["engineering"]


static func _default_room_type(module_kind: String) -> String:
	match module_kind:
		"habitat": return "quarters"
		"cargo": return "cargo"
		"cockpit": return "bridge"
		_: return "engineering"


static func _cell_key(cell: Vector3i) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, cell.z]


static func _cell_from_key(key: String) -> Variant:
	var parts := key.split(",")
	if parts.size() != 3:
		return null
	var coords: Array[int] = []
	for part: String in parts:
		if part.is_empty() or str(int(part)) != part:
			return null
		coords.append(int(part))
	return Vector3i(coords[0], coords[1], coords[2])


static func _integer_equals(value: Variant, expected: int) -> bool:
	if typeof(value) == TYPE_INT:
		return value == expected
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number == expected
