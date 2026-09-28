extends SceneTree

func _initialize() -> void: _run()

func _run() -> void:
	var state := GameState.new()
	state.system_index = 0
	var data := Universe.system_data(0)
	var count: int = data.planets.size()
	assert(count > 1)
	assert(PlanetSurveys.system_progress(state, 0).recorded == 0)
	assert(PlanetSurveys.record(state, 0) == "")
	var partial := PlanetSurveys.pending_value(state)
	assert(PlanetSurveys.system_progress(state, 0).pending_bonus == 0)
	assert(PlanetSurveys.sell(state) == "")
	var baseline := state.credits
	var remaining_value := 0
	for planet in range(1, count):
		assert(PlanetSurveys.record(state, planet) == "")
		remaining_value += 250 + (150 if data.planets[planet].atmosphere else 0) + (350 if Universe.planet_has_ocean(data, planet) else 0)
	var bonus := 500 + 100 * count
	var progress := PlanetSurveys.system_progress(state, 0)
	assert(progress.recorded == count and progress.total == count and progress.pending_bonus == bonus)
	assert(PlanetSurveys.pending_value(state) == remaining_value + bonus, "completion after an earlier sale includes exactly one bonus")
	var path := "user://survey-completion-%d.json" % OS.get_process_id()
	assert(state.save(path) == "")
	var loaded := GameState.new()
	assert(loaded.load_save(path) == "")
	assert(PlanetSurveys.pending_value(loaded) == remaining_value + bonus, "pending completion survives reload")
	assert(PlanetSurveys.sell(loaded) == "" and loaded.credits == baseline + remaining_value + bonus)
	assert(PlanetSurveys.pending_value(loaded) == 0 and PlanetSurveys.system_progress(loaded, 0).pending_bonus == 0)
	assert(PlanetSurveys.sell(loaded) != "", "repeated sale never repeats bonus")
	assert(loaded.save(path) == "")
	assert(state.load_save(path) == "" and PlanetSurveys.pending_value(state) == 0, "sold completion stays sold after reload")
	var other := GameState.new()
	assert(PlanetSurveys.pending_value(other) == 0, "world survey archives remain independent")
	assert(PlanetSurveys.system_progress(other, -1).pending_bonus == 0)
	assert(PlanetSurveys.system_progress(other, GameState.SYSTEM_LIMIT).total == 0)
	var empty_found := false
	var second_found := false
	for system in range(1, 100):
		var body_count: int = Universe.system_data(system).planets.size()
		if body_count == 0:
			empty_found = true
			var empty := PlanetSurveys.system_progress(state, system)
			assert(empty.total == 0 and empty.bonus == 0 and empty.pending_bonus == 0, "empty system has no completion reward")
		elif not second_found:
			second_found = true
			for planet in range(body_count): state.planet_surveys["%d:%d" % [system, planet]] = 1
			assert(PlanetSurveys.system_progress(state, system).pending_bonus == 500 + 100 * body_count)
			assert(PlanetSurveys.system_progress(state, 0).pending_bonus == 0, "pending data in another system cannot reactivate a sold system bonus")
	assert(empty_found and second_found)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert(partial > 0)
	print("SURVEY_COMPLETION_OK: progress, partial sales, one-time payout, pending/sold reload and world isolation")
	quit()
