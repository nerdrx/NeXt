extends Node3D

const SAVE_PATH := "user://commander.json"
const GOODS := ["Food", "Alloys", "Medicine"]
var pilot: Pilot
var sector: Node3D
var system_index: int = 0
var credits: int = 2400
var cargo: Dictionary = {"Food": 0, "Alloys": 0, "Medicine": 0}
var hull: float = 100.0
var modules: int = 0
var kills: int = 0
var hud: Label
var notice: Label
var panel: PanelContainer
var menu_content: VBoxContainer
var targets: Array[Node3D] = []
var attack_clock: float = 0.0
var message_clock: float = 0.0
var system: Dictionary
var automation: bool = false

func _ready() -> void:
	automation = "--smoke" in OS.get_cmdline_user_args()
	_input_actions()
	_environment()
	pilot = Pilot.new()
	add_child(pilot)
	pilot.fired.connect(_shoot)
	_ui()
	_load_game()
	_generate()
	pilot.teleport(Vector3(0, 2, 20))
	_open_menu("welcome")
	if automation:
		_smoke()

func _input_actions() -> void:
	var keys: Dictionary = {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_SPACE, "move_down": KEY_CTRL, "boost": KEY_SHIFT}
	for action: String in keys:
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	InputMap.add_action("fire")
	var fire := InputEventMouseButton.new()
	fire.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", fire)

func _environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("030713")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("647fa8")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_color = Color("c4dfff")
	light.light_energy = 1.8
	add_child(light)

func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collision: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	mesh.position = pos
	if collision:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collider.shape = box
		mesh.add_child(body)
		body.add_child(collider)
	return mesh

func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	sphere.radial_segments = 48
	sphere.rings = 24
	mesh.mesh = sphere
	mesh.material_override = _material(color, glow)
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

func _label(parent: Node3D, pos: Vector3, title: String, size: int = 64) -> void:
	var label := Label3D.new()
	label.text = title
	label.font_size = size
	label.pixel_size = 0.025
	label.modulate = Color("75e9df")
	parent.add_child(label)
	label.position = pos

func _generate() -> void:
	if is_instance_valid(sector):
		remove_child(sector)
		sector.queue_free()
	targets.clear()
	sector = Node3D.new()
	add_child(sector)
	system = Universe.system_data(system_index)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(system.station_seed)
	# Local space is deliberately compact; galaxy addresses do not use world coordinates.
	for i in range(420):
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		_sphere(sector, direction * 6500, rng.randf_range(1.5, 5), Color("c1d6ef"), true)
	_sphere(sector, Vector3(-2100, 1200, -4900), 380, system.star_color, true)
	var planet_i: int = 0
	for planet: Dictionary in system.planets:
		var pos := Vector3(900 + planet_i * 1100, 200 + planet_i * 200, -2100 - planet_i * 800)
		var radius: float = float(planet.radius) * 60.0
		radius = clampf(radius, 100, 400)
		_sphere(sector, pos, radius, planet.color)
		if planet.atmosphere:
			var air := _sphere(sector, pos, radius * 1.045, Color(0.15, 0.6, 0.95, 0.12), true)
			var mat := air.material_override as StandardMaterial3D
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		planet_i += 1
	_box(sector, Vector3(0, -1, 0), Vector3(100, 2, 110), Color("142235"), true)
	_box(sector, Vector3(0, 18, 45), Vector3(100, 36, 2), Color("22334a"), true)
	for side in [-1, 1]:
		_box(sector, Vector3(side * 49, 12, 0), Vector3(2, 24, 110), Color("18293d"), true)
		for i in range(8):
			_box(sector, Vector3(side * 44, 6, 35 - i * 11), Vector3(5, 12, 3), Color("31475a"), true)
			_box(sector, Vector3(side * 41, 10, 35 - i * 11), Vector3(0.2, 0.3, 5), Color("4cf4e4"))
	for i in range(12):
		_box(sector, Vector3(-30 + i * 5, 0.04, 0), Vector3(0.15, 0.08, 85), Color("397c88"))
	for i in range(28):
		var angle: float = TAU * i / 28.0
		var tower := _box(sector, Vector3(cos(angle) * 180, sin(angle) * 180 + 60, 110), Vector3(28, rng.randf_range(30, 80), 50), Color("25364c"))
		tower.rotation.z = angle
	_label(sector, Vector3(0, 12, 43.8), "N E X T   /   ORBITAL EXCHANGE\nCONCOURSE 01", 90)
	_label(sector, Vector3(0, 5, -22), "PATHFINDER\n[E] BOARD / LAUNCH", 48)
	_box(sector, Vector3(0, 1.8, -22), Vector3(6, 2.4, 11), Color("b7c9d9"), true)
	_box(sector, Vector3(0, 3.2, -23), Vector3(3, 1, 4), Color("14788f"))
	for side in [-1, 1]:
		_box(sector, Vector3(side * 5, 1.3, -20), Vector3(5, 0.5, 7), Color("536c83"))
	for i in range(6):
		var target := Node3D.new()
		sector.add_child(target)
		target.position = Vector3(-70 + i * 28, 10 + i * 7, -250 - i * 100)
		target.set_meta("hp", 3)
		_box(target, Vector3.ZERO, Vector3(9, 4, 12), Color("b94847"))
		_box(target, Vector3.ZERO, Vector3(18, 1, 6), Color("ec8054"))
		_label(target, Vector3(0, 9, 0), "PIRATE  /  250 CR", 38)
		targets.append(target)
	# Station practice targets support first-person combat without hostile NPC AI yet.
	for i in range(3):
		var target := Node3D.new()
		sector.add_child(target)
		target.position = Vector3(22 + i * 7, 2, -18)
		target.set_meta("hp", 2)
		target.set_meta("practice", true)
		_box(target, Vector3.ZERO, Vector3(1.5, 3, 1), Color("ed9362"))
		targets.append(target)

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var theme := Theme.new()
	theme.default_font_size = 20
	var base := Control.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.theme = theme
	layer.add_child(base)
	hud = Label.new()
	hud.position = Vector2(30, 24)
	hud.add_theme_color_override("font_color", Color("90e7e2"))
	base.add_child(hud)
	notice = Label.new()
	notice.position = Vector2(30, 800)
	base.add_child(notice)
	var crosshair := Label.new()
	crosshair.text = "·"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.add_theme_font_size_override("font_size", 36)
	base.add_child(crosshair)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(720 - 330, 110)
	panel.custom_minimum_size = Vector2(660, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.075, 0.98)
	style.border_color = Color("317f8d")
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	base.add_child(panel)
	menu_content = VBoxContainer.new()
	menu_content.add_theme_constant_override("separation", 12)
	panel.add_child(menu_content)

func _text(value: String, large: bool = false) -> void:
	var label := Label.new()
	label.text = value
	if large:
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Color("85eee3"))
	menu_content.add_child(label)

func _button(title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	menu_content.add_child(button)

func _open_menu(page: String = "main") -> void:
	for child in menu_content.get_children():
		menu_content.remove_child(child)
		child.queue_free()
	panel.show()
	pilot.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_text("N E X T    /    COMMAND", true)
	_text("%s  •  %s\n%s credits  /  Hull %d%%" % [system.name, system.faction, credits, int(hull)])
	match page:
		"welcome":
			_text("Your next life begins among the stars.")
			_text("WASD   Move     •     Mouse   Look\nShift   Boost     •     Space / Ctrl   Up / Down\nE   Board ship / dock within 180 m\nLeft click   Fire     •     Tab / Esc   Command menu\nF5   Save     •     F9   Load")
			_text("Prototype 0.1 — placeholder geometry, local solo play.")
			_button("BEGIN EXPLORING", _close_menu)
		"navigation":
			_text("HYPERDRIVE / Select a system", true)
			for offset in range(1, 5):
				var destination: int = (system_index + offset * 7919) % 1000000000
				var data: Dictionary = Universe.system_data(destination)
				_button("%s  /  %s" % [data.name, data.star_type], _jump.bind(destination))
			var address := SpinBox.new()
			address.max_value = 999999999
			address.step = 1
			address.value = system_index
			address.prefix = "System address: "
			menu_content.add_child(address)
			_button("JUMP TO ADDRESS", func(): _jump(int(address.value)))
			_button("BACK", _open_menu.bind("main"))
		"market":
			_text("ORBITAL EXCHANGE / Cargo %d / %d" % [_cargo_total(), 20 + modules * 5])
			for good: String in GOODS:
				var price: int = Universe.price(system_index, good)
				_button("BUY %s  /  %d CR  /  Held %d" % [good, price, cargo[good]], _trade.bind(good, 1))
				_button("SELL %s  /  %d CR" % [good, int(price * 0.85)], _trade.bind(good, -1))
			_button("BACK", _open_menu.bind("main"))
		"shipyard":
			_text("PATHFINDER / Modular cargo refit")
			_text("Cargo pods installed: %d / 8\nEach pod adds 5 cargo slots. Cost: 500 CR.\nFreeform ship construction is planned." % modules)
			_button("INSTALL CARGO POD", _refit)
			_button("REPAIR HULL / 200 CR", _repair)
			_button("BACK", _open_menu.bind("main"))
		_:
			_button("RESUME", _close_menu)
			_button("GALAXY / HYPERDRIVE", _open_menu.bind("navigation"))
			_button("COMMODITY EXCHANGE", func():
				if pilot.flying: _notify("Dock at the station before trading.")
				else: _open_menu("market"))
			_button("SHIPYARD", func():
				if pilot.flying: _notify("Dock at the station for refitting.")
				else: _open_menu("shipyard"))
			_button("SAVE COMMANDER", _save_game)
			_button("SAVE AND QUIT", func():
				if _save_game(): get_tree().quit())
	var first := menu_content.find_children("*", "Button", false)
	if not first.is_empty(): first[0].grab_focus()

func _close_menu() -> void:
	panel.hide()
	pilot.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode in [KEY_TAB, KEY_ESCAPE]:
		if panel.visible: _close_menu()
		else: _open_menu()
	elif event.keycode == KEY_E and not panel.visible:
		if pilot.flying:
			if pilot.position.length() > 180:
				_notify("Approach the station to within 180 m to dock.")
				return
			pilot.set_flight(false)
			pilot.teleport(Vector3(0, 2, 20))
		else:
			pilot.set_flight(true)
			pilot.teleport(Vector3(0, 12, -80))
	elif event.keycode == KEY_F5: _save_game()
	elif event.keycode == KEY_F9:
		_load_game()
		_generate()
		pilot.set_flight(false)
		pilot.teleport(Vector3(0, 2, 20))
		_open_menu()

func _jump(destination: int) -> void:
	if not pilot.flying:
		_notify("Board your ship with E before engaging hyperdrive.")
		return
	system_index = clampi(destination, 0, 999999999)
	_generate()
	pilot.teleport(Vector3(0, 12, -80))
	_close_menu()
	_notify("Hyperdrive complete. Welcome to %s." % system.name)

func _cargo_total() -> int:
	var total: int = 0
	for count: int in cargo.values(): total += count
	return total

func _trade(good: String, amount: int) -> void:
	if pilot.flying or good not in GOODS: return
	var price: int = Universe.price(system_index, good)
	if amount == 1 and credits >= price and _cargo_total() < 20 + modules * 5:
		credits -= price
		cargo[good] += 1
	elif amount == -1 and cargo[good] > 0:
		credits += int(price * 0.85)
		cargo[good] -= 1
	else: _notify("Insufficient credits, cargo, or hold capacity.")
	_open_menu("market")

func _refit() -> void:
	if not pilot.flying and modules < 8 and credits >= 500:
		credits -= 500
		modules += 1
	else: _notify("Refit unavailable: requires docking, 500 CR, and a free slot.")
	_open_menu("shipyard")

func _repair() -> void:
	if not pilot.flying and credits >= 200 and hull < 100:
		credits -= 200
		hull = 100
	_open_menu("shipyard")

func _shoot(origin: Vector3, direction: Vector3) -> void:
	var best: Node3D = null
	var distance: float = 1800.0 if pilot.flying else 90.0
	for target in targets:
		var offset: Vector3 = target.global_position - origin
		var along: float = offset.dot(direction)
		var radius: float = 1.8 if target.has_meta("practice") else 11.0
		if along > 0 and along < distance and (offset - direction * along).length() < radius:
			best = target
			distance = along
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance)
	query.exclude = [pilot.get_rid()]
	var obstruction: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty():
		distance = origin.distance_to(obstruction.position)
		best = null
	var beam := _box(sector, origin + direction * distance * 0.5, Vector3(0.07, 0.07, distance), Color("6ffff0"))
	beam.look_at(origin + direction * distance, Vector3.UP)
	beam.material_override = _material(Color("6ffff0"), true)
	get_tree().create_timer(0.08).timeout.connect(beam.queue_free)
	if best != null:
		var hp: int = int(best.get_meta("hp")) - 1
		best.set_meta("hp", hp)
		if hp <= 0:
			if not best.has_meta("practice"):
				credits += 250
				kills += 1
				_notify("Pirate neutralized. Bounty +250 CR.")
			targets.erase(best)
			best.queue_free()

func _process(delta: float) -> void:
	if pilot == null or system.is_empty(): return
	hud.text = "N E X T  /  %s\n%s  •  %s\n%04d CR    HULL %03d%%    CARGO %d/%d\n%s   /   TAB Command   E Board or dock" % [system.name, system.star_type, system.faction, credits, int(hull), _cargo_total(), 20 + modules * 5, "FLIGHT" if pilot.flying else "ON FOOT"]
	message_clock -= delta
	if message_clock < 0: notice.text = ""
	if not pilot.enabled: return
	if pilot.position.y < -100 and not pilot.flying: pilot.teleport(Vector3(0, 2, 20))
	if pilot.position.length() > 15000:
		pilot.teleport(Vector3(0, 12, -80))
		_notify("Local flight boundary reached. Use hyperdrive to travel between systems.")
	attack_clock += delta
	if pilot.flying and attack_clock > 2.0:
		attack_clock = 0
		for target in targets:
			if not target.has_meta("practice") and target.position.distance_to(pilot.position) < 180:
				hull -= 4
				_notify("Incoming pirate fire! Hull damaged.")
				break
		if hull <= 0:
			hull = 100
			credits = maxi(0, credits - 300)
			pilot.set_flight(false)
			pilot.teleport(Vector3(0, 2, 20))
			_notify("Rescued at station. Recovery fee: up to 300 CR.")

func _notify(value: String) -> void:
	notice.text = value
	message_clock = 5

func _save_game() -> bool:
	var path: String = "user://smoke_commander.json" if automation else SAVE_PATH
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		_notify("Save failed: could not open temporary file.")
		return false
	file.store_string(JSON.stringify({"version": 1, "system": system_index, "credits": credits, "cargo": cargo, "hull": hull, "modules": modules, "kills": kills}))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		_notify("Save failed. Previous save retained.")
		return false
	_notify("Commander saved locally. Resume at this system's station.")
	return true

func _load_game() -> void:
	var path: String = "user://smoke_commander.json" if automation else SAVE_PATH
	if not FileAccess.file_exists(path): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1:
		_notify("Unsupported or damaged save. Current commander retained.")
		return
	for key: String in ["system", "credits", "modules", "hull", "kills"]:
		if not (data.get(key) is float or data.get(key) is int):
			_notify("Invalid save fields. Current commander retained.")
			return
	if not data.get("cargo") is Dictionary: return
	var loaded_cargo: Dictionary = {}
	for good: String in GOODS:
		var amount: Variant = data.cargo.get(good, 0)
		if not (amount is float or amount is int): return
		loaded_cargo[good] = clampi(int(amount), 0, 60)
	var loaded_modules: int = clampi(int(data.modules), 0, 8)
	var total: int = 0
	for value: int in loaded_cargo.values(): total += value
	if total > 20 + loaded_modules * 5: return
	system_index = clampi(int(data.system), 0, 999999999)
	credits = clampi(int(data.credits), 0, 2000000000)
	modules = loaded_modules
	hull = clampf(float(data.hull), 1, 100)
	kills = maxi(int(data.kills), 0)
	cargo = loaded_cargo

func _smoke() -> void:
	await get_tree().process_frame
	credits = 2400
	cargo = {"Food": 0, "Alloys": 0, "Medicine": 0}
	modules = 0
	_trade("Food", 1)
	assert(cargo.Food == 1 and credits < 2400)
	_trade("Food", -1)
	assert(cargo.Food == 0 and credits < 2400)
	_refit()
	assert(modules == 1)
	pilot.set_flight(true)
	_jump(7919)
	assert(system_index == 7919 and targets.size() == 9)
	var target: Node3D = targets[0]
	var origin: Vector3 = target.position + Vector3(0, 0, 40)
	for i in range(3): _shoot(origin, Vector3.FORWARD)
	assert(kills >= 1 and targets.size() == 8)
	assert(_save_game())
	credits = 0
	_load_game()
	assert(credits > 0 and system_index == 7919 and modules == 1)
	DirAccess.remove_absolute("user://smoke_commander.json")
	pilot.set_flight(false)
	pilot.teleport(Vector3(0, 2, 20))
	_open_menu("welcome")
	await get_tree().create_timer(2).timeout
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("res://build/preview.png")
	print("NEXT_SMOKE_OK: trade, refit, jump, combat, save/load")
	get_tree().quit()
