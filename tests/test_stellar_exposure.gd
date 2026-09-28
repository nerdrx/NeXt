extends SceneTree

const Physics = preload("res://scripts/celestial_physics.gd")
const Exposure = preload("res://scripts/stellar_exposure.gd")

func _initialize() -> void:
	var sun := {"luminosity_w": Physics.SOLAR_LUMINOSITY_W, "radius_m": Physics.SOLAR_RADIUS_M}
	var at_reference := Exposure.irradiance(sun, Vector3.ZERO, Vector3(4500, 0, 0), [])
	var twice_as_far := Exposure.irradiance(sun, Vector3.ZERO, Vector3(9000, 0, 0), [])
	assert(absf(at_reference - 1361.0) < 2.0, "4500 local metres map to one solar AU")
	assert(absf(twice_as_far * 4.0 - at_reference) < 0.01, "irradiance follows inverse square")
	assert(is_equal_approx(Exposure.irradiance(sun, Vector3.ZERO, Vector3.ZERO, []), Exposure.irradiance(sun, Vector3.ZERO, Vector3(250, 0, 0), [])), "local distance has a 250 m floor")

	var dim_large_star := {"luminosity_w": Physics.SOLAR_LUMINOSITY_W * 0.000001, "radius_m": Physics.SOLAR_RADIUS_M * 0.1}
	var radius_limited := Exposure.irradiance(dim_large_star, Vector3.ZERO, Vector3(250, 0, 0), [])
	assert(is_equal_approx(radius_limited, Physics.irradiance(dim_large_star.luminosity_w, Physics.AU_M * 250.0 / 4500.0)), "dim stars retain the one-AU reference floor shared with gravity")

	var occluder := {"position": Vector3(2250, 0, 0), "visual_radius": 10.0}
	assert(Exposure.irradiance(sun, Vector3.ZERO, Vector3(4500, 0, 0), [occluder]) == 0.0, "planet on the point-star segment shadows")
	assert(Exposure.irradiance(sun, Vector3.ZERO, Vector3(4500, 0, 0), [{"position": Vector3(2250, 10, 0), "visual_radius": 10.0}]) == 0.0, "tangent planet also shadows")
	assert(Exposure.irradiance(sun, Vector3.ZERO, Vector3(4500, 0, 0), [{"position": Vector3(5000, 0, 0), "visual_radius": 10.0}]) > 0.0, "planet beyond star does not shadow")
	assert(Exposure.irradiance(sun, Vector3.ZERO, Vector3(4500, 0, 0), [{"position": Vector3.ZERO, "visual_radius": 1.0}]) == 0.0, "sample inside a planet is occluded")

	var box := Vector3(2, 4, 6)
	assert(is_equal_approx(Exposure.absorbed_power(100.0, box, Vector3.RIGHT), 840.0), "face-on X projected area")
	assert(is_equal_approx(Exposure.absorbed_power(100.0, box, Vector3.UP), 420.0), "face-on Y projected area")
	assert(is_equal_approx(Exposure.absorbed_power(100.0, box * 2.0, Vector3.RIGHT), 3360.0), "doubling dimensions quadruples absorbed power")
	assert(is_equal_approx(Exposure.absorbed_power(100.0, box, Vector3(1, 1, 0)), 100.0 * (24.0 + 12.0) / sqrt(2.0) * 0.35), "oblique direction sums projected faces")
	assert(Exposure.absorbed_power(-1.0, box, Vector3.RIGHT) == 0.0)
	assert(Exposure.absorbed_power(INF, box, Vector3.RIGHT) == 0.0)
	assert(Exposure.absorbed_power(10.0, Vector3(-1, 2, 3), Vector3.RIGHT) == 0.0)
	assert(Exposure.absorbed_power(10.0, box, Vector3.ZERO) == 0.0)
	assert(Exposure.absorbed_power(10.0, Vector3(NAN, 1, 1), Vector3.RIGHT) == 0.0)
	assert(Exposure.irradiance({"luminosity_w": 0.0, "radius_m": 10.0}, Vector3.ZERO, Vector3.ONE, []) == 0.0)
	assert(Exposure.irradiance(sun, Vector3(NAN, 0, 0), Vector3.ONE, []) == 0.0)

	print("STELLAR_EXPOSURE_OK: scaled inverse-square light, surface floor, segment shadows and projected absorption")
	quit()
