class_name VisitSave
extends RefCounted

static func commit(home: GameState, home_path: String, visitor: GameState, visitor_path: String) -> String:
	var recovery_error: String = recover(home_path)
	if not recovery_error.is_empty(): return recovery_error
	if home == null or visitor == null: return "Visit save state is missing."
	var home_data: Dictionary = home._save_data()
	var visitor_data: Dictionary = visitor._save_data()
	var error: String = _validate_data(home_data)
	if not error.is_empty(): return "Invalid home snapshot: " + error
	error = _validate_data(visitor_data)
	if not error.is_empty(): return "Invalid visitor snapshot: " + error
	if not _valid_world_id(visitor_data.get("world_id")): return "Invalid visitor world identity."
	if visitor_path != "user://visits/" + str(visitor_data.world_id) + ".json": return "Visitor save path is not canonical."
	var journal_path: String = home_path + ".visit-journal.json"
	var temp_path: String = journal_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null: return "Could not open visit journal temporary file."
	file.store_string(JSON.stringify({"version": 1, "home_data": home_data, "visitor_data": visitor_data}))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return "Could not write visit journal."
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(journal_path)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return "Could not replace visit journal."
	return _apply(home_path, visitor_data.world_id, home_data, visitor_data, journal_path)

static func recover(home_path: String) -> String:
	if home_path.strip_edges().is_empty(): return "Home save path is empty."
	var journal_path: String = home_path + ".visit-journal.json"
	if not FileAccess.file_exists(journal_path): return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(journal_path))
	if not parsed is Dictionary: return "Visit journal is malformed."
	var journal: Dictionary = parsed
	if journal.size() != 3 or journal.get("version") != 1 or not journal.get("home_data") is Dictionary or not journal.get("visitor_data") is Dictionary:
		return "Visit journal has invalid fields."
	var home_data: Dictionary = journal.home_data
	var visitor_data: Dictionary = journal.visitor_data
	var error: String = _validate_data(home_data)
	if not error.is_empty(): return "Invalid home snapshot in visit journal: " + error
	error = _validate_data(visitor_data)
	if not error.is_empty(): return "Invalid visitor snapshot in visit journal: " + error
	var visitor_id: Variant = visitor_data.get("world_id")
	if not _valid_world_id(visitor_id): return "Invalid visitor world identity in visit journal."
	return _apply(home_path, visitor_id, home_data, visitor_data, journal_path)

static func _apply(home_path: String, visitor_id: String, home_data: Dictionary, visitor_data: Dictionary, journal_path: String) -> String:
	var visit_dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://visits"))
	if visit_dir_error != OK and visit_dir_error != ERR_ALREADY_EXISTS: return "Could not create visitor save directory."
	var visitor: GameState = GameState.new()
	var error: String = visitor.load_data(visitor_data)
	if not error.is_empty(): return "Invalid visitor snapshot: " + error
	error = visitor.save("user://visits/" + visitor_id + ".json")
	if not error.is_empty(): return "Could not apply visitor save: " + error
	var home: GameState = GameState.new()
	error = home.load_data(home_data)
	if not error.is_empty(): return "Invalid home snapshot: " + error
	error = home.save(home_path)
	if not error.is_empty(): return "Could not apply home save: " + error
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(journal_path)) != OK: return "Could not remove completed visit journal."
	return ""

static func _validate_data(data: Dictionary) -> String:
	var candidate: GameState = GameState.new()
	return candidate.load_data(data)

static func _valid_world_id(value: Variant) -> bool:
	if not value is String or value.length() != 32: return false
	for character: String in value:
		if not ((character >= "0" and character <= "9") or (character >= "a" and character <= "f")): return false
	return true
