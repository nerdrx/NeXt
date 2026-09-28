extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewAppearanceDomain = preload("res://scripts/crew_appearance.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var path := "user://commander-appearance-%d.json" % OS.get_process_id()
	var state := GameStateScript.new()
	assert(state.commander_appearance == {"suit": 0, "armor": 0})
	assert(state.set_commander_appearance(4, 2).is_empty())
	assert(state.commander_appearance == {"suit": 4, "armor": 2})
	assert(not state.set_commander_appearance(-1, 0).is_empty())
	assert(not state.set_commander_appearance(0, CrewAppearanceDomain.ARMORS.size()).is_empty())
	assert(state.commander_appearance == {"suit": 4, "armor": 2}, "invalid setter calls leave appearance unchanged")
	assert(state.save(path).is_empty())
	var restored := GameStateScript.new()
	assert(restored.load_save(path).is_empty())
	assert(restored.commander_appearance == state.commander_appearance, "appearance palette survives save/load")
	var integral_json_numbers: Dictionary = state._save_data().duplicate(true)
	integral_json_numbers.commander_appearance = {"suit": 4.0, "armor": 2.0}
	_write(path, integral_json_numbers)
	assert(restored.load_save(path).is_empty())
	assert(restored.commander_appearance == {"suit": 4, "armor": 2}, "integral JSON numbers normalize to indices")

	var old_save: Dictionary = state._save_data().duplicate(true)
	old_save.erase("commander_appearance")
	_write(path, old_save)
	var migrated := GameStateScript.new()
	assert(migrated.load_save(path).is_empty())
	assert(migrated.commander_appearance == {"suit": 0, "armor": 0}, "older saves default the new record")
	old_save.version = 2
	for key: String in ["fleet_ships", "crew_orders", "recovery", "ship_layout"]: old_save.erase(key)
	_write(path, old_save)
	var migrated_v2 := GameStateScript.new()
	assert(migrated_v2.load_save(path).is_empty())
	assert(migrated_v2.commander_appearance == {"suit": 0, "armor": 0}, "version 2 saves default the new record")

	var target := GameStateScript.new()
	assert(target.set_commander_appearance(1, 1).is_empty())
	var stable: Dictionary = target._save_data().duplicate(true)
	for invalid: Variant in [
		null,
		[],
		{"suit": "1", "armor": 0},
		{"suit": 1.5, "armor": 0},
		{"suit": 0, "armor": CrewAppearanceDomain.ARMORS.size()},
		{"suit": CrewAppearanceDomain.SUITS.size(), "armor": 0},
		{"suit": 0, "armor": 0, "extra": 1},
	]:
		var malformed: Dictionary = state._save_data().duplicate(true)
		malformed.commander_appearance = invalid
		_write(path, malformed)
		assert(not target.load_save(path).is_empty(), "malformed appearance is rejected")
		assert(target._save_data() == stable, "invalid appearance saves are rejected atomically")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("COMMANDER_APPEARANCE_OK: setter, save/load, legacy defaults, strict validation and atomic rejection")
	quit()

func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
