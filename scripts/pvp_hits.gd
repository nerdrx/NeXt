class_name PvPHits
extends RefCounted

const RANGE: float = 2200.0
const CAMERA_OFFSET := Vector3(0, 1.55, 0)


# Profiles come from NetworkSession validation; clients never supply damage or a victim.
static func trace(attacker: Dictionary, presence: Dictionary, direction: Vector3, attacker_id: int = -1) -> Dictionary:
	if not attacker.get("pvp", false) or not attacker.get("flying", false): return {}
	if not direction.is_finite() or not is_finite(direction.length_squared()) or direction.length_squared() < 0.000001: return {}
	var origin: Variant = SectorPosition.from_save(attacker.get("address"))
	if origin == null: return {}
	var ray := direction.normalized()
	var closest := RANGE + 1.0
	var target_id := -1
	var eligible := false
	for id: int in presence:
		if id == attacker_id: continue
		var profile: Dictionary = presence[id]
		var address: Variant = SectorPosition.from_save(profile.get("address"))
		if address == null: continue
		# Include hull extent when bounding sector conversion, then clip the actual ray hit.
		var offset: Variant = address.relative_to(origin, RANGE + 300.0)
		if offset == null: continue
		var rotation: Vector3 = profile.get("rotation", Vector3.ZERO)
		if not rotation.is_finite(): continue
		var inverse := Basis.from_euler(rotation).inverse()
		var start: Vector3 = inverse * (CAMERA_OFFSET - offset)
		var local_ray := inverse * ray
		var modules: Array = profile.get("ship_modules", [])
		if modules.is_empty(): continue
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for module: Dictionary in modules:
			var cell := _cell(module)
			low = low.min(cell)
			high = high.max(cell)
		# ShipVisual centers its hull around the module bounds midpoint.
		var center := (low + high) * ShipVisual.CELL_SIZE * 0.5
		for module: Dictionary in modules:
			var box_center := _cell(module) * ShipVisual.CELL_SIZE - center
			var distance := _box_distance(start - box_center, local_ray)
			var can_damage: bool = profile.get("pvp", false) and profile.get("flying", false)
			var tied := is_equal_approx(distance, closest)
			if distance >= 0.0 and distance <= RANGE and (distance < closest or (tied and ((eligible and not can_damage) or (eligible == can_damage and id < target_id)))):
				closest = distance
				target_id = id
				eligible = can_damage
	if target_id < 0 or not eligible: return {}
	var state := GameState.new()
	state.ship_modules.assign(attacker.get("ship_modules", []))
	var damage := float(state.ship_stats().damage)
	if not is_finite(damage) or damage <= 0.0: return {}
	return {"target": target_id, "distance": closest, "damage": damage}


static func _box_distance(start: Vector3, direction: Vector3) -> float:
	var near := 0.0
	var far := RANGE
	var half := ShipVisual.CELL_SIZE * 0.5
	for axis in range(3):
		if absf(direction[axis]) < 0.0000001:
			if absf(start[axis]) > half: return -1.0
			continue
		var a := (-half - start[axis]) / direction[axis]
		var b := (half - start[axis]) / direction[axis]
		near = maxf(near, minf(a, b))
		far = minf(far, maxf(a, b))
		if far < near: return -1.0
	return near


static func _cell(module: Dictionary) -> Vector3:
	return Vector3(module.cell) if module.has("cell") else Vector3(module.get("x", 0), module.get("y", 0), module.get("z", 0))
