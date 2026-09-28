class_name AtmosphericFlight
extends RefCounted

const SEA_LEVEL_DENSITY := 1.225
const SCALE_HEIGHT_LOCAL_M := 40.0
const TAPER_START_LOCAL_M := 180.0
const VACUUM_LOCAL_M := 220.0

# Cd = 1 is a tuning value; drag follows the standard equation form.
# https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/drag-equation/
# Model uses compressed-scale local metres, still air, and no lift, heating, or real atmospheric composition.
static func density(altitude: float) -> float:
	if not is_finite(altitude) or altitude >= VACUUM_LOCAL_M:
		return 0.0
	var height := maxf(altitude, 0.0)
	var result := SEA_LEVEL_DENSITY * exp(-height / SCALE_HEIGHT_LOCAL_M)
	if height > TAPER_START_LOCAL_M:
		var t := (height - TAPER_START_LOCAL_M) / (VACUUM_LOCAL_M - TAPER_START_LOCAL_M)
		var smooth := t * t * (3.0 - 2.0 * t)
		result *= 1.0 - smooth
	return result

static func drag_velocity(velocity: Vector3, density_kg_m3: float, dimensions: Vector3, orientation: Basis, mass_kg: float, delta: float) -> Vector3:
	if not velocity.is_finite():
		return Vector3.ZERO
	if not is_finite(density_kg_m3) or density_kg_m3 < 0.0 or not dimensions.is_finite() or dimensions.x < 0.0 or dimensions.y < 0.0 or dimensions.z < 0.0 or not is_finite(mass_kg) or mass_kg <= 0.0 or not is_finite(delta) or delta <= 0.0 or delta > 1.0:
		return velocity
	if not orientation.is_finite():
		return velocity
	var determinant := orientation.determinant()
	if not is_finite(determinant) or absf(determinant) <= 0.0000001:
		return velocity
	if density_kg_m3 == 0.0 or velocity == Vector3.ZERO or dimensions == Vector3.ZERO:
		return velocity

	var speed := velocity.length()
	if not is_finite(speed):
		return velocity
	var local_direction := orientation.inverse() * (velocity / speed)
	if not local_direction.is_finite():
		return velocity
	var local_length := local_direction.length()
	if not is_finite(local_length) or local_length <= 0.0:
		return velocity
	local_direction /= local_length
	var area := absf(local_direction.x) * dimensions.y * dimensions.z + absf(local_direction.y) * dimensions.x * dimensions.z + absf(local_direction.z) * dimensions.x * dimensions.y
	if not is_finite(area) or area <= 0.0:
		return velocity
	var drag_factor := 0.5 * density_kg_m3
	drag_factor *= area
	drag_factor *= speed
	drag_factor *= delta
	drag_factor /= mass_kg
	if not is_finite(drag_factor) or drag_factor < 0.0:
		return velocity
	var divisor := 1.0 + drag_factor
	if not is_finite(divisor) or divisor <= 0.0:
		return velocity
	var result := velocity / divisor
	return result if result.is_finite() else velocity
