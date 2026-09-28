class_name StellarGravity
extends RefCounted

# Newtonian far field; not relativistic gravity or an event-horizon model.
# https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/weight-equation-2/
static func acceleration(star: Dictionary, point: Vector3, center: Vector3) -> Vector3:
	if not point.is_finite() or not center.is_finite(): return Vector3.ZERO
	var mu: Variant = star.get("mu_m3_s2", 0.0)
	if not (mu is int or mu is float) or not is_finite(float(mu)) or float(mu) <= 0.0: return Vector3.ZERO
	var offset := center - point
	var local_distance := offset.length()
	if not is_finite(local_distance) or local_distance <= 0.00001: return Vector3.ZERO
	var distance := StellarExposure.physical_distance(star, local_distance)
	if distance <= 0.0: return Vector3.ZERO
	var strength := CelestialPhysics.surface_gravity(float(mu), distance)
	# Bounded linear core avoids a direction discontinuity and singular impulse.
	strength *= minf(1.0, local_distance / StellarExposure.MIN_LOCAL_DISTANCE)
	var result := offset / local_distance * strength
	return result if result.is_finite() else Vector3.ZERO
