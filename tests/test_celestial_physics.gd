extends SceneTree

const Physics = preload("res://scripts/celestial_physics.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	assert(absf(Physics.surface_gravity(Physics.EARTH_MU, Physics.EARTH_RADIUS_M) - 9.8) < 0.02)
	var earth_year: float = Physics.orbital_period(Physics.SOLAR_MU, Physics.AU_M)
	assert(absf(earth_year / 86400.0 - 365.26) < 0.1)
	assert(absf(Physics.irradiance(Physics.SOLAR_LUMINOSITY_W, Physics.AU_M) - 1361.0) < 2.0)
	assert(absf(Physics.equilibrium_temperature(1361.0, 0.3) - 255.0) < 1.0)
	assert(absf(pow(Physics.SOLAR_LUMINOSITY_W / (4.0 * PI * Physics.SOLAR_RADIUS_M * Physics.SOLAR_RADIUS_M * Physics.STEFAN_BOLTZMANN), 0.25) - 5772.0) < 2.0)
	assert(absf(Physics.schwarzschild_radius(Physics.SOLAR_MU) / 1000.0 - 2.953) < 0.01)

	var eccentricity: float = 0.2
	var perihelion: Dictionary = Physics.orbital_state(Physics.SOLAR_MU, Physics.AU_M, eccentricity, 0.0, 0.0)
	var aphelion: Dictionary = Physics.orbital_state(Physics.SOLAR_MU, Physics.AU_M, eccentricity, PI, 0.0)
	assert(absf(float(perihelion.distance_m) - Physics.AU_M * (1.0 - eccentricity)) < 1.0)
	assert(absf(float(aphelion.distance_m) - Physics.AU_M * (1.0 + eccentricity)) < 1.0)
	assert(float(perihelion.speed_mps) > float(aphelion.speed_mps))
	var one_year_later: Dictionary = Physics.orbital_state(Physics.SOLAR_MU, Physics.AU_M, eccentricity, 0.7, earth_year)
	var at_epoch: Dictionary = Physics.orbital_state(Physics.SOLAR_MU, Physics.AU_M, eccentricity, 0.7, 0.0)
	assert(absf(float(one_year_later.x_m) - float(at_epoch.x_m)) < 1.0)
	assert(absf(float(one_year_later.y_m) - float(at_epoch.y_m)) < 1.0)
	for result: Dictionary in [perihelion, aphelion, one_year_later]:
		for value: Variant in result.values(): assert(is_finite(float(value)))
	assert(Physics.luminosity(INF, 5000.0) == 0.0)
	assert(Physics.irradiance(1.0, NAN) == 0.0)
	assert(Physics.equilibrium_temperature(1.0, 1.1) == 0.0)
	assert(Physics.surface_gravity(1.0, 0.0) == 0.0)
	assert(Physics.orbital_period(-1.0, 1.0) == 0.0)
	assert(Physics.schwarzschild_radius(NAN) == 0.0)
	assert(Physics.orbital_state(Physics.SOLAR_MU, Physics.AU_M, 0.81, 0.0, 0.0).is_empty())
	assert(Physics.orbital_state(INF, Physics.AU_M, 0.2, 0.0, 0.0).is_empty())
	assert(Physics.orbital_state(Physics.SOLAR_MU, Physics.AU_M, 0.2, NAN, 0.0).is_empty())
	assert(Physics.orbital_state(Physics.SOLAR_MU, Physics.AU_M, 0.2, 0.0, INF).is_empty())
	assert(Physics.orbital_state(Physics.SOLAR_MU, 1.0e31, 0.2, 0.0, 0.0).is_empty())
	assert(absf(Physics.irradiance(1e308, 1e154) - 1.0 / (4.0 * PI)) < 1e-12)
	assert(absf(Physics.surface_gravity(1e300, 1e155) / 1e-10 - 1.0) < 1e-12)
	assert(Physics.equilibrium_temperature(1e308, 0.0) > 1e78)
	assert(Physics.orbital_period(1e-300, 1e29) > 1e190)
	print("CELESTIAL_PHYSICS_OK: reference values, elliptic orbit, invalid inputs")
	quit()
