extends Node3D

var state: GameState
var pilot: Pilot
var world: SpaceWorld
var actors: Array[Node3D] = []
var ship_display: ShipVisual
var owned_root: Node3D
var hud: FlightHUD
var deck: CommandDeck
var sound: Soundscape
var session: NetworkSession
var remote_ships: Dictionary = {}
var home_state: GameState
var home_save_path: String = ""
var interior: ShipInterior
var aboard: bool = false
var interior_deck: int = 0
var return_position := Vector3.ZERO
var return_flying: bool = false
var ui_open: bool = true
var surface_index: int = -1
var jump_charge: float = 0.0
var jump_destination: int = 0
var suit_health: float = 100.0
var autosave_clock: float = 0.0
var shield_delay: float = 0.0
var automation: bool = false
var save_path: String = "user://commander.json"
var enemy_clock: float = 0.0
var _last_stats: Dictionary = {}
var _network_clock: float = 0.0

func _ready() -> void:
	automation = "--smoke" in OS.get_cmdline_user_args() or "--visual-tour" in OS.get_cmdline_user_args() or "--capture-only" in OS.get_cmdline_user_args()
	if automation: save_path = "user://integration_commander-%d.json" % OS.get_process_id()
	_input_actions()
	state = GameState.new()
	if not automation and FileAccess.file_exists(save_path):
		var error: String = state.load_save(save_path)
		if not error.is_empty(): push_warning(error)
	world = SpaceWorld.new()
	add_child(world)
	pilot = Pilot.new()
	add_child(pilot)
	pilot.fired.connect(_player_fire)
	pilot.autopilot_arrived.connect(func(): notify("Cruise approach complete. Manual control restored."))
	sound = Soundscape.new()
	sound.muted = automation
	add_child(sound)
	_load_settings()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = FlightHUD.new()
	hud.game = self
	canvas.add_child(hud)
	deck = CommandDeck.new()
	deck.game = self
	canvas.add_child(deck)
	session = NetworkSession.new()
	session.system_index = state.system_index
	session.ship_modules = state.ship_modules.duplicate(true)
	add_child(session)
	session.world_joined.connect(_visit_host)
	session.peers_changed.connect(_sync_visitors)
	session.session_message.connect(notify)
	_build_system()
	apply_ship_stats()
	deck.show_page("overview")
	if automation and "--capture-only" not in OS.get_cmdline_user_args(): _integration_check.call_deferred()

func _input_actions() -> void:
	var keys: Dictionary = {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_SPACE, "move_down": KEY_CTRL, "boost": KEY_SHIFT, "roll_left": KEY_Q, "roll_right": KEY_R}
	for action: String in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	if not InputMap.has_action("fire"): InputMap.add_action("fire")
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", button)

func _build_system() -> void:
	if aboard: exit_interior()
	_clear_actors()
	surface_index = -1
	world.build(state.system_index)
	pilot.set_flight(false)
	pilot.teleport(world.spawn_position)
	pilot.reset_view()
	_spawn_actors()
	rebuild_player_ship()
	rebuild_owned_stations()

func _clear_actors() -> void:
	for actor in actors:
		if is_instance_valid(actor):
			actor.active = false
			remove_child(actor)
			actor.queue_free()
	actors.clear()

func _location_key() -> String:
	return "%d:%d" % [state.system_index, surface_index]

func _spawn_actors() -> void:
	var eliminated: Array = state.world_flags.get(_location_key(), [])
	if surface_index < 0:
		for i in range(5):
			var id: String = "raider_%d" % i
			if id in eliminated: continue
			var actor := ShipActor.new()
			actor.actor_id = id
			actor.faction = "pirate"
			actor.position = Vector3(-300 + i * 170, 90 + i * 35, -950 - i * 300)
			actor.target = pilot
			actor.destroyed.connect(_actor_destroyed)
			actor.fired.connect(_enemy_fire)
			add_child(actor)
			actors.append(actor)
		for i in range(2):
			var actor := ShipActor.new()
			actor.actor_id = "security_%d" % i
			if actor.actor_id in eliminated:
				actor.free()
				continue
			actor.faction = "police"
			actor.hostile = state.wanted > 0
			actor.target = pilot
			actor.position = Vector3(-230 + i * 460, 45, -400)
			actor.destroyed.connect(_actor_destroyed)
			actor.fired.connect(_enemy_fire)
			add_child(actor)
			actors.append(actor)
	_spawn_people(eliminated)

func _spawn_people(eliminated: Array) -> void:
	var roles: Array[String] = ["Shipwright", "Broker", "Recruiter", "Security"]
	for i in range(4):
		var person := GroundActor.new()
		person.actor_id = "resident_%d" % i
		if person.actor_id in eliminated:
			person.free()
			continue
		person.faction = "police" if i == 3 else "civilian"
		person.hostile = false
		person.role = roles[i]
		person.display_name = ["Mara Voss", "Niko Vale", "Sera Kade", "Marshal Ren"][i]
		person.position = Vector3(-24 + i * 16, 3, 6 if surface_index < 0 else -36)
		person.target = pilot
		person.set_meta("service", ["shipyard", "market", "company", "factions"][i])
		person.destroyed.connect(_actor_destroyed)
		person.fired.connect(_enemy_fire)
		add_child(person)
		actors.append(person)
	if surface_index >= 0:
		for i in range(5):
			var person := GroundActor.new()
			person.actor_id = "outlaw_%d" % i
			if person.actor_id in eliminated:
				person.free()
				continue
			person.faction = "pirate"
			person.hostile = true
			person.position = Vector3(-55 + i * 25, 4, -90)
			person.target = pilot
			person.destroyed.connect(_actor_destroyed)
			person.fired.connect(_enemy_fire)
			add_child(person)
			actors.append(person)

func rebuild_player_ship() -> void:
	if is_instance_valid(ship_display):
		remove_child(ship_display)
		ship_display.queue_free()
	ship_display = ShipVisual.new()
	add_child(ship_display)
	ship_display.build(state.ship_modules, "player")
	var low := Vector3(16, 16, 16)
	var high := Vector3(-16, -16, -16)
	for module: Dictionary in state.ship_modules:
		var cell := Vector3(module.x, module.y, module.z)
		low = low.min(cell)
		high = high.max(cell)
	var center := (low + high) * 0.5 * ShipVisual.CELL_SIZE
	var bottom := (high.y - low.y) * 0.5 * ShipVisual.CELL_SIZE + 1.28
	ship_display.position = Vector3(0, bottom + 0.7, -22)
	for module: Dictionary in state.ship_modules:
		if float(module.y) != low.y: continue
		var cell := Vector3(module.x, module.y, module.z) * ShipVisual.CELL_SIZE - center
		for side in [-1.0, 1.0]:
			_box(ship_display, cell + Vector3(side * 0.9, -1.58, 0), Vector3(0.12, 0.6, 0.15), Color("a6acaf"))
			_box(ship_display, cell + Vector3(side * 0.9, -1.9, 0), Vector3(0.4, 0.16, 1.9), Color("252b30"))
	ship_display.visible = not pilot.flying

func apply_ship_stats() -> void:
	_last_stats = state.ship_stats()
	pilot.flight_speed = float(_last_stats.speed)
	state.hull = minf(state.hull, float(_last_stats.max_hull))
	state.shield = minf(state.shield, float(_last_stats.max_shield))
	if session != null: session.ship_modules = state.ship_modules.duplicate(true)

func rebuild_owned_stations() -> void:
	if is_instance_valid(owned_root):
		remove_child(owned_root)
		owned_root.queue_free()
	owned_root = Node3D.new()
	add_child(owned_root)
	if surface_index >= 0: return
	var count: int = 0
	for station: Dictionary in state.stations:
		if int(station.get("system", station.get("system_index", -1))) != state.system_index: continue
		var base := Node3D.new()
		owned_root.add_child(base)
		base.position = Vector3(600 + count * 450, 60, -500)
		var level: int = int(station.level)
		for ring_index in range(level):
			var ring := MeshInstance3D.new()
			var mesh := TorusMesh.new()
			mesh.inner_radius = 44
			mesh.outer_radius = 50
			ring.mesh = mesh
			ring.rotation.x = PI / 2
			ring.position.z = ring_index * 18
			ring.material_override = _material(Color("405967"), false)
			base.add_child(ring)
		_box(base, Vector3.ZERO, Vector3(12, 12, 120), Color("264453"))
		for i in range(8):
			var angle: float = i * TAU / 8
			_box(base, Vector3(cos(angle) * 45, sin(angle) * 45, 0), Vector3(8, 8, 24), Color("75d7d0"))
		var label := Label3D.new()
		label.text = str(station.name).to_upper() + "\nOWNED OUTPOST  /  LEVEL " + str(level)
		label.position.y = 65
		label.font_size = 48
		label.pixel_size = 0.05
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		base.add_child(label)
		count += 1

func _material(color: Color, unshaded: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.65
	material.roughness = 0.36
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2
	return material

func _box(parent: Node3D, position: Vector3, size: Vector3, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color, unshaded)
	parent.add_child(mesh)
	mesh.position = position
	return mesh

func _beam(origin: Vector3, end: Vector3, color: Color) -> void:
	var distance: float = origin.distance_to(end)
	if distance < 0.01: return
	var beam := _box(self, (origin + end) * 0.5, Vector3(0.06, 0.06, distance), color, true)
	var direction: Vector3 = (end - origin).normalized()
	beam.look_at(end, Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP)
	var tween := create_tween()
	tween.tween_property(beam, "scale:x", 0.01, 0.1)
	tween.tween_callback(beam.queue_free)

func _ray(origin: Vector3, direction: Vector3, distance: float, exclude: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * distance, 7, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _player_fire(origin: Vector3, direction: Vector3) -> void:
	if ui_open or jump_charge > 0: return
	sound.play_sound("shot")
	var distance: float = 2200 if pilot.flying else 150
	var hit: Dictionary = _ray(origin, direction, distance, [pilot.get_rid()])
	var endpoint: Vector3 = hit.get("position", origin + direction * distance)
	_beam(origin + pilot.camera.global_basis.x * 0.18 - pilot.camera.global_basis.y * 0.12, endpoint, Color("75f6e7"))
	if not hit.is_empty():
		var victim: Object = hit.collider
		if victim.has_method("take_damage"):
			if victim.faction != "pirate" and not victim.get_meta("assault_reported", false):
				state.wanted += 1
				victim.set_meta("assault_reported", true)
				notify("Assault reported. Security alert increased.")
			victim.set_meta("player_hit", true)
			victim.take_damage(float(_last_stats.damage) if pilot.flying else 34.0)

func _enemy_fire(actor: Node3D, origin: Vector3, direction: Vector3) -> void:
	if ui_open or jump_charge > 0: return
	var hit: Dictionary = _ray(origin, direction, 2400 if actor is ShipActor else 120, [actor.get_rid()])
	var endpoint: Vector3 = hit.get("position", origin + direction * 180)
	_beam(origin, endpoint, Color("ff9673"))
	if hit.get("collider") == pilot:
		var damage: float = 9 if actor is ShipActor else 12
		shield_delay = 6
		if pilot.flying:
			var absorbed: float = minf(state.shield, damage)
			state.shield -= absorbed
			state.hull -= damage - absorbed
		else: suit_health -= damage
		pilot.kick(0.5)
		hud.flash = 0.5
		if state.hull <= 0 or suit_health <= 0: _rescue()

func _actor_destroyed(actor: Node3D) -> void:
	var eliminated: Array = state.world_flags.get(_location_key(), [])
	if actor.actor_id not in eliminated: eliminated.append(actor.actor_id)
	state.world_flags[_location_key()] = eliminated
	if actor.get_meta("player_hit", false):
		state.record_kill(actor.faction)
		notify("Pirate neutralized. Bounty credited." if actor.faction == "pirate" else "Civilian/security casualty recorded. Wanted status updated.")
	_explosion(actor.global_position, 8 if actor is ShipActor else 1.5)
	actors.erase(actor)

func _explosion(position: Vector3, radius: float) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	mesh.mesh = sphere
	mesh.material_override = _material(Color("ffb75f"), true)
	add_child(mesh)
	mesh.position = position
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ONE * 3.0, 0.15)
	tween.tween_property(mesh, "scale", Vector3.ONE * 0.01, 0.25)
	tween.tween_callback(mesh.queue_free)

func _rescue() -> void:
	state.hull = float(_last_stats.max_hull)
	state.shield = float(_last_stats.max_shield)
	suit_health = 100
	state.credits = maxi(0, state.credits - 1000)
	_build_system()
	close_menu()
	notify("Rescue completed. Recovery fee: up to 1,000 CR.")

func interaction_hint() -> String:
	if aboard: return "Return to helm  /  PgUp/PgDn change deck"
	if surface_index >= 0: return "Board ship / return to orbit" if _near_person() == null else "Talk to " + _near_person().display_name
	var person: Node3D = _near_person()
	if person != null: return "Talk to " + person.display_name
	return "Board ship" if pilot.position.distance_to(Vector3(0, 2, -22)) < 20 else "Approach your ship or a service officer"

func _near_person() -> Node3D:
	for actor in actors:
		if actor is GroundActor and actor.has_meta("service") and actor.position.distance_to(pilot.position) < 6: return actor
	return null

func _interact() -> void:
	if aboard:
		exit_interior()
		return
	if jump_charge > 0: return
	if pilot.flying:
		if pilot.position.distance_to(world.launch_position) > 250:
			notify("Approach the orbital dock to within 250 m.")
			return
		pilot.set_flight(false)
		pilot.teleport(world.spawn_position)
		pilot.reset_view()
		rebuild_player_ship()
		save_commander(false)
		notify("Docking complete. Welcome aboard.")
		return
	var person: Node3D = _near_person()
	if person != null:
		open_menu(str(person.get_meta("service")))
		return
	if pilot.position.distance_to(Vector3(0, 2, -22)) > 20:
		notify("Approach your ship on the landing pad to board.")
		return
	if surface_index >= 0:
		_build_system()
	pilot.set_flight(true)
	pilot.teleport(world.launch_position)
	pilot.reset_view()
	ship_display.hide()
	notify("Docking clamps released. Flight assist online.")

func request_jump(destination: int) -> void:
	if aboard:
		notify("Return to the helm before engaging hyperdrive.")
		return
	if session.connected and not session.is_host:
		notify("The world host controls interstellar travel during a visit.")
		return
	if not pilot.flying:
		notify("Board your ship before engaging hyperdrive.")
		return
	if destination == state.system_index:
		notify("You are already in this system.")
		return
	if destination < 0 or destination >= Universe.SYSTEM_LIMIT:
		notify("Invalid system address.")
		return
	jump_destination = destination
	jump_charge = 3.0
	close_menu()
	pilot.enabled = false
	sound.play_sound("jump")

func _complete_jump() -> void:
	var error: String = state.jump(jump_destination)
	if not error.is_empty():
		notify(error)
		pilot.enabled = true
		return
	_build_system()
	pilot.set_flight(true)
	pilot.teleport(world.launch_position)
	ship_display.hide()
	apply_ship_stats()
	close_menu()
	if session.connected and session.is_host: session.travel(state.system_index)
	save_commander(false)
	notify("Frame shift complete. Welcome to %s." % world.data.name)

func land(planet_index: int) -> void:
	if not pilot.flying or surface_index >= 0 or planet_index < 0 or planet_index >= world.planets.size():
		notify("Launch into orbit before requesting a surface approach.")
		return
	if session.connected:
		notify("Surface excursions require leaving the current multiplayer visit.")
		return
	_clear_actors()
	surface_index = planet_index
	world.build_surface(planet_index)
	pilot.set_flight(false)
	pilot.teleport(world.spawn_position)
	pilot.reset_view()
	suit_health = 100
	_spawn_actors()
	rebuild_player_ship()
	rebuild_owned_stations()
	close_menu()
	save_commander(false)
	notify("Landing complete. Explore the colony; return to your ship to depart.")

func pay_fines() -> void:
	var cost: int = state.wanted * 750
	if pilot.flying or aboard or state.wanted <= 0:
		notify("Dock at a station to settle your fines.")
	elif state.credits < cost: notify("Outstanding fine: %d CR." % cost)
	else:
		state.credits -= cost
		state.wanted = 0
		save_commander(false)
		deck.refresh()
		notify("Fines paid. Wanted status cleared.")

func location_title() -> String:
	if aboard: return "Ship interior / deck %d" % interior_deck
	if surface_index >= 0 and surface_index < world.planets.size(): return str(world.planets[surface_index].name) + " colony"
	return "Free flight" if pilot.flying else "Orbital concourse"

func notify(message: String) -> void:
	if hud != null: hud.notify(message)
	if deck != null and ui_open: deck.note(message)

func open_menu(page: String = "overview") -> void:
	if jump_charge <= 0: deck.show_page(page)

func close_menu() -> void:
	deck.hide()
	ui_open = false
	pilot.enabled = jump_charge <= 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_TAB, KEY_ESCAPE:
			if jump_charge > 0:
				jump_charge = 0
				pilot.enabled = true
				notify("Hyperdrive charge cancelled.")
			elif ui_open: close_menu()
			else: open_menu()
		KEY_PAGEUP, KEY_PAGEDOWN:
			if aboard and not ui_open:
				var index: int = interior.decks.find(interior_deck)
				index = clampi(index + (1 if event.keycode == KEY_PAGEUP else -1), 0, interior.decks.size() - 1)
				interior_deck = interior.decks[index]
				pilot.teleport(interior.spawn_on_deck(interior_deck))
				notify("Lift arrived at deck %d." % interior_deck)
		KEY_E:
			if not ui_open: _interact()
		KEY_J: open_menu("navigation")
		KEY_F5: save_commander(true)
		KEY_F9: load_commander()

func _process(delta: float) -> void:
	if pilot == null or state == null: return
	if home_state != null and not session.connected: _return_home()
	for actor in actors:
		if not is_instance_valid(actor): continue
		actor.active = not ui_open and jump_charge <= 0 and not aboard
		if actor.faction == "police": actor.hostile = state.wanted > 0
	if jump_charge > 0:
		jump_charge = maxf(0, jump_charge - delta)
		if jump_charge == 0: _complete_jump()
	if not ui_open and jump_charge <= 0:
		shield_delay -= delta
		if shield_delay <= 0: state.shield = minf(float(_last_stats.get("max_shield", 100)), state.shield + delta * 5)
		if pilot.position.y < -150 and not pilot.flying: pilot.teleport(world.spawn_position)
		if pilot.position.length() > 28000:
			pilot.teleport(world.launch_position)
			notify("Leaving local flight space. Plot a hyperdrive course to continue.")
		autosave_clock += delta
		if autosave_clock > 60 and not automation:
			autosave_clock = 0
			save_commander(false)
	sound.flight(pilot.velocity.length() / maxf(pilot.flight_speed, 1), pilot.flying)
	_network_clock += delta
	if session != null and session.connected and _network_clock > 0.05:
		_network_clock = 0
		session.publish_pose(pilot.position, pilot.rotation)
		_update_remote_positions()

func save_commander(show_message: bool = true) -> bool:
	var error: String = state.save(save_path)
	if not error.is_empty():
		notify(error)
		return false
	if home_state != null:
		_copy_carried_ship(state, home_state)
		var home_error: String = home_state.save(home_save_path)
		if not home_error.is_empty():
			notify("Visit saved, but home ship could not be saved: " + home_error)
			return false
	if show_message: notify("Commander, ship, enterprise and world changes saved locally.")
	return true

func load_commander() -> void:
	if session.connected:
		notify("Leave the multiplayer visit before loading a commander.")
		return
	var error: String = state.load_save(save_path)
	if not error.is_empty():
		notify(error)
		return
	_build_system()
	apply_ship_stats()
	open_menu()
	notify("Commander restored at the saved system's orbital station.")

func quit_game() -> void:
	if home_state != null:
		session.leave()
		_return_home()
	if save_commander(false):
		session.leave()
		sound.shutdown()
		await get_tree().process_frame
		get_tree().quit()

func save_settings() -> void:
	if automation: return
	var config := ConfigFile.new()
	config.set_value("controls", "sensitivity", pilot.mouse_sensitivity)
	config.set_value("controls", "invert_y", pilot.inverted_y)
	config.save("user://settings.cfg")

func _load_settings() -> void:
	if automation: return
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		pilot.mouse_sensitivity = clampf(float(config.get_value("controls", "sensitivity", 0.0025)), 0.0005, 0.006)
		pilot.inverted_y = bool(config.get_value("controls", "invert_y", false))

func _visit_host(index: int) -> void:
	if session.is_host: return
	if home_state == null:
		if not save_commander(false):
			session.leave()
			return
		var visitor := GameState.new()
		DirAccess.make_dir_recursive_absolute("user://visits")
		var visitor_path: String = "user://visits/" + session.world_id + ".json"
		if FileAccess.file_exists(visitor_path):
			var error: String = visitor.load_save(visitor_path)
			if not error.is_empty():
				session.leave()
				notify("Visitor profile could not load: " + error)
				return
		home_state = state
		home_save_path = save_path
		visitor.ship_modules = state.ship_modules.duplicate(true)
		visitor.cargo = state.cargo.duplicate(true)
		visitor.hull = state.hull
		visitor.shield = state.shield
		visitor.fuel = state.fuel
		visitor.world_id = session.world_id
		state = visitor
		save_path = visitor_path
	state.system_index = index
	if index not in state.visited: state.visited.append(index)
	while state.visited.size() > GameState.MAX_ITEMS: state.visited.pop_front()
	_build_system()
	pilot.set_flight(true)
	pilot.teleport(world.launch_position + Vector3(25, 0, 0))
	ship_display.hide()
	close_menu()
	notify("Arrived in the host's system with your ship.")

func _sync_visitors() -> void:
	# Transform presence is independent of local commander economics.
	for peer_id: int in remote_ships.keys():
		if not session.presence.has(peer_id):
			remote_ships[peer_id].queue_free()
			remote_ships.erase(peer_id)
	for peer_id: int in session.presence:
		if peer_id == multiplayer.get_unique_id() or remote_ships.has(peer_id): continue
		var visual := ShipVisual.new()
		add_child(visual)
		visual.build(session.presence[peer_id].ship_modules, "player")
		remote_ships[peer_id] = visual

func _update_remote_positions() -> void:
	for peer_id: int in remote_ships:
		if session.presence.has(peer_id):
			var player: Dictionary = session.presence[peer_id]
			remote_ships[peer_id].position = player.position
			remote_ships[peer_id].rotation = player.rotation

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("INTEGRATION FAILED: " + message)
		get_tree().quit(1)
	return condition

func _integration_check() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	if not _check(world.planets.size() > 0, "home system planets"): return
	if not _check(state.trade("food", 1, true).is_empty(), "commodity buy"): return
	if not _check(state.trade("food", 1, false).is_empty(), "commodity sell"): return
	var before: int = state.credits
	if not _check(state.trade_stock(str(GameState.COMPANIES.keys()[0]), 1, true).is_empty(), "stock buy"): return
	if not _check(state.credits < before, "share debit"): return
	var module_error: String = state.add_module("cargo", Vector3i(1, 0, 0))
	# Starter layout may already occupy this cell; a legal adjacent cell is found below.
	if not module_error.is_empty():
		for item: Dictionary in state.ship_modules.duplicate(true):
			var cell := Vector3i(int(item.x), int(item.y) + 1, int(item.z))
			module_error = state.add_module("cargo", cell)
			if module_error.is_empty(): break
	if not _check(module_error.is_empty(), "connected module build"): return
	apply_ship_stats()
	rebuild_player_ship()
	close_menu()
	pilot.set_flight(true)
	pilot.teleport(Vector3(0, 100, -700))
	ship_display.hide()
	var victim: ShipActor = null
	for actor in actors:
		if actor is ShipActor and actor.faction == "pirate":
			victim = actor
			break
	if not _check(victim != null, "pirate AI spawned"): return
	var victim_id: String = victim.actor_id
	victim.active = true
	victim.set_meta("player_hit", true)
	victim.take_damage(10000)
	if not _check(victim_id in state.world_flags.get(_location_key(), []), "persistent kill state"): return
	if not _check(save_commander(false), "save commander"): return
	var restored := GameState.new()
	if not _check(restored.load_save(save_path).is_empty(), "load commander"): return
	if not _check(restored.world_flags == state.world_flags, "world flags round trip"): return
	var error: String = state.jump(7919)
	if not _check(error.is_empty(), "hyperdrive travel: " + error): return
	_build_system()
	pilot.set_flight(true)
	pilot.teleport(world.launch_position)
	ship_display.hide()
	if not _check(state.system_index == 7919, "hyperdrive destination"): return
	open_menu("overview")
	await _capture("command")
	close_menu()
	pilot.set_flight(false)
	pilot.teleport(Vector3(12, 2, 26))
	pilot.reset_view()
	ship_display.show()
	await _capture("hangar")
	pilot.set_flight(true)
	pilot.teleport(Vector3(0, 80, -250))
	pilot.reset_view()
	ship_display.hide()
	await _capture("flight")
	open_menu("shipyard")
	await _capture("shipyard")
	close_menu()
	if world.planets.is_empty():
		state.jump(0)
		_build_system()
		pilot.set_flight(true)
	land(0)
	await get_tree().physics_frame
	if not _check(surface_index == 0 and not pilot.flying, "surface landing"): return
	await _capture("colony")
	var habitat_error: String = state.add_module("habitat", Vector3i(0, 0, 3))
	if not _check(habitat_error.is_empty(), "habitat construction"): return
	apply_ship_stats()
	enter_interior()
	if not _check(aboard and interior != null, "walkable ship interior"): return
	await get_tree().create_timer(0.3).timeout
	if not _check(pilot.position.y > 5999, "interior floor collision"): return
	var interior_start: Vector3 = pilot.position
	Input.action_press("move_forward")
	await get_tree().create_timer(0.45).timeout
	Input.action_release("move_forward")
	if not _check(pilot.position.z < interior_start.z - 1.0, "walk through connected interior doorway"): return
	await _capture("interior")
	exit_interior()
	if not _check(not aboard and not pilot.flying, "return from interior"): return
	var money_before_menu: int = state.credits
	for menu_page in ["overview", "navigation", "market", "shipyard", "contracts", "company", "factions", "stations", "settings"]:
		open_menu(menu_page)
		await get_tree().process_frame
	if not _check(state.credits == money_before_menu, "menu browsing must not change finances"): return
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".bak")
	await get_tree().create_timer(0.5).timeout
	print("NEXT_INTEGRATION_OK: trading, stock, construction, persistent combat, save/load, hyperdrive, landing, walkable interior, menu safety")
	sound.shutdown()
	await get_tree().process_frame
	get_tree().quit()

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var folder: String = "res://build/" if OS.has_feature("editor") else "user://"
	get_viewport().get_texture().get_image().save_png(folder + name + ".png")

func enter_interior() -> void:
	if aboard:
		close_menu()
		return
	if session.connected:
		notify("Leave the current world visit before boarding the interior.")
		return
	for actor in actors:
		if is_instance_valid(actor) and actor.hostile and actor.position.distance_to(pilot.position) < 1000 and pilot.flying:
			notify("Leave the combat zone before leaving the helm.")
			return
	if not bool(state.ship_stats().get("walkable", false)):
		notify("Install a habitat and at least eight connected modules to support walkable decks.")
		return
	return_position = pilot.position
	return_flying = pilot.flying
	interior = ShipInterior.new()
	add_child(interior)
	interior.position = Vector3(0, 6000, 0)
	interior.build(state.ship_modules)
	aboard = true
	interior_deck = 0 if 0 in interior.decks else interior.decks[0]
	pilot.set_flight(false)
	pilot.teleport(interior.spawn_on_deck(interior_deck))
	pilot.reset_view()
	close_menu()
	notify("Aboard your ship. E returns to helm; PgUp/PgDn use the deck lift.")

func exit_interior() -> void:
	if not aboard: return
	aboard = false
	interior.queue_free()
	interior = null
	pilot.set_flight(return_flying)
	pilot.teleport(return_position)
	pilot.reset_view()
	close_menu()

func _copy_carried_ship(source: GameState, destination: GameState) -> void:
	destination.ship_modules = source.ship_modules.duplicate(true)
	destination.cargo = source.cargo.duplicate(true)
	destination.hull = source.hull
	destination.shield = source.shield
	destination.fuel = source.fuel

func leave_visit() -> void:
	session.leave()
	if home_state != null: _return_home()
	_sync_visitors()

func _return_home() -> void:
	if home_state == null: return
	var saved: bool = save_commander(false)
	_copy_carried_ship(state, home_state)
	state = home_state
	home_state = null
	save_path = home_save_path
	home_save_path = ""
	_build_system()
	apply_ship_stats()
	open_menu()
	notify("Returned home with your ship and cargo. World finances stayed separate." if saved else "Returned home; previous save failed. Save again before quitting.")

func cruise_to(point: Vector3) -> void:
	if not pilot.flying or aboard:
		notify("Launch your ship before engaging cruise autopilot.")
		return
	close_menu()
	pilot.autopilot_to(point)
	notify("Cruise autopilot engaged. Movement or mouse input returns manual control.")

func approach_planet(index: int) -> void:
	if index < 0 or index >= world.planets.size(): return
	var body: Dictionary = world.planets[index]
	var radial: Vector3 = (pilot.position - Vector3(body.position)).normalized()
	cruise_to(Vector3(body.position) + radial * (float(body.visual_radius) + 160.0))
