extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for family_id: String in ["pathfinder", "merchant"]:
		var blueprint: Dictionary = ShipBlueprint.family(family_id)
		var model := GameState.new()
		model.ship_modules.assign(blueprint.modules)
		var stats: Dictionary = model.ship_stats()
		var actor := ShipActor.new()
		actor.hull_family = family_id
		actor.shields = 0.0
		root.add_child(actor)
		actor.set_physics_process(false)
		await process_frame
		assert(is_equal_approx(actor.max_hull, float(stats.max_hull)), "%s actor uses family hull capacity" % family_id)
		assert(is_equal_approx(actor.weapon_damage, float(stats.damage)), "%s actor uses family weapon damage" % family_id)
		actor.take_damage(actor.max_hull * 0.25)
		assert(is_equal_approx(actor.hp, 75.0), "%s hull damage remains normalized to percent" % family_id)
		actor.hp = 100.0
		actor.shields = 6.0
		actor.take_damage(10.0)
		assert(is_equal_approx(actor.shields, 0.0), "shields absorb absolute damage first")
		assert(is_equal_approx(actor.hp, 100.0 - 4.0 * 100.0 / actor.max_hull),
			"shield overflow converts absolute hull damage to percent")
		actor.queue_free()
		await process_frame

	var damaged_family := ShipActor.new()
	damaged_family.hull_family = "pathfinder"
	damaged_family.hp = 30.0
	root.add_child(damaged_family)
	await process_frame
	assert(is_equal_approx(damaged_family.hp, 30.0), "family setup preserves normalized pre-ready hull")
	damaged_family.queue_free()
	await process_frame

	var legacy := ShipActor.new()
	legacy.shields = 0.0
	root.add_child(legacy)
	await process_frame
	assert(is_equal_approx(legacy.max_hull, 100.0) and is_equal_approx(legacy.weapon_damage, 9.0),
		"legacy actors retain default combat stats")
	legacy.take_damage(25.0)
	assert(is_equal_approx(legacy.hp, 75.0), "legacy absolute damage keeps existing percent behavior")
	print("FAMILY_COMBAT_OK: family hull scaling, shields, legacy damage")
	quit()
