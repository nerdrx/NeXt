extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const Surveys = preload("res://scripts/planet_surveys.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var state = GameStateScript.new()
	state.system_index = _system_with_planets()
	state.location = {"system": state.system_index, "surface": -1, "address": SectorPosition.new().to_save(), "rotation": [0, 0, 0], "flying": false}
	var planets: Array = Universe.system_data(state.system_index).planets
	var data: Dictionary = Universe.system_data(state.system_index)
	var expected_value := 250 + (150 if planets[0].atmosphere else 0) + (350 if Universe.planet_has_ocean(data, 0) else 0)
	assert(Surveys.record(state, 0) == "", "record a valid planet")
	assert(state.planet_surveys == {"%d:0" % state.system_index: 1}, "record stored as pending")
	assert(Surveys.validate(state.planet_surveys), "valid survey archive accepted")
	assert(Surveys.pending_value(state) == expected_value, "reward follows atmosphere and ocean traits")
	assert(Surveys.record(state, 0) != "" and state.planet_surveys.size() == 1, "duplicate record rejected")
	assert(Surveys.record(state, -1) != "" and Surveys.record(state, planets.size()) != "", "invalid planet indices rejected")
	var initial_credits: int = state.credits
	assert(Surveys.sell(state) == "" and state.credits == initial_credits + expected_value, "sale pays pending survey once")
	assert(state.planet_surveys["%d:0" % state.system_index] == 2 and Surveys.pending_value(state) == 0, "sale marks survey sold")
	assert(Surveys.sell(state) != "" and state.credits == initial_credits + expected_value, "sold data cannot pay twice")
	assert(not Surveys.validate({"%d:0" % state.system_index: 3}) and not Surveys.validate({"%d:00" % state.system_index: 1}), "invalid status and noncanonical key rejected")

	var path := "user://planet-surveys-%d.json" % OS.get_process_id()
	assert(state.save(path) == "", "save sold survey")
	var loaded = GameStateScript.new()
	assert(loaded.load_save(path) == "" and loaded.planet_surveys == state.planet_surveys, "survey status roundtrips")
	var legacy: Dictionary = state._save_data().duplicate(true)
	legacy.erase("planet_surveys")
	_write_save(path, legacy)
	assert(loaded.load_save(path) == "" and loaded.planet_surveys.is_empty(), "save without optional survey field loads as empty")

	var stable: Dictionary = state._save_data().duplicate(true)
	_write_save(path, stable)
	assert(loaded.load_save(path) == "", "restore survey save before transactional checks")
	var loaded_before: Dictionary = loaded._save_data().duplicate(true)
	for archive: Dictionary in [{"%d:0" % state.system_index: 3}, {"%d:00" % state.system_index: 1}]:
		var malformed: Dictionary = stable.duplicate(true)
		malformed.planet_surveys = archive
		malformed.credits = 1
		_write_save(path, malformed)
		assert(loaded.load_save(path) != "" and loaded._save_data() == loaded_before, "malformed survey save rejected transactionally")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PLANET_SURVEYS_OK: record, sale, persistence and validation")
	quit()

func _system_with_planets() -> int:
	for system: int in range(100):
		if not Universe.system_data(system).planets.is_empty(): return system
	assert(false, "test data must include at least one planet")
	return 0

func _write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
