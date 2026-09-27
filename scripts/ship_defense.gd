class_name ShipDefense
extends RefCounted

const MAX_RANGE: float = 720.0
const MUZZLE_HEIGHT: float = 1.6


static func find_shot(modules: Array, hull: Transform3D, candidates: Array, space: PhysicsDirectSpaceState3D, excluded: Array[RID]) -> Dictionary:
	var weapons: Array[Vector3] = []
	var cells: Array[Vector3] = []
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for module in modules:
		if not module is Dictionary: continue
		var cell := _cell(module)
		cells.append(cell)
		low = low.min(cell)
		high = high.max(cell)
	if cells.is_empty(): return {}
	var center := (low + high) * ShipVisual.CELL_SIZE * 0.5
	for module in modules:
		if module is Dictionary and str(module.get("kind", "")) == "weapon":
			weapons.append((_cell(module) * ShipVisual.CELL_SIZE - center) + Vector3.UP * MUZZLE_HEIGHT)
	if weapons.is_empty(): return {}

	var eligible: Array[ShipActor] = []
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate is ShipActor: continue
		var actor: ShipActor = candidate
		if actor.faction == "player_fleet" or not actor.hostile or not actor.active or actor._destroyed or actor.hp <= 0.0: continue
		if hull.origin.distance_to(actor.global_position) <= MAX_RANGE:
			eligible.append(actor)
	eligible.sort_custom(func(a: ShipActor, b: ShipActor) -> bool:
		return hull.origin.distance_squared_to(a.global_position) < hull.origin.distance_squared_to(b.global_position))

	for actor in eligible:
		for local_origin in weapons:
			var origin := hull * local_origin
			var direction := actor.global_position - origin
			var distance := direction.length()
			if distance <= 0.001 or distance > MAX_RANGE: continue
			var ray := direction / distance
			var local_start := hull.basis.inverse() * (origin - hull.origin)
			var local_ray := hull.basis.inverse() * ray
			var blocked_by_hull := false
			for cell in cells:
				var box_center := cell * ShipVisual.CELL_SIZE - center
				var hit_distance := PvPHits._box_distance(local_start - box_center, local_ray)
				if hit_distance >= 0.0 and hit_distance < distance - 0.01:
					blocked_by_hull = true
					break
			if blocked_by_hull: continue
			var query := PhysicsRayQueryParameters3D.create(origin, actor.global_position, 7, excluded)
			var hit := space.intersect_ray(query)
			if hit.get("collider") == actor:
				return {"target": actor, "origin": origin, "direction": ray, "position": hit.position}
	return {}


static func _cell(module: Dictionary) -> Vector3:
	return Vector3(module.cell) if module.has("cell") else Vector3(module.get("x", 0), module.get("y", 0), module.get("z", 0))
