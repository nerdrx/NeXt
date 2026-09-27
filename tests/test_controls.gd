extends SceneTree

var main: Node
var test_save_path: String
var owns_path: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	test_save_path = "user://controls-test-%d.json" % OS.get_process_id()
	if FileAccess.file_exists(test_save_path):
		_fail("test save path already exists")
		return
	owns_path = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.save_path = test_save_path
	main.close_menu()
	for actor: Node in main.actors:
		actor.active = false
	var walk_start: Vector3 = main.pilot.global_position
	Input.action_press("move_forward")
	await create_timer(0.4).timeout
	Input.action_release("move_forward")
	if not _check(main.pilot.global_position.z < walk_start.z - 0.4, "manual walking moves on the station floor"): return
	await create_timer(0.35).timeout
	if not _check(main.pilot.is_on_floor() and absf(main.pilot.global_position.y) < 0.2, "station collision floor supports the walking pilot"): return

	main.pilot.set_flight(true)
	main.state.fuel = 37.0
	main.state.shield = 0.0
	main.cockpit_instruments.refresh()
	if not _check(main.cockpit_instruments.readouts[2].text == "FUEL   037%" and main.cockpit_instruments.readouts[1].text == "SHIELD   000%", "physical displays use actual ship vitals"): return
	main.pilot.teleport(Vector3(0, 80, -180))
	await physics_frame
	var destination := Vector3(0, 80, -340)
	var initial_distance: float = main.pilot.global_position.distance_to(destination)
	main.pilot.autopilot_to(destination)
	await create_timer(0.45).timeout
	var progressing_distance: float = main.pilot.global_position.distance_to(destination)
	if not _check(main.pilot.autopilot_active and progressing_distance < initial_distance - 2.0, "cruise autopilot progresses outside the station"): return
	if not _check(main.cockpit_instruments.mode_label.text == "CRUISE ENGAGED", "physical cruise indicator follows autopilot"): return
	var cancel_position: Vector3 = main.pilot.global_position
	Input.action_press("move_right")
	await create_timer(0.3).timeout
	Input.action_release("move_right")
	if not _check(not main.pilot.autopilot_active and main.pilot.global_position.distance_to(cancel_position) > 0.5, "manual flight input cancels cruise and takes control"): return

	if not _check(main.cockpit_instruments.mode_label.text == "FLIGHT ASSIST", "physical cruise indicator clears on manual input"): return
	main.pilot.teleport(Vector3(0, 120, -240))
	main.pilot.reset_view()
	main.pilot.set_flight(true)
	main.close_menu()
	for actor: Node in main.actors:
		actor.active = false
	var origin: Vector3 = main.pilot.camera.global_position
	var direction: Vector3 = -main.pilot.camera.global_basis.z
	var victim := ShipActor.new()
	victim.actor_id = "controls-test-pirate"
	victim.faction = "pirate"
	victim.target = null
	victim.active = false
	victim.shields = 0.0
	victim.hp = float(main._last_stats.damage) * 2.0
	victim.position = origin + direction * 55.0
	victim.destroyed.connect(main._actor_destroyed)
	main.add_child(victim)
	main.actors.append(victim)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = origin + direction * 25.0
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 8, 1)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	main.add_child(wall)
	wall.look_at(wall.position + direction, Vector3.UP)
	await physics_frame
	var kills_before: int = main.state.kills
	var credits_before: int = main.state.credits
	main._player_fire(origin, direction)
	await physics_frame
	if not _check(victim.hp == float(main._last_stats.damage) * 2.0 and main.state.kills == kills_before, "station wall blocks the weapon ray"): return
	wall.queue_free()
	await physics_frame
	await physics_frame
	main._player_fire(origin, direction)
	await physics_frame
	if not _check(victim.hp == float(main._last_stats.damage) and main.state.kills == kills_before, "unobstructed weapon ray damages pirate hull"): return
	main._player_fire(origin, direction)
	await physics_frame
	if not _check(main.state.kills == kills_before + 1 and main.state.credits == credits_before + 250, "destroying player-hit pirate records one kill and bounty"): return
	var awarded_credits: int = main.state.credits
	await physics_frame
	main._player_fire(origin, direction)
	await physics_frame
	if not _check(main.state.kills == kills_before + 1 and main.state.credits == awarded_credits, "destroyed target cannot pay bounty twice"): return
	main.sound.shutdown()
	_cleanup()
	print("CONTROLS_TEST_OK: walking, cruise/cancel, occluded fire, single bounty")
	quit()


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("CONTROLS_TEST_FAILED: " + message)
	if main != null:
		if main.session != null: main.session.leave()
		if main.sound != null: main.sound.shutdown()
	_cleanup()
	quit(1)


func _cleanup() -> void:
	if owns_path and FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
