extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert("--capture-only" in OS.get_cmdline_user_args(), "run as a capture-only scene test")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.session.connected = true
	game.session.is_host = true
	game._spawn_actors()
	await process_frame
	var records: Array = game._npc_snapshot()
	assert(records.size() == 7, "host snapshot contains five raiders and two security ships")
	var expected_ids := ["raider_0", "raider_1", "raider_2", "raider_3", "raider_4", "security_0", "security_1"]
	var ids: Array[String] = []
	for record: Dictionary in records: ids.append(record.id)
	for id: String in expected_ids: assert(ids.has(id), "host snapshot includes " + id)

	game._clear_actors()
	await process_frame
	game.session.is_host = false
	game._spawn_actors()
	await process_frame
	for actor: Node in game.actors:
		if actor is ShipActor and actor.actor_id in expected_ids and not actor.get_meta("network_npc", false):
			assert(false, "guest suppresses local original " + actor.actor_id)

	game._receive_npc_ships(records)
	await process_frame
	assert(game.npc_replicas.size() == 7, "guest creates one replica per host NPC")
	for actor: ShipActor in game.npc_replicas.values(): assert(not actor.active, "received NPC replica is inactive")
	# Let Main run its real activation pass; replicas must stay presentation-only.
	game._network_clock = -1.0
	game.set_process(true)
	await process_frame
	game.set_process(false)
	var replica: ShipActor = game.npc_replicas["raider_0"]
	assert(not replica.active, "Main process cannot activate a network NPC")
	var original_hp: float = replica.hp
	var original_shields: float = replica.shields
	replica.take_damage(20.0, true)
	assert(replica.hp == original_hp and replica.shields == original_shields, "inactive replica rejects direct damage")

	# Aim a real player-fire ray through a relocated replica and verify the hit is presentation-only.
	game.pilot.teleport(Vector3(10000, 4000, 10000))
	game.ui_open = false
	var shot_records: Array = records.duplicate(true)
	var shot_position: Vector3 = game.pilot.position + Vector3(0, 0, -50)
	var shot_address: SectorPosition = game.flight_origin.clone()
	assert(shot_address.move_delta(shot_position), "shot target address is representable")
	for record: Dictionary in shot_records:
		if record.id == "raider_0": record.address = shot_address.to_save()
	game._receive_npc_ships(shot_records)
	await physics_frame
	await physics_frame
	replica = game.npc_replicas["raider_0"]
	var shot_origin: Vector3 = game.pilot.position
	var excluded: Array[RID] = [game.pilot.get_rid()]
	var hit: Dictionary = game._ray(shot_origin, Vector3.FORWARD, 150.0, excluded)
	assert(not hit.is_empty() and hit.collider == replica, "test ray actually hits the network replica")
	var wanted_before: int = game.state.wanted
	game._player_fire(shot_origin, Vector3.FORWARD)
	assert(replica.hp == original_hp and replica.shields == original_shields and not replica.has_meta("player_hit") and game.state.wanted == wanted_before,
		"player fire does not damage or flag a network replica")

	# Rebase the local origin: the stored absolute address must resolve to a shifted position.
	var absolute: SectorPosition
	for record: Dictionary in shot_records:
		if record.id == "raider_0": absolute = SectorPosition.from_save(record.address)
	var old_position: Vector3 = replica.position
	var shifted_origin: SectorPosition = game.flight_origin.clone()
	assert(shifted_origin.move_delta(Vector3(8192, 0, 0)), "shifted origin is representable")
	game.flight_origin = shifted_origin
	game._update_npc_positions(0.0)
	var expected_position: Vector3 = absolute.relative_to(shifted_origin, 30000.0)
	assert(expected_position != null and replica.position.distance_to(expected_position) < 0.01 and replica.position.distance_to(old_position) > 8191.0,
		"replica repositions from its absolute address after origin change")
	var far_origin: SectorPosition = shifted_origin.clone()
	assert(far_origin.move_delta(Vector3(35000, 0, 0)), "far origin is representable")
	game.flight_origin = far_origin
	game._update_npc_positions(0.0)
	assert(not replica.visible and replica.collision_layer == 0, "distant replica hides and leaves collision")

	game._receive_npc_ships([])
	assert(game.npc_replicas.is_empty(), "empty snapshot removes all replicas")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	await process_frame
	print("NPC_SCENE_OK: seven host NPCs, guest suppression, inactive replicas, safe ray hits, rebase, culling and removal")
	quit()
