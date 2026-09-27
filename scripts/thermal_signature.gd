class_name ThermalSignature
extends RefCounted

const EMISSIVITY: float = 0.8
const STEFAN_BOLTZMANN: float = 5.670374419e-8
const BASELINE_POWER_W: float = EMISSIVITY * STEFAN_BOLTZMANN * 40.0 * pow(300.0, 4.0)

# Detection tuning: 800 m at the baseline emission, capped at 6000 m. These
# values are gameplay tuning, not specifications for a real sensor.
const BASELINE_RANGE_M: float = 800.0
const MAX_RANGE_M: float = 6000.0


static func emitted_power_w(temperature_k: float, area_m2: float) -> float:
	if not is_finite(temperature_k) or temperature_k < 300.0 or temperature_k > 700.0:
		return 0.0
	if not is_finite(area_m2) or area_m2 < 0.0 or area_m2 > 3040.0:
		return 0.0
	return EMISSIVITY * STEFAN_BOLTZMANN * area_m2 * pow(temperature_k, 4.0)


static func detection_range_m(power_w: float) -> float:
	if not is_finite(power_w) or power_w <= 0.0:
		return 0.0
	return clampf(BASELINE_RANGE_M * sqrt(power_w / BASELINE_POWER_W), 0.0, MAX_RANGE_M)
