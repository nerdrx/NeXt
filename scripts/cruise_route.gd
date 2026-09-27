class_name CruiseRoute
extends RefCounted

const CLEARANCE := 15.0
const SHELL := 100.0
const MAX_DETOURS := 32
const MAX_POINTS := 4096


static func plan(start: Vector3, goal: Vector3, bodies: Array[Dictionary]) -> Dictionary:
	if not _finite(start) or not _finite(goal) or not _finite(goal - start):
		return _failure("Invalid route coordinates")
	for body in bodies:
		if not body.get("center") is Vector3 or not _finite(body.center):
			return _failure("Invalid body center")
		if not (body.get("radius") is float or body.get("radius") is int):
			return _failure("Invalid body radius")
		if not is_finite(float(body.radius)) or float(body.radius) <= 0.0:
			return _failure("Invalid body radius")
		if not _finite(start - body.center) or not _finite(goal - body.center):
			return _failure("Body is outside numeric route bounds")
		if goal.distance_to(body.center) < float(body.radius) + CLEARANCE:
			return _failure("Destination is below safe clearance")

	var points: Array[Vector3] = []
	var route_start := start
	var escaped_body := -1
	for i in bodies.size():
		var body := bodies[i]
		if start.distance_to(body.center) < float(body.radius) + CLEARANCE:
			if escaped_body >= 0:
				return _failure("Overlapping departure obstacles")
			escaped_body = i
			var radial: Vector3 = start - body.center
			if radial.length_squared() < 0.000001:
				radial = Vector3.RIGHT
			route_start = body.center + radial.normalized() * (float(body.radius) + SHELL)
	if escaped_body >= 0:
		for i in bodies.size():
			if i != escaped_body and _blocked(start, route_start, bodies[i]):
				return _failure("Radial departure is obstructed")
		points.append(route_start)

	var route: Array[Vector3] = [route_start, goal]
	# ponytail: bounded spherical detours; explicitly fail dense/overlapping geometry.
	for _attempt in MAX_DETOURS:
		var changed := false
		for segment in range(route.size() - 1):
			for body in bodies:
				if not _blocked(route[segment], route[segment + 1], body):
					continue
				var detour := _detour(route[segment], route[segment + 1], body)
				if detour.is_empty() or route.size() + detour.size() > MAX_POINTS:
					return _failure("No bounded safe route")
				for j in detour.size():
					route.insert(segment + 1 + j, detour[j])
				changed = true
				break
			if changed:
				break
		if not changed:
			for i in range(1, route.size()):
				if points.is_empty() or points[-1].distance_to(route[i]) > 0.001:
					points.append(route[i])
			return {"ok": true, "points": points, "error": ""}
	return _failure("Route detour limit reached")


static func _finite(value: Vector3) -> bool:
	return value.is_finite() and is_finite(value.length_squared())


static func _blocked(a: Vector3, b: Vector3, body: Dictionary) -> bool:
	var delta := b - a
	var t := 0.0
	if delta.length_squared() > 0.000001:
		t = clampf((body.center - a).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return (a + delta * t).distance_to(body.center) < float(body.radius) + CLEARANCE


static func _detour(a: Vector3, b: Vector3, body: Dictionary) -> Array[Vector3]:
	var center: Vector3 = body.center
	var radius := float(body.radius)
	if a.distance_to(center) < radius + CLEARANCE or b.distance_to(center) < radius + CLEARANCE:
		return []
	var from := (a - center).normalized()
	var to := (b - center).normalized()
	var angle := acos(clampf(from.dot(to), -1.0, 1.0))
	var axis := from.cross(to)
	if axis.length_squared() < 0.000001:
		axis = from.cross(Vector3.UP if absf(from.y) < 0.9 else Vector3.RIGHT)
	axis = axis.normalized()
	var shell := radius + SHELL
	# Chord clearance remains safe even when planet radius is much larger than 100 m.
	var step := minf(0.2, 2.0 * acos((radius + CLEARANCE + 1.0) / shell))
	if step <= 0.0 or not is_finite(step):
		return []
	var count := ceili(angle / step)
	if count > MAX_POINTS - 2:
		return []
	var result: Array[Vector3] = [center + from * shell]
	for i in range(1, count):
		result.append(center + from.rotated(axis, angle * float(i) / count) * shell)
	result.append(center + to * shell)
	return result


static func _failure(message: String) -> Dictionary:
	var empty: Array[Vector3] = []
	return {"ok": false, "points": empty, "error": message}
