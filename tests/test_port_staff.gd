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
	save_path = "user://port-staff-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.close_menu()
	var names := _names()
	if not _check(names.size() == game.colonies.size() * 6, "six stable identities per port"): return
	var colony: Node3D = game.colonies[0]
	game.pilot.set_flight(true)
	game.pilot.teleport(colony.to_global(colony.landing_position) + Vector3.UP * 25)
	game.pilot.velocity = Vector3.ZERO
	game._interact()
	game._process(0.0)
	if not _check(game.manual_planet == 0 and not game.pilot.flying, "actual port docking"): return
	await create_timer(0.6).timeout
	for slot in 4:
		var clerk := _person("port_0_resident_%d" % slot)
		if not _check(clerk != null and clerk.is_on_floor(), "clerk %d supported by room floor" % slot): return
		var before := clerk.position
		game.pilot.teleport(colony.to_global(colony.interior_positions[slot] + Vector3(0, 0.3, 0.5)))
		game.pilot.reset_view()
		await create_timer(0.25).timeout
		var service: Dictionary = game._colony_service()
		if not _check(not service.is_empty() and clerk.display_name in service.label, "service identifies clerk %d" % slot): return
		game._interact()
		if not _check(game.ui_open and game.deck.page == clerk.get_meta("service"), "E opens clerk service %d" % slot): return
		game.close_menu()
		game._process(0.0)
		if not _check(Vector2(clerk.position.x - before.x, clerk.position.z - before.z).length() < 0.02, "clerk holds counter instead of following"): return
		if DisplayServer.get_name() != "headless" and slot == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/port-staff.png")
	var remote_count := 0
	for actor in game.actors:
		if actor.has_meta("colony_index") and actor.position.distance_to(game.pilot.position) > 250:
			remote_count += 1
			if not _check(not actor.active, "remote port residents suspended"): return
	if not _check(remote_count > 0, "remote residents exercised"): return
	if not _check(game.save_commander(false), "staffed port saved"): return
	game.load_commander()
	game.close_menu()
	game._process(0.0)
	if not _check(_names() == names, "names survive full world rebuild and save load"): return
	colony = game.colonies[0]
	var victim := _person("port_0_resident_0")
	game.pilot.teleport(colony.to_global(colony.interior_positions[0] + Vector3(0, 0.3, 0.5)))
	game.pilot.reset_view()
	await create_timer(0.3).timeout
	# Fire through the real player ray path above the counter, not direct damage.
	var origin: Vector3 = game.pilot.camera.global_position
	var direction := origin.direction_to(victim.global_position + Vector3.UP * 1.5)
	var excluded: Array[RID] = [game.pilot.get_rid()]
	var hit: Dictionary = game._ray(origin, direction, 150, excluded)
	if not _check(hit.get("collider") == victim, "player shot has clear physical ray to clerk"): return
	var wanted: int = game.state.wanted
	game._player_fire(origin, direction)
	if not _check(victim.hp == 66.0 and game.state.wanted == wanted + 1, "nonlethal assault reports wanted immediately"): return
	game._process(0.0)
	for slot in [4, 5]:
		if not _check(_person("port_0_resident_%d" % slot).hostile, "port security responds to assault"): return
	game._player_fire(origin, direction)
	game._player_fire(origin, direction)
	await process_frame
	if not _check(_person("port_0_resident_0") == null, "lethal player shots remove clerk"): return
	if not _check(game.save_commander(false), "casualty saved"): return
	game.load_commander()
	game.close_menu()
	var survivors := names.duplicate()
	survivors.erase("port_0_resident_0")
	if not _check(_names() == survivors, "dead clerk remains absent; every surviving identity remains stable"): return
	_cleanup()
	game.queue_free()
	await process_frame
	await process_frame
	print("PORT_STAFF_OK: physical clerks, named services, stable identities, distant suspension, ray-fired assault, security response, persisted casualty")
	quit()

func _person(actor_id: String) -> GroundActor:
	for actor in game.actors:
		if actor is GroundActor and actor.actor_id == actor_id: return actor
	return null

func _names() -> Dictionary:
	var result := {}
	for actor in game.actors:
		if actor.has_meta("colony_index"): result[actor.actor_id] = actor.display_name
	return result

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("PORT_STAFF_FAILED: " + message)
		_cleanup()
		quit(1)
	return ok

func _cleanup() -> void:
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
