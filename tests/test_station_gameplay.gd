extends SceneTree

var game: Node
var save_path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	save_path = "user://station-test-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.state.credits = 50000
	game.state.cargo.alloys = 20
	if not _check(game.state.build_station("New Horizon").is_empty(), "construct station"): return
	game.rebuild_owned_stations()
	var station: Node3D = game._station_node(0)
	if not _check(station != null, "station exists in loaded world"): return
	game.pilot.set_flight(true)
	game.pilot.teleport(station.to_global(station.launch_position))
	game.pilot.velocity = Vector3(80, 0, 0)
	game._interact()
	if not _check(game.pilot.flying and game.docked_station == -1, "fast docking rejected"): return
	game.pilot.velocity = Vector3.ZERO
	game._interact()
	if not _check(not game.pilot.flying and game.docked_station == 0, "slow docking accepted"): return
	if not _check(game.ship_display.position.distance_to(station.to_global(station.dock_position)) < 12, "ship appears on owned pad"): return
	game.close_menu()
	await create_timer(0.5).timeout
	if not _check(game.pilot.is_on_floor(), "docking deck supports walking pilot"): return
	game.pilot.teleport(station.to_global(station.stand_position) - Vector3(0, 200, 0))
	game._process(0.01)
	if not _check(game.pilot.position.distance_to(station.to_global(station.stand_position)) < 0.1, "fall recovery stays at owned station"): return
	game.pilot.teleport(station.to_global(station.dock_position) + Vector3(12, 1, 0))
	game._interact()
	if not _check(game.pilot.flying and game.docked_station == -1, "board and launch from owned pad"): return
	if not _check(game.pilot.position.distance_to(station.to_global(station.launch_position)) < 0.1, "departure uses this station"): return
	if not _check(game.state.found_faction("Horizon League").is_empty(), "found faction"): return
	game.state.faction_deposit(5000)
	if not _check(game.state.claim_station_faction(0).is_empty(), "affiliate station"): return
	var local_faction: String = Universe.system_data(game.state.system_index).faction
	game.state.set_diplomatic_stance(local_faction, "hostile")
	game._process(0.01)
	for actor in game.actors:
		if actor.faction == "police" and not _check(actor.hostile, "diplomacy affects police AI"): return
	game.state.set_diplomatic_stance(local_faction, "neutral")
	game._process(0.01)
	for actor in game.actors:
		if actor.faction == "police" and not _check(not actor.hostile, "neutral stance clears diplomatic hostility"): return
	game.open_menu("factions")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/factions.png")
	_cleanup()
	game.queue_free()
	await process_frame
	await process_frame
	print("STATION_GAMEPLAY_OK: docking speed, deck collision, launch, affiliation, police diplomacy")
	quit()

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("STATION_GAMEPLAY_FAILED: " + message)
		_cleanup()
		quit(1)
	return ok

func _cleanup() -> void:
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
