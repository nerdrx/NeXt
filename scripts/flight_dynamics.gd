class_name FlightDynamics
extends RefCounted

# Standard gravity is a unit reference, not the local gravitational field.
# https://physics.nist.gov/cgi-bin/cuu/Value?gn
const STANDARD_GRAVITY := 9.80665
const CRUISE_G := 3.0
const BOOST_G := 6.0

static func command_velocity(current: Vector3, desired: Vector3, delta: float, boost: bool = false) -> Vector3:
	if not current.is_finite(): return Vector3.ZERO
	if not desired.is_finite() or not is_finite(delta) or delta <= 0.0 or delta > 1.0: return current
	return current.move_toward(desired, STANDARD_GRAVITY * (BOOST_G if boost else CRUISE_G) * delta)

static func approach_speed(distance: float, maximum: float) -> float:
	if not is_finite(distance) or not is_finite(maximum): return 0.0
	return minf(maxf(maximum, 0.0), sqrt(2.0 * STANDARD_GRAVITY * CRUISE_G * maxf(distance - 1.0, 0.0)))

static func thrust_load(before: Vector3, after: Vector3, delta: float) -> float:
	if not before.is_finite() or not after.is_finite() or not is_finite(delta) or delta <= 0.0: return 0.0
	return before.distance_to(after) / (delta * STANDARD_GRAVITY)
