extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := GameState.new()
	state.commander_health = 37.5
	var path := "user://health-test-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty())
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty() and restored.commander_health == 37.5)
	var old := state._save_data().duplicate(true)
	old.erase("commander_health")
	assert(restored.load_data(old).is_empty() and restored.commander_health == 100, "older saves default to full health")
	restored.commander_health = 22
	var unchanged := restored._save_data().duplicate(true)
	for invalid: Variant in [-1, 101, NAN, INF, "50", true, null]:
		var malformed := state._save_data().duplicate(true)
		malformed.commander_health = invalid
		assert(not restored.load_data(malformed).is_empty(), "reject invalid health")
		assert(restored._save_data() == unchanged, "rejected load is atomic")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.save_path = path
	game.suit_health = 37.5
	assert(game.state.commander_health == 37.5)
	assert(game.save_commander(false))
	game.suit_health = 90
	game.load_commander()
	assert(game.suit_health == 37.5, "reload restores injuries")
	game.pilot.set_flight(true)
	game.land(0)
	assert(game.surface_index == 0 and game.suit_health == 37.5, "landing does not heal")
	# Zero health is a recoverable saved state, not a free resurrection on load.
	game.suit_health = -8
	assert(game.state.commander_health == 0, "fatal damage clamps persisted health to zero")
	assert(game.save_commander(false))
	game.suit_health = 90
	game.load_commander()
	assert(game.suit_health == 0)
	var credits: int = game.state.credits
	game._process(0)
	assert(game.suit_health == 100 and game.state.credits == credits - 250, "loaded fatal injury uses ordinary rescue")
	assert(restored.load_save(path).is_empty() and restored.commander_health == 100)
	game._process(0)
	assert(game.state.credits == credits - 250, "rescue fee applies once")
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("COMMANDER_HEALTH_OK: persistence, legacy default, atomic validation, reload, landing and fatal rescue")
	quit()
