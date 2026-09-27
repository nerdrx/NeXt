extends SceneTree

func _initialize() -> void:
	var one_second := Vector3.ZERO
	for i in 60: one_second = FlightDynamics.command_velocity(one_second, Vector3(1000, 0, 0), 1.0 / 60.0)
	var coarse := FlightDynamics.command_velocity(Vector3.ZERO, Vector3(1000, 0, 0), 1.0)
	assert(one_second.distance_to(coarse) < 0.0001, "acceleration is independent of physics step")
	assert(absf(one_second.x - 3.0 * 9.80665) < 0.0001)
	var boosted := FlightDynamics.command_velocity(Vector3.ZERO, Vector3(1000, 0, 0), 1.0, true)
	assert(absf(boosted.x - 6.0 * 9.80665) < 0.0001)
	var braking := FlightDynamics.command_velocity(Vector3(100, 0, 0), Vector3.ZERO, 1.0)
	assert(is_equal_approx(FlightDynamics.thrust_load(Vector3(100, 0, 0), braking, 1.0), 3.0))
	assert(FlightDynamics.command_velocity(Vector3.ONE, Vector3.INF, 0.1) == Vector3.ONE)
	assert(FlightDynamics.thrust_load(Vector3.ZERO, Vector3.ONE, 0) == 0.0)
	var approach := FlightDynamics.approach_speed(101.0, 1000.0)
	assert(absf(approach * approach / (2.0 * 3.0 * 9.80665) - 100.0) < 0.001, "approach speed respects stopping distance")
	print("FLIGHT_DYNAMICS_OK: step independence, cruise and boost limits, braking, invalid input and stopping distance")
	quit()
