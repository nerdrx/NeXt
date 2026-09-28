extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const Surveys = preload("res://scripts/planet_surveys.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var state = GameStateScript.new()
	state.planet_surveys = {}
	for system: int in range(23):
		for planet: int in range(2):
			state.planet_surveys["%d:%d" % [system, planet]] = 1 if (system + planet) % 2 == 0 else 2
	var original: Dictionary = state.planet_surveys.duplicate(true)
	var first: Dictionary = Surveys.journal_page(state, 0)
	var second: Dictionary = Surveys.journal_page(state, 1)
	var last: Dictionary = Surveys.journal_page(state, 2)
	assert(first.page == 0 and first.pages == 3 and first.total == 46 and first.entries.size() == 20, "first page metadata and size")
	assert(second.entries.size() == 20 and last.entries.size() == 6, "page boundaries cover all records")
	var all_entries: Array = first.entries + second.entries + last.entries
	var seen: Dictionary = {}
	for index: int in range(all_entries.size()):
		var entry: Dictionary = all_entries[index]
		var key := "%d:%d" % [entry.system, entry.planet]
		assert(not seen.has(key), "pages do not overlap")
		seen[key] = true
		if index > 0:
			var previous: Dictionary = all_entries[index - 1]
			assert(previous.system < entry.system or (previous.system == entry.system and previous.planet < entry.planet), "numeric system then planet order")
	assert(seen.size() == 46 and all_entries[4].system == 2 and all_entries[20].system == 10, "system 2 sorts before system 10 across page boundary")

	var pending: Dictionary = Surveys.journal_page(state, 0, true)
	assert(pending.total == 23 and pending.pages == 2 and pending.entries.size() == 20, "pending filter and pagination")
	for entry: Dictionary in pending.entries:
		assert(entry.status == 1, "pending page contains only pending surveys")
	var pending_last: Dictionary = Surveys.journal_page(state, 1, true)
	assert(pending_last.total == 23 and pending_last.entries.size() == 3, "pending final page")
	var negative: Dictionary = Surveys.journal_page(state, -100)
	var huge: Dictionary = Surveys.journal_page(state, 999999)
	assert(negative.page == 0 and negative.entries == first.entries, "negative page clamps to first")
	assert(huge.page == 2 and huge.entries == last.entries, "large page clamps to last")
	assert(state.planet_surveys == original, "journal reads do not mutate survey archive")

	state.planet_surveys.clear()
	var empty: Dictionary = Surveys.journal_page(state, -1)
	assert(empty.page == 0 and empty.pages == 1 and empty.total == 0 and empty.entries.is_empty(), "empty archive has one empty page")
	print("SURVEY_JOURNAL_OK: sorted pagination, filtering, clamping, empty archive and immutability")
	quit()
