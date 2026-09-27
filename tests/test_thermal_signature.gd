extends SceneTree

const ThermalSignatureScript = preload("res://scripts/thermal_signature.gd")


func _initialize() -> void:
	var baseline: float = ThermalSignatureScript.emitted_power_w(300.0, 40.0)
	var doubled_temperature: float = ThermalSignatureScript.emitted_power_w(600.0, 40.0)
	var double_area: float = ThermalSignatureScript.emitted_power_w(300.0, 80.0)
	assert(is_equal_approx(doubled_temperature / baseline, 16.0), "emission follows the fourth power of temperature")
	assert(is_equal_approx(double_area / baseline, 2.0), "emission scales linearly with area")
	assert(is_equal_approx(ThermalSignatureScript.detection_range_m(baseline * 4.0), 1600.0), "detection range follows inverse-square scaling")
	assert(is_equal_approx(ThermalSignatureScript.detection_range_m(baseline * 100.0), 6000.0), "detection range is capped")
	for temperature: float in [NAN, INF, -INF, 299.0, 701.0]:
		assert(ThermalSignatureScript.emitted_power_w(temperature, 40.0) == 0.0, "invalid temperature returns zero")
	for area: float in [NAN, INF, -INF, -0.01, 3040.01]:
		assert(ThermalSignatureScript.emitted_power_w(300.0, area) == 0.0, "invalid area returns zero")
	for power: float in [NAN, INF, -INF, 0.0, -1.0]:
		assert(ThermalSignatureScript.detection_range_m(power) == 0.0, "invalid or nonpositive power returns zero")
	print("Thermal signature tests passed")
	quit()
