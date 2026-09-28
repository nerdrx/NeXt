class_name StellarExposure
extends RefCounted

const LOCAL_METRES_PER_REFERENCE := 4500.0
const MIN_LOCAL_DISTANCE := 250.0
const REFERENCE_RADIUS_FLOOR := 8.0
const ABSORPTIVITY := 0.35


static func irradiance(star: Dictionary, point: Vector3, star_position: Vector3, planets: Array) -> float:
	if not point.is_finite() or not star_position.is_finite(): return 0.0
	var luminosity: Variant = star.get("luminosity_w", 0.0)
	var radius: Variant = star.get("radius_m", 0.0)
	if not _positive_finite(luminosity) or not _positive_finite(radius): return 0.0
	var distance := physical_distance(star, point.distance_to(star_position))
	if distance <= 0.0 or _shadowed(point, star_position, planets): return 0.0
	return CelestialPhysics.irradiance(float(luminosity), distance)


# One mapping for radiation and gravity. Dim compact primaries must not shrink
# the whole scene to stellar-surface distances. Geometry remains compressed.
static func physical_distance(star: Dictionary, local_distance: float) -> float:
	var luminosity: Variant = star.get("luminosity_w", 0.0)
	var radius: Variant = star.get("radius_m", 0.0)
	if not (luminosity is int or luminosity is float) or not is_finite(float(luminosity)) or float(luminosity) < 0.0 or not _positive_finite(radius) or not is_finite(local_distance) or local_distance < 0.0: return 0.0
	var reference_m := maxf(1.0, sqrt(float(luminosity) / CelestialPhysics.SOLAR_LUMINOSITY_W)) * CelestialPhysics.AU_M
	reference_m = maxf(reference_m, REFERENCE_RADIUS_FLOOR * float(radius))
	var distance := maxf(float(radius), maxf(local_distance, MIN_LOCAL_DISTANCE) / LOCAL_METRES_PER_REFERENCE * reference_m)
	return distance if is_finite(distance) else 0.0


static func absorbed_power(flux: float, dimensions: Vector3, local_direction: Vector3) -> float:
	if not is_finite(flux) or flux < 0.0 or not dimensions.is_finite() or dimensions.x < 0.0 or dimensions.y < 0.0 or dimensions.z < 0.0 or not local_direction.is_finite() or local_direction.length_squared() <= 0.0:
		return 0.0
	if not is_finite(local_direction.length_squared()): return 0.0
	var direction := local_direction.normalized()
	var projected_area := absf(direction.x) * dimensions.y * dimensions.z
	projected_area += absf(direction.y) * dimensions.x * dimensions.z
	projected_area += absf(direction.z) * dimensions.x * dimensions.y
	var result := flux * projected_area * ABSORPTIVITY
	return result if is_finite(result) else 0.0


static func _shadowed(point: Vector3, star_position: Vector3, planets: Array) -> bool:
	var segment := star_position - point
	var segment_length := segment.length()
	if not is_finite(segment_length) or segment_length <= 0.0: return false
	var direction := segment / segment_length
	for body: Variant in planets:
		if not body is Dictionary: continue
		var center: Variant = body.get("position")
		var radius: Variant = body.get("visual_radius", 0.0)
		if not center is Vector3 or not center.is_finite() or not _positive_finite(radius): continue
		var to_center: Vector3 = center - point
		if to_center.length_squared() <= float(radius) * float(radius): return true
		var along := clampf(to_center.dot(direction), 0.0, segment_length)
		var closest := point + direction * along
		if closest.distance_squared_to(center) <= float(radius) * float(radius): return true
	return false


static func _positive_finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0
