extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := GameState.new()
	state.credits = 100000
	state.cargo.ore = 10
	state.fuel = 38.0
	state.drive_temperature_k = 560.0
	state.hull = float(state.ship_stats().max_hull) * 0.5
	state.shield = float(state.ship_stats().max_shield) * 0.25
	assert(state.hire("engineer").is_empty())
	var crew_before := state.crew.duplicate(true)
	var cash_before := state.credits
	var quote := state.hull_family_quote("pathfinder")
	assert(quote.price == 8200 and quote.trade_in == 1487 and quote.net == 6713, "quote includes condition-adjusted trade-in once")
	assert(state.refit_hull_family("pathfinder").is_empty())
	assert(state.credits == cash_before - quote.net and state.cargo.ore == 10 and state.crew == crew_before)
	assert(is_equal_approx(state.hull / state.ship_stats().max_hull, 0.5))
	assert(is_equal_approx(state.shield / state.ship_stats().max_shield, 0.25))
	assert(state.fuel == 38.0 and state.drive_temperature_k == 560.0)
	var snapshot := state._save_data().duplicate(true)
	assert(not state.refit_hull_family("pathfinder").is_empty() and state._save_data() == snapshot, "repeat layout is rejected atomically")
	assert(not state.refit_hull_family("unknown").is_empty() and state._save_data() == snapshot)
	state.credits = 0
	snapshot = state._save_data().duplicate(true)
	assert(not state.refit_hull_family("merchant").is_empty() and state._save_data() == snapshot)
	state.credits = 100000
	assert(state.refit_hull_family("merchant").is_empty())
	state.cargo.ore = 100
	snapshot = state._save_data().duplicate(true)
	assert(not state.refit_hull_family("pathfinder").is_empty() and state._save_data() == snapshot, "cargo is never silently discarded")
	var crew_state := GameState.new()
	crew_state.credits = 100000
	assert(crew_state.refit_hull_family("merchant").is_empty())
	assert(crew_state.add_module("habitat",Vector3i(-2,0,-1)).is_empty())
	for i in 7: assert(crew_state.hire("engineer").is_empty())
	var crew_snapshot := crew_state._save_data().duplicate(true)
	assert(not crew_state.refit_hull_family("pathfinder").is_empty() and crew_state._save_data() == crew_snapshot, "crew cannot be discarded to fit a smaller hull")
	var refund_state := GameState.new()
	refund_state.credits = 100000
	assert(refund_state.refit_hull_family("merchant").is_empty())
	for z in range(4,9): assert(refund_state.add_module("reactor",Vector3i(0,0,z)).is_empty())
	assert(refund_state.repair().is_empty())
	var refund_quote := refund_state.hull_family_quote("pathfinder")
	assert(refund_quote.net < 0, "valuable trade-in can produce an explicit refund")
	var refund_cash := refund_state.credits
	assert(refund_state.refit_hull_family("pathfinder").is_empty())
	assert(refund_state.credits == refund_cash - refund_quote.net)
	var path := "user://hull-family-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty())
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty())
	assert(restored.ship_modules == state.ship_modules and restored.ship_layout == state.ship_layout)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.pilot.set_physics_process(false)
	game._clear_actors()
	game.save_path = path
	game.state.credits = 100000
	var original: Array = game.state.ship_modules.duplicate(true)
	game.pilot.flying = true
	assert(not game.refit_hull_family("pathfinder").is_empty())
	game.pilot.flying = false
	game.aboard = true
	assert(not game.refit_hull_family("pathfinder").is_empty())
	game.aboard = false
	game.session.connected = true
	assert(not game.refit_hull_family("pathfinder").is_empty())
	game.session.connected = false
	assert(game.state.ship_modules == original)
	game.open_menu("hulls")
	var button: Button
	var preview: ShipDesigner
	for child in game.deck.content.get_children():
		if child is Button and child.has_meta("hull_family_refit"): button = child
		if child is ShipDesigner: preview = child
	assert(button != null and not button.disabled and preview != null and preview.read_only)
	if DisplayServer.get_name() != "headless":
		for _frame in 32: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/hull-family-shipyard.png")
	button.pressed.emit()
	await process_frame
	var expected := ShipBlueprint.family("pathfinder")
	assert(game.state.ship_modules == expected.modules and game.state.ship_layout == expected.layout)
	assert(restored.load_save(path).is_empty() and restored.ship_modules == game.state.ship_modules)
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("HULL_FAMILY_REFIT_OK: quote, atomic rejects, preservation, save roundtrip and guarded shipyard action")
	quit()
