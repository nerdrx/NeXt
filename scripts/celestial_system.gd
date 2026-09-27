class_name CelestialSystem
extends RefCounted

# Physical catalog v2. Separate RNG leaves existing terrain, names and saves intact.
# Stellar profiles are bounded game-generation approximations, not stellar evolution.
const MODEL_VERSION := 2
const GRAVITATIONAL_CONSTANT := 6.67430e-11

static func generate(index: int) -> Dictionary:
	var address := clampi(index, 0, Universe.SYSTEM_LIMIT - 1)
	var legacy := Universe.system_data(address)
	var rng := Universe._rng(address, 2903)
	# Orientation draws must not perturb v1 physical properties or legacy worlds.
	var frame_rng := Universe._rng(address, 2904)
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
		body["inclination_rad"] = frame_rng.randf_range(-0.12, 0.12)
		body["ascending_node_rad"] = frame_rng.randf_range(0.0, TAU)
		body["periapsis_rad"] = frame_rng.randf_range(0.0, TAU)
		body["axial_tilt_rad"] = frame_rng.randf_range(0.0, 0.65)
		body["spin_phase_at_epoch"] = frame_rng.randf_range(0.0, TAU)
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
	var oriented := CelestialFrame.oriented_orbit(orbit, body.get("inclination_rad", 0.0), body.get("ascending_node_rad", 0.0), body.get("periapsis_rad", 0.0))
	if oriented.is_empty(): return {}
	orbit.merge(oriented)
	var position: Array = orbit.position_m
	var address := SectorPosition.from_meters(position[0], position[1], position[2])
	if address == null: return {}
	orbit["address"] = address.to_save()
	var flux := CelestialPhysics.irradiance(star.luminosity_w, orbit.distance_m)
	orbit["irradiance_w_m2"] = flux
	orbit["equilibrium_temperature_k"] = CelestialPhysics.equilibrium_temperature(flux, body.bond_albedo)
	return orbit

static func surface_sample(catalog: Dictionary, planet_index: int, local_point: Vector3, elapsed_seconds: float) -> Dictionary:
	var orbit := sample(catalog, planet_index, elapsed_seconds)
	if orbit.is_empty() or not local_point.is_finite() or local_point.length_squared() <= 0.0: return {}
	var frame := CelestialFrame.surface_state(orbit, catalog.planets[planet_index], local_point, elapsed_seconds)
	if frame.is_empty(): return {}
	var position: Array = frame.position_m
	var distance := sqrt(float(position[0]) * position[0] + float(position[1]) * position[1] + float(position[2]) * position[2])
	if not is_finite(distance) or distance <= 0.0: return {}
	var normal: Vector3 = frame.orientation * local_point.normalized()
	var cosine := -(normal.x * float(position[0]) + normal.y * float(position[1]) + normal.z * float(position[2])) / distance
	# Point-source illumination on a spherical surface, before atmospheric absorption.
	frame["direct_irradiance_w_m2"] = CelestialPhysics.irradiance(catalog.star.luminosity_w, distance) * clampf(cosine, 0.0, 1.0)
	frame["sun_above_horizon"] = cosine > 0.0
	return frame

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
