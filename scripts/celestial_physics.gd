class_name CelestialPhysics
extends RefCounted

const SOLAR_RADIUS_M: float = 6.957e8
const SOLAR_MU: float = 1.3271244e20
const SOLAR_LUMINOSITY_W: float = 3.828e26
const EARTH_RADIUS_M: float = 6.3781e6
const EARTH_MU: float = 3.986004e14
const AU_M: float = 149597870700.0
const STEFAN_BOLTZMANN: float = 5.670374419e-8
const LIGHT_SPEED_MPS: float = 299792458.0

# Nominal solar and terrestrial constants follow IAU 2015 B3; thermal approximation follows NASA.
# https://iauarchive.eso.org/static/resolutions/IAU2015_English.pdf
# https://science.nasa.gov/wp-content/uploads/2023/09/Habitable_Zone.pdf
# Orbital inputs are bounded to mu <= 1e40 m^3/s^2 and 1e-50 <= a <= 1e30 m.
const MAX_ORBITAL_MU: float = 1.0e40
const MIN_ORBITAL_AXIS_M: float = 1.0e-50
const MAX_ORBITAL_AXIS_M: float = 1.0e30


# Log-space scalar formulas avoid intermediate overflow for representable results.
static func luminosity(radius_m: float, temp_k: float) -> float:
	if not _positive_finite(radius_m) or not _positive_finite(temp_k): return 0.0
	var result: float = exp(log(4.0 * PI * STEFAN_BOLTZMANN) + 2.0 * log(radius_m) + 4.0 * log(temp_k))
	return result if is_finite(result) else 0.0


static func irradiance(luminosity_w: float, distance_m: float) -> float:
	if not _positive_finite(luminosity_w) or not _positive_finite(distance_m): return 0.0
	var result: float = exp(log(luminosity_w) - log(4.0 * PI) - 2.0 * log(distance_m))
	return result if is_finite(result) else 0.0


static func equilibrium_temperature(flux_w_m2: float, bond_albedo: float) -> float:
	if not _positive_finite(flux_w_m2) or not is_finite(bond_albedo) or bond_albedo < 0.0 or bond_albedo > 1.0: return 0.0
	if bond_albedo == 1.0: return 0.0
	var result: float = exp(0.25 * (log(flux_w_m2) + log(1.0 - bond_albedo) - log(4.0 * STEFAN_BOLTZMANN)))
	return result if is_finite(result) else 0.0


static func surface_gravity(mu_m3_s2: float, radius_m: float) -> float:
	if not _positive_finite(mu_m3_s2) or not _positive_finite(radius_m): return 0.0
	var result: float = exp(log(mu_m3_s2) - 2.0 * log(radius_m))
	return result if is_finite(result) else 0.0


static func orbital_period(mu_m3_s2: float, semi_major_m: float) -> float:
	if not _valid_orbit_scale(mu_m3_s2, semi_major_m): return 0.0
	var result: float = TAU * exp(1.5 * log(semi_major_m) - 0.5 * log(mu_m3_s2))
	return result if is_finite(result) else 0.0


static func schwarzschild_radius(mu_m3_s2: float) -> float:
	if not _positive_finite(mu_m3_s2): return 0.0
	var result: float = mu_m3_s2 / (LIGHT_SPEED_MPS * LIGHT_SPEED_MPS) * 2.0
	return result if is_finite(result) else 0.0


static func orbital_state(mu_m3_s2: float, semi_major_m: float, eccentricity: float, mean_anomaly_at_epoch: float, elapsed_seconds: float) -> Dictionary:
	if not _valid_orbit_scale(mu_m3_s2, semi_major_m) or not is_finite(eccentricity) or eccentricity < 0.0 or eccentricity > 0.8 or not is_finite(mean_anomaly_at_epoch) or not is_finite(elapsed_seconds):
		return {}
	var period: float = orbital_period(mu_m3_s2, semi_major_m)
	if period <= 0.0: return {}
	var elapsed_mod: float = fposmod(elapsed_seconds, period)
	var mean_anomaly: float = fposmod(mean_anomaly_at_epoch + TAU * (elapsed_mod / period), TAU)
	var eccentric_anomaly: float = mean_anomaly
	for _iteration: int in 16:
		var correction: float = (eccentric_anomaly - eccentricity * sin(eccentric_anomaly) - mean_anomaly) / (1.0 - eccentricity * cos(eccentric_anomaly))
		eccentric_anomaly -= correction
		if absf(correction) <= 1.0e-12: break
	var cos_e: float = cos(eccentric_anomaly)
	var sin_e: float = sin(eccentric_anomaly)
	var radius: float = semi_major_m * (1.0 - eccentricity * cos_e)
	var x: float = semi_major_m * (cos_e - eccentricity)
	var y: float = semi_major_m * sqrt(1.0 - eccentricity * eccentricity) * sin_e
	var speed_squared: float = mu_m3_s2 * (2.0 / radius - 1.0 / semi_major_m)
	var speed: float = sqrt(speed_squared) if speed_squared >= 0.0 else NAN
	if not is_finite(radius) or not is_finite(x) or not is_finite(y) or not is_finite(speed) or not is_finite(period): return {}
	return {"distance_m": radius, "x_m": x, "y_m": y, "speed_mps": speed, "period_seconds": period}


static func _valid_orbit_scale(mu_m3_s2: float, semi_major_m: float) -> bool:
	return _positive_finite(mu_m3_s2) and mu_m3_s2 <= MAX_ORBITAL_MU and _positive_finite(semi_major_m) and semi_major_m >= MIN_ORBITAL_AXIS_M and semi_major_m <= MAX_ORBITAL_AXIS_M


static func _positive_finite(value: float) -> bool:
	return is_finite(value) and value > 0.0
