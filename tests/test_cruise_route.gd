extends SceneTree

const Route = preload("res://scripts/cruise_route.gd")


func _initialize() -> void:
	var bodies: Array[Dictionary] = [{"center": Vector3.ZERO, "radius": 850.0}]
	var direct := Route.plan(Vector3(1200, 0, 0), Vector3(1200, 200, 0), bodies)
	assert(direct.ok and direct.points == [Vector3(1200, 200, 0)])
	for pair in [
		[Vector3(1500, 0, 0), Vector3(-1500, 0, 0)],
		[Vector3(0, 1500, 0), Vector3(0, -1500, 0)],
		[Vector3(1500, 40, 80), Vector3(-1100, -60, 200)],
		[Vector3(0, 880, 0), Vector3(0, -890, 0)],
	]:
		var result := Route.plan(pair[0], pair[1], bodies)
		_check(result, pair[0], pair[1], bodies)
		assert(result.points == Route.plan(pair[0], pair[1], bodies).points)

	var multi: Array[Dictionary] = [
		{"center": Vector3(-1200, 0, 0), "radius": 300.0},
		{"center": Vector3(0, 0, 0), "radius": 300.0},
		{"center": Vector3(1200, 0, 0), "radius": 300.0},
	]
	_check(Route.plan(Vector3(-2200, 0, 0), Vector3(2200, 0, 0), multi), Vector3(-2200, 0, 0), Vector3(2200, 0, 0), multi)
	var huge: Array[Dictionary] = [{"center": Vector3.ZERO, "radius": 1000000.0}]
	_check(Route.plan(Vector3(1100000, 0, 0), Vector3(-1100000, 0, 0), huge), Vector3(1100000, 0, 0), Vector3(-1100000, 0, 0), huge)

	var escape := Route.plan(Vector3(851, 0, 0), Vector3(-1500, 0, 0), bodies)
	assert(escape.ok and escape.points[0].is_equal_approx(Vector3(950, 0, 0)))
	var remaining := escape.duplicate(true)
	remaining.points = escape.points.slice(1)
	_check(remaining, escape.points[0], Vector3(-1500, 0, 0), bodies)
	var center_escape := Route.plan(Vector3.ZERO, Vector3(1500, 0, 0), bodies)
	assert(center_escape.ok and center_escape.points[0] == Vector3(950, 0, 0))
	var overlapping: Array[Dictionary] = [
		{"center": Vector3.ZERO, "radius": 850.0},
		{"center": Vector3(900, 0, 0), "radius": 50.0},
	]
	assert(not Route.plan(Vector3(851, 0, 0), Vector3(1500, 0, 0), overlapping).ok)
	assert(not Route.plan(Vector3(1500, 0, 0), Vector3(851, 0, 0), bodies).ok)
	assert(not Route.plan(Vector3(INF, 0, 0), Vector3.ZERO, []).ok)
	assert(not Route.plan(Vector3.ZERO, Vector3(NAN, 0, 0), []).ok)
	assert(not Route.plan(Vector3.ZERO, Vector3.ONE, [{"center": Vector3.ZERO, "radius": INF}]).ok)
	assert(not Route.plan(Vector3.ZERO, Vector3.ONE, [{"center": Vector3.ZERO, "radius": -1}]).ok)
	assert(not Route.plan(Vector3.ZERO, Vector3.ONE, [{"radius": 1}]).ok)
	assert(not Route.plan(Vector3.ZERO, Vector3.ONE, [{"center": Vector3(NAN, 0, 0), "radius": 1}]).ok)
	print("CruiseRoute tests passed: direct, antipodal, polar, multi-body, large-radius, radial escape, validation")
	quit()


func _check(result: Dictionary, start: Vector3, goal: Vector3, bodies: Array[Dictionary]) -> void:
	assert(result.ok, str(result.error))
	assert(not result.points.is_empty() and result.points[-1].is_equal_approx(goal))
	var previous := start
	for point: Vector3 in result.points:
		assert(point.is_finite())
		for body in bodies:
			var line := point - previous
			var t := clampf((body.center - previous).dot(line) / maxf(line.length_squared(), 0.000001), 0.0, 1.0)
			var distance := (previous + line * t).distance_to(body.center)
			assert(distance >= body.radius + 15.0 - 0.01, "Unsafe segment: " + str(distance))
		previous = point
