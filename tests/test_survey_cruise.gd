extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.pilot.set_flight(true)
	var count: int = game.world.planets.size()
	assert(count >= 2)
	for i in range(2, count): game.state.planet_surveys["0:%d" % i] = 2
	var body: Dictionary = game.world.planets[0]
	game.pilot.teleport(game._planet_center(0) + Vector3.UP * (float(body.visual_radius) + 700))
	assert(game.next_unsurveyed_planet() == 0, "nearest surface is selected")
	var credits: int = game.state.credits
	game.open_menu("journal")
	var button := game.deck.find_child("NextSurveyApproach", true, false) as Button
	assert(button != null and not button.disabled)
	button.pressed.emit()
	assert(game.cruise_address != null and game.pilot.autopilot_active)
	var destination: Vector3 = game.cruise_address.relative_to(SectorPosition.new(), SectorPosition.MAX_RELATIVE_DISTANCE)
	assert(is_equal_approx(destination.distance_to(Vector3(body.position)) - float(body.visual_radius), 600.0), "survey approach ends 600m above surface")
	assert(game.state.credits == credits and not game.state.planet_surveys.has("0:0"), "routing does not scan or pay")
	game.pilot.cancel_autopilot()
	game.cruise_address = null
	game.state.planet_surveys["0:0"] = 1
	assert(game.next_unsurveyed_planet() == 1, "pending surveys are skipped")
	game.aboard = true
	game.approach_next_unsurveyed()
	assert(game.cruise_address == null, "aboard action is guarded")
	game.aboard = false
	game.state.systems_online = false
	game.approach_next_unsurveyed()
	assert(game.cruise_address == null, "offline ship cannot start route")
	game.state.systems_online = true
	game.jump_charge = 1.0
	game.approach_next_unsurveyed()
	assert(game.cruise_address == null, "jump charge prevents cruise replacement")
	game.jump_charge = 0.0
	game.state.planet_surveys["0:1"] = 2
	assert(game.next_unsurveyed_planet() == -1)
	game.open_menu("navigation")
	button = game.deck.find_child("NextSurveyApproach", true, false) as Button
	assert(button.disabled, "completed system has no next survey cruise")
	game.approach_next_unsurveyed()
	assert(game.cruise_address == null)
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("SURVEY_CRUISE_OK: nearest selection, real menu approach, altitude, manual scan, exclusions and completed system")
	quit()
