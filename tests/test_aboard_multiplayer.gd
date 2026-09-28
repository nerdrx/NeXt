extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	assert("--capture-only" in OS.get_cmdline_user_args())
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	var path := "user://aboard-multiplayer-%d.json" % OS.get_process_id()
	game.save_path = path
	game.state.credits = 50000
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	game.apply_ship_stats()
	game.session.world_id = "0123456789abcdef0123456789abcdef"
	assert(game.session.host(27881).is_empty())
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(5000, 1800, 1000))
	game.pilot.restore_view(Vector3(0.1, 0.2, 0.0))
	game.pilot.restore_flight_velocity(Vector3(80, 0, 0))
	var board_key := InputEventKey.new()
	board_key.keycode = KEY_F
	board_key.pressed = true
	game._unhandled_key_input(board_key)
	assert(game.aboard and not game.pilot.flying and is_instance_valid(game.coasting_hull), "connected own ship supports walkable interior")
	var before: SectorPosition = game.flight_origin.clone()
	assert(before.move_delta(game.coasting_hull.position))
	game._rebase_flight()
	assert(game.flight_origin.sector.x == 1, "aboard ship rebases")
	var pose: Dictionary = game._network_ship_pose()
	var after: SectorPosition = game.flight_origin.clone()
	assert(after.move_delta(pose.position))
	assert(after.relative_to(before, 60000).length() < 0.01 and pose.flying, "wire pose preserves absolute flying hull after rebase")
	game.pilot.position += Vector3(2, 0, 1)
	assert(game._network_ship_pose().position == game.coasting_hull.position and game._network_ship_pose().rotation == game.coasting_hull.rotation, "walking passenger cannot move or rotate published hull")
	# Aim through a real outer hull collision shape; aboard geometry must be excluded from target occlusion.
	var hull: CoastingHull = game.coasting_hull
	var target_shape: CollisionShape3D = hull.get_child(0)
	var endpoint := target_shape.global_position
	var origin := endpoint + Vector3(0, 0, -100)
	var attacker: SectorPosition = game.flight_origin.clone()
	assert(attacker.move_delta(origin - PvPHits.CAMERA_OFFSET))
	game.session.presence[42] = {"address": attacker.to_save(), "name": "Visitor"}
	await physics_frame
	await physics_frame
	var direction := (endpoint - origin).normalized()
	var empty: Array[RID] = []
	var physical: Dictionary = game._ray(origin, direction, 105.0, empty)
	assert(not physical.is_empty(), "test ray actually intersects aboard vessel geometry")
	assert(game._pvp_clear_shot(42, game.multiplayer.get_unique_id(), direction, 101.0), "own hull and decks do not occlude confirmed PvP hit")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 20, 2)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position = origin + direction * 50.0
	await physics_frame
	await physics_frame
	assert(not game._pvp_clear_shot(42, game.multiplayer.get_unique_id(), direction, 101.0), "external wall still occludes aboard PvP")
	wall.queue_free()
	game.session.presence.erase(42)
	game.session.leave()
	game.session.connected = true
	game.session.is_host = false
	game.state.shield = 20.0
	game.state.hull = 100.0
	var suit: float = game.suit_health
	game._receive_npc_damage(30.0)
	assert(game.state.shield == 0.0 and game.state.hull == 90.0 and game.suit_health == suit, "NPC hit damages own ship while passenger walks")
	game.state.shield = 5.0
	game._receive_pvp_damage(42, 15.0)
	assert(game.state.shield == 0.0 and game.state.hull == 80.0 and game.suit_health == suit, "PvP hit damages own ship while passenger walks")
	var position: Vector3 = hull.position
	var velocity: Vector3 = hull.velocity
	game.exit_interior()
	assert(game.pilot.flying and game.pilot.position.distance_to(position) < 0.01 and game.pilot.flight_velocity().is_equal_approx(velocity), "connected helm return preserves exterior position and velocity")
	game.pilot.set_flight(false)
	game.enter_interior()
	assert(game.aboard and not game._network_ship_pose().flying and game._network_ship_pose().position == game.ship_display.position, "parked interior publishes parked hull")
	game._receive_npc_damage(30.0)
	game._receive_pvp_damage(42, 30.0)
	assert(game.state.hull == 80.0, "parked interior ignores late flight damage")
	game.exit_interior()
	game.pilot.set_flight(true)
	game.pilot.teleport(position)
	game.enter_interior()
	var wreck_address: SectorPosition = game.flight_origin.clone()
	assert(wreck_address.move_delta(game.coasting_hull.position))
	game.state.shield = 0.0
	game.state.hull = 5.0
	game._receive_npc_damage(30.0)
	assert(not game.aboard and not game.pilot.flying and not is_instance_valid(game.coasting_hull), "fatal network hit rescues passenger and releases hull")
	assert(game.state.hull > 0 and game.state.recovery.wrecks.size() == 1)
	var wreck: Dictionary = game.state.recovery.wrecks[0]
	assert(SectorPosition.from_save(wreck.address).relative_to(wreck_address, 60000).length() < 0.01, "network wreck uses hull address")
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty() and restored.recovery.wrecks.size() == 1, "network rescue persists")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("ABOARD_MULTIPLAYER_OK: connected boarding, hull wire pose, rebase, PvP cover, NPC/PvP damage, parked exclusion, helm return and rescue")
	quit()
