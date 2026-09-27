extends SceneTree

var game: Node
var fired_count := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.close_menu()
	game._clear_actors()
	game.pilot.set_flight(true)
	game.pilot.teleport(Vector3(10000, 5000, 0))
	game.state.drive_temperature_k = 300.0
	var pirate := _ship("contact-search-pirate", "pirate", game.pilot.position + Vector3(1500, 0, 0))
	pirate.fired.connect(_on_fired)
	game._update_combat_targets()
	assert(pirate.target == null, "cold player is not acquired")
	game.state.drive_temperature_k = 600.0
	game._update_combat_targets()
	assert(pirate.target == game.pilot, "hot player is acquired through scene combat flow")
	var first_contact: Vector3 = game.pilot.global_position
	assert(pirate.last_contact_position == first_contact and pirate.search_seconds_remaining == pirate.CONTACT_SEARCH_SECONDS, "acquisition stores contact point and starts search clock")
	game.state.drive_temperature_k = 300.0
	game._update_combat_targets()
	assert(pirate.target == null, "cooling loses active target")
	assert(pirate.last_contact_position == first_contact and pirate.search_seconds_remaining == pirate.CONTACT_SEARCH_SECONDS, "loss retains last contact and does not restart clock")
	pirate.observe_target(null)
	assert(pirate.last_contact_position == first_contact and pirate.search_seconds_remaining == pirate.CONTACT_SEARCH_SECONDS, "null observation preserves the search clock")
	game.pilot.teleport(first_contact + Vector3(3000, 0, 0))
	pirate._physics_process(0.1)
	assert(pirate.last_contact_position == first_contact and pirate.search_seconds_remaining < pirate.CONTACT_SEARCH_SECONDS, "search uses remembered point after hidden player moves")
	assert(pirate.velocity.x < 0.0, "search movement heads toward the remembered point")
	assert(fired_count == 0, "searching ship does not fire without current contact")
	var clock_before_invalid_delta: float = pirate.search_seconds_remaining
	var position_before_invalid_delta: Vector3 = pirate.global_position
	pirate._physics_process(NAN)
	pirate._physics_process(2.0)
	assert(pirate.search_seconds_remaining == clock_before_invalid_delta and pirate.global_position == position_before_invalid_delta, "invalid or oversized physics steps are ignored")
	game.state.drive_temperature_k = 600.0
	game._update_combat_targets()
	assert(pirate.target == game.pilot and pirate.last_contact_position == game.pilot.global_position and pirate.search_seconds_remaining == pirate.CONTACT_SEARCH_SECONDS, "reacquisition refreshes point and clock")
	game.state.drive_temperature_k = 300.0
	game._update_combat_targets()
	var remembered := pirate.last_contact_position
	pirate.active = false
	pirate._physics_process(0.1)
	assert(pirate.search_seconds_remaining == pirate.CONTACT_SEARCH_SECONDS, "inactive ship pauses its search clock")
	pirate.active = true
	pirate.apply_origin_shift(Vector3(100, 20, -40))
	assert(pirate.last_contact_position == remembered - Vector3(100, 20, -40), "origin shift moves remembered contact")
	pirate.hostile = true
	pirate.global_position = pirate._home + Vector3(500, 0, 0)
	for _i in range(160):
		pirate._physics_process(0.1)
	assert(pirate.search_seconds_remaining <= 0.001, "search expires after fifteen seconds")
	assert(pirate.velocity.x < 0.0, "expired search returns toward home patrol")
	pirate.hostile = true
	pirate.observe_target(game.pilot)
	pirate.hostile = false
	pirate.observe_target(null)
	assert(pirate.search_seconds_remaining == 0.0, "passive ship clears search memory")
	assert(fired_count == 0, "loss, pause and passive transition never fire")
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	print("CONTACT_SEARCH_OK: acquisition, cold loss, remembered search, reacquisition, no-fire, pause, shift, passive clear")
	quit()

func _ship(id: String, faction: String, at: Vector3) -> ShipActor:
	var actor := ShipActor.new()
	actor.actor_id = id
	actor.faction = faction
	actor.position = at
	actor.speed = 65.0
	actor.set_physics_process(false)
	game.add_child(actor)
	game.actors.append(actor)
	return actor

func _on_fired(_actor: ShipActor, _origin: Vector3, _direction: Vector3) -> void:
	fired_count += 1
