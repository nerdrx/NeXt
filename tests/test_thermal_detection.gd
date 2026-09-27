extends SceneTree

var game: Node

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._clear_actors()
	game.close_menu()
	game.state.credits = 50000
	assert(game.state.add_module("habitat", Vector3i(0, 0, 3)).is_empty())
	game.apply_ship_stats()
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(10000, 5000, 0))
	game.state.drive_temperature_k = 300.0
	var pirate := _ship("thermal-pirate", "pirate", game.pilot.position + Vector3(1500, 0, 0))
	game._update_combat_targets()
	assert(pirate.target == null, "cold player ship stays below pirate detection threshold")
	game.state.drive_temperature_k = 600.0
	game._update_combat_targets()
	assert(pirate.target == game.pilot, "hot player ship is acquired at 1500 m")
	assert(game._ship_detectable(game.pilot, pirate), "NPC's default 450 K, 40 m² signature is detected within 1800 m")
	pirate.position = game.pilot.position + Vector3(1801, 0, 0)
	assert(not game._ship_detectable(game.pilot, pirate), "NPC signature falls beyond its 1800 m detection range")
	pirate.position = game.pilot.position + Vector3(1500, 0, 0)
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/thermal-visibility-hud.png")
	game.state.drive_temperature_k = 300.0
	game._update_combat_targets()
	assert(pirate.target == null, "cooling below threshold drops pirate lock")

	game.state.drive_temperature_k = 600.0
	var wall := StaticBody3D.new()
	game.add_child(wall)
	wall.position = game.pilot.position + Vector3(750, 0, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 200, 200)
	shape.shape = box
	wall.add_child(shape)
	await physics_frame
	await physics_frame
	game._update_combat_targets()
	assert(pirate.target == null, "world collision cover blocks thermal detection")
	wall.queue_free()
	await physics_frame
	await physics_frame
	game._update_combat_targets()
	assert(pirate.target == game.pilot, "thermal detection reacquires after cover is removed")

	game.enter_interior()
	assert(game.aboard and is_instance_valid(game.coasting_hull), "fixture boards the player ship")
	game._update_combat_targets()
	assert(pirate.target == game.coasting_hull, "pirate detects the occupied hull while player is aboard")
	var police := _ship("thermal-police", "police", game.coasting_hull.position + Vector3(-1500, 0, 0))
	police.hostile = false
	game._update_combat_targets()
	assert(not police.hostile, "thermal visibility does not change passive police stance")

	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	print("THERMAL_DETECTION_OK: cold/hot/cooling, blocked/reacquired LOS, aboard hull and passive police")
	quit()

func _ship(id: String, faction: String, at: Vector3) -> ShipActor:
	var actor := ShipActor.new()
	actor.actor_id = id
	actor.faction = faction
	actor.position = at
	actor.speed = 0
	actor.set_physics_process(false)
	game.add_child(actor)
	game.actors.append(actor)
	return actor
