extends SceneTree

var reports := 0
var ally_reports := 0
var ally_shots := 0

func _initialize() -> void: _run.call_deferred()

func _guard(game: Node3D, at: Vector3) -> GroundActor:
	var actor := GroundActor.new()
	actor.position = at
	actor.speed = 0
	actor.hold_position = true
	actor.target = game.pilot
	actor.contact_spotted.connect(game._ground_contact_report)
	game.add_child(actor)
	actor.set_physics_process(false)
	game.actors.append(actor)
	return actor

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	for actor in game.actors:
		if actor is GroundActor: assert(actor.contact_spotted.is_connected(game._ground_contact_report), "live resident radio wiring")
	game._clear_actors()
	var base := Vector3(10000, 10000, 10000)
	game.pilot.teleport(base + Vector3(0, 0, -20))
	var source := _guard(game, base)
	var ally := _guard(game, base + Vector3(20, 0, 0))
	source.contact_spotted.connect(func(_actor, _point): reports += 1)
	ally.contact_spotted.connect(func(_actor, _point): ally_reports += 1)
	ally.fired.connect(func(_actor, _origin, _direction): ally_shots += 1)
	var excluded: Array[GroundActor] = []
	for i in range(5): excluded.append(_guard(game, base + Vector3(22 + i, 0, 0)))
	excluded[0].hostile = false
	excluded[1].faction = "police"
	excluded[2].active = false
	excluded[3].position.x += 100
	excluded[4].set_meta("colony_index", 4)
	var wall := StaticBody3D.new()
	wall.position = base + Vector3(10, 2, -10)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 12, 80)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	await physics_frame
	await physics_frame
	source._physics_process(0.1)
	assert(reports == 1 and ally.contact_remaining == GroundActor.SEARCH_SECONDS, "visual acquisition reaches nearby hostile ally")
	assert(ally.last_seen_position == game.pilot.global_position)
	for actor in excluded: assert(actor.contact_remaining == 0, "neutral, other faction, inactive, distant and other colony are excluded")
	for tick in range(5): source._physics_process(0.1)
	assert(reports == 1, "visual reports are rate limited")
	var observed := ally.last_seen_position
	game.pilot.position.z -= 5
	ally._physics_process(0.1)
	assert(ally_shots == 0 and ally_reports == 0 and ally.last_seen_position == observed, "radio does not grant sight, fire or relay hidden target motion")
	for tick in range(61): ally._physics_process(0.1)
	assert(ally.contact_remaining == 0, "radio memory expires without fresh sightings")
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("GROUND_RADIO_OK: live wiring, nearby ally report, filters, rate limit, cover, no relay and expiry")
	quit()
