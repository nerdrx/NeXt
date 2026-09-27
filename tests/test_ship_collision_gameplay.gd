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
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.close_menu()
	save_path = "user://ship-collision-%d.json" % OS.get_process_id()
	game.save_path = save_path
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(1500, 1500, 1500))
	await process_frame
	await process_frame
	var initial_radius: float = game.pilot.hull_radius
	var initial_modules: Array = game.state.ship_modules.duplicate(true)
	game.state.credits = 100000
	for step in range(2, 13):
		for side in [-1, 1]:
			if not _check(game.state.add_module("cargo", Vector3i(side * step, 0, 0)).is_empty(), "build connected wide wings"): return
	game.apply_ship_stats()
	await process_frame
	await process_frame
	var expanded_radius: float = game.pilot.hull_radius
	if not _check(expanded_radius > 35 and expanded_radius > initial_radius and game.pilot._module_shapes.size() == game.state.ship_modules.size(), "builder changes reach physical hull"): return
	if not _check(game.save_commander(false), "save widened ship"): return
	game.state.ship_modules.assign(initial_modules)
	game.apply_ship_stats()
	await process_frame
	await process_frame
	if not _check(is_equal_approx(game.pilot.hull_radius, initial_radius), "removing wings shrinks collision bounds"): return
	game.load_commander()
	game._clear_actors()
	await process_frame
	await process_frame
	if not _check(is_equal_approx(game.pilot.hull_radius, expanded_radius) and game.pilot._module_shapes.size() == game.state.ship_modules.size(), "load restores custom collision geometry"): return
	var dry_site: Vector3 = game._surface_landing_direction(0)
	if not _check(dry_site != Vector3.ZERO, "wide ship can find open ground using occupied-module footprints"): return
	game.approach_colony(0)
	if not _check(game.cruise_address != null, "large ship can plan a surface port approach"): return
	var destination: Vector3 = game.cruise_address.relative_to(SectorPosition.new(), 60000)
	var body: Dictionary = game.world.planets[0]
	if not _check(destination.distance_to(body.position) >= float(body.visual_radius) + 14 + expanded_radius + 14.9, "large ship approach keeps its full hull above port"): return
	game.pilot.teleport(destination)
	game._interact()
	if not _check(game.pilot.flying and "exceeds this port" in game.hud.message, "oversized ship cannot dock through port buildings"): return
	var foot: Vector3 = game._surface_disembark_direction(Vector3.RIGHT, float(body.visual_radius))
	if not _check(foot.slide(Vector3.RIGHT).length() * float(body.visual_radius) > expanded_radius + 2.9, "surface disembarkation clears the wide hull"): return
	game.pilot.cancel_autopilot()
	game.sound.shutdown()
	game.session.leave()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game.queue_free()
	await process_frame
	await process_frame
	print("SHIP_COLLISION_GAMEPLAY_OK: module building, geometry save/restore and hull-aware surface approach")
	quit()

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		game.sound.shutdown()
		game.session.leave()
		if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
		quit(1)
	return ok
