extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()

func _run() -> void:
	var home_path := "user://journal-home-%d.json" % OS.get_process_id()
	var visitor := GameState.new()
	visitor.world_id = "abcddcbaabcddcbaabcddcba%08x" % OS.get_process_id()
	var visit_path := "user://visits/" + visitor.world_id + ".json"
	var journal_path := home_path + ".visit-journal.json"
	assert(not FileAccess.file_exists(home_path) and not FileAccess.file_exists(visit_path) and not FileAccess.file_exists(journal_path))
	var home := GameState.new()
	home.credits = 34567
	visitor.credits = 9876
	home.cargo.ore = 5
	visitor.cargo.ore = 5
	assert(VisitSave.commit(home, home_path, visitor, visit_path).is_empty(), "ordinary paired save")
	assert(not FileAccess.file_exists(journal_path), "successful commit clears journal")
	var loaded := GameState.new()
	assert(loaded.load_save(home_path).is_empty() and loaded.credits == 34567 and loaded.cargo.ore == 5)
	# Simulate interruption after visitor replacement but before home replacement.
	home.cargo.ore = 9
	visitor.cargo.ore = 9
	visitor.credits = 7654
	var journal := {"version":1, "home_data":home._save_data(), "visitor_data":visitor._save_data()}
	_write(journal_path, journal)
	assert(visitor.save(visit_path).is_empty())
	assert(VisitSave.recover(home_path).is_empty(), "replay interrupted pair")
	assert(loaded.load_save(home_path).is_empty() and loaded.cargo.ore == 9 and loaded.credits == 34567)
	assert(loaded.load_save(visit_path).is_empty() and loaded.cargo.ore == 9 and loaded.credits == 7654)
	# A completed pair may still retain its journal after an interrupted cleanup.
	_write(journal_path, journal)
	assert(VisitSave.recover(home_path).is_empty() and VisitSave.recover(home_path).is_empty(), "replay is idempotent")
	var old_home := FileAccess.get_file_as_string(home_path)
	var old_visit := FileAccess.get_file_as_string(visit_path)
	journal.visitor_data.world_id = "../../not-a-world"
	_write(journal_path, journal)
	assert(not VisitSave.recover(home_path).is_empty(), "malformed visitor snapshot rejected")
	assert(FileAccess.get_file_as_string(home_path) == old_home and FileAccess.get_file_as_string(visit_path) == old_visit,
		"validate both snapshots before replacing either file")
	assert(FileAccess.file_exists(journal_path), "failed journal remains available for repair")
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(journal_path)) == OK)
	assert(not VisitSave.commit(home, home_path, visitor, home_path).is_empty(), "reject noncanonical visitor destination")
	assert(not FileAccess.file_exists(journal_path), "invalid destination makes no journal")
	# A real apply failure must retain the journal and recover once writable.
	var blocked := home_path + ".blocked"
	assert(DirAccess.make_dir_absolute(blocked) == OK)
	assert(not VisitSave.commit(home, blocked, visitor, visit_path).is_empty(), "home replacement failure reported")
	assert(FileAccess.file_exists(blocked + ".visit-journal.json"))
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked)) == OK)
	assert(VisitSave.recover(blocked).is_empty(), "retry retained journal after home becomes writable")
	for path: String in [home_path, visit_path, journal_path, blocked, blocked + ".visit-journal.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("VISIT_JOURNAL_OK: paired save, interrupted replay, idempotence, validation and write-failure recovery")
	quit()
