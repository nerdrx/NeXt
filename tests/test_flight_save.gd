extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	var path: String = "user://flight-save-%d.json" % OS.get_process_id()
	var state = GameStateScript.new()
	state.location = _location([1, -2, 3], true)
	assert(state.save(path) == "", "save flying velocity")
	var loaded = GameStateScript.new()
	assert(loaded.load_save(path) == "" and loaded.location.velocity == [1.0, -2.0, 3.0], "flight velocity roundtrips as floats")

	var legacy: Dictionary = state._save_data().duplicate(true)
	legacy.location.erase("velocity")
	_write_save(path, legacy)
	assert(loaded.load_save(path) == "" and not loaded.location.has("velocity"), "legacy flight location without velocity remains valid")

	var stable: Dictionary = loaded._save_data().duplicate(true)
	for velocity: Variant in ["1,2,3", [], [1, 2], [1, 2, 3, 4], [1, "2", 3], [1, true, 3], [1e999, 2, 3], [100001, 0, 0]]:
		var bad: Dictionary = state._save_data().duplicate(true)
		bad.location.velocity = velocity
		_write_save(path, bad)
		assert(loaded.load_save(path) != "" and loaded._save_data() == stable, "reject malformed flight velocity transactionally: %s" % str(velocity))
	for nonfinite: float in [NAN, INF, -INF]:
		var invalid_location: Dictionary = _location([nonfinite, 0, 0], true)
		assert(not state._valid_location(invalid_location, 0), "reject non-finite flight velocity")
	var walking: Dictionary = state._save_data().duplicate(true)
	walking.location = _location([0, 0, 0], false)
	walking.location.velocity = [0, 0, 0]
	_write_save(path, walking)
	assert(loaded.load_save(path) != "" and loaded._save_data() == stable, "reject flight velocity when not flying transactionally")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("FLIGHT_SAVE_OK: velocity roundtrip, legacy compatibility, validation and transactional rejection")
	quit()

func _location(velocity: Array, flying: bool) -> Dictionary:
	var location: Dictionary = {"system": 0, "surface": -1, "address": SectorPosition.new().to_save(), "rotation": [0, 0, 0], "flying": flying}
	if flying: location.velocity = velocity
	return location

func _write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
