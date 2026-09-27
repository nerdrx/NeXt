extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const ShipBlueprintScript = preload("res://scripts/ship_blueprint.gd")
const ShipLayoutScript = preload("res://scripts/ship_layout.gd")

var game: Node
var save_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	save_path = "user://fleet-layout-%d.json" % OS.get_process_id()
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
		_fail("unique test save path already exists")
		return
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = save_path
	root.add_child(game)
	await process_frame
	game.save_path = save_path # Main selects its automation save path during _ready().
	game.set_process(false)
	game.close_menu()
	game._clear_actors()
	game.state.credits = 50000
	var orders: CrewOrders = game.crew_operations()
	assert(orders.purchase_ship("Layout Merchant", "merchant").is_empty())
	var ship: Dictionary = game.state.fleet_ships.back()
	var ship_id := str(ship.id)
	var habitat := Vector3i(-1, 0, -1)
	var cockpit := Vector3i(0, 0, -2)
	var credits_before: int = game.state.credits

	assert(game.refit_fleet_layout(ship_id, habitat, "medical").is_empty(), "local idle merchant accepts a compatible room refit")
	assert(game.state.credits == credits_before - ShipLayoutScript.ROOM_REFIT_COST)
	assert(ship.layout.rooms[ShipLayoutScript.cell_key(habitat)] == "medical")
	credits_before = game.state.credits
	assert(game.refit_fleet_layout(ship_id, cockpit, "window", "-z").is_empty(), "exposed cockpit face accepts a window panel")
	assert(game.state.credits == credits_before - int(ShipLayoutScript.PANEL_COSTS.window))
	assert(ship.layout.panels[ShipLayoutScript.cell_key(cockpit)]["-z"] == "window")

	var expected_layout: Dictionary = ship.layout.duplicate(true)
	assert(game.save_commander(false), "fleet layout save succeeds")
	var restored := GameStateScript.new()
	assert(restored.load_save(save_path).is_empty(), "fleet layout reload succeeds")
	assert(_layout_matches(restored.fleet_ships.back().layout, expected_layout), "fleet room and panel refits survive reload exactly")

	var before_ship: Dictionary = ship.duplicate(true)
	credits_before = game.state.credits
	_reject_main_refit(ship, ship_id, habitat, "bridge", "", "incompatible room")
	_reject_main_refit(ship, ship_id, Vector3i(90, 0, 0), "medical", "", "missing cell")
	_reject_main_refit(ship, ship_id, cockpit, "window", "+z", "internal hull face")
	assert(ship == before_ship and game.state.credits == credits_before, "invalid room and panel refits are atomic")

	game.state.credits = 0
	_reject_main_refit(ship, ship_id, habitat, "quarters", "", "unaffordable room")
	assert(ship == before_ship and game.state.credits == 0, "insufficient credits leave fleet layout unchanged")
	game.state.credits = credits_before

	var original_system: int = int(ship.system)
	ship.system = (game.state.system_index + 1) % GameStateScript.SYSTEM_LIMIT
	_reject_main_refit(ship, ship_id, habitat, "quarters", "", "remote vessel")
	ship.system = original_system
	var original_hull: float = float(ship.hull)
	ship.hull = 0.0
	_reject_main_refit(ship, ship_id, habitat, "quarters", "", "disabled vessel")
	ship.hull = original_hull

	# Exercise the actual fleet page and both refit button callbacks.
	game.deck.show_page("fleet")
	var open_layout: Button
	for candidate: Node in game.deck.find_children("*", "Button", true, false):
		if candidate.has_meta("fleet_layout_id") and str(candidate.get_meta("fleet_layout_id")) == ship_id:
			open_layout = candidate
			break
	assert(open_layout != null, "family fleet ship exposes its room and hull refit page")
	open_layout.pressed.emit()
	assert(game.deck.page == "fleet_layout" and game.deck.fleet_room_refit != null and game.deck.fleet_panel_refit != null)
	game.deck.fleet_layout_designer.selected_cell = habitat
	var room_choice: OptionButton = game.deck.fleet_room_refit.get_meta("room_choice")
	_select_option(room_choice, "quarters")
	credits_before = game.state.credits
	game.deck.fleet_room_refit.pressed.emit()
	assert(ship.layout.rooms.get(ShipLayoutScript.cell_key(habitat), ShipLayoutScript.default_room("habitat")) == "quarters", "fleet room button applies selected compatible room")
	assert(game.state.credits == credits_before - ShipLayoutScript.ROOM_REFIT_COST, "fleet room button charges the room cost")
	game.deck.fleet_layout_designer.selected_cell = cockpit
	var face_choice: OptionButton = game.deck.fleet_panel_refit.get_meta("face_choice")
	var panel_choice: OptionButton = game.deck.fleet_panel_refit.get_meta("panel_choice")
	_select_option(face_choice, "-z")
	_select_option(panel_choice, "armored")
	credits_before = game.state.credits
	game.deck.fleet_panel_refit.pressed.emit()
	assert(ship.layout.panels[ShipLayoutScript.cell_key(cockpit)]["-z"] == "armored", "fleet panel button applies selected exposed-face panel")
	assert(game.state.credits == credits_before - int(ShipLayoutScript.PANEL_COSTS.armored), "fleet panel button charges the panel cost")
	game.deck.fleet_layout_designer.selected_cell = Vector3i(-1,0,0)
	var module_choice: OptionButton = game.deck.fleet_module_refit.get_meta("module_choice")
	_select_option(module_choice, "weapon")
	credits_before = game.state.credits
	game.deck.fleet_module_refit.pressed.emit()
	assert(game.state.credits == credits_before - 675 and int(ship.capacity) == 145, "equipment UI replaces cargo with a weapon and charges net price")
	assert(CrewOrders.vessel_combat_stats(ship).damage == 25)
	expected_layout = ship.layout.duplicate(true)
	assert(game.save_commander(false), "UI refits save fleet layout")
	var ui_reload := GameStateScript.new()
	assert(ui_reload.load_save(save_path).is_empty() and _layout_matches(ui_reload.fleet_ships.back().layout, expected_layout), "UI refits survive reload")

	credits_before = game.state.credits
	var occupied_ship_before: Dictionary = ship.duplicate(true)
	game.enter_interior(ship_id)
	assert(game.interior.modules == ship.modules, "boarded ship uses refitted equipment")
	assert(game.aboard_fleet_id == ship_id and _layout_matches(game.interior._layout, expected_layout), "boarded merchant uses its saved layout")
	_reject_main_refit(ship, ship_id, habitat, "medical", "", "occupied vessel")
	assert(orders.refit_layout(ship_id, habitat, "medical").length() > 0, "crew operations also rejects its occupied vessel")
	assert(ship == occupied_ship_before and game.state.credits == credits_before, "occupied refit leaves fleet and credits unchanged")
	game.exit_interior()

	game.deck.show_page("fleet_layout")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(game.get_viewport().get_texture().get_image().save_png("user://fleet-layout.png") == OK)

	var fleet_actor := ShipActor.new()
	fleet_actor.hull_family = "merchant"
	fleet_actor.hull_layout = ship.layout.duplicate(true)
	fleet_actor.hull_modules = ship.modules.duplicate(true)
	fleet_actor.actor_id = "fleet-layout-actor"
	fleet_actor.set_physics_process(false)
	game.add_child(fleet_actor)
	await process_frame
	assert(fleet_actor.weapon_damage == 25.0, "actor uses refitted weapon equipment")
	assert(_layout_matches(fleet_actor.hull_layout, expected_layout) and fleet_actor._visual.get_child_count() > 0, "fleet actor builds from its saved hull layout")
	var baseline := ShipVisual.new()
	var family := ShipBlueprintScript.family("merchant")
	baseline.build(ship.modules, "neutral", family.layout)
	assert(fleet_actor._visual.get_child_count() > baseline.get_child_count(), "saved armor creates additional hull meshes")
	baseline.free()
	fleet_actor.queue_free()
	assert(game.state.hire("gunner").is_empty())
	var gunner_id: String = game.state.crew.back().id
	assert(game.crew_operations().assign_patrol(gunner_id,ship_id,game.state.system_index).is_empty())
	game._sync_fleet_actors()
	assert(game.fleet_actors[ship_id].weapon_damage == 25.0, "main scene spawns the saved equipment loadout")

	var blueprint: Dictionary = ShipBlueprintScript.family("merchant")
	var missing_layout: Dictionary = game.state._save_data().duplicate(true)
	missing_layout.fleet_ships.back().erase("layout")
	missing_layout.fleet_ships.back().erase("modules")
	missing_layout.fleet_ships.back().capacity = int(CrewOrders.commission_quote("merchant").capacity)
	_write_save(missing_layout)
	var backward_compatible := GameStateScript.new()
	assert(backward_compatible.load_save(save_path).is_empty(), "older family fleet record without a layout remains valid")
	assert(not backward_compatible.fleet_ships.back().has("layout"), "missing optional layout uses the family blueprint default")
	assert(blueprint.layout.rooms[ShipLayoutScript.cell_key(habitat)] == "lounge")

	var bad_layout: Dictionary = game.state._save_data().duplicate(true)
	bad_layout.fleet_ships.back().layout.rooms[ShipLayoutScript.cell_key(habitat)] = "bridge"
	var layout_without_family: Dictionary = game.state._save_data().duplicate(true)
	layout_without_family.fleet_ships.back().erase("hull_family")
	layout_without_family.fleet_ships.back().capacity = 25
	var unknown_field: Dictionary = game.state._save_data().duplicate(true)
	unknown_field.fleet_ships.back().unexpected = true
	var missing_field: Dictionary = game.state._save_data().duplicate(true)
	missing_field.fleet_ships.back().erase("name")
	var invalid_saves: Array[Dictionary] = [bad_layout, layout_without_family, unknown_field, missing_field]
	var unchanged := GameStateScript.new()
	unchanged.credits = 4321
	var unchanged_before: Dictionary = unchanged._save_data().duplicate(true)
	for invalid_data: Dictionary in invalid_saves:
		_write_save(invalid_data)
		assert(not unchanged.load_save(save_path).is_empty(), "malformed fleet record or layout is rejected")
		assert(unchanged._save_data() == unchanged_before, "rejected fleet layout save does not mutate loaded state")

	_cleanup()
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	print("FLEET_LAYOUT_OK: room/panel refits, guards, persistence, strict fleet layout validation")
	quit()


func _reject_main_refit(ship: Dictionary, ship_id: String, cell: Vector3i, value: String, face: String, label: String) -> void:
	var ship_before: Dictionary = ship.duplicate(true)
	var credits_before: int = game.state.credits
	assert(not game.refit_fleet_layout(ship_id, cell, value, face).is_empty(), label + " is rejected")
	assert(ship == ship_before and game.state.credits == credits_before, label + " rejection is atomic")


func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	assert(file != null, "test save can be written")
	file.store_string(JSON.stringify(data))
	file.close()


func _layout_matches(actual: Dictionary, expected: Dictionary) -> bool:
	return int(actual.get("version", -1)) == ShipLayoutScript.VERSION and actual.get("rooms", {}) == expected.get("rooms", {}) and actual.get("panels", {}) == expected.get("panels", {})


func _select_option(choice: OptionButton, metadata: String) -> void:
	for index: int in range(choice.item_count):
		if str(choice.get_item_metadata(index)) == metadata:
			choice.select(index)
			return
	assert(false, "option exists: " + metadata)


func _cleanup() -> void:
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	push_error("FLEET_LAYOUT_FAILED: " + message)
	quit(1)
