extends SceneTree

var game: Node
var shots := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	game.close_menu()
	var path := "user://aboard-combat-%d.json" % OS.get_process_id()
	game.save_path = path
	game.state.credits = 50000
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	game.apply_ship_stats()
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(4090, 1800, 1000))
	game.pilot.restore_flight_velocity(Vector3(80, 0, 0))
	var pirate := ShipActor.new()
	pirate.position = game.pilot.position + Vector3(0, 0, -100)
	pirate.fired.connect(game._enemy_fire)
	pirate.fired.connect(func(_actor, _origin, _direction): shots += 1)
	game.add_child(pirate)
	game.actors.append(pirate)
	pirate.set_physics_process(false)
	game.enter_interior()
	assert(game.aboard, "nearby hostiles no longer block leaving the helm")
	game._process(0)
	assert(pirate.active and pirate.target == game.coasting_hull, "pirate targets occupied vessel while passenger walks")
	var shield: float = game.state.shield
	var suit: float = game.suit_health
	pirate.set_physics_process(true)
	await create_timer(1.4).timeout
	pirate.set_physics_process(false)
	assert(shots > 0 and game.state.shield < shield, "real actor firing damages occupied vessel")
	assert(game.aboard and game.suit_health == suit and game.pilot.is_on_floor(), "ship shields protect passenger")
	assert(game.flight_origin.sector.x == 1, "combat target survives origin rebase")
	game.coasting_hull.velocity = Vector3.ZERO
	var origin: Vector3 = game.coasting_hull.position + Vector3(0, 0, -100)
	var direction := Vector3.BACK
	pirate.position = origin
	var wall := StaticBody3D.new()
	game.add_child(wall)
	wall.position = game.coasting_hull.position + Vector3(0, 0, -50)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 20, 1)
	shape.shape = box
	wall.add_child(shape)
	await physics_frame
	await physics_frame
	shield = game.state.shield
	game._enemy_fire(pirate, origin, direction)
	assert(game.state.shield == shield, "world geometry still blocks incoming ship fire")
	wall.queue_free()
	await physics_frame
	await physics_frame
	pirate.weapon_damage = 17.0
	game._enemy_fire(pirate, origin, direction)
	assert(game.state.shield == shield - 17 and game.suit_health == suit, "outer hull receives damage after cover removed")
	var wreck_address := SectorPosition.new(game.flight_origin.sector, game.coasting_hull.position)
	game.state.shield = 0
	game.state.hull = 5
	game.state.cargo.food = 5
	game._enemy_fire(pirate, origin, direction)
	assert(not game.aboard and not game.pilot.flying and not is_instance_valid(game.coasting_hull), "fatal hit rescues passenger and releases occupied hull")
	assert(game.state.hull > 0 and game.state.recovery.wrecks.size() == 1)
	var wreck: Dictionary = game.state.recovery.wrecks[0]
	assert(SectorPosition.from_save(wreck.address).relative_to(wreck_address, 60000).length() < 0.01, "wreck records destroyed hull address, not passenger offset")
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty() and restored.recovery.wrecks.size() == 1, "rescue and wreck persist")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	for filename in [path, path + ".bak"]:
		if FileAccess.file_exists(filename): DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
	print("ABOARD_COMBAT_OK: active pirate fire, shield damage, protected passenger, origin rebase, world cover and persisted wreck rescue")
	quit()
