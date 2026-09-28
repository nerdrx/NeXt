extends SceneTree

const PORT := 27879
const POSITION := Vector3(10000, 4000, 10000)
var game: Node
var guest: NetworkSession
var outcomes: Array = []
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
	game.pilot.teleport(POSITION + Vector3(100, 0, 0))
	save_path = "user://npc-fire-scene-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.session.world_id = "0123456789abcdef0123456789abcdef"
	assert(game.session.host(PORT).is_empty())
	var guest_scope := _scope("Guest")
	var guest_main := Node.new()
	guest_main.name = "Main"
	guest_scope.add_child(guest_main)
	guest = NetworkSession.new()
	guest.name = "NetworkSession"
	guest_main.add_child(guest)
	guest.npc_hit_received.connect(func(faction: String, killed: bool, assault: bool): outcomes.append([faction, killed, assault]))
	assert(guest.join("127.0.0.1", PORT).is_empty())
	assert(await _wait(func() -> bool: return guest.connected and game.session.presence.size() == 2), "guest admitted")
	var attacker := guest.multiplayer.get_unique_id()
	var address: SectorPosition = game.flight_origin.clone()
	assert(address.move_delta(POSITION))
	game.session.presence[attacker].address = address.to_save()
	var pirate := _ship("raider_0", "pirate", POSITION + PvPHits.CAMERA_OFFSET + Vector3(0, 0, -60))
	pirate.max_hull = 100.0
	pirate.max_shields = 20.0
	pirate.shields = 20.0
	await _physics_sync()
	var excluded: Array[RID] = []
	var hit: Dictionary = game._ray(POSITION + PvPHits.CAMERA_OFFSET, Vector3.FORWARD, PvPHits.RANGE, excluded)
	assert(hit.get("collider") == pirate, "actual host ray hits NPC hull: " + str(hit))
	game._visitor_npc_shot(attacker, Vector3.FORWARD, 30.0)
	assert(is_equal_approx(pirate.shields, 0.0) and is_equal_approx(pirate.hp, 90.0), "host applies shields before hull")
	assert(await _wait(func() -> bool: return outcomes.size() == 1), "real guest receives hit confirmation")
	assert(outcomes.back() == ["pirate", false, false])

	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 20, 2)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position = POSITION + Vector3(0, 0, -30)
	await _physics_sync()
	game._visitor_npc_shot(attacker, Vector3.FORWARD, 30.0)
	assert(is_equal_approx(pirate.hp, 90.0), "wall blocks visitor fire")
	wall.queue_free()
	await _physics_sync()
	pirate.position = POSITION + PvPHits.CAMERA_OFFSET + Vector3(0, 0, -PvPHits.RANGE - 100)
	await _physics_sync()
	game._visitor_npc_shot(attacker, Vector3.FORWARD, 30.0)
	assert(is_equal_approx(pirate.hp, 90.0), "target beyond weapon range is unharmed")
	pirate.position = POSITION + PvPHits.CAMERA_OFFSET + Vector3(0, 0, -60)
	pirate.faction = "player_fleet"
	await _physics_sync()
	game._visitor_npc_shot(attacker, Vector3.FORWARD, 30.0)
	assert(is_equal_approx(pirate.hp, 90.0), "NPC firing path cannot damage player fleet")
	pirate.faction = "pirate"
	game.pilot.teleport(POSITION + Vector3(0, 0, -25))
	var hull_before: float = game.state.hull
	await _physics_sync()
	game._visitor_npc_shot(attacker, Vector3.FORWARD, 30.0)
	assert(is_equal_approx(game.state.hull, hull_before) and is_equal_approx(pirate.hp, 90.0), "host player blocks ray without taking NPC-path damage")
	game.pilot.teleport(POSITION + Vector3(100, 0, 0))
	await _physics_sync()
	var credits_before: int = game.state.credits
	var kills_before: int = game.state.kills
	pirate.set_meta("player_hit", true)
	game._visitor_npc_shot(attacker, Vector3.FORWARD, 100.0)
	assert(game.state.credits == credits_before and game.state.kills == kills_before, "visitor kill grants no host bounty even after prior host damage")
	assert(game.state.world_flags.get(game._location_key(), []).has("raider_0"), "visitor kill persists host world elimination")
	assert(await _wait(func() -> bool: return outcomes.size() == 2))
	assert(outcomes.back() == ["pirate", true, false])
	var police := _ship("security_0", "police", POSITION + PvPHits.CAMERA_OFFSET + Vector3(0, 0, -60))
	police.max_hull = 1000.0
	await _physics_sync()
	game._visitor_npc_shot(attacker, Vector3.FORWARD, 1.0)
	game._visitor_npc_shot(attacker, Vector3.FORWARD, 1.0)
	assert(await _wait(func() -> bool: return outcomes.size() == 4))
	assert(outcomes[2] == ["police", false, true] and outcomes[3] == ["police", false, false], "police assault reported once per attacker per victim")
	# Use the actual receiver against an isolated local commander, without changing a home save.
	guest.leave()
	game.session.leave()
	game.session.connected = true
	game.session.is_host = false
	var wanted_before: int = game.state.wanted
	game._receive_npc_hit("police", false, true)
	assert(game.state.wanted == wanted_before + 1)
	game._receive_npc_hit("pirate", true, false)
	assert(game.state.kills == kills_before + 1 and game.state.credits == credits_before + 250)
	var restored := GameState.new()
	assert(restored.load_save(save_path).is_empty() and restored.kills == game.state.kills and restored.wanted == game.state.wanted, "confirmed visitor outcome persists")
	game.sound.shutdown()
	game.session.leave()
	host_scope.queue_free()
	guest_scope.queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	print("NPC_FIRE_SCENE_OK: host ray, shields, walls, range, fleet/player immunity, guest outcomes, bounty ownership and police assault")
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
