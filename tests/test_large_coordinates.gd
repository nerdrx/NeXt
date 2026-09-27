extends SceneTree

const REGION_SECTORS := 1073741824
const HALF_REGION_SECTORS := REGION_SECTORS / 2
const HALF_SECTOR := 4096.0
const AU := 149597870700.0


func _initialize() -> void:
	_test_region_boundaries()
	_test_far_relative_coordinates()
	_test_rejected_inputs_are_safe()
	_test_save_migration()
	var directional_origin := SectorPosition.new(Vector3i.ZERO, Vector3(0, -4095, 0))
	var directional_target := SectorPosition.new(Vector3i(123, 0, 0), Vector3(0, 4095, 0))
	var expected_direction := Vector3(123 * SectorPosition.SECTOR_SIZE, 8190, 0).normalized()
	assert(directional_origin.direction_to(directional_target).distance_to(expected_direction) < 1e-7, "remote guidance includes transverse local offsets")
	print("Large coordinate tests passed")
	quit()


func _test_region_boundaries() -> void:
	var positive := SectorPosition.new(
		Vector3i(HALF_REGION_SECTORS - 1, 0, 0), Vector3(HALF_SECTOR - 0.01, 0.0, 0.0)
	)
	var before_boundary := positive.clone()
	assert(positive.move_delta(Vector3(0.02, 0.0, 0.0)))
	assert(positive.region == Vector3i(1, 0, 0))
	assert(positive.sector == Vector3i(-HALF_REGION_SECTORS, 0, 0))
	assert(is_equal_approx(positive.local.x, -HALF_SECTOR + 0.01))
	assert(absf(positive.relative_to(before_boundary, 1.0).x - 0.02) < 0.001)

	var negative := SectorPosition.new(
		Vector3i(-HALF_REGION_SECTORS, 0, 0), Vector3(-HALF_SECTOR + 0.01, 0.0, 0.0)
	)
	assert(negative.move_delta(Vector3(-0.02, 0.0, 0.0)))
	assert(negative.region == Vector3i(-1, 0, 0))
	assert(negative.sector == Vector3i(HALF_REGION_SECTORS - 1, 0, 0))
	assert(is_equal_approx(negative.local.x, HALF_SECTOR - 0.01))

	var neighbor := positive.clone()
	assert(neighbor.move_delta(Vector3(0.01, 0.0, 0.0)))
	assert(is_equal_approx(neighbor.relative_to(positive, 1.0).x, 0.01))


func _test_far_relative_coordinates() -> void:
	var several_au: SectorPosition = SectorPosition.from_meters(3.0 * AU, -2.0 * AU, 0.5 * AU)
	assert(several_au != null)
	var near_several_au: SectorPosition = SectorPosition.from_meters(3.0 * AU + 1.0, -2.0 * AU, 0.5 * AU)
	assert(near_several_au != null)
	assert(near_several_au.relative_to(several_au, 2.0) == Vector3(1.0, 0.0, 0.0))
	assert(several_au.direction_to(SectorPosition.new()).dot(Vector3(-3.0, 2.0, -0.5).normalized()) > 0.999999)

	var ten_thousand_au: SectorPosition = SectorPosition.from_meters(10000.0 * AU, 0.0, 0.0)
	var one_meter_away: SectorPosition = SectorPosition.from_meters(10000.0 * AU + 1.0, 0.0, 0.0)
	assert(ten_thousand_au != null and one_meter_away != null)
	assert(one_meter_away.relative_to(ten_thousand_au, 2.0) == Vector3(1.0, 0.0, 0.0))


func _test_rejected_inputs_are_safe() -> void:
	assert(SectorPosition.from_meters(INF, 0.0, 0.0) == null)
	assert(SectorPosition.from_meters(NAN, 0.0, 0.0) == null)
	assert(SectorPosition.from_meters(1.0e300, 0.0, 0.0) == null)

	var overflowing := SectorPosition.new(
		Vector3i(HALF_REGION_SECTORS - 1, 0, 0), Vector3(HALF_SECTOR - 0.01, 0.0, 0.0),
		Vector3i(2147483647, 0, 0)
	)
	var before := overflowing.to_save()
	assert(not overflowing.move_delta(Vector3(0.02, 0.0, 0.0)))
	assert(overflowing.to_save() == before, "overflow must not partially mutate address")

	var underflowing := SectorPosition.new(
		Vector3i(-HALF_REGION_SECTORS, 0, 0), Vector3(-HALF_SECTOR + 0.01, 0.0, 0.0),
		Vector3i(-2147483648, 0, 0)
	)
	before = underflowing.to_save()
	assert(not underflowing.move_delta(Vector3(-0.02, 0.0, 0.0)))
	assert(underflowing.to_save() == before, "underflow must not partially mutate address")


func _test_save_migration() -> void:
	var original := SectorPosition.new(Vector3i(123, -456, 7), Vector3(0.01, -0.02, 7.5), Vector3i(17, -9, 2))
	var json_value: Variant = JSON.parse_string(JSON.stringify(original.to_save()))
	var restored: SectorPosition = SectorPosition.from_save(json_value)
	assert(restored != null and restored.region == original.region and restored.sector == original.sector)
	assert(absf(restored.local.x - 0.01) < 0.0001 and absf(restored.local.y + 0.02) < 0.0001)
	assert(restored.relative_to(original, 0.0) == Vector3.ZERO)

	var legacy: SectorPosition = SectorPosition.from_save({
		"version": 1,
		"sector": [2147483647, -2147483648, 0],
		"local": [123.25, -456.5, 0.0],
	})
	assert(legacy != null)
	assert(legacy.region == Vector3i(2, -2, 0))
	assert(legacy.sector == Vector3i(-1, 0, 0))
	assert(legacy.local == Vector3(123.25, -456.5, 0.0))
	assert(legacy.relative_to(SectorPosition.new(legacy.sector, legacy.local, legacy.region), 0.0) == Vector3.ZERO)
	assert(legacy.to_save().get("version") == 2)
