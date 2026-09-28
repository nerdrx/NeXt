extends SceneTree

const PORT := 27882
const POSITION := Vector3(10000, 4000, 10000)
var game: Node
var guest: NetworkSession
var outcomes: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _scope(label: String) -> Node:
	var node := Node.new()
	node.name = label
	root.add_child(node)
	set_multiplayer(MultiplayerAPI.create_default_interface(), node.get_path())
	return node

func _run() -> void:
	assert("--capture-only" in OS.get_cmdline_user_args())
	var host_scope := _scope("Host")
	game = load("res://scenes/main.tscn").instantiate()
	game.name = "Main"
	host_scope.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.ui_open = false
	game.pilot.teleport(POSITION + Vector3(100, 0, 0))
	game.session.world_id = "0123456789abcdef0123456789abcdef"
	assert(game.session.host(PORT).is_empty())
	var guest_scope := _scope("Guest")
	var guest_main := Node.new()
	guest_main.name = "Main"
	guest_scope.add_child(guest_main)
	guest = NetworkSession.new()
	guest.name = "NetworkSession"
	guest_main.add_child(guest)
	guest.npc_beam_received.connect(func(id: String, origin: Dictionary, endpoint: Dictionary): outcomes.append([id, origin, endpoint]))
	assert(guest.join("127.0.0.1", PORT).is_empty())
	assert(await _wait(func() -> bool: return guest.connected and game.session.presence.size() == 2))
	var pirate := _ship("raider_0", "pirate", POSITION)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 20, 2)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position = POSITION + Vector3(0, 0, -50)
	await _physics_sync()
	game._enemy_fire(pirate, POSITION, Vector3.FORWARD)
	assert(await _wait(func() -> bool: return outcomes.size() == 1), "host firing broadcasts real ENet beam")
	var packet: Array = outcomes[0]
	assert(packet[0] == "raider_0")
	var start: SectorPosition = SectorPosition.from_save(packet[1])
	var end: SectorPosition = SectorPosition.from_save(packet[2])
	assert(start.relative_to(game.flight_origin, 30000).distance_to(POSITION) < 0.01)
	assert(end.relative_to(start, 30000).distance_to(Vector3(0, 0, -49)) < 0.02, "broadcast endpoint stops at wall front")
	wall.queue_free()
	await _physics_sync()
	await create_timer(0.21).timeout
	game._enemy_fire(pirate, POSITION, Vector3.FORWARD)
	assert(await _wait(func() -> bool: return outcomes.size() == 2))
	var miss_end: SectorPosition = SectorPosition.from_save(outcomes[1][2])
	assert(miss_end.relative_to(start, 30000).distance_to(Vector3(0, 0, -180)) < 0.01, "miss broadcast preserves visible short beam endpoint")
	await create_timer(0.2).timeout
	guest.leave()
	game.session.leave()
	game.session.connected = true
	game.session.is_host = false
	var shifted: SectorPosition = game.flight_origin.clone()
	assert(shifted.move_delta(Vector3(8192, 0, 0)))
	game.flight_origin = shifted
	var hull: float = game.state.hull
	var shield: float = game.state.shield
	var count := game.get_child_count()
	game._receive_npc_beam(packet[0], packet[1], packet[2])
	assert(game.get_child_count() == count + 1, "guest creates one cosmetic mesh")
	var beam: MeshInstance3D = game.get_child(game.get_child_count() - 1)
	var local_start: Vector3 = start.relative_to(shifted, 30000)
	var local_end: Vector3 = end.relative_to(shifted, 30000)
	assert(beam.position.distance_to((local_start + local_end) * 0.5) < 0.01, "absolute packet rebases to guest origin")
	assert(is_equal_approx(beam.mesh.size.z, local_start.distance_to(local_end)))
	assert((-beam.basis.z).dot((local_end - local_start).normalized()) > 0.999, "mesh points toward broadcast endpoint")
	assert(beam.material_override.albedo_color.is_equal_approx(Color("ff9673")), "NPC beam uses orange material")
	assert(game.state.hull == hull and game.state.shield == shield, "beam event cannot damage commander")
	var far: SectorPosition = shifted.clone()
	assert(far.move_delta(Vector3(60000, 0, 0)))
	game.flight_origin = far
	game._receive_npc_beam(packet[0], packet[1], packet[2])
	assert(game.get_child_count() == count + 1, "far beam is culled")
	await create_timer(0.25).timeout
	assert(not is_instance_valid(beam), "tween frees received beam")
	game.sound.shutdown()
	game.session.leave()
	host_scope.queue_free()
	guest_scope.queue_free()
	await process_frame
	await process_frame
	print("NPC_BEAM_SCENE_OK: real host shot, wall and miss endpoints, ENet event, guest origin conversion, color, culling and cosmetic cleanup")
	quit()

func _ship(id: String, faction: String, point: Vector3) -> ShipActor:
	var actor := ShipActor.new()
	actor.actor_id = id
	actor.faction = faction
	game.add_child(actor)
	actor.position = point
	actor.set_physics_process(false)
	actor.destroyed.connect(game._actor_destroyed)
	game.actors.append(actor)
	return actor

func _physics_sync() -> void:
	await physics_frame
	await physics_frame

func _wait(condition: Callable) -> bool:
	for i in range(150):
		if condition.call(): return true
		await create_timer(0.02).timeout
	return condition.call()
