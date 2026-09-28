extends SceneTree

var game: Node
var impacts: Array[float] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	var pilot: Pilot = game.pilot
	pilot.set_physics_process(false)
	pilot.set_flight(false)
	pilot.collision_mask = 1
	pilot.landing_impact.connect(func(value: float): impacts.append(value))
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(10000, -0.5, 10000)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	floor_body.add_child(shape)
	root.add_child(floor_body)
	await physics_frame
	await physics_frame
	var path := "user://landing-injury-%d.json" % OS.get_process_id()
	game.save_path = path
	var hull: float = game.state.hull
	var shield: float = game.state.shield
	# A short descent and tangential motion do not damage the commander.
	await _drop(0.8)
	assert(game.suit_health == 100 and impacts.is_empty())
	pilot.teleport(Vector3(10000, 0.05, 10000))
	pilot._walk_velocity = Vector3(14, -1, 0)
	await physics_frame
	pilot._physics_process(1.0 / 60.0)
	assert(game.suit_health == 100 and impacts.is_empty(), "normal speed matters, not horizontal running")
	await _drop(5.0)
	assert(impacts.size() == 1 and impacts[0] > 8.0)
	assert(game.suit_health > 0 and game.suit_health < 100, "hard fall injures the commander")
	assert(game.state.hull == hull and game.state.shield == shield, "landing injury does not debit ship defenses")
	assert(game.save_commander(false))
	var loaded := GameState.new()
	assert(loaded.load_save(path).is_empty() and is_equal_approx(loaded.commander_health, game.suit_health))
	var health: float = game.suit_health
	for value: float in [8.0, -1.0, INF, NAN]: game._walking_impact(value)
	assert(game.suit_health == health, "invalid and safe impacts do nothing")
	pilot.set_flight(true)
	game._walking_impact(100)
	assert(game.suit_health == health, "flight uses its own impact path")
	pilot.set_flight(false)
	game.suit_health = 100
	var credits: int = game.state.credits
	await _drop(20.0)
	await process_frame
	assert(game.suit_health == 100 and game.state.credits == credits - 250, "fatal fall triggers medical rescue")
	assert(game.state.hull == hull and game.state.recovery.wrecks.is_empty(), "suit death does not destroy the parked ship")
	assert(loaded.load_save(path).is_empty() and loaded.commander_health == 100 and loaded.credits == credits - 250)
	floor_body.queue_free()
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("LANDING_INJURY_OK: safe descent, normal impact, persisted injury, ship isolation and fatal medical rescue")
	quit()

func _drop(height: float) -> void:
	game.pilot.teleport(Vector3(10000, height, 10000))
	for step in range(130):
		await physics_frame
		game.pilot._physics_process(1.0 / 60.0)
		if game.pilot.is_on_floor(): return
	assert(false, "drop did not reach collision floor")
