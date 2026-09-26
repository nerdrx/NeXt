extends SceneTree


func _initialize() -> void:
	var position := SectorPosition.new()
	assert(position.move_delta(Vector3(4096.0, -4096.0, 0.0)))
	assert(position.sector == Vector3i(1, 0, 0))
	assert(position.local == Vector3(-4096.0, -4096.0, 0.0))
	assert(position.move_delta(Vector3(0.0, -0.25, 0.0)))
	assert(position.sector.y == -1 and position.local.y == 4095.75)

	var long_run := SectorPosition.new()
	for _i in 10000:
		assert(long_run.move_delta(Vector3(8192.25, -8192.25, 0.0)))
	assert(long_run.sector == Vector3i(10000, -10000, 0))
	assert(is_equal_approx(long_run.local.x, 2500.0))
	assert(is_equal_approx(long_run.local.y, -2500.0))

	var saved := long_run.to_save()
	var loaded: SectorPosition = SectorPosition.from_save(saved)
	assert(loaded != null and loaded.sector == long_run.sector and loaded.local == long_run.local)
	assert(loaded.to_save() == saved, "save/load must preserve canonical address")
	assert(loaded.relative_to(long_run, 0.0) == Vector3.ZERO)
	assert(loaded.relative_to(SectorPosition.new(Vector3i(10000, -10000, 0), Vector3.ZERO), 4000.0) == loaded.local)
	assert(loaded.relative_to(SectorPosition.new(), 3000.0) == null, "far offsets must not become draw coordinates")
	assert(loaded.relative_to(long_run, 1_000_001.0) == null, "relative radius has a hard safety cap")

	var before := position.to_save()
	assert(not position.move_delta(Vector3(INF, 0.0, 0.0)))
	assert(position.to_save() == before, "invalid moves must not mutate position")
	assert(SectorPosition.from_save({"version": 1, "sector": [0, 0.5, 0], "local": [0, 0, 0]}) == null)
	assert(SectorPosition.from_save({"version": 1, "sector": [0, 0, 0], "local": [4096, 0, 0]}) == null)
	assert(SectorPosition.from_save({"version": 1, "sector": [2147483648, 0, 0], "local": [0, 0, 0]}) == null)
	assert(SectorPosition.from_save({"version": 2, "sector": [0, 0, 0], "local": [0, 0, 0]}) == null)

	print("SectorPosition tests passed")
	quit()
