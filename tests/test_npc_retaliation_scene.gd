extends SceneTree

const PORT := 27880
const POSITION := Vector3(10000, 4000, 10000)
var game: Node
var guest: NetworkSession
var received: Array = []
var bystander_hits: Array = []
var save_path: String

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
	game.surface_index = -1
	game.pilot.teleport(POSITION + Vector3(500, 0, 0))
	save_path = "user://npc-retaliation-scene-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.session.world_id = "0123456789abcdef0123456789abcdef"
	assert(game.session.host(PORT).is_empty())
	guest = _guest("Guest")
	guest.npc_damage_received.connect(func(damage: float): received.append(damage))
	var bystander := _guest("Bystander")
	bystander.npc_damage_received.connect(func(damage: float): bystander_hits.append(damage))
	assert(guest.join("127.0.0.1", PORT).is_empty())
	assert(bystander.join("127.0.0.1", PORT).is_empty())
	assert(await _wait(func() -> bool: return guest.connected and bystander.connected and game.session.presence.size() == 3))
	var peer_id := guest.multiplayer.get_unique_id()
	var second_id := bystander.multiplayer.get_unique_id()
	guest.publish_pose(POSITION, Vector3.ZERO, game.flight_origin.to_save(), true)
	bystander.publish_pose(POSITION + Vector3(200, 0, 0), Vector3.ZERO, game.flight_origin.to_save(), true)
	assert(await _wait(func() -> bool: return game.session.is_visitor_flying(peer_id) and game.session.is_visitor_flying(second_id)))
	game._update_remote_positions()
	var pirate := _ship("raider_0", "pirate", POSITION + Vector3(0, 0, -60))
	pirate.weapon_damage = 30.0
	var police := _ship("security_0", "police", POSITION + Vector3(0, 0, -80))
	await _physics_sync()
	game._update_combat_targets()
	var visitor: Node3D = game.remote_ships[peer_id]
	var hit_body: StaticBody3D = visitor.get_meta("hit_body")
	var hit_shape: CollisionShape3D = hit_body.get_child(0)
	var shot_direction := (hit_shape.global_position - pirate.global_position).normalized()
	assert(pirate.target == visitor and pirate._target_is_active(), "pirate targets nearest fresh flying visitor")
	assert(game._nearest_hostile_visitor(police) == null, "police ignores peaceful visitors")
	police.set_meta("visitor_assaults", [peer_id])
	game._update_combat_targets()
	assert(police.target == visitor and police.hostile, "police retaliates against visitor who assaulted this ship")
	game.session._last_remote_pose_msec[peer_id] = Time.get_ticks_msec() - 2000
	game._update_combat_targets()
	assert(police.target != visitor and not visitor.get_meta("npc_target_active"), "stale pose cannot remain an active target")
	game.session._last_remote_pose_msec[peer_id] = Time.get_ticks_msec()
	game.session.presence[peer_id].flying = false
	game._update_combat_targets()
	assert(police.target != visitor and not visitor.get_meta("npc_target_active"), "grounded visitor cannot be targeted")
	game.session.presence[peer_id].flying = true
	game._update_combat_targets()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 30, 2)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position = POSITION + Vector3(0, 0, -30)
	await _physics_sync()
	assert(not game._ship_detectable(pirate, visitor), "wall blocks visitor sensor line of sight")
	assert(game._nearest_hostile_visitor(police) == null, "police cannot select visitor behind wall")
	game._enemy_fire(pirate, pirate.position, shot_direction)
	await create_timer(0.1).timeout
	assert(received.is_empty(), "wall blocks NPC damage delivery")
	wall.queue_free()
	await _physics_sync()
	game.session._last_remote_pose_msec[peer_id] = Time.get_ticks_msec()
	var excluded: Array[RID] = [pirate.get_rid()]
	var hit: Dictionary = game._ray(pirate.position, shot_direction, 2400.0, excluded)
	assert(hit.get("collider") == visitor.get_meta("hit_body"), "actual NPC firing ray strikes guest collision: " + str(hit))
	game._enemy_fire(pirate, pirate.position, shot_direction)
	assert(await _wait(func() -> bool: return received.size() == 1), "hit guest receives reliable damage")
	assert(received == [30.0] and bystander_hits.is_empty(), "only struck guest receives weapon damage")
	guest.leave()
	bystander.leave()
	game.session.leave()
	game.session.connected = true
	game.session.is_host = false
	game.pilot.flying = true
	game.state.shield = 20.0
	game.state.hull = 100.0
	game._receive_npc_damage(float(received[0]))
	assert(is_equal_approx(game.state.shield, 0.0) and is_equal_approx(game.state.hull, 90.0), "guest damage consumes shield before hull")
	game.pilot.flying = false
	game._receive_npc_damage(30.0)
	assert(is_equal_approx(game.state.hull, 90.0), "grounded scene ignores late NPC damage")
	game.sound.shutdown()
	game.session.leave()
	host_scope.queue_free()
	root.get_node("Guest").queue_free()
	root.get_node("Bystander").queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	print("NPC_RETALIATION_SCENE_OK: fresh pirate target, police hostility, stale and grounded exclusion, obstruction, targeted ENet damage and guest shields")
	quit()

func _guest(label: String) -> NetworkSession:
	var scope := _scope(label)
	var node := Node.new()
	node.name = "Main"
	scope.add_child(node)
	var session := NetworkSession.new()
	session.name = "NetworkSession"
	session.ship_modules = game.state.ship_modules.duplicate(true)
	session.ship_layout = game.state.ship_layout.duplicate(true)
	node.add_child(session)
	return session

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
