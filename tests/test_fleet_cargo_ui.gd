extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")

var game: Node
var save_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	save_path = "user://fleet-cargo-ui-%d.json" % OS.get_process_id()
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
	game.state.cargo.ore = 3
	assert(game.crew_operations().purchase_ship("UI Mule", "").is_empty(), "utility fleet vessel commissions")
	var ship: Dictionary = game.state.fleet_ships.back()
	var ship_id := str(ship.id)
	assert(int(ship.cargo.get("ore", 0)) == 0 and int(ship.capacity) >= 3, "new utility vessel has an empty cargo hold")

	game.deck.show_page("fleet")
	var ship_choice := _control_with_meta(game.deck, "fleet_cargo_ship") as OptionButton
	var good_choice := _control_with_meta(game.deck, "fleet_cargo_good") as OptionButton
	var quantity := _control_with_meta(game.deck, "fleet_cargo_quantity") as SpinBox
	assert(ship_choice != null and good_choice != null and quantity != null, "fleet page exposes cargo ship, good, and quantity controls")
	_select_option(ship_choice, ship_id)
	_select_option(good_choice, "ore")
	quantity.value = 3
	var load_button := _transfer_button(game.deck, true)
	var collect_button := _transfer_button(game.deck, false)
	assert(load_button != null and collect_button != null and not load_button.disabled and not collect_button.disabled, "docked idle fleet cargo actions are enabled")
	load_button.pressed.emit()
	assert(game.state.cargo.ore == 0 and ship.cargo.ore == 3, "load control transfers ore into the fleet hold")
	assert(game.deck.page == "fleet", "successful transfer refreshes the fleet page")
	var summary := _hold_summary(game.deck)
	assert(summary != null and "Ore: your hold 0 / fleet hold 3." in summary.text, "refreshed hold summary shows transferred quantities")

	ship_choice = _control_with_meta(game.deck, "fleet_cargo_ship") as OptionButton
	good_choice = _control_with_meta(game.deck, "fleet_cargo_good") as OptionButton
	quantity = _control_with_meta(game.deck, "fleet_cargo_quantity") as SpinBox
	_select_option(ship_choice, ship_id)
	_select_option(good_choice, "ore")
	quantity.value = 2
	collect_button = _transfer_button(game.deck, false)
	assert(collect_button != null and not collect_button.disabled, "refreshed collect control is enabled")
	collect_button.pressed.emit()
	assert(game.state.cargo.ore == 2 and ship.cargo.ore == 1, "collect control transfers two ore to the personal hold")

	var expected_personal := int(game.state.cargo.ore)
	var expected_fleet := int(ship.cargo.ore)
	assert(game.save_commander(false), "fleet cargo save succeeds")
	var restored := GameStateScript.new()
	assert(restored.load_save(save_path).is_empty(), "fleet cargo reload succeeds")
	assert(restored.cargo.ore == expected_personal and int(restored.fleet_ships.back().cargo.ore) == expected_fleet, "both holds retain their quantities after reload")

	# The UI disables transfers in every blocked scene state; the main API also rejects atomically.
	for guard: String in ["session", "flight", "aboard", "surface", "manual_planet"]:
		_set_guard(guard, true)
		game.deck.show_page("fleet")
		assert(_transfer_button(game.deck, true).disabled and _transfer_button(game.deck, false).disabled, "%s disables both cargo controls" % guard)
		var before: Dictionary = game.state._save_data().duplicate(true)
		assert(not game.transfer_fleet_cargo(ship_id, "ore", 1, true).is_empty(), "%s main-scene guard rejects transfer" % guard)
		assert(game.state._save_data() == before, "%s rejection leaves saved state unchanged" % guard)
		_set_guard(guard, false)

	game.deck.show_page("fleet")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(game.get_viewport().get_texture().get_image().save_png("user://fleet-cargo-transfer.png") == OK)

	_cleanup()
	game.sound.shutdown()
	game.session.leave()
	game.queue_free()
	await process_frame
	print("FLEET_CARGO_UI_OK: transfer controls, refreshed hold totals, guards, persistence")
	quit()


func _control_with_meta(parent: Node, key: String) -> Node:
	for node: Node in parent.find_children("*", "Control", true, false):
		if node.has_meta(key) and bool(node.get_meta(key)):
			return node
	return null


func _transfer_button(parent: Node, to_fleet: bool) -> Button:
	for node: Node in parent.find_children("*", "Button", true, false):
		if node.has_meta("fleet_cargo_direction") and bool(node.get_meta("fleet_cargo_direction")) == to_fleet:
			return node as Button
	return null


func _hold_summary(parent: Node) -> Label:
	for node: Node in parent.find_children("*", "Label", true, false):
		if node is Label and "your hold" in (node as Label).text and "fleet hold" in (node as Label).text:
			return node as Label
	return null


func _select_option(choice: OptionButton, metadata: String) -> void:
	for index: int in range(choice.item_count):
		if str(choice.get_item_metadata(index)) == metadata:
			choice.select(index)
			choice.item_selected.emit(index)
			return
	assert(false, "option exists: " + metadata)


func _set_guard(guard: String, blocked: bool) -> void:
	match guard:
		"session": game.session.connected = blocked
		"flight": game.pilot.flying = blocked
		"aboard": game.aboard = blocked
		"surface": game.surface_index = 0 if blocked else -1
		"manual_planet": game.manual_planet = 0 if blocked else -1


func _cleanup() -> void:
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	push_error("FLEET_CARGO_UI_FAILED: " + message)
	quit(1)
