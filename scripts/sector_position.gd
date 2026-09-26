class_name SectorPosition
extends RefCounted

const SECTOR_SIZE: float = 8192.0
const HALF_SECTOR: float = SECTOR_SIZE * 0.5
const MAX_RELATIVE_DISTANCE: float = 1_000_000.0
const MAX_SECTOR_COORDINATE: int = 2147483647
const SAVE_VERSION: int = 1

var sector: Vector3i
var local: Vector3


func _init(sector_coordinates: Vector3i = Vector3i.ZERO, local_position: Vector3 = Vector3.ZERO) -> void:
	sector = sector_coordinates
	local = local_position
	if not _normalize():
		sector = Vector3i.ZERO
		local = Vector3.ZERO


func move_delta(delta: Vector3) -> bool:
	if not _finite_vector(delta):
		return false
	var old_sector := sector
	var old_local := local
	local += delta
	if _normalize():
		return true
	sector = old_sector
	local = old_local
	return false


func relative_to(origin: SectorPosition, max_distance: float) -> Variant:
	if origin == null or not is_finite(max_distance) or max_distance < 0.0 or max_distance > MAX_RELATIVE_DISTANCE:
		return null
	var dx: int = sector.x - origin.sector.x
	var dy: int = sector.y - origin.sector.y
	var dz: int = sector.z - origin.sector.z
	var sector_limit := ceili(max_distance / SECTOR_SIZE) + 1
	if absi(dx) > sector_limit or absi(dy) > sector_limit or absi(dz) > sector_limit:
		return null
	var offset := Vector3(dx, dy, dz) * SECTOR_SIZE + (local - origin.local)
	return offset if offset.length_squared() <= max_distance * max_distance else null


func to_save() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"sector": [sector.x, sector.y, sector.z],
		"local": [local.x, local.y, local.z],
	}


static func from_save(value: Variant) -> Variant:
	if not value is Dictionary or value.get("version") != SAVE_VERSION:
		return null
	var sector_values: Variant = value.get("sector")
	var local_values: Variant = value.get("local")
	if not sector_values is Array or sector_values.size() != 3 or not local_values is Array or local_values.size() != 3:
		return null
	var coords: Array[int] = []
	var offsets: Array[float] = []
	for component in sector_values:
		if not _is_integer_component(component) or float(component) < -2147483648.0 or float(component) > MAX_SECTOR_COORDINATE:
			return null
		coords.append(int(component))
	for component in local_values:
		if not _is_finite_number(component):
			return null
		var offset := float(component)
		if offset < -HALF_SECTOR or offset >= HALF_SECTOR:
			return null
		offsets.append(offset)
	return SectorPosition.new(Vector3i(coords[0], coords[1], coords[2]), Vector3(offsets[0], offsets[1], offsets[2]))


func _normalize() -> bool:
	if not _finite_vector(local):
		return false
	var x := _normalize_axis(sector.x, local.x)
	var y := _normalize_axis(sector.y, local.y)
	var z := _normalize_axis(sector.z, local.z)
	if x.is_empty() or y.is_empty() or z.is_empty():
		return false
	sector = Vector3i(x[0], y[0], z[0])
	local = Vector3(x[1], y[1], z[1])
	return true


static func _normalize_axis(base: int, value: float) -> Array:
	var shift_float: float = floor((value + HALF_SECTOR) / SECTOR_SIZE)
	if absf(shift_float) > MAX_SECTOR_COORDINATE * 2.0:
		return []
	var shift := int(shift_float)
	var coordinate := base + shift
	if coordinate < -MAX_SECTOR_COORDINATE - 1 or coordinate > MAX_SECTOR_COORDINATE:
		return []
	var offset: float = value - shift_float * SECTOR_SIZE
	# Correct boundary drift while keeping sector size exactly representable.
	if offset >= HALF_SECTOR:
		coordinate += 1
		offset -= SECTOR_SIZE
	elif offset < -HALF_SECTOR:
		coordinate -= 1
		offset += SECTOR_SIZE
	if coordinate < -MAX_SECTOR_COORDINATE - 1 or coordinate > MAX_SECTOR_COORDINATE:
		return []
	return [coordinate, offset]


static func _is_integer_component(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number)


static func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
