class_name CommandDeck
extends Control

var game: Node3D
var page: String = "overview"
var content: VBoxContainer
var heading: Label
var feedback: Label
var subtitle: Label
var tabs: Dictionary = {}
var destination: int = 0
var navigation_info: Label
var balance_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = InterfaceTheme.create()
	var background := ColorRect.new()
	background.color = Color(0.012, 0.026, 0.047, 0.76)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 105)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 28)
	margin.add_child(layout)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 235
	layout.add_child(sidebar)
	sidebar.add_child(InterfaceTheme.label("COMMAND DECK", 13, InterfaceTheme.CYAN))
	sidebar.add_child(InterfaceTheme.label("Your place\namong the stars.", 24))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 14
	sidebar.add_child(spacer)
	var sections: Dictionary = {"overview": "01   Commander", "navigation": "02   Navigation", "market": "03   Exchange", "shipyard": "04   Ship architect", "contracts": "05   Contracts", "company": "06   Enterprise", "factions": "07   Allegiances", "stations": "08   Station works", "settings": "09   Flight settings"}
	for key: String in sections:
		var button := InterfaceTheme.button(sections[key], show_page.bind(key))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sidebar.add_child(button)
		tabs[key] = button
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(grow)
	sidebar.add_child(InterfaceTheme.button("RETURN TO WORLD   /   TAB", game.close_menu))
	sidebar.add_child(InterfaceTheme.label("LOCAL COMMANDER  •  AUTOSAVE ON", 11, InterfaceTheme.MUTED))
	var main_panel := PanelContainer.new()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(main_panel)
	var body := VBoxContainer.new()
	main_panel.add_child(body)
	heading = InterfaceTheme.label("", 32)
	body.add_child(heading)
	subtitle = InterfaceTheme.label("", 14, InterfaceTheme.MUTED)
	body.add_child(subtitle)
	feedback = InterfaceTheme.label("", 15, InterfaceTheme.GOLD)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 24
	body.add_child(feedback)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

func show_page(value: String = "overview") -> void:
	page = value
	show()
	game.ui_open = true
	game.pilot.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for key: String in tabs:
		tabs[key].modulate = InterfaceTheme.CYAN if key == page else Color.WHITE
	feedback.text = ""
	var state: GameState = game.state
	subtitle.text = "%s  /  %s  /  DAY %03d" % [Universe.system_data(state.system_index).name, game.location_title(), state.day]
	match page:
		"overview": _overview()
		"navigation": _navigation()
		"market": _market()
		"shipyard": _shipyard()
		"contracts": _contracts()
		"company": _company()
		"factions": _factions()
		"stations": _stations()
		"settings": _settings()

func refresh() -> void:
	show_page(page)

func note(text: String) -> void:
	feedback.text = text

func _text(text: String, size: int = 18, color: Color = InterfaceTheme.WHITE) -> Label:
	var label := InterfaceTheme.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label

func _button(text: String, action: Callable, disabled: bool = false) -> Button:
	var button := InterfaceTheme.button(text, action)
	button.disabled = disabled
	content.add_child(button)
	return button

func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	content.add_child(row)
	return row

func _act(action: Callable, success: String) -> void:
	var error: String = action.call()
	if error.is_empty():
		game.apply_ship_stats()
		var saved: bool = game.save_commander(false)
		refresh()
		note(success if saved else success + " Changes are NOT SAVED; check storage and save again.")
	else: note(error)

func _overview() -> void:
	heading.text = "INHABIT THE INFINITE"
	_text("Explore a distant system. Find a profitable route. Design your next ship. Build somewhere worth coming home to.", 22)
	var s: GameState = game.state
	var stats: Dictionary = s.ship_stats()
	_text("COMMANDER'S LOG", 13, InterfaceTheme.CYAN)
	_text("%s credits    •    %d systems visited    •    %d hostiles defeated" % [s.credits, s.visited.size(), s.kills])
	_text("SHIP MANIFEST", 13, InterfaceTheme.CYAN)
	_text("%d modules  /  %d cargo capacity  /  %d m/s cruise\nPower balance: %s  •  Hull: %d / %d  •  Fuel: %d%%" % [s.ship_modules.size(), stats.cargo_capacity, stats.speed, stats.power_balance, s.hull, stats.max_hull, s.fuel])
	var row := _row()
	row.add_child(InterfaceTheme.button("ENTER WORLD", game.close_menu))
	row.add_child(InterfaceTheme.button("PLOT A COURSE", show_page.bind("navigation")))
	row.add_child(InterfaceTheme.button("WALK YOUR SHIP", game.enter_interior))
	_text("FLIGHT & FOOT CONTROLS", 13, InterfaceTheme.CYAN)
	_text("WASD move · mouse look · Shift boost/sprint · Space/Ctrl altitude\nQ/R roll · E board/dock/interact · Left click fire · J navigation\nTab command deck · F5 save · F9 load", 16, InterfaceTheme.MUTED)
	_text("Station services require docking. Hyperdrive consumes fuel; contracts, trade and pirate bounties earn credits. Company wages and production settle when the simulation day advances.", 16, InterfaceTheme.MUTED)
	var actions := _row()
	actions.add_child(InterfaceTheme.button("SAVE COMMANDER", func(): game.save_commander(true)))
	actions.add_child(InterfaceTheme.button("LOAD COMMANDER", game.load_commander))
	actions.add_child(InterfaceTheme.button("SAVE & EXIT", game.quit_game))

func _navigation() -> void:
	heading.text = "STELLAR CARTOGRAPHY"
	var chart := GalaxyChart.new()
	content.add_child(chart)
	chart.configure(game.state.system_index)
	chart.selected.connect(_select_destination)
	destination = game.state.system_index
	navigation_info = _text("Select a star to inspect its system.", 17)
	var controls := _row()
	var address := SpinBox.new()
	address.max_value = Universe.SYSTEM_LIMIT - 1
	address.step = 1
	address.value = game.state.system_index
	address.prefix = "Address "
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(address)
	controls.add_child(InterfaceTheme.button("INSPECT", func():
		_select_destination(int(address.value))
		chart.destination = int(address.value)
		chart.queue_redraw()))
	controls.add_child(InterfaceTheme.button("ENGAGE HYPERDRIVE", func(): game.request_jump(destination)))
	_text("LOCAL SYSTEM / SURFACE APPROACH", 13, InterfaceTheme.CYAN)
	_button("CRUISE TO ORBITAL DOCK", game.cruise_to.bind(game.world.launch_position), not game.pilot.flying or game.aboard)
	for index in game.world.planets.size():
		var planet: Dictionary = game.world.planets[index]
		var row := _row()
		var title := InterfaceTheme.label("%s / %s" % [planet.name, "Atmosphere" if planet.atmosphere else "Airless"], 15)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var approach := InterfaceTheme.button("CRUISE APPROACH", game.approach_planet.bind(index))
		approach.disabled = not game.pilot.flying or game.surface_index >= 0
		row.add_child(approach)
		var land_button := InterfaceTheme.button("LAND AT COLONY", game.land.bind(index))
		land_button.disabled = not game.pilot.flying or game.surface_index >= 0
		row.add_child(land_button)

func _select_destination(address: int) -> void:
	destination = address
	var data: Dictionary = Universe.system_data(address)
	navigation_info.text = "%s  /  %s\n%s  •  %d planets  •  Address %d" % [data.name, data.star_type, data.faction, data.planets.size(), address]

func _market() -> void:
	heading.text = "ORBITAL EXCHANGE"
	var s: GameState = game.state
	_text("Hold %d / %d    •    Cash %d CR" % [s.cargo_total(), s.ship_stats().cargo_capacity, s.credits], 21, InterfaceTheme.CYAN)
	if game.pilot.flying or game.aboard: _text("Dock to trade commodities.", 16, InterfaceTheme.GOLD)
	for good: String in GameState.GOODS:
		var row := _row()
		var label := InterfaceTheme.label("%s\n%d CR  •  %d in hold" % [good.capitalize(), s.price(good), int(s.cargo.get(good, 0))], 17)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		for quantity in [1, 10]:
			var buy := InterfaceTheme.button("BUY %d" % quantity, _act.bind(s.trade.bind(good, quantity, true), "Cargo purchased."))
			buy.disabled = game.pilot.flying or game.aboard
			row.add_child(buy)
		var sell := InterfaceTheme.button("SELL 1", _act.bind(s.trade.bind(good, 1, false), "Cargo sold."))
		sell.disabled = game.pilot.flying or game.aboard
		row.add_child(sell)
	var services := _row()
	services.add_child(InterfaceTheme.button("REFUEL", _act.bind(s.refuel, "Fuel tanks replenished.")))
	services.add_child(InterfaceTheme.button("REPAIR", _act.bind(s.repair, "Hull restored.")))
	for child in services.get_children(): child.disabled = game.pilot.flying or game.aboard

func _shipyard() -> void:
	heading.text = "SHIP ARCHITECT"
	var s: GameState = game.state
	var stats: Dictionary = s.ship_stats()
	_text("MASS %s   /   POWER %+d   /   CARGO %d   /   THRUST %d m/s" % [stats.mass, stats.power_balance, stats.cargo_capacity, stats.speed], 15, InterfaceTheme.CYAN)
	_text("Choose a deck and cell, then install a module. Every module must connect to the ship. Essential systems and cargo capacity are protected.", 15, InterfaceTheme.MUTED)
	var designer := ShipDesigner.new()
	designer.modules = s.ship_modules.duplicate(true)
	content.add_child(designer)
	designer.requested.connect(func(kind: String, cell: Vector3i, remove: bool):
		if game.pilot.flying or game.aboard or game.session.connected:
			note("Dock and leave multiplayer visits before modifying your ship.")
			return
		var error: String = s.remove_module(cell) if remove else s.add_module(kind, cell)
		if error.is_empty():
			game.apply_ship_stats()
			game.rebuild_player_ship()
			var saved: bool = game.save_commander(false)
			designer.refresh(s.ship_modules)
			note("Assembly updated." if saved else "Assembly updated but NOT SAVED. Check storage and save again.")
		else: note(error))

func _contracts() -> void:
	heading.text = "CONTRACT EXCHANGE"
	var s: GameState = game.state
	_text("ACTIVE CONTRACTS", 13, InterfaceTheme.CYAN)
	if s.contracts.is_empty(): _text("No active contracts. Take a job below.", 16, InterfaceTheme.MUTED)
	for job: Dictionary in s.contracts:
		if not job.get("accepted", false) or job.get("completed", false): continue
		var row := _row()
		var label := InterfaceTheme.label(_contract_description(job), 16)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(InterfaceTheme.button("CLAIM", _act.bind(s.claim_contract.bind(str(job.id)), "Contract completed. Payment received.")))
	_text("AVAILABLE CONTRACTS", 13, InterfaceTheme.CYAN)
	for job: Dictionary in s.contracts:
		if job.get("accepted", false) or job.get("completed", false): continue
		_button(_contract_description(job), _act.bind(s.accept_contract.bind(str(job.id)), "Contract accepted."))

func _contract_description(job: Dictionary) -> String:
	return str(job.get("title", str(job.get("type", "Contract")).capitalize())) + "  /  " + str(job.get("reward", 0)) + " CR\n" + str(job.get("description", ""))

func _company() -> void:
	heading.text = "ENTERPRISE"
	var s: GameState = game.state
	_text("SECURITIES EXCHANGE", 13, InterfaceTheme.CYAN)
	for ticker: String in GameState.COMPANIES:
		var row := _row()
		var item: Dictionary = GameState.COMPANIES[ticker]
		var label := InterfaceTheme.label("%s  /  %s\n%d CR per share  •  %d owned" % [ticker, item.name, s.stock_price(ticker), s.shares.get(ticker, 0)], 16)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(InterfaceTheme.button("BUY", _act.bind(s.trade_stock.bind(ticker, 1, true), "Share purchased.")))
		row.add_child(InterfaceTheme.button("SELL", _act.bind(s.trade_stock.bind(ticker, 1, false), "Share sold.")))
	_text("YOUR COMPANY", 13, InterfaceTheme.CYAN)
	if s.company_name.is_empty():
		var row := _row()
		var name_field := LineEdit.new()
		name_field.placeholder_text = "Company name"
		name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_field)
		row.add_child(InterfaceTheme.button("INCORPORATE / 5,000 CR", func(): _act(s.found_company.bind(name_field.text), "Company registered.")))
	else:
		_text("%s  /  Treasury %d CR" % [s.company_name, s.company_balance], 21)
		_button("WITHDRAW DIVIDEND", _act.bind(s.withdraw_company.bind(s.company_balance), "Company dividend withdrawn."), s.company_balance <= 0)
	_text("CREW ROSTER", 13, InterfaceTheme.CYAN)
	for index in s.crew.size():
		var member: Dictionary = s.crew[index]
		var member_row := _row()
		var member_label := InterfaceTheme.label("%s  /  %s  /  %s CR per day" % [member.get("name", "Crew"), member.role, member.get("salary", 0)], 16)
		member_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		member_row.add_child(member_label)
		member_row.add_child(InterfaceTheme.button("DISMISS", _act.bind(s.dismiss_crew.bind(index), "Crew contract ended.")))
	var hires := _row()
	for role in ["engineer", "gunner", "trader"]:
		hires.add_child(InterfaceTheme.button("HIRE " + role.to_upper() + " / 500 CR", _act.bind(s.hire.bind(role), "Crew member hired.")))
	_text("Share prices change with simulation days. Crew wages and company production settle on travel; check your reserves before expanding.", 14, InterfaceTheme.MUTED)

func _factions() -> void:
	heading.text = "ALLEGIANCES & LAW"
	var s: GameState = game.state
	_text("Wanted level: %d" % s.wanted, 22, InterfaceTheme.GOLD)
	_text("Pirate bounties build your standing. Attacking police creates a wanted level; local security pursues wanted ships.", 16)
	for faction: String in Universe.FACTIONS:
		var reputation: int = int(s.reputation.get(faction, 0))
		_text("%s  /  %s  (%+d)" % [faction, "Trusted" if reputation >= 10 else ("Hostile" if reputation < -5 else "Neutral"), reputation], 19)
	_button("PAY OUTSTANDING FINES", game.pay_fines, game.pilot.flying or s.wanted <= 0)

func _stations() -> void:
	heading.text = "STATION WORKS"
	var s: GameState = game.state
	_text("Construct a persistent orbital outpost, then expand it. Station and ship assembly are the only crafting systems.", 18)
	var row := _row()
	var name_field := LineEdit.new()
	name_field.placeholder_text = "New station name"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_field)
	row.add_child(InterfaceTheme.button("BUILD / 3,000 CR + 20 ALLOYS", func():
		_act(s.build_station.bind(name_field.text), "Station constructed in this system.")
		game.rebuild_owned_stations()))
	if s.stations.is_empty(): _text("No owned stations yet. Trade and complete contracts to fund your first outpost.", 16, InterfaceTheme.MUTED)
	for index in s.stations.size():
		var station: Dictionary = s.stations[index]
		_button("%s  /  SYSTEM %d  /  LEVEL %d  /  EXPAND" % [station.name, station.get("system", station.get("system_index", 0)), station.level], func():
			_act(s.upgrade_station.bind(index), "Station expanded.")
			game.rebuild_owned_stations())

func _settings() -> void:
	heading.text = "FLIGHT SETTINGS"
	_text("Mouse sensitivity", 18)
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0005
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value = game.pilot.mouse_sensitivity
	sensitivity.value_changed.connect(func(value: float):
		game.pilot.mouse_sensitivity = value
		game.save_settings())
	content.add_child(sensitivity)
	var invert := CheckButton.new()
	invert.text = "Invert vertical look"
	invert.button_pressed = game.pilot.inverted_y
	invert.toggled.connect(func(value: bool):
		game.pilot.inverted_y = value
		game.save_settings())
	content.add_child(invert)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(value: bool): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED))
	content.add_child(fullscreen)
	_text("Presentation: cinematic procedural placeholders. Art can be replaced through the asset checklist. Steam friend transport and VR need their platform integrations before they can be enabled.", 16, InterfaceTheme.MUTED)
	_text("WORLD VISITS / LOCAL NETWORK", 13, InterfaceTheme.CYAN)
	_text("Bring your current ship into a host's system. This connects presence and host travel; economy and combat remain local. Steam friends transport is not installed.", 15, InterfaceTheme.MUTED)
	var connection := _row()
	var name_field := LineEdit.new()
	name_field.placeholder_text = "Pilot callsign"
	name_field.text = game.session.display_name
	connection.add_child(name_field)
	var address_field := LineEdit.new()
	address_field.placeholder_text = "Host address"
	address_field.text = "127.0.0.1"
	address_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connection.add_child(address_field)
	var buttons := _row()
	buttons.add_child(InterfaceTheme.button("HOST VISIT", func():
		game.session.ship_modules = game.state.ship_modules.duplicate(true)
		game.session.system_index = game.state.system_index
		game.session.world_id = game.state.world_id
		game.session.display_name = name_field.text
		var error: String = game.session.host()
		note(error if not error.is_empty() else "Hosting on UDP 27840. Share this machine's LAN address.")))
	buttons.add_child(InterfaceTheme.button("JOIN HOST", func():
		game.session.ship_modules = game.state.ship_modules.duplicate(true)
		game.session.display_name = name_field.text
		var error: String = game.session.join(address_field.text)
		note(error if not error.is_empty() else "Connecting to host…")))
	buttons.add_child(InterfaceTheme.button("LEAVE VISIT", func():
		game.leave_visit()
		note("Disconnected from world visit.")))
