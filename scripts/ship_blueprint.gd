class_name ShipBlueprint
extends RefCounted

# One metre-scale contract for pressure cells, interior floors and collision.
const CELL_SIZE := 2.8
const PRESSURE_SIZE := Vector3(3.0, 2.66, 3.0)
const COLLISION_SIZE := Vector3(3.0, 2.8, 3.0)
const FLOOR_OFFSET := 1.23
const CLEAR_HEIGHT := 2.45
const FAMILIES := ["pathfinder", "merchant"]


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
	var modules: Array[Dictionary] = [{"kind":"cockpit", "x":0, "y":0, "z":-2}]
	for z in range(-1, 2 if id == "pathfinder" else 4):
		for x in range(-1, 2):
			var kind := "cargo"
			if z == -1 and x == 0: kind = "core"
			elif z == -1 and x == -1: kind = "habitat"
			elif z == 0 and x == 0: kind = "reactor"
			elif z == 0 and x == 1: kind = "shield"
			elif z == (1 if id == "pathfinder" else 3) and x != 0: kind = "engine"
			modules.append({"kind":kind, "x":x, "y":0, "z":z})
	var layout := ShipLayout.empty_data()
	if id == "merchant": layout.rooms["-1,0,-1"] = "lounge"
	return {"family":id, "modules":modules, "layout":layout}


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
	var beam_scale := 1.2 if family_id == "pathfinder" else 1.16
	var length_scale := 1.06 if family_id == "pathfinder" else 1.035
	return HullGeometry.profile(outline, [Vector3(1.02, -1.48, 1.01), Vector3(beam_scale, -0.25, length_scale), Vector3(1.0, PRESSURE_SIZE.y * 0.5, 1.0)])
