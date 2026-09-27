extends SceneTree

const Physics = preload("res://scripts/celestial_physics.gd")
const Frame = preload("res://scripts/celestial_frame.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var axis := 1.0e7
	var mu := 3.986004e14
	var period := Physics.orbital_period(mu, axis)
	var quarter: Dictionary = Physics.orbital_state(mu, axis, 0.0, 0.0, period * 0.25)
	var circular: Dictionary = Frame.oriented_orbit(quarter, 0.0, 0.0, 0.0)
	assert(circular.size() == 2)
	assert(absf(circular.position_m[0]) < 0.01)
	assert(absf(circular.position_m[1]) < 0.01)
	assert(absf(circular.position_m[2] - axis) < 0.01)
	assert(absf(circular.velocity_mps[0] + sqrt(mu / axis)) < 1.0e-6)
	assert(absf(circular.velocity_mps[2]) < 1.0e-6)

	var eccentricity := 0.37
	var elapsed := period * 0.173
	var dt := 0.1
	var angles := Vector3(0.41, 1.12, 0.73)
	var before: Dictionary = Frame.oriented_orbit(Physics.orbital_state(mu, axis, eccentricity, 0.6, elapsed - dt), angles.x, angles.y, angles.z)
	var now: Dictionary = Frame.oriented_orbit(Physics.orbital_state(mu, axis, eccentricity, 0.6, elapsed), angles.x, angles.y, angles.z)
	var after: Dictionary = Frame.oriented_orbit(Physics.orbital_state(mu, axis, eccentricity, 0.6, elapsed + dt), angles.x, angles.y, angles.z)
	for i in 3:
		var measured: float = (after.position_m[i] - before.position_m[i]) / (2.0 * dt)
		assert(absf(measured - now.velocity_mps[i]) < 0.02)

	var base_position := [Physics.AU_M, 0.0, 0.0]
	var base_velocity := [0.0, 0.0, 0.0]
	var body := {"rotation_seconds": 86400.0, "spin_phase_at_epoch": 0.0, "axial_tilt_rad": 0.0, "inclination_rad": 0.0, "ascending_node_rad": 0.0}
	var sample := {"position_m": base_position, "velocity_mps": base_velocity}
	var equator: Dictionary = Frame.surface_state(sample, body, Vector3(10.0, 0.0, 0.0), 0.0)
	assert(not equator.is_empty())
	assert(absf(equator.velocity_mps[0]) < 1.0e-10)
	assert(absf(equator.velocity_mps[1]) < 1.0e-10)
	assert(absf(equator.velocity_mps[2] - TAU * 10.0 / 86400.0) < 1.0e-10)
	var tilted_body := {"rotation_seconds": 43200.0, "spin_phase_at_epoch": 0.3, "axial_tilt_rad": 0.4, "inclination_rad": -0.2, "ascending_node_rad": 1.1}
	var surface_point := Vector3(Physics.EARTH_RADIUS_M, 0.0, 0.0)
	var surface_before: Dictionary = Frame.surface_state(sample, tilted_body, surface_point, 5000.0 - 0.1)
	var surface_middle: Dictionary = Frame.surface_state(sample, tilted_body, surface_point, 5000.0)
	var surface_after: Dictionary = Frame.surface_state(sample, tilted_body, surface_point, 5000.0 + 0.1)
	for i in 3:
		var measured: float = (surface_after.position_m[i] - surface_before.position_m[i]) / 0.2
		assert(absf(measured - surface_middle.velocity_mps[i]) < 0.1)
	var pole_now: Dictionary = Frame.surface_state(sample, body, Vector3(0.0, 10.0, 0.0), 0.0)
	var pole_later: Dictionary = Frame.surface_state(sample, body, Vector3(0.0, 10.0, 0.0), 12345.0)
	assert(Vector3(pole_now.position_m[0], pole_now.position_m[1], pole_now.position_m[2]).distance_to(Vector3(pole_later.position_m[0], pole_later.position_m[1], pole_later.position_m[2])) < 1.0e-5)
	var spun_once: Dictionary = Frame.surface_state(sample, body, Vector3(10.0, 0.0, 0.0), 86400.0)
	assert(Basis(spun_once.orientation).is_equal_approx(Basis(equator.orientation)))

	var offset_sample := {"position_m": [Physics.AU_M, 0.0, 0.0], "velocity_mps": [0.0, 0.0, 0.0]}
	var offset_body := body.duplicate()
	offset_body.rotation_seconds = 1.0e100
	var offset: Dictionary = Frame.surface_state(offset_sample, offset_body, Vector3(0.25, 0.0, 0.0), 0.0)
	var origin: SectorPosition = SectorPosition.from_meters(Physics.AU_M, 0.0, 0.0)
	var saved_position: SectorPosition = SectorPosition.from_save(offset.address)
	assert(saved_position != null)
	var recovered: Variant = saved_position.relative_to(origin, 1.0)
	assert(recovered != null and absf(Vector3(recovered).x - 0.25) < 0.001)

	assert(Frame.oriented_orbit({"x_m": 1.0, "y_m": 0.0, "vx_mps": 0.0, "vy_mps": 1.0}, NAN, 0.0, 0.0).is_empty())
	assert(Frame.oriented_orbit({"x_m": 1.0, "y_m": 0.0, "vx_mps": 0.0, "vy_mps": 1.0}, 0.0, INF, 0.0).is_empty())
	assert(Frame.surface_state(sample, body, Vector3.ZERO, NAN).is_empty())
	assert(Frame.surface_state(sample, body, Vector3(NAN, 0.0, 0.0), 0.0).is_empty())
	var invalid_period := body.duplicate()
	invalid_period.rotation_seconds = 0.0
	assert(Frame.surface_state(sample, invalid_period, Vector3.RIGHT, 0.0).is_empty())
	var legacy_body := {"rotation_seconds": 86400.0}
	assert(not Frame.surface_state(sample, legacy_body, Vector3.RIGHT, 0.0).is_empty(), "legacy bodies default missing orientation angles")
	print("CELESTIAL_FRAME_OK: orbit basis and velocity, spinning surfaces, address precision and invalid inputs")
	quit()
