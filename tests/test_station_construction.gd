extends SceneTree

var game: Node
var save_path: String

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	save_path = "user://station-construction-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.state.credits = 200000
	game.state.cargo.alloys = 20
	assert(game.state.build_station("Aurora Exchange").is_empty())
	game.rebuild_owned_stations()
	game.open_menu("stations")
	var kinds: Array[String] = ["market", "company", "shipyard", "contracts", "factions", "stations"]
	for room in range(3, 16):
		game.state.cargo.alloys = 5
		var selector: OptionButton = _control(game.deck, "station_room_kind")
		selector.select(room % kinds.size())
		_control(game.deck, "station_room_add").pressed.emit()
		await process_frame
		assert(StationLayout.rooms_for(game.state.stations[0]).size() == room + 1)
	assert(_control(game.deck, "station_room_add").disabled)
	var room_selector: OptionButton = _control(game.deck, "station_room_selector")
	room_selector.select(15)
	_control(game.deck, "station_room_kind").select(4)
	_control(game.deck, "station_room_refit").pressed.emit()
	await process_frame
	assert(StationLayout.rooms_for(game.state.stations[0])[15] == "factions")
	_control(game.deck, "station_room_remove").pressed.emit()
	await process_frame
	assert(StationLayout.rooms_for(game.state.stations[0]).size() == 15)
	game.state.cargo.alloys = 5
	_control(game.deck, "station_room_kind").select(4)
	_control(game.deck, "station_room_add").pressed.emit()
	await process_frame
	var saved := GameState.new()
	assert(saved.load_save(save_path).is_empty())
	assert(saved.stations[0].rooms == game.state.stations[0].rooms)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/station-construction.png")
	game.close_menu()
	var station: OwnedStation = game._station_node(0)
	assert(station.interior_services.size() == 16)
	game.pilot.set_flight(true)
	game.pilot.teleport(station.to_global(station.launch_position))
	game._interact()
	var credits: int = game.state.credits
	assert(not game.edit_station_rooms(0, "remove").is_empty())
	assert(game.state.credits == credits and station.interior_services.size() == 16)
	var service: Dictionary = station.interior_services[15]
	assert(service.page == "factions")
	var target: Vector3 = service.position
	for local_point: Vector3 in [Vector3(18, 0.1, 40), Vector3(37, 0.1, 40), Vector3(124, 0.1, 40), Vector3(124, 0.1, target.z), Vector3(127.6, 0.1, target.z), target]:
		var arrived := false
		for frame in 2500:
			var offset: Vector3 = station.to_global(local_point) - game.pilot.position
			offset.y = 0
			if offset.length() < 0.4:
				arrived = true
				break
			game.pilot.rotation.y = atan2(-offset.x, -offset.z)
			Input.action_press("move_forward")
			await physics_frame
			assert(station.to_local(game.pilot.position).y > -0.5)
		Input.action_release("move_forward")
		assert(arrived, "reachable constructed room")
	game._interact()
	assert(game.ui_open and game.deck.page == "factions")
	assert(game.save_commander(false))
	game.load_commander()
	game.set_process(false)
	assert(game.docked_station == 0)
	assert(game._station_node(0).interior_services.size() == 16)
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game.queue_free()
	await process_frame
	await process_frame
	print("STATION_CONSTRUCTION_OK: menu add/refit/refund, save, occupied guard and physical access to room 16")
	quit()

func _control(node: Node, key: String) -> Node:
	if node.has_meta(key) and int(node.get_meta(key)) == 0: return node
	for child: Node in node.get_children():
		var found := _control(child, key)
		if found != null: return found
	return null
