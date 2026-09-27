extends SceneTree

const PlanetGeologyScript = preload("res://scripts/planet_geology.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for radius: float in [6_378_100.0, 38_000_000.0]:
		for normal: Vector3 in [Vector3(-1.0, 0.015, 0.00001).normalized(), Vector3.UP, Vector3.DOWN, Vector3(0.0001, 1.0, 0.0).normalized()]:
			var started: int = Time.get_ticks_msec()
			var first: Array[Dictionary] = PlanetGeologyScript.placements(radius, normal, 200.0, 773)
			var elapsed: int = Time.get_ticks_msec() - started
			var repeated: Array[Dictionary] = PlanetGeologyScript.placements(radius, normal, 200.0, 773)
			assert(first == repeated, "large-world patch query remains reproducible")
			assert(not first.is_empty() and first.size() <= PlanetGeologyScript.MAX_INSTANCES)
			assert(elapsed < 5000, "large-world placement work stays bounded")
			for entry: Dictionary in first:
				var local: Vector3 = entry.local_position
				assert(local.is_finite() and local.length() < 1000.0, "anchor-relative position avoids radius-sized coordinates")
				var direction: Vector3 = entry.direction
				var height: float = PlanetHeightField.surface_height(direction, 773) - entry.scale.y * 0.25
				var dir_length: float = sqrt(float(direction.x) * direction.x + float(direction.y) * direction.y + float(direction.z) * direction.z)
				var up: Vector3 = normal if normal.is_normalized() else normal.normalized()
				var up_length: float = sqrt(float(up.x) * up.x + float(up.y) * up.y + float(up.z) * up.z)
				var expected := Vector3(float(direction.x) / dir_length * (radius + height) - float(up.x) / up_length * radius, float(direction.y) / dir_length * (radius + height) - float(up.y) / up_length * radius, float(direction.z) / dir_length * (radius + height) - float(up.z) / up_length * radius)
				assert(local.distance_to(expected) < 0.02, "local rock origin touches computed surface")
			print("Large geology tests passed for radius %s, normal %s in %d ms" % [radius, normal, elapsed])
	var radius: float = 38_000_000.0
	var normal := Vector3(-1.0, 0.015, 0.00001).normalized()
	var shifted_normal := (normal + Vector3(0.0, 0.0, 0.0000001)).normalized()
	var original: Array[Dictionary] = PlanetGeologyScript.placements(radius, normal, 200.0, 773)
	var shifted: Array[Dictionary] = PlanetGeologyScript.placements(radius, shifted_normal, 200.0, 773)
	var shifted_by_id: Dictionary = {}
	for entry: Dictionary in shifted:
		shifted_by_id[entry.id] = entry
	var shared: int = 0
	for entry: Dictionary in original:
		if not shifted_by_id.has(entry.id):
			continue
		var world_a: Array[float] = _world_components(radius, normal, entry.local_position)
		var other: Dictionary = shifted_by_id[entry.id]
		var world_b: Array[float] = _world_components(radius, shifted_normal, other.local_position)
		assert(Vector3(world_a[0] - world_b[0], world_a[1] - world_b[1], world_a[2] - world_b[2]).length() < 0.001, "shared large-world rock stays fixed after recentering")
		shared += 1
	assert(shared > 0, "nearby large patches share placement IDs")
	quit()

func _world_components(radius: float, normal: Vector3, local: Vector3) -> Array[float]:
	var up: Vector3 = normal if normal.is_normalized() else normal.normalized()
	var up_length: float = sqrt(float(up.x) * up.x + float(up.y) * up.y + float(up.z) * up.z)
	return [float(up.x) / up_length * radius + local.x, float(up.y) / up_length * radius + local.y, float(up.z) / up_length * radius + local.z]
