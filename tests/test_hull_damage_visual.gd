extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _damage(visual: ShipVisual) -> float:
	return float(visual.get_node("FamilyPressureHull").material_override.get_shader_parameter("damage_amount"))

func _run() -> void:
	var actor := ShipActor.new()
	actor.hull_family = "pathfinder"
	actor.hp = 65.0
	root.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor._visual as ShipVisual
	assert(is_equal_approx(_damage(visual), 0.35), "spawned saved condition reaches material")
	actor.max_shields = 100
	actor.shields = 100
	actor.take_damage(20)
	assert(is_equal_approx(_damage(visual), 0.35), "shield-only hit does not scorch hull")
	actor.take_damage(actor.max_hull * 0.2, true)
	assert(is_equal_approx(_damage(visual), 0.55), "actual hull damage changes visual")
	actor.hp = 100
	assert(is_zero_approx(_damage(visual)), "repair clears scorch")
	visual.set_hull_integrity(-1)
	assert(_damage(visual) == 1)
	visual.set_hull_integrity(NAN)
	assert(_damage(visual) == 1)
	visual.set_hull_integrity(2)
	assert(_damage(visual) == 0)
	actor.queue_free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.pilot.set_physics_process(false)
	var family := ShipBlueprint.family("pathfinder")
	game.state.ship_modules.assign(family.modules)
	game.state.ship_layout = family.layout
	game.apply_ship_stats()
	game.state.hull = float(game._last_stats.max_hull) * 0.4
	game.rebuild_player_ship()
	assert(is_equal_approx(_damage(game.ship_display), 0.6), "player parked display uses absolute hull divided by max")
	game.state.hull = float(game._last_stats.max_hull)
	game._process(0.0)
	assert(is_zero_approx(_damage(game.ship_display)), "live repair refreshes parked display")
	game.session.leave()
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("HULL_DAMAGE_VISUAL_OK: saved actor, shield absorption, hull damage, repair, bounds and player display")
	quit()
