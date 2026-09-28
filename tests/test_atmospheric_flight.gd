extends SceneTree

const Flight = preload("res://scripts/atmospheric_flight.gd")

func _initialize() -> void:
	assert(is_equal_approx(Flight.density(0.0), 1.225))
	assert(is_equal_approx(Flight.density(-100.0), 1.225))
	assert(Flight.density(220.0) == 0.0 and Flight.density(INF) == 0.0)
	var previous := Flight.density(0.0)
	for height in range(1, 220):
		var current := Flight.density(float(height))
		assert(current <= previous and current >= 0.0, "density tapers monotonically")
		previous = current
	assert(Flight.density(NAN) == 0.0)

	var velocity := Vector3(100.0, 0.0, 0.0)
	var box := Vector3(2.0, 4.0, 6.0)
	var expected := velocity / (1.0 + 0.5 * 1.0 * 24.0 * 100.0 * 0.1 / 1000.0)
	var slowed := Flight.drag_velocity(velocity, 1.0, box, Basis.IDENTITY, 1000.0, 0.1)
	assert(slowed.is_equal_approx(expected), "matches analytic quadratic drag reference")
	assert(slowed.x > 0.0 and slowed.y == 0.0 and slowed.z == 0.0, "drag never reverses or changes direction")
	assert(Flight.drag_velocity(velocity, 0.0, box, Basis.IDENTITY, 1000.0, 0.1) == velocity)
	assert(Flight.drag_velocity(velocity, 1.0, Vector3.ZERO, Basis.IDENTITY, 1000.0, 0.1) == velocity)
	assert(Flight.drag_velocity(velocity, 1.0, box, Basis.IDENTITY, 2000.0, 0.1).x > slowed.x, "greater mass slows less")
	assert(Flight.drag_velocity(velocity, 1.0, box * 2.0, Basis.IDENTITY, 1000.0, 0.1).x < slowed.x, "larger area slows more")
	var quarter_turn := Basis(Vector3.BACK, PI / 2.0)
	var rotated := Flight.drag_velocity(velocity, 1.0, box, quarter_turn, 1000.0, 0.1)
	assert(rotated.x > slowed.x, "orientation changes projected area")
	var first_half := Flight.drag_velocity(velocity, 1.0, box, Basis.IDENTITY, 1000.0, 0.05)
	var split := Flight.drag_velocity(first_half, 1.0, box, Basis.IDENTITY, 1000.0, 0.05)
	assert(is_equal_approx(split.x, slowed.x), "constant-condition drag is timestep-splitting invariant")

	assert(Flight.drag_velocity(Vector3(NAN, 0, 0), 1.0, box, Basis.IDENTITY, 1000.0, 0.1) == Vector3.ZERO)
	assert(Flight.drag_velocity(velocity, -1.0, box, Basis.IDENTITY, 1000.0, 0.1) == velocity)
	assert(Flight.drag_velocity(velocity, 1.0, box, Basis.IDENTITY, 0.0, 0.1) == velocity)
	assert(Flight.drag_velocity(velocity, 1.0, box, Basis.IDENTITY, 1000.0, 0.0) == velocity)
	assert(Flight.drag_velocity(velocity, 1.0, box, Basis.IDENTITY, 1000.0, 1.1) == velocity)
	assert(Flight.drag_velocity(velocity, 1.0, box, Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), 1000.0, 0.1) == velocity)
	assert(Flight.drag_velocity(velocity, INF, box, Basis.IDENTITY, 1000.0, 0.1) == velocity)
	assert(Flight.drag_velocity(velocity, 1.0, Vector3(INF, 1, 1), Basis.IDENTITY, 1000.0, 0.1) == velocity)
	assert(Flight.drag_velocity(Vector3(1e20, 0, 0), 1e308, box, Basis.IDENTITY, 1000.0, 0.1) == Vector3(1e20, 0, 0), "finite inputs with overflowing intermediates preserve velocity")
	assert(Flight.drag_velocity(Vector3(1e308, 1e308, 0), 1.0, box, Basis.IDENTITY, 1000.0, 0.1).is_finite())

	print("ATMOSPHERIC_FLIGHT_OK: density taper, projected drag, safeguards")
	quit()
