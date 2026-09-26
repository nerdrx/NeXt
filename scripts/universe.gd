class_name Universe
extends RefCounted

const SYSTEM_LIMIT: int = 1_000_000_000
const FACTIONS: Array[String] = ["Independent", "Solar Union", "Veyran Compact", "Free Worlds", "Asterion Directorate", "Outer Reach"]
const STAR_TYPES: Array[String] = ["Red Dwarf", "Yellow Star", "Blue Giant", "White Dwarf", "Neutron Star", "Black Hole", "Nebula"]
const STAR_COLORS: Array[Color] = [Color("ff704d"), Color("ffe08a"), Color("8ecbff"), Color("e4edff"), Color("9be8ff"), Color("33265c"), Color("d17cff")]
const PLANET_NAMES: Array[String] = ["Aurelia", "Vesper", "Kestrel", "Nadir", "Caldera", "Morrow", "Ilyon", "Thule", "Cinder", "Pelagos"]
const COMMODITIES: Dictionary = {"ore": 35, "alloys": 115, "food": 18, "fuel": 52, "medicine": 95, "electronics": 140, "luxuries": 210}
const GALAXY_RADIUS: float = 1000000.0


static func _seed_for(index: int, salt: int = 0) -> int:
	var value: int = (index & 0x7fffffff) ^ (salt * 0x45d9f3b)
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff
	return value ^ (value >> 16)


static func _rng(index: int, salt: int = 0) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed_for(index, salt)
	return rng


static func system_data(index: int) -> Dictionary:
	var safe_index: int = clampi(index, 0, SYSTEM_LIMIT - 1)
	var rng: RandomNumberGenerator = _rng(safe_index)
	var star_index: int = rng.randi_range(0, STAR_TYPES.size() - 1)
	var planet_count: int = rng.randi_range(0, 8)
	var planets: Array[Dictionary] = []
	for planet_index: int in range(planet_count):
		var planet: Dictionary = {
			"name": "%s %s-%d" % [PLANET_NAMES[rng.randi_range(0, PLANET_NAMES.size() - 1)], _roman(planet_index + 1), safe_index % 997],
			"radius": rng.randf_range(0.25, 6.0),
			"orbit": 40.0 + float(planet_index) * 24.0 + rng.randf_range(-5.0, 5.0),
			"color": Color.from_hsv(rng.randf(), rng.randf_range(0.25, 0.85), rng.randf_range(0.45, 1.0)),
			"atmosphere": rng.randf() < 0.62,
		}
		planets.append(planet)
	return {
		"name": "%s-%04d" % [PLANET_NAMES[rng.randi_range(0, PLANET_NAMES.size() - 1)], safe_index % 10000],
		"faction": FACTIONS[rng.randi_range(0, FACTIONS.size() - 1)],
		"star_type": STAR_TYPES[star_index],
		"star_color": STAR_COLORS[star_index],
		"planets": planets,
		"station_seed": _seed_for(safe_index, 831),
	}


static func price(system_index: int, commodity: String) -> int:
	var base: int = int(COMMODITIES.get(commodity.to_lower(), 50))
	var commodity_salt: int = 0
	for character: int in commodity.to_lower().to_ascii_buffer():
		commodity_salt = (commodity_salt * 31 + character) & 0x7fffffff
	var rng: RandomNumberGenerator = _rng(clampi(system_index, 0, SYSTEM_LIMIT - 1), commodity_salt)
	return maxi(1, roundi(float(base) * rng.randf_range(0.55, 1.65)))


static func galaxy_position(index: int) -> Vector3:
	var safe_index: int = clampi(index, 0, SYSTEM_LIMIT - 1)
	var rng: RandomNumberGenerator = _rng(safe_index, 1701)
	var radius: float = sqrt(rng.randf()) * GALAXY_RADIUS
	var angle: float = float(safe_index) * 2.399963229728653 + rng.randf_range(-0.04, 0.04)
	return Vector3(cos(angle) * radius, rng.randf_range(-18000.0, 18000.0), sin(angle) * radius)


static func _roman(number: int) -> String:
	const NUMERALS: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
	return NUMERALS[clampi(number - 1, 0, NUMERALS.size() - 1)]
