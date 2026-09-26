extends SceneTree


func _initialize() -> void:
	var first: Dictionary = Universe.system_data(123456)
	var second: Dictionary = Universe.system_data(123456)
	assert(first == second, "system generation must be deterministic")
	assert(first.has_all(["name", "faction", "star_type", "star_color", "planets", "station_seed"]))
	assert(Universe.system_data(0) != Universe.system_data(1), "systems should vary")
	assert(Universe.galaxy_position(42) == Universe.galaxy_position(42), "positions must be deterministic")
	assert(Universe.galaxy_position(42) != Universe.galaxy_position(43), "positions should vary")
	assert(Universe.price(77, "ore") == Universe.price(77, "ore"), "prices must be deterministic")
	assert(Universe.price(77, "alloys") == Universe.price(77, "alloys"), "alloy prices must be deterministic")
	assert(Universe.price(77, "alloys") != Universe.price(77, "ore"), "commodities should have distinct market pricing")
	assert(Universe.system_data(999999999) == Universe.system_data(999999999), "highest supported index must be deterministic")
	var prices: Array[int] = []
	for system_index: int in range(20):
		prices.append(Universe.price(system_index, "ore"))
	assert(prices.max() > prices.min(), "commodity prices should vary by system")
	print("Universe tests passed")
	quit()
