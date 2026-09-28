class_name FlightDynamics
extends RefCounted

# Standard gravity is a unit reference, not the local gravitational field.
# https://physics.nist.gov/cgi-bin/cuu/Value?gn
const STANDARD_GRAVITY := 9.80665
const CRUISE_G := 3.0
const BOOST_G := 6.0

static func command_velocity(current: Vector3, desired: Vector3, delta: float, boost: bool = false, acceleration: float = STANDARD_GRAVITY * CRUISE_G, boost_acceleration: float = -1.0) -> Vector3:
	if not current.is_finite(): return Vector3.ZERO
	if not desired.is_finite() or not is_finite(delta) or delta <= 0.0 or delta > 1.0: return current
	return current.move_toward(desired, command_acceleration(acceleration, boost, boost_acceleration) * delta)

static func command_acceleration(acceleration: float, boost: bool = false, boost_acceleration: float = -1.0) -> float:
	var limit := usable_acceleration(acceleration)
	if boost:
		limit = limit * 2.0 if boost_acceleration == -1.0 else (clampf(boost_acceleration, 0.0, STANDARD_GRAVITY * BOOST_G) if is_finite(boost_acceleration) else 0.0)
	return limit

static func approach_speed(distance: float, maximum: float, acceleration: float = STANDARD_GRAVITY * CRUISE_G) -> float:
	if not is_finite(distance) or not is_finite(maximum): return 0.0
	return minf(maxf(maximum, 0.0), sqrt(2.0 * usable_acceleration(acceleration) * maxf(distance - 1.0, 0.0)))

# World-space change from applied forces, excluding teleport and collision impulses.
static func acceleration_vector(before: Vector3, after: Vector3, delta: float) -> Vector3:
	if not before.is_finite() or not after.is_finite() or not is_finite(delta) or delta <= 0.0: return Vector3.ZERO
	var acceleration := (after - before) / delta
	return acceleration if acceleration.is_finite() and is_finite(acceleration.length_squared()) else Vector3.ZERO

static func thrust_load(before: Vector3, after: Vector3, delta: float) -> float:
	return acceleration_vector(before, after, delta).length() / STANDARD_GRAVITY

static func braking_distance(speed: float, acceleration: float = STANDARD_GRAVITY * CRUISE_G) -> float:
	if not is_finite(speed): return 0.0
	# A powerless ship cannot stop; keep collision queries finite.
	if usable_acceleration(acceleration) <= 0.0: return 100000.0 if speed > 0.0 else 0.0
	return minf(100000.0, maxf(speed, 0.0) * maxf(speed, 0.0) / (2.0 * usable_acceleration(acceleration)))

static func usable_acceleration(acceleration: float) -> float:
	if not is_finite(acceleration): return 0.0
	return clampf(acceleration, 0.0, STANDARD_GRAVITY * CRUISE_G)
