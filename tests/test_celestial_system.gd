extends SceneTree

func _initialize() -> void:
	var legacy_hashes := {0: "ab189da0f664f3eeab06215c04ca437de7826f729891916331d03c1365c1bd4e", 42: "8589858de3caa5b41d3a4ae3e836253d1e53c58e7cd3abaa6ba5a03aa165e960", 123456: "654c04bc44338c8e30cd4f9261022b40223dfb56071fb97e7c79423235792201", 999999999: "d3c5153ea03f7e0a6e57c9bf512a9e513b7c66a24a29230e5ae12c21c6233dfd"}
	for index: int in legacy_hashes:
		assert(JSON.stringify(Universe.system_data(index)).sha256_text() == legacy_hashes[index], "existing world generation remains stable")
	var kinds := {}
	for index in 100:
		var catalog := CelestialSystem.generate(index)
		assert(catalog == CelestialSystem.generate(index))
		var star: Dictionary = catalog.star
		kinds[Universe.system_data(index).star_type] = true
		assert(star.mu_m3_s2 > 0 and star.radius_m > 0 and is_finite(star.mass_kg))
		if star.kind == "Black Hole":
			assert(star.luminosity_w == 0.0)
			assert(is_equal_approx(star.radius_m, CelestialPhysics.schwarzschild_radius(star.mu_m3_s2)))
		var previous_apo := 0.0
		for i in catalog.planets.size():
			var body: Dictionary = catalog.planets[i]
			assert(body.semi_major_m * (1.0 - body.eccentricity) > maxf(star.radius_m, previous_apo))
			previous_apo = body.semi_major_m * (1.0 + body.eccentricity)
			var sample := CelestialSystem.sample(catalog, i, 0.0)
			assert(not sample.is_empty())
			assert(sample.equilibrium_temperature_k >= 0.0 and is_finite(sample.irradiance_w_m2))
			assert(sample == CelestialSystem.sample(catalog, i, 0.0))
	assert(kinds.size() == Universe.STAR_TYPES.size())
	# Shared orbital distance drives radiation and equilibrium temperature.
	var fixture := CelestialSystem.generate(0)
	fixture.star.luminosity_w = CelestialPhysics.SOLAR_LUMINOSITY_W
	fixture.planets[0].eccentricity = 0.2
	fixture.planets[0].mean_anomaly_at_epoch = 0.0
	var near := CelestialSystem.sample(fixture, 0, 0.0)
	var far := CelestialSystem.sample(fixture, 0, near.period_seconds * 0.5)
	assert(near.irradiance_w_m2 > far.irradiance_w_m2)
	assert(near.equilibrium_temperature_k > far.equilibrium_temperature_k)
	assert(absf(near.irradiance_w_m2 / far.irradiance_w_m2 - 2.25) < 0.00001)
	assert(absf(near.equilibrium_temperature_k / far.equilibrium_temperature_k - sqrt(1.5)) < 0.00001)
	# Spin changes local daylight without changing the orbit-wide equilibrium model.
	var body: Dictionary = fixture.planets[0]
	body.eccentricity = 0.0
	body.inclination_rad = 0.0
	body.ascending_node_rad = 0.0
	body.periapsis_rad = 0.0
	body.axial_tilt_rad = 0.0
	body.spin_phase_at_epoch = 0.0
	body.rotation_seconds = 86400.0
	var site := Vector3(float(body.radius_m), 0.0, 0.0)
	var night := CelestialSystem.surface_sample(fixture, 0, site, 0.0)
	var noon := CelestialSystem.surface_sample(fixture, 0, site, 43200.0)
	assert(not night.sun_above_horizon and night.direct_irradiance_w_m2 == 0.0)
	assert(noon.sun_above_horizon and noon.direct_irradiance_w_m2 > 0.0)
	assert(CelestialSystem.surface_sample(fixture, 0, Vector3.ZERO, 0.0).is_empty())
	# Existing v1 physical catalogs retain their unrotated XZ orbit interpretation.
	var old := fixture.duplicate(true)
	for key in ["inclination_rad", "ascending_node_rad", "periapsis_rad", "axial_tilt_rad", "spin_phase_at_epoch"]:
		old.planets[0].erase(key)
	var old_sample := CelestialSystem.sample(old, 0, 1234.0)
	assert(old_sample.position_m == [old_sample.x_m, 0.0, old_sample.y_m])
	assert(not CelestialSystem.surface_sample(old, 0, site, 1234.0).is_empty())
	var state := GameState.new()
	state.advance_time(1234.0)
	var seconds := (state.day + state.day_progress / GameState.DAY_SECONDS) * 86400.0
	var expected := CelestialSystem.sample(fixture, 0, seconds)
	var site_before := CelestialSystem.surface_sample(fixture, 0, site, seconds - 0.1)
	var site_now := CelestialSystem.surface_sample(fixture, 0, site, seconds)
	var site_after := CelestialSystem.surface_sample(fixture, 0, site, seconds + 0.1)
	for component in 3:
		var derivative: float = (site_after.position_m[component] - site_before.position_m[component]) / 0.2
		assert(absf(derivative - site_now.velocity_mps[component]) < 0.1, "surface motion combines orbit and spin velocity")
	var path := "user://celestial-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty())
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty())
	var restored_seconds := (restored.day + restored.day_progress / GameState.DAY_SECONDS) * 86400.0
	assert(expected == CelestialSystem.sample(fixture, 0, restored_seconds), "saved calendar restores the same orbital and thermal state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("CELESTIAL_SYSTEM_OK: generation stability, physical profiles, orbit-radiation-temperature coupling, saved epoch")
	quit()
