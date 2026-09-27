extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

var game: Node
var path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	path = "user://fleet-boarding-%d.json" % OS.get_process_id()
	game.save_path = path
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.close_menu()
	game._clear_actors()
	path = "user://fleet-boarding-%d.json" % OS.get_process_id()
	game.save_path = path
	game.state.credits = 50000
	assert(game.state.hire("trader").is_empty())
	var orders: CrewOrders = game.crew_operations()
	assert(orders.purchase_ship("Boarding Merchant", "merchant").is_empty())
	var ship: Dictionary = game.state.fleet_ships.back()
	var ship_id := str(ship.id)
	var crew_id := str(game.state.crew[0].id)
	var original_modules: Array = game.state.ship_modules.duplicate(true)
	var original_layout: Dictionary = game.state.ship_layout.duplicate(true)
	var original_cargo: Dictionary = game.state.cargo.duplicate(true)
	var blueprint: Dictionary = ShipBlueprint.family("merchant")
	var return_position: Vector3 = game.pilot.position
	var return_view := Vector3(game.pilot.camera.rotation.x, game.pilot.rotation.y, game.pilot.camera.rotation.z)
	assert(game.fleet_boarding_issue(ship_id).is_empty(), "local idle family ship can be boarded")
	game.deck.show_page("fleet")
	var inspect_button: Button
	for button: Node in game.deck.find_children("*", "Button", true, false):
		if button.text == "INSPECT DOCKED INTERIOR": inspect_button = button
	assert(inspect_button != null and not inspect_button.disabled)
	inspect_button.pressed.emit()
	assert(game.aboard_fleet_id == ship_id and game.aboard and game.interior != null, "boarded ship interior becomes active")
	assert(game.interior.modules == blueprint.modules, "fleet interior uses commissioned family modules")
	assert(game.interior._layout.rooms == blueprint.layout.rooms, "fleet interior preserves blueprint room layout")
	assert(game.state.ship_modules == original_modules and game.state.ship_layout == original_layout and game.state.cargo == original_cargo,
		"fleet boarding preserves player ship blueprint, layout, and cargo")
	await create_timer(0.4).timeout
	assert(game.pilot.is_on_floor(), "player stands on fleet interior floor after physics")
	var start: Vector3 = game.interior.to_local(game.pilot.position)
	Input.action_press("move_forward")
	await create_timer(0.4).timeout
	Input.action_release("move_forward")
	assert(game.interior.to_local(game.pilot.position).z > start.z + 1.0, "entry faces the corridor and supports walking through its doorway")
	var occupied: CrewOrders = game.crew_operations()
	assert(str(occupied.occupied_ship_id) == ship_id, "crew operations locks occupied fleet ship")
	var fleet_before: Dictionary = ship.duplicate(true)
	var orders_before: Dictionary = game.state.crew_orders.duplicate(true)
	var credits_before: int = game.state.credits
	assert(not occupied.assign_trade_route(crew_id, ship_id, "ore", (game.state.system_index + 1) % GameStateScript.SYSTEM_LIMIT).is_empty(),
		"trade dispatch rejects occupied fleet ship")
	assert(ship == fleet_before and game.state.crew_orders == orders_before and game.state.credits == credits_before,
		"rejected dispatch leaves fleet, orders, and credits unchanged")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("user://fleet-interior.png") == OK)
	game.exit_interior()
	assert(game.aboard_fleet_id.is_empty() and not game.aboard and str(game.crew_operations().occupied_ship_id).is_empty(),
		"exit clears boarding state and fleet lock")
	assert(game.pilot.position.distance_to(return_position) < 0.1 and Vector3(game.pilot.camera.rotation.x, game.pilot.rotation.y, game.pilot.camera.rotation.z).distance_to(return_view) < 0.01,
		"exit restores concourse position and view")
	assert(game.crew_operations().assign_trade_route(crew_id, ship_id, "ore", (game.state.system_index + 1) % GameStateScript.SYSTEM_LIMIT).is_empty(),
		"fleet ship accepts trade route after exit")
	assert(game.crew_operations().cancel(crew_id).is_empty())

	# Invalid and unavailable ships must fail before creating an interior.
	assert(not game.fleet_boarding_issue("missing-fleet-id").is_empty(), "missing fleet ship rejected")
	var original_system: int = int(ship.system)
	ship.system = (game.state.system_index + 1) % GameStateScript.SYSTEM_LIMIT
	assert(not game.fleet_boarding_issue(ship_id).is_empty(), "remote fleet ship rejected")
	ship.system = original_system
	var original_hull: float = float(ship.hull)
	ship.hull = 0
	assert(not game.fleet_boarding_issue(ship_id).is_empty(), "destroyed fleet ship rejected")
	ship.hull = original_hull
	var original_family: String = str(ship.hull_family)
	ship.hull_family = "invalid-family"
	assert(not game.fleet_boarding_issue(ship_id).is_empty(), "invalid family rejected")
	ship.hull_family = original_family
	var legacy_family: Variant = ship.get("hull_family", null)
	ship.erase("hull_family")
	assert(not game.fleet_boarding_issue(ship_id).is_empty(), "legacy hull without family rejected")
	if legacy_family != null: ship.hull_family = legacy_family
	assert(orders.assign_trade_route(crew_id, ship_id, "ore", (game.state.system_index + 1) % GameStateScript.SYSTEM_LIMIT).is_empty())
	assert(not game.fleet_boarding_issue(ship_id).is_empty(), "fleet ship with crew order rejected")
	assert(orders.cancel(crew_id).is_empty())

	assert(not game.fleet_boarding_issue("").is_empty(), "player ship boarding requires existing eligible family fleet id")
	game.pilot.set_flight(true)
	assert(not game.fleet_boarding_issue(ship_id).is_empty(), "flight boarding rejected")
	game.pilot.set_flight(false)
	game.surface_index = 0
	assert(not game.fleet_boarding_issue(ship_id).is_empty(), "surface boarding rejected")
	game.surface_index = -1
	game.manual_planet = 0
	assert(not game.fleet_boarding_issue(ship_id).is_empty(), "manual planet boarding rejected")
	game.manual_planet = -1
	game.session.connected = true
	assert(not game.fleet_boarding_issue(ship_id).is_empty(), "connected session boarding rejected")
	game.session.connected = false
	assert(not game.aboard and game.interior == null, "every rejected boarding attempt leaves player outside")

	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	for file_path: String in [path, path + ".bak"]:
		if FileAccess.file_exists(file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	print("FLEET_BOARDING_OK: family interior, crew lock, state preservation, guards, and exit")
	quit()
