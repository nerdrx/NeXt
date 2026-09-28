class_name PlanetSurveys
extends RefCounted

const LIMIT := 10000

static func record(state: GameState, planet_index: int) -> String:
	var planets: Array = Universe.system_data(state.system_index).planets
	if planet_index < 0 or planet_index >= planets.size(): return "Planet is unavailable."
	var key := "%d:%d" % [state.system_index, planet_index]
	if state.planet_surveys.has(key): return "This planet is already surveyed."
	if state.planet_surveys.size() >= LIMIT: return "Survey archive is full."
	state.planet_surveys[key] = 1
	return ""

static func pending_value(state: GameState) -> int:
	var total := 0
	for key: String in state.planet_surveys:
		if int(state.planet_surveys[key]) != 1: continue
		var parts := key.split(":")
		var data := Universe.system_data(int(parts[0]))
		var planet: Dictionary = data.planets[int(parts[1])]
		total += 250 + (150 if planet.atmosphere else 0) + (350 if Universe.planet_has_ocean(data, int(parts[1])) else 0)
	return total

static func sell(state: GameState) -> String:
	var value := pending_value(state)
	if value <= 0: return "No unsold survey data."
	state.credits += value
	for key: String in state.planet_surveys:
		if int(state.planet_surveys[key]) == 1: state.planet_surveys[key] = 2
	return ""

static func validate(data: Variant) -> bool:
	if not data is Dictionary or data.size() > LIMIT: return false
	for key: Variant in data:
		if not key is String: return false
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
		var system := int(parts[0])
		var planet := int(parts[1])
		if system < 0 or system >= GameState.SYSTEM_LIMIT or planet < 0 or planet >= 8: return false
		if key != "%d:%d" % [system, planet]: return false
		if planet >= Universe.system_data(system).planets.size(): return false
		if typeof(data[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[key])) or float(data[key]) not in [1.0, 2.0]: return false
	return true
