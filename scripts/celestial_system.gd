class_name CelestialSystem
extends RefCounted

# Physical catalog v1. Separate RNG leaves existing terrain, names and saves intact.
# Stellar profiles are bounded game-generation approximations, not stellar evolution.
const MODEL_VERSION := 1
const GRAVITATIONAL_CONSTANT := 6.67430e-11

static func generate(index: int) -> Dictionary:
	var address := clampi(index, 0, Universe.SYSTEM_LIMIT - 1)
	var legacy := Universe.system_data(address)
	var rng := Universe._rng(address, 2903)
	var star := _star(str(legacy.star_type), rng)
	star["id"] = "%d:primary" % address
	var bodies: Array[Dictionary] = []
	var axis := maxf(0.05 * CelestialPhysics.AU_M, maxf(8.0 * float(star.radius_m), 0.4 * sqrt(maxf(float(star.luminosity_w) / CelestialPhysics.SOLAR_LUMINOSITY_W, 0.25)) * CelestialPhysics.AU_M))
	for i in legacy.planets.size():
		var source: Dictionary = legacy.planets[i]
		var radius := float(source.radius) * CelestialPhysics.EARTH_RADIUS_M
		var giant := float(source.radius) >= 1.8
		var density := rng.randf_range(1000.0, 1800.0) if giant else rng.randf_range(3500.0, 6500.0)
		var mass := 4.0 / 3.0 * PI * pow(radius, 3.0) * density
		var body := {
			"id": "%d:planet:%d" % [address, i], "name": source.name,
			"kind": "Ice giant" if giant else "Rocky", "radius_m": radius,
			"mass_kg": mass, "mu_m3_s2": mass * GRAVITATIONAL_CONSTANT,
			"semi_major_m": axis, "eccentricity": rng.randf_range(0.0, 0.15),
			"mean_anomaly_at_epoch": rng.randf_range(0.0, TAU),
			"bond_albedo": rng.randf_range(0.08, 0.65),
			"rotation_seconds": rng.randf_range(10.0, 72.0) * 3600.0,
			"atmosphere": giant or bool(source.atmosphere),
		}
		body["surface_gravity_mps2"] = CelestialPhysics.surface_gravity(body.mu_m3_s2, radius)
		body["period_seconds"] = CelestialPhysics.orbital_period(float(star.mu_m3_s2) + mass * GRAVITATIONAL_CONSTANT, axis)
		bodies.append(body)
		axis *= rng.randf_range(1.8, 2.2)
	return {"version": MODEL_VERSION, "system_index": address, "star": star, "planets": bodies}

static func sample(catalog: Dictionary, planet_index: int, elapsed_seconds: float) -> Dictionary:
	if planet_index < 0 or planet_index >= catalog.planets.size(): return {}
	var body: Dictionary = catalog.planets[planet_index]
	var star: Dictionary = catalog.star
	var orbit := CelestialPhysics.orbital_state(float(star.mu_m3_s2) + float(body.mu_m3_s2), body.semi_major_m, body.eccentricity, body.mean_anomaly_at_epoch, elapsed_seconds)
	if orbit.is_empty(): return {}
	var flux := CelestialPhysics.irradiance(star.luminosity_w, orbit.distance_m)
	orbit["irradiance_w_m2"] = flux
	orbit["equilibrium_temperature_k"] = CelestialPhysics.equilibrium_temperature(flux, body.bond_albedo)
	return orbit

static func _star(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var mass_solar := rng.randf_range(0.8, 1.3)
	var radius := 0.0
	var temperature := 0.0
	var light := 0.0
	match kind:
		"Red Dwarf": mass_solar = rng.randf_range(0.1, 0.55)
		"Blue Giant": mass_solar = rng.randf_range(8.0, 30.0)
		"White Dwarf": mass_solar = rng.randf_range(0.5, 1.1)
		"Neutron Star": mass_solar = rng.randf_range(1.2, 2.0)
		"Black Hole": mass_solar = rng.randf_range(4.0, 20.0)
	var mu := mass_solar * CelestialPhysics.SOLAR_MU
	match kind:
		"Black Hole": radius = CelestialPhysics.schwarzschild_radius(mu)
		"Neutron Star":
			radius = rng.randf_range(10000.0, 14000.0)
			temperature = rng.randf_range(500000.0, 2000000.0)
		"White Dwarf":
			radius = 0.012 * CelestialPhysics.SOLAR_RADIUS_M * pow(mass_solar / 0.6, -1.0 / 3.0)
			temperature = rng.randf_range(8000.0, 30000.0)
		_:
			radius = CelestialPhysics.SOLAR_RADIUS_M * pow(mass_solar, 0.8)
			light = CelestialPhysics.SOLAR_LUMINOSITY_W * (0.23 * pow(mass_solar, 2.3) if mass_solar < 0.43 else pow(mass_solar, 3.5 if kind == "Blue Giant" else 4.0))
			if kind == "Blue Giant": radius *= 1.8
			temperature = pow(light / (4.0 * PI * radius * radius * CelestialPhysics.STEFAN_BOLTZMANN), 0.25)
	if kind != "Black Hole": light = CelestialPhysics.luminosity(radius, temperature)
	return {"kind": "Yellow Star" if kind == "Nebula" else kind, "embedded_nebula": kind == "Nebula", "mass_kg": mu / GRAVITATIONAL_CONSTANT, "mu_m3_s2": mu, "radius_m": radius, "temperature_k": temperature, "luminosity_w": light}
