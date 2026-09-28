class_name ShipBlueprint
extends RefCounted

# One metre-scale contract for pressure cells, interior floors and collision.
const CELL_SIZE := 2.8
const PRESSURE_SIZE := Vector3(3.0, 2.66, 3.0)
const COLLISION_SIZE := Vector3(3.0, 2.8, 3.0)
const FLOOR_OFFSET := 1.23
const CLEAR_HEIGHT := 2.45
const FAMILIES := ["pathfinder", "merchant", "ranger"]
const FLEET_EQUIPMENT := ["cargo", "weapon", "shield", "habitat", "radiator", "reactor"]


static func center(cells: Array[Vector3i]) -> Vector3:
	if cells.is_empty(): return Vector3.ZERO
	var low := cells[0]
	var high := cells[0]
	for cell in cells:
		low = Vector3i(mini(low.x,cell.x), mini(low.y,cell.y), mini(low.z,cell.z))
		high = Vector3i(maxi(high.x,cell.x), maxi(high.y,cell.y), maxi(high.z,cell.z))
	return (Vector3(low) + Vector3(high)) * CELL_SIZE * 0.5


static func interior_offset(cells: Array[Vector3i]) -> Vector3:
	return -center(cells) - Vector3.UP * FLOOR_OFFSET


static func family(id: String) -> Dictionary:
	if id not in FAMILIES: return {}
	# Curated occupied volumes; room roles can change only within compatible bays.
	var last_row: int = {"pathfinder": 1, "merchant": 3, "ranger": 4}[id]
	var modules: Array[Dictionary] = [{"kind":"cockpit", "x":0, "y":0, "z":-4 if id == "ranger" else -2}]
	if id == "ranger":
		modules.append({"kind":"habitat", "x":0, "y":0, "z":-3})
		modules.append({"kind":"radiator", "x":0, "y":0, "z":-2})
	for z in range(-1, last_row + 1):
		for x in range(-1, 2):
			var kind := "cargo"
			if z == -1 and x == 0: kind = "core"
			elif z == -1 and x == -1: kind = "habitat"
			elif z == 0 and x == 0: kind = "reactor"
			elif z == 0 and x == 1: kind = "shield"
			elif z == last_row and x != 0: kind = "engine"
			elif id == "ranger" and z == 0 and x == -1: kind = "habitat"
			elif id == "ranger" and z == 1 and x != 0: kind = "radiator"
			modules.append({"kind":kind, "x":x, "y":0, "z":z})
	if id == "ranger":
		for z in [2, 3]:
			for x in [-2, 2]:
				modules.append({"kind":"radiator" if z == 2 else "cargo", "x":x, "y":0, "z":z})
	var layout := ShipLayout.empty_data()
	if id == "merchant": layout.rooms["-1,0,-1"] = "lounge"
	if id == "ranger":
		layout.rooms["0,0,-3"] = "lounge"
		layout.rooms["-1,0,0"] = "medical"
		layout.rooms["0,0,1"] = "workshop"
	return {"family":id, "modules":modules, "layout":layout}


static func for_vessel(vessel: Dictionary) -> Dictionary:
	var family_id := str(vessel.get("hull_family", ""))
	var blueprint := family(family_id)
	if family_id == "custom":
		var modules: Variant = vessel.get("modules")
		var layout: Variant = vessel.get("layout")
		if not valid_custom_modules(modules) or not ShipLayout.validate_data(layout, modules): return {}
		blueprint = {"family": "custom", "modules": modules.duplicate(true), "layout": layout.duplicate(true)}
	if blueprint.is_empty(): return {}
	if family_id != "custom":
		blueprint.modules = vessel.get("modules", blueprint.modules).duplicate(true)
		blueprint.layout = vessel.get("layout", blueprint.layout).duplicate(true)
	return blueprint

static func valid_equipment(family_id: String, modules: Variant) -> bool:
	if family_id == "custom": return valid_custom_modules(modules)
	var blueprint := family(family_id)
	if blueprint.is_empty() or not modules is Array or modules.size() != blueprint.modules.size(): return false
	var model := GameState.new()
	var original := {}
	for item: Dictionary in blueprint.modules: original[Vector3i(item.x,item.y,item.z)] = item.kind
	var seen := {}
	var candidate: Array[Dictionary] = []
	for item: Variant in modules:
		if not item is Dictionary or not model._valid_module(item): return false
		var cell := Vector3i(int(item.x),int(item.y),int(item.z))
		if not original.has(cell) or seen.has(cell): return false
		var locked: bool = original[cell] in ["core", "cockpit", "reactor", "engine"]
		if (locked and item.kind != original[cell]) or (not locked and item.kind not in FLEET_EQUIPMENT): return false
		seen[cell] = true
		candidate.append({"kind":str(item.kind), "x":cell.x, "y":cell.y, "z":cell.z})
	var stats := model._stats_for(candidate)
	return model._has_required_modules(candidate) and stats.power_balance >= 0 and stats.walkable


static func valid_custom_modules(modules: Variant) -> bool:
	if not modules is Array or modules.is_empty() or modules.size() > GameState.MAX_SHIP_MODULES: return false
	var model := GameState.new()
	var candidate: Array[Dictionary] = []
	for item: Variant in modules:
		if not item is Dictionary or not model._valid_module(item): return false
		candidate.append({"kind": item.kind, "x": int(item.x), "y": int(item.y), "z": int(item.z)})
	if model._module_cells_duplicate(candidate) or not model._connected(candidate) or not model._has_required_modules(candidate): return false
	return int(model._stats_for(candidate).power_balance) >= 0


static func family_for_cells(cells: Array[Vector3i]) -> String:
	var occupied := {}
	for cell in cells: occupied[cell] = true
	for id: String in FAMILIES:
		var expected := {}
		for module: Dictionary in family(id).modules:
			expected[Vector3i(module.x,module.y,module.z)] = true
		if occupied == expected: return id
	return ""


static func pressure_outline(cells: Array[Vector3i]) -> PackedVector2Array:
	if family_for_cells(cells).is_empty(): return PackedVector2Array()
	var ordered := cells.duplicate()
	ordered.sort_custom(func(a: Vector3i,b: Vector3i): return a.z < b.z if a.z != b.z else a.x < b.x)
	var pivot := center(cells)
	var outline := PackedVector2Array()
	var half := Vector2(PRESSURE_SIZE.x, PRESSURE_SIZE.z)*0.5
	for cell: Vector3i in ordered:
		var p := Vector2(cell.x*CELL_SIZE-pivot.x,cell.z*CELL_SIZE-pivot.z)
		var rectangle := PackedVector2Array([p-half,p+Vector2(half.x,-half.y),p+half,p+Vector2(-half.x,half.y)])
		if outline.is_empty(): outline = rectangle
		else:
			var merged := Geometry2D.merge_polygons(outline,rectangle)
			if merged.size() != 1: return PackedVector2Array()
			outline = merged[0]
	return outline


static func collision_size(cells: Array[Vector3i]) -> Vector3:
	return Vector3(4.8, 3.8, 4.8) if not family_for_cells(cells).is_empty() else COLLISION_SIZE


static func outer_hull(cells: Array[Vector3i]) -> ArrayMesh:
	var outline := pressure_outline(cells)
	if outline.is_empty(): return null
	# Sloped armor wraps the pressure volume without reducing room clearances.
	var family_id := family_for_cells(cells)
	if family_id == "ranger":
		return HullGeometry.profile_offset(outline, [Vector2(-1.48, 0.12), Vector2(-0.25, 0.6), Vector2(PRESSURE_SIZE.y * 0.5, 0.03)])
	var beam_scale := 1.2 if family_id == "pathfinder" else 1.16
	var length_scale := 1.06 if family_id == "pathfinder" else 1.035
	return HullGeometry.profile(outline, [Vector3(1.02, -1.48, 1.01), Vector3(beam_scale, -0.25, length_scale), Vector3(1.0, PRESSURE_SIZE.y * 0.5, 1.0)])
