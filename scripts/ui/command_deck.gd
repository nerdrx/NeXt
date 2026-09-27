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
var _clock_label := ""
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
	_clock_label = ""
	_update_clock()
	match page:
		"overview": _overview()
		"navigation": _navigation()
		"market": _market()
		"shipyard": _shipyard()
		"contracts": _contracts()
		"company": _company()
		"fleet": _fleet()
		"recovery": _recovery()
		"factions": _factions()
		"stations": _stations()
		"settings": _settings()

func _process(_delta: float) -> void:
	if visible: _update_clock()

func _update_clock() -> void:
	var state: GameState = game.state
	var text := "%03d %s" % [state.day, state.clock_text()]
	if text == _clock_label: return
	_clock_label = text
	subtitle.text = "%s  /  %s  /  DAY %s" % [Universe.system_data(state.system_index).name, game.location_title(), text]

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
	_button("RECOVERY BEACONS", show_page.bind("recovery"))
	_text("LOCAL SYSTEM / SURFACE APPROACH", 13, InterfaceTheme.CYAN)
	_button("CRUISE TO ORBITAL DOCK", game.cruise_system_to.bind(game.world.launch_position), not game.pilot.flying or game.aboard)
	for index in game.world.planets.size():
		var planet: Dictionary = game.world.planets[index]
		var row := _row()
		var title := InterfaceTheme.label("%s / %s" % [planet.name, "Atmosphere" if planet.atmosphere else "Airless"], 15)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var approach := InterfaceTheme.button("SURFACE APPROACH", game.approach_planet_surface.bind(index))
		approach.disabled = not game.pilot.flying or game.surface_index >= 0
		row.add_child(approach)
		var land_button := InterfaceTheme.button("COLONY APPROACH", game.approach_colony.bind(index))
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
		var label := InterfaceTheme.label("%s\nBuy %d / Sell %d CR  •  %d in hold" % [good.capitalize(), s.trade_quote(good, true), s.trade_quote(good, false), int(s.cargo.get(good, 0))], 17)
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
	_button("INSURANCE & WRECK RECOVERY", show_page.bind("recovery"))

func _shipyard() -> void:
	heading.text = "SHIP ARCHITECT"
	var s: GameState = game.state
	var stats: Dictionary = s.ship_stats()
	_text("MASS %s   /   POWER %+d   /   CARGO %d   /   THRUST %d m/s" % [stats.mass, stats.power_balance, stats.cargo_capacity, stats.speed], 15, InterfaceTheme.CYAN)
	_text("Choose a deck and cell, then install a module. Every module must connect to the ship. Essential systems and cargo capacity are protected.", 15, InterfaceTheme.MUTED)
	var designer := ShipDesigner.new()
	designer.modules = s.ship_modules.duplicate(true)
	designer.layout = s.ship_layout.duplicate(true)
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
			designer.layout = s.ship_layout.duplicate(true)
			designer.refresh(s.ship_modules)
			note("Assembly updated." if saved else "Assembly updated but NOT SAVED. Check storage and save again.")
		else: note(error))
	_text("ROOM & HULL REFITS", 13, InterfaceTheme.CYAN)
	_text("Select a module on the grid above. Room fittings preserve module function; hull panels change exposed faces. Armor and glazing are appearance refits in this build.", 15, InterfaceTheme.MUTED)
	var room_row := _row()
	var room_choice := OptionButton.new()
	for room_type: String in ShipLayout.ROOM_TYPES:
		room_choice.add_item(room_type.capitalize())
		room_choice.set_item_metadata(room_choice.item_count - 1, room_type)
	room_row.add_child(room_choice)
	room_row.add_child(InterfaceTheme.button("REFIT ROOM / %d CR" % ShipLayout.ROOM_REFIT_COST, func():
		if game.pilot.flying or game.aboard or game.session.connected:
			note("Dock and leave visits before refitting.")
			return
		var result: String = ShipLayout.configure_room(s, designer.selected_cell, str(room_choice.get_selected_metadata()))
		_refit_result(result, designer)))
	var panel_row := _row()
	var face_choice := OptionButton.new()
	for face: String in ShipLayout.FACES: face_choice.add_item(face)
	panel_row.add_child(face_choice)
	var panel_choice := OptionButton.new()
	for panel_type: String in ShipLayout.PANEL_COSTS:
		panel_choice.add_item("%s / %d CR" % [panel_type.capitalize(), ShipLayout.PANEL_COSTS[panel_type]])
		panel_choice.set_item_metadata(panel_choice.item_count - 1, panel_type)
	panel_row.add_child(panel_choice)
	panel_row.add_child(InterfaceTheme.button("REFIT HULL FACE", func():
		if game.pilot.flying or game.aboard or game.session.connected:
			note("Dock and leave visits before refitting.")
			return
		var result: String = ShipLayout.set_panel(s, designer.selected_cell, ShipLayout.FACES[face_choice.selected], str(panel_choice.get_selected_metadata()))
		_refit_result(result, designer)))

func _refit_result(error: String, designer: ShipDesigner) -> void:
	if not error.is_empty():
		note(error)
		return
	designer.layout = game.state.ship_layout.duplicate(true)
	designer.refresh(game.state.ship_modules)
	game.rebuild_player_ship()
	note("Refit complete." if game.save_commander(false) else "Refit complete but NOT SAVED. Check storage.")

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
	_button("CREW & FLEET OPERATIONS", show_page.bind("fleet"))
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
	_text("A day lasts 20 minutes while this world is open, including menus. Hyperdrive also advances one day. Daily payroll, company income and market prices follow this clock. Assigned crew are paid on their operation timers. Closed worlds do not advance.", 14, InterfaceTheme.MUTED)

func _factions() -> void:
	heading.text = "ALLEGIANCES & LAW"
	var s: GameState = game.state
	_text("Wanted level: %d" % s.wanted, 22, InterfaceTheme.GOLD)
	_text("Pirate bounties build your standing. Attacking police creates a wanted level; local security pursues wanted ships.", 16)
	_button("PAY OUTSTANDING FINES", game.pay_fines, game.pilot.flying or s.wanted <= 0)

	_text("YOUR FACTION", 13, InterfaceTheme.CYAN)
	if str(s.faction.name).is_empty():
		_text("Found a human faction, fund its treasury and affiliate your stations. Claims apply to your property, not whole inhabited systems.", 16)
		var founding := _row()
		var faction_name := LineEdit.new()
		faction_name.placeholder_text = "Faction name"
		faction_name.max_length = 32
		faction_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		founding.add_child(faction_name)
		founding.add_child(InterfaceTheme.button("FOUND / 10,000 CR", func():
			_act(s.found_faction.bind(faction_name.text), "Faction charter registered.")))
		for faction: String in Universe.FACTIONS:
			_text("%s / Reputation %+d" % [faction, int(s.reputation.get(faction, 0))], 17)
		return
	_text("%s  /  Treasury %d CR  /  %d affiliated stations" % [s.faction.name, s.faction.treasury, s.faction.claimed_stations.size()], 21)
	var funds := _row()
	funds.add_child(InterfaceTheme.button("DEPOSIT 1,000 CR", _act.bind(s.faction_deposit.bind(1000), "Treasury funded.")))
	funds.add_child(InterfaceTheme.button("WITHDRAW 1,000 CR", _act.bind(s.faction_withdraw.bind(1000), "Treasury withdrawal completed.")))
	_text("Diplomatic changes cost 500 treasury CR. Friendly relations improve personal commodity terms; hostility worsens terms and makes local police hostile. Criminal fines remain separate.", 15, InterfaceTheme.MUTED)
	for faction: String in Universe.FACTIONS:
		var diplomacy := _row()
		var label := InterfaceTheme.label("%s / %s / Standing %+d" % [faction, s.diplomatic_stance(faction).capitalize(), int(s.reputation.get(faction, 0))], 16)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		diplomacy.add_child(label)
		for stance: String in ["friendly", "neutral", "hostile"]:
			var button := InterfaceTheme.button(stance.capitalize(), _act.bind(s.set_diplomatic_stance.bind(faction, stance), "Diplomatic stance updated."))
			button.disabled = stance == s.diplomatic_stance(faction)
			diplomacy.add_child(button)

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
		var affiliation: String = s.station_affiliation(index)
		if index in s.faction.claimed_stations: _text("Affiliation / " + affiliation, 15, InterfaceTheme.CYAN)
		var access := _row()
		access.add_child(InterfaceTheme.button("APPROACH DOCK", game.approach_owned_station.bind(index)))
		if not str(s.faction.name).is_empty() and index not in s.faction.claimed_stations:
			access.add_child(InterfaceTheme.button("AFFILIATE / 1,000 TREASURY CR", _act.bind(s.claim_station_faction.bind(index), "Station affiliated with your faction.")))
		_button("%s  /  SYSTEM %d  /  LEVEL %d  /  EXPAND" % [station.name, station.get("system", station.get("system_index", 0)), station.level], func():
			_act(s.upgrade_station.bind(index), "Station expanded.")
			game.rebuild_owned_stations())
		for good: String in station.get("stock", {}):
			var amount: int = int(station.stock[good])
			if amount <= 0: continue
			_button("COLLECT %d %s" % [amount, good.to_upper()], _act.bind(game.collect_station_stock.bind(index, good, amount), "Station stock delivered to your hold."), game.pilot.flying or game.aboard or int(station.system) != s.system_index)

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
	_text("Presentation: cinematic procedural placeholders. Art can be replaced through the asset checklist. Steam sessions require a configured Steam-enabled build. VR controls are not yet available.", 16, InterfaceTheme.MUTED)
	_text("STEAM FRIENDS", 13, InterfaceTheme.CYAN)
	var steam_ready: bool = game.steam_available() and game.steam_app_id() > 0
	_text("Host a friends-only world, then invite friends through the Steam overlay." if steam_ready else "Steam sessions are unavailable in this build. Local network visits remain available below.", 15, InterfaceTheme.MUTED)
	var steam_buttons := _row()
	var host_button := InterfaceTheme.button("HOST FRIENDS WORLD", func():
		var error: String = game.start_steam_host()
		note(error if not error.is_empty() else "Creating friends-only lobby…"))
	host_button.disabled = not steam_ready or game.session.connected
	steam_buttons.add_child(host_button)
	var invite_button := InterfaceTheme.button("INVITE FRIENDS", func():
		var error: String = game.session.invite_steam_friends()
		note(error if not error.is_empty() else "Steam invitation overlay opened."))
	invite_button.disabled = not steam_ready
	steam_buttons.add_child(invite_button)
	if game.pending_steam_lobby > 0:
		_button("JOIN INVITATION", func():
			var error: String = game.join_steam_invitation()
			note(error if not error.is_empty() else "Joining invited world…"), not steam_ready or game.session.connected)
	_text("WORLD VISITS / LOCAL NETWORK", 13, InterfaceTheme.CYAN)
	_text("Bring your current ship into a host's system. This connects presence, host travel and mutually opted-in ship combat. World economies and NPC combat remain local. Steam availability is shown above.", 15, InterfaceTheme.MUTED)
	var consent := CheckButton.new()
	consent.text = "Allow ship PvP with other opted-in pilots"
	consent.button_pressed = game.session.is_pvp_allowed()
	consent.disabled = not game.session.connected
	consent.toggled.connect(func(allowed: bool): game.session.set_pvp_allowed(allowed))
	content.add_child(consent)
	_text("Both pilots must opt in and be flying. Consent resets when leaving or changing systems. The host checks shot range and obstructions; local ship damage and rescue still use your commander save.", 14, InterfaceTheme.MUTED)
	for peer_id: int in game.session.presence:
		var peer: Dictionary = game.session.presence[peer_id]
		_text("%s  /  %s" % [peer.name, "PvP enabled" if peer.get("pvp", false) else "Protected"], 14)
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
		game.session.ship_layout = game.state.ship_layout.duplicate(true)
		game.session.system_index = game.state.system_index
		game.session.world_id = game.state.world_id
		game.session.display_name = name_field.text
		var error: String = game.session.host()
		note(error if not error.is_empty() else "Hosting on UDP 27840. Share this machine's LAN address.")))
	buttons.add_child(InterfaceTheme.button("JOIN HOST", func():
		game.session.ship_modules = game.state.ship_modules.duplicate(true)
		game.session.ship_layout = game.state.ship_layout.duplicate(true)
		game.session.display_name = name_field.text
		var error: String = game.session.join(address_field.text)
		note(error if not error.is_empty() else "Connecting to host…")))
	buttons.add_child(InterfaceTheme.button("LEAVE VISIT", func():
		game.leave_visit()
		note("Disconnected from world visit.")))

func _choice(row: HBoxContainer, options: Array, label_key: String, id_key: String) -> OptionButton:
	var choice := OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: Dictionary in options:
		choice.add_item(str(item[label_key]))
		choice.set_item_metadata(choice.item_count - 1, item[id_key])
	row.add_child(choice)
	return choice

func _fleet() -> void:
	heading.text = "CREW OPERATIONS"
	var s: GameState = game.state
	_text("Give named crew persistent orders. Trade captains buy and carry goods; patrols fight pirates in local space and use strategic simulation in distant systems; managers operate owned stations. Unpaid local patrols stop engaging but remain vulnerable. Operations advance while this world is hosted, never while closed.", 17)
	_text("FLEET REGISTRY", 13, InterfaceTheme.CYAN)
	var purchase := _row()
	var ship_name := LineEdit.new()
	ship_name.placeholder_text = "Fleet vessel name"
	ship_name.max_length = 32
	ship_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	purchase.add_child(ship_name)
	purchase.add_child(InterfaceTheme.button("COMMISSION / %d CR" % CrewOrders.SHIP_PRICE, func(): _act(game.crew_operations().purchase_ship.bind(ship_name.text), "Fleet vessel commissioned.")))
	for vessel: Dictionary in s.fleet_ships:
		_text("%s / system %d / hull %.0f%%" % [vessel.name, vessel.system, vessel.hull], 17)
		if game.fleet_actors.has(str(vessel.id)):
			_button("APPROACH LOCAL PATROL", game.approach_fleet_ship.bind(str(vessel.id)), not game.pilot.flying or game.aboard)
		_button("REPAIR / %d CR" % ceili((100.0 - float(vessel.hull)) * 4.0), _act.bind(game.crew_operations().repair_fleet_ship.bind(str(vessel.id)), "Fleet repairs arranged."), float(vessel.hull) >= 100)
		for good: String in vessel.cargo:
			var amount: int = int(vessel.cargo[good])
			if amount <= 0: continue
			_button("SELL %d %s FROM %s" % [amount, good.to_upper(), vessel.name], _act.bind(game.sell_fleet_cargo.bind(str(vessel.id), good, amount), "Fleet cargo sold."), game.pilot.flying or game.aboard or int(vessel.system) != s.system_index)
	if s.crew.is_empty():
		_text("Hire crew in Enterprise before assigning orders.", 16, InterfaceTheme.GOLD)
		_button("RECRUIT CREW", show_page.bind("company"))
		return
	_text("CURRENT ORDERS", 13, InterfaceTheme.CYAN)
	for member: Dictionary in s.crew:
		var row := _row()
		var order: Dictionary = s.crew_orders.get(member.id, {})
		var text := "%s / %s" % [member.name, "Available" if order.is_empty() else str(order.get("kind", "Order")).capitalize() + " / " + ("Paused" if order.get("paused", false) else str(order.get("phase", "Active")))]
		var label := InterfaceTheme.label(text, 16)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var cancel := InterfaceTheme.button("CANCEL ORDER", _act.bind(game.crew_operations().cancel.bind(str(member.id)), "Order cancelled; unused escrow returned. Fleet cargo retained."))
		cancel.disabled = order.is_empty()
		row.add_child(cancel)
	_text("ISSUE ORDER", 13, InterfaceTheme.CYAN)
	var assignment := _row()
	var crew_choice := _choice(assignment, s.crew, "name", "id")
	var ship_choice := _choice(assignment, s.fleet_ships, "name", "id")
	var settings := _row()
	var destination_field := SpinBox.new()
	destination_field.prefix = "System "
	destination_field.max_value = Universe.SYSTEM_LIMIT - 1
	destination_field.value = s.system_index
	destination_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_child(destination_field)
	var goods_choice := OptionButton.new()
	for good: String in GameState.GOODS:
		goods_choice.add_item(good.capitalize())
		goods_choice.set_item_metadata(goods_choice.item_count - 1, good)
	settings.add_child(goods_choice)
	var quantity := SpinBox.new()
	quantity.prefix = "Cargo "
	quantity.custom_minimum_size.x = 155
	quantity.min_value = 1
	quantity.max_value = 25
	quantity.value = 5
	settings.add_child(quantity)
	var quote_label := _text("Select a vessel, commodity and destination to quote the route.", 15, InterfaceTheme.GOLD)
	_button("QUOTE ROUTE", func():
		var quote: Dictionary = game.crew_operations().route_quote(str(goods_choice.get_selected_metadata()), int(destination_field.value), int(quantity.value), str(ship_choice.get_selected_metadata()) if not s.fleet_ships.is_empty() else "")
		quote_label.text = ("Reserve %d CR / Estimated gross trading margin %d CR, before wages. Market prices can change." % [quote.escrow, quote.expected_profit]) if quote.ok else str(quote.message))
	var orders := _row()
	var trade := InterfaceTheme.button("TRADE ROUTE", func():
		_act(game.crew_operations().assign_trade_route.bind(str(crew_choice.get_selected_metadata()), str(ship_choice.get_selected_metadata()), str(goods_choice.get_selected_metadata()), int(destination_field.value), int(quantity.value)), "Trade route ordered."))
	trade.disabled = s.fleet_ships.is_empty()
	orders.add_child(trade)
	var patrol := InterfaceTheme.button("PATROL SYSTEM", func():
		_act(game.crew_operations().assign_patrol.bind(str(crew_choice.get_selected_metadata()), str(ship_choice.get_selected_metadata()), int(destination_field.value)), "Patrol ordered."))
	patrol.disabled = s.fleet_ships.is_empty()
	orders.add_child(patrol)
	if not s.stations.is_empty():
		var property_row := _row()
		var station_choice := OptionButton.new()
		station_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for station: Dictionary in s.stations: station_choice.add_item(str(station.name))
		property_row.add_child(station_choice)
		property_row.add_child(InterfaceTheme.button("MANAGE STATION", func():
			_act(game.crew_operations().assign_station_manager.bind(str(crew_choice.get_selected_metadata()), station_choice.selected), "Station manager assigned.")))
	_button("REFRESH REPORTS", refresh)
	_button("BACK TO ENTERPRISE", show_page.bind("company"))

func _recovery() -> void:
	heading.text = "RESCUE & RECOVERY"
	var s: GameState = game.state
	var recovery: Dictionary = s.recovery
	_text("Ship destruction leaves recoverable cargo and hull salvage. Insurance retains your design at partial hull; without coverage, rescue restores the same design at lower hull and a higher deductible. Unpaid deductibles remain as debt.", 17)
	_text("COVERAGE & LIABILITY", 13, InterfaceTheme.CYAN)
	var covered: bool = int(recovery.get("insurance_until_day", -1)) >= s.day
	_text("%s / Rescue debt %d CR" % ["Covered through day %d" % recovery.insurance_until_day if covered else "No active insurance", int(recovery.get("debt", 0))], 20)
	_button("INSURE 30 DAYS / %d CR" % ShipRecovery.insurance_cost(s), _act.bind(game.purchase_insurance, "Insurance coverage purchased."), game.pilot.flying or game.aboard)
	var debt: int = int(recovery.get("debt", 0))
	_button("PAY RESCUE DEBT / %d CR" % mini(debt, s.credits), _act.bind(ShipRecovery.repay_debt.bind(s, mini(debt, s.credits)), "Rescue debt payment recorded."), debt <= 0 or s.credits <= 0)
	_text("WRECK BEACONS", 13, InterfaceTheme.CYAN)
	var wrecks: Array = recovery.get("wrecks", [])
	if wrecks.is_empty(): _text("No wreck beacons recorded.", 16, InterfaceTheme.MUTED)
	for wreck: Dictionary in wrecks:
		var here: bool = int(wreck.system) == s.system_index and int(wreck.surface) == game.surface_index
		var local_point: Variant = game._wreck_position(wreck)
		var distance: float = game.pilot.position.distance_to(local_point) if here and local_point != null else INF
		var units: int = 0
		for amount: Variant in wreck.get("cargo", {}).values(): units += int(amount)
		_text("%s / system %d / %s / %d cargo units / hull salvage %d CR" % [wreck.id, wreck.system, "%.0f m" % distance if here else "Remote beacon", units, 0 if wreck.get("salvaged", false) else int(wreck.get("salvage_value", 0))], 17)
		var controls := _row()
		var cruise := InterfaceTheme.button("APPROACH", game.approach_wreck.bind(str(wreck.id)))
		cruise.disabled = not here or not game.pilot.flying or game.aboard
		controls.add_child(cruise)
		var recover := InterfaceTheme.button("RECOVER CARGO", _act.bind(game.recover_wreck.bind(str(wreck.id), false), "Available cargo recovered."))
		recover.disabled = not here or distance > (80.0 if game.pilot.flying else 8.0) or game.aboard or units <= 0
		controls.add_child(recover)
		var salvage := InterfaceTheme.button("SALVAGE HULL", _act.bind(game.recover_wreck.bind(str(wreck.id), true), "Wreck salvaged."))
		salvage.disabled = not here or distance > (80.0 if game.pilot.flying else 8.0) or game.aboard or bool(wreck.get("salvaged", false))
		controls.add_child(salvage)
	_button("REFRESH BEACONS", refresh)
	_button("BACK TO EXCHANGE", show_page.bind("market"))
