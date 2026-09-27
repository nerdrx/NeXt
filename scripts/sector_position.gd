class_name SectorPosition
extends RefCounted

const SECTOR_SIZE: float = 8192.0
const HALF_SECTOR: float = SECTOR_SIZE * 0.5
const MAX_RELATIVE_DISTANCE: float = 1_000_000.0
const MAX_SECTOR_COORDINATE: int = 2147483647
const REGION_SECTORS: int = 1073741824
const HALF_REGION_SECTORS: int = REGION_SECTORS / 2
const SAVE_VERSION: int = 2

var region: Vector3i
var sector: Vector3i
var local: Vector3

func _init(sector_coordinates: Vector3i = Vector3i.ZERO, local_position: Vector3 = Vector3.ZERO, region_coordinates: Vector3i = Vector3i.ZERO) -> void:
	region = region_coordinates
	sector = sector_coordinates
	local = local_position
	if not _normalize():
		region = Vector3i.ZERO
		sector = Vector3i.ZERO
		local = Vector3.ZERO

func clone() -> SectorPosition:
	return SectorPosition.new(sector, local, region)

func sector_origin() -> SectorPosition:
	# Origin of this local sector, retaining its enclosing region.
	return SectorPosition.new(sector, Vector3.ZERO, region)

func move_delta(delta: Vector3) -> bool:
	if not delta.is_finite(): return false
	var old_local := local
	local += delta
	if _normalize(): return true
	local = old_local
	return false

func relative_to(origin: SectorPosition, max_distance: float) -> Variant:
	if origin == null or not is_finite(max_distance) or max_distance < 0.0 or max_distance > MAX_RELATIVE_DISTANCE: return null
	# Reject far regions before any float conversion or large integer product.
	var rx: int = int(region.x) - int(origin.region.x)
	var ry: int = int(region.y) - int(origin.region.y)
	var rz: int = int(region.z) - int(origin.region.z)
	if absi(rx) > 1 or absi(ry) > 1 or absi(rz) > 1: return null
	var dx: int = rx * REGION_SECTORS + int(sector.x) - int(origin.sector.x)
	var dy: int = ry * REGION_SECTORS + int(sector.y) - int(origin.sector.y)
	var dz: int = rz * REGION_SECTORS + int(sector.z) - int(origin.sector.z)
	var sector_limit := ceili(max_distance / SECTOR_SIZE) + 1
	if absi(dx) > sector_limit or absi(dy) > sector_limit or absi(dz) > sector_limit: return null
	var offset := Vector3(dx, dy, dz) * SECTOR_SIZE + (local - origin.local)
	return offset if offset.length_squared() <= max_distance * max_distance else null

func direction_to(target: SectorPosition) -> Vector3:
	if target == null: return Vector3.ZERO
	var nearby: Variant = target.relative_to(self, MAX_RELATIVE_DISTANCE)
	if nearby != null: return Vector3(nearby).normalized()
	# Only a direction is needed for remote route planning, not a physics position.
	var x := (float(target.region.x) - region.x) * REGION_SECTORS + float(target.sector.x) - sector.x + (float(target.local.x) - local.x) / SECTOR_SIZE
	var y := (float(target.region.y) - region.y) * REGION_SECTORS + float(target.sector.y) - sector.y + (float(target.local.y) - local.y) / SECTOR_SIZE
	var z := (float(target.region.z) - region.z) * REGION_SECTORS + float(target.sector.z) - sector.z + (float(target.local.z) - local.z) / SECTOR_SIZE
	return Vector3(x, y, z).normalized()

func to_save() -> Dictionary:
	return {"version": SAVE_VERSION, "region": [region.x, region.y, region.z], "sector": [sector.x, sector.y, sector.z], "local": [local.x, local.y, local.z]}

static func from_save(value: Variant) -> Variant:
	if not value is Dictionary or not _is_integer_component(value.get("version")): return null
	if int(value.version) != 1 and int(value.version) != SAVE_VERSION: return null
	var legacy: bool = value.version == 1
	var raw_regions: Variant = [0, 0, 0] if legacy else value.get("region")
	var raw_sectors: Variant = value.get("sector")
	var raw_local: Variant = value.get("local")
	if not raw_regions is Array or raw_regions.size() != 3 or not raw_sectors is Array or raw_sectors.size() != 3 or not raw_local is Array or raw_local.size() != 3: return null
	for component: Variant in raw_regions:
		if not _valid_int32(component): return null
	for component: Variant in raw_sectors:
		if not _valid_int32(component): return null
		if not legacy and (int(component) < -HALF_REGION_SECTORS or int(component) >= HALF_REGION_SECTORS): return null
	for component: Variant in raw_local:
		if not _is_finite_number(component) or float(component) < -HALF_SECTOR or float(component) >= HALF_SECTOR: return null
	var result := SectorPosition.new()
	result.region = Vector3i(int(raw_regions[0]), int(raw_regions[1]), int(raw_regions[2]))
	result.sector = Vector3i(int(raw_sectors[0]), int(raw_sectors[1]), int(raw_sectors[2]))
	result.local = Vector3(float(raw_local[0]), float(raw_local[1]), float(raw_local[2]))
	return result if result._normalize() else null

static func from_meters(x: float, y: float, z: float) -> SectorPosition:
	# Split scalar doubles before storing bounded residuals in Godot's float Vector3.
	var parts: Array = []
	for component: float in [x, y, z]:
		if not is_finite(component): return null
		var regions: float = floor((component / SECTOR_SIZE + HALF_REGION_SECTORS) / REGION_SECTORS)
		if regions < -2147483648.0 or regions > MAX_SECTOR_COORDINATE: return null
		var residual: float = component - regions * REGION_SECTORS * SECTOR_SIZE
		var axis := _normalize_axis(int(regions), 0, residual)
		if axis.is_empty(): return null
		parts.append(axis)
	return SectorPosition.new(Vector3i(parts[0][1], parts[1][1], parts[2][1]), Vector3(parts[0][2], parts[1][2], parts[2][2]), Vector3i(parts[0][0], parts[1][0], parts[2][0]))

func _normalize() -> bool:
	if not local.is_finite(): return false
	var x := _normalize_axis(region.x, sector.x, local.x)
	var y := _normalize_axis(region.y, sector.y, local.y)
	var z := _normalize_axis(region.z, sector.z, local.z)
	if x.is_empty() or y.is_empty() or z.is_empty(): return false
	region = Vector3i(x[0], y[0], z[0])
	sector = Vector3i(x[1], y[1], z[1])
	local = Vector3(x[2], y[2], z[2])
	return true

static func _normalize_axis(base_region: int, base_sector: int, value: float) -> Array:
	var shift_float: float = floor((value + HALF_SECTOR) / SECTOR_SIZE)
	# Bound intermediates below int64 overflow. Larger moves must use from_meters.
	if not is_finite(shift_float) or absf(shift_float) > MAX_SECTOR_COORDINATE * 2.0: return []
	var coordinate: int = base_sector + int(shift_float)
	var offset: float = value - shift_float * SECTOR_SIZE
	if offset >= HALF_SECTOR:
		coordinate += 1
		offset -= SECTOR_SIZE
	elif offset < -HALF_SECTOR:
		coordinate -= 1
		offset += SECTOR_SIZE
	var region_shift: int = int(floor(float(coordinate + HALF_REGION_SECTORS) / REGION_SECTORS))
	var next_region: int = base_region + region_shift
	if next_region < -2147483648 or next_region > MAX_SECTOR_COORDINATE: return []
	return [next_region, coordinate - region_shift * REGION_SECTORS, offset]

static func _valid_int32(value: Variant) -> bool:
	return _is_integer_component(value) and float(value) >= -2147483648.0 and float(value) <= MAX_SECTOR_COORDINATE

static func _is_integer_component(value: Variant) -> bool:
	if typeof(value) == TYPE_INT: return true
	if typeof(value) != TYPE_FLOAT: return false
	var number := float(value)
	return is_finite(number) and number == floor(number)

static func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))
