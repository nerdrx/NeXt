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
