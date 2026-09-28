class_name CommandDeck
extends Control

var game: Node3D
var page: String = "overview"
var hull_family: String = "pathfinder"
var content: VBoxContainer
var heading: Label
var feedback: Label
var subtitle: Label
var tabs: Dictionary = {}
var destination: int = 0
var navigation_info: Label
var _clock_label := ""
var balance_label: Label
var survey_catalog: Dictionary = {}
var survey_labels: Array[Label] = []
var fleet_layout_id: String = ""
var fleet_layout_designer: ShipDesigner
var fleet_room_refit: Button
var fleet_panel_refit: Button
var fleet_module_refit: Button
var fleet_module_choice: OptionButton
var fleet_layout_blocked: bool = false
var fleet_layout_reason: String = ""

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
	scroll.follow_focus = true
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

func show_page(value: String = "overview") -> void:
	page = value
	fleet_layout_designer = null
	fleet_room_refit = null
	fleet_panel_refit = null
	fleet_module_refit = null
	fleet_module_choice = null
	survey_catalog = {}
	survey_labels.clear()
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
		"survey": _survey()
		"market": _market()
		"shipyard": _shipyard()
		"hulls": _hull_families()
		"contracts": _contracts()
		"company": _company()
		"fleet": _fleet()
		"fleet_layout": _fleet_layout()
		"recovery": _recovery()
		"factions": _factions()
		"stations": _stations()
		"settings": _settings()

func _process(_delta: float) -> void:
	if visible:
		_update_clock()
		if page == "fleet_layout" and is_instance_valid(fleet_layout_designer) and is_instance_valid(fleet_room_refit) and is_instance_valid(fleet_panel_refit) and is_instance_valid(fleet_module_refit):
			var occupied := false
			for module: Dictionary in fleet_layout_designer.modules:
				if Vector3i(module.x, module.y, module.z) == fleet_layout_designer.selected_cell:
					occupied = true
					var vessel: Dictionary = game.crew_operations()._ship(fleet_layout_id)
					if not vessel.is_empty():
						var price := CrewOrders.equipment_refit_price(vessel,str(module.kind),str(fleet_module_choice.get_selected_metadata()))
						fleet_module_refit.text = "REFIT / %d CR" % price if price >= 0 else "REFIT / REFUND %d CR" % -price
					break
			fleet_room_refit.disabled = fleet_layout_blocked or not occupied
			fleet_panel_refit.disabled = fleet_layout_blocked or not occupied
			fleet_module_refit.disabled = fleet_layout_blocked or not occupied

func _update_clock() -> void:
	var state: GameState = game.state
	var text := "%03d %s" % [state.day, state.clock_text()]
	if text == _clock_label: return
	_clock_label = text
	if page == "survey" and not survey_catalog.is_empty(): _update_survey()
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
	if game.aboard_cruise or game.pilot.autopilot_active:
		var cruise := _row()
		cruise.add_child(InterfaceTheme.button("STOP CRUISE", func(): game.stop_cruise(); refresh()))
	_text("FLIGHT & FOOT CONTROLS", 13, InterfaceTheme.CYAN)
	_text("WASD move · mouse look · Shift boost/sprint · Space/Ctrl altitude\nQ/R roll · B brake · E board/dock/interact · Left click fire · J navigation\nTab command deck · F5 save · F9 load", 16, InterfaceTheme.MUTED)
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
	_button("INSPECT SYSTEM PHYSICS", show_page.bind("survey"))
	_button("RECOVERY BEACONS", show_page.bind("recovery"))
	_text("LOCAL SYSTEM / SURFACE APPROACH", 13, InterfaceTheme.CYAN)
	_button("CRUISE TO ORBITAL DOCK", game.approach_public_station, not game.pilot.flying or game.aboard)
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

func _survey() -> void:
	heading.text = "PHYSICAL SYSTEM SURVEY"
	survey_catalog = CelestialSystem.generate(destination)
	var star: Dictionary = survey_catalog.star
	_text("%s / %s%s" % [Universe.system_data(destination).name, star.kind, " within a nebula" if star.embedded_nebula else ""], 22, InterfaceTheme.CYAN)
	if star.kind == "Black Hole":
		_text("Mass %.2f solar / Event horizon %.1f km\nNon-rotating, inactive model; accretion radiation excluded." % [star.mu_m3_s2 / CelestialPhysics.SOLAR_MU, star.radius_m / 1000.0], 17)
	else:
		_text("Mass %.2f solar / Radius %.0f km / Effective temperature %.0f K\nLuminosity %.4f solar" % [star.mu_m3_s2 / CelestialPhysics.SOLAR_MU, star.radius_m / 1000.0, star.temperature_k, star.luminosity_w / CelestialPhysics.SOLAR_LUMINOSITY_W], 17)
	_text("Orbital and radiation model. Flight locations currently remain compressed and stationary. Equilibrium temperature excludes atmosphere warming and internal heat.", 16, InterfaceTheme.GOLD)
	for body: Dictionary in survey_catalog.planets:
		_text(str(body.name).to_upper() + " / " + str(body.kind), 16, InterfaceTheme.CYAN)
		survey_labels.append(_text("", 17))
	if survey_catalog.planets.is_empty(): _text("No planets catalogued in this system.")
	_update_survey()
	_button("RETURN TO NAVIGATION", show_page.bind("navigation"))

func _update_survey() -> void:
	# Physical time advances one second per active second, separately from the economy calendar.
	var seconds: float = game.state.ephemeris_seconds
	for i in survey_labels.size():
		var body: Dictionary = survey_catalog.planets[i]
		var sample := CelestialSystem.sample(survey_catalog, i, seconds)
		if sample.is_empty():
			survey_labels[i].text = "Orbital estimate unavailable."
			continue
		survey_labels[i].text = "Radius %.0f km / Gravity %.2f g / Orbit %.3f AU\nYear %.1f days / Speed %.1f km/s / Equilibrium %.0f K\nReceived radiation %.1f W/m² / Reflectivity %.0f%%" % [body.radius_m / 1000.0, body.surface_gravity_mps2 / FlightDynamics.STANDARD_GRAVITY, sample.distance_m / CelestialPhysics.AU_M, body.period_seconds / 86400.0, sample.speed_mps / 1000.0, sample.equilibrium_temperature_k, sample.irradiance_w_m2, body.bond_albedo * 100.0]
		var surface := CelestialSystem.surface_sample(survey_catalog, i, Vector3(float(body.radius_m), 0.0, 0.0), seconds)
		if not surface.is_empty():
			survey_labels[i].text += "\nSpin %.1f hours / Axial tilt %.1f° / Inclination %.1f°\nEquator, longitude 0°: %s / Direct light %.1f W/m² before atmosphere" % [body.rotation_seconds / 3600.0, rad_to_deg(body.axial_tilt_rad), rad_to_deg(body.inclination_rad), "Day" if surface.sun_above_horizon else "Night", surface.direct_irradiance_w_m2]

func _select_destination(address: int) -> void:
	destination = address
	var data: Dictionary = Universe.system_data(address)
	navigation_info.text = "%s  /  %s\n%s  •  %d planets  •  Address %d" % [data.name, data.star_type, data.faction, data.planets.size(), address]

func _market() -> void:
	heading.text = "ORBITAL EXCHANGE"
	var s: GameState = game.state
	_text("Hold %d / %d    •    Cash %d CR" % [s.cargo_total(), s.ship_stats().cargo_capacity, s.credits], 21, InterfaceTheme.CYAN)
	_text("Prices respond to supply. Button prices include the entire order.", 14, InterfaceTheme.MUTED)
	if game.pilot.flying or game.aboard: _text("Dock to trade commodities.", 16, InterfaceTheme.GOLD)
	for good: String in GameState.GOODS:
		var row := _row()
		var label := InterfaceTheme.label("%s\n%d in market  •  %d in hold" % [good.capitalize(), s.market_stock(good), int(s.cargo.get(good, 0))], 17)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		for quantity in [1, 10]:
			var total: int = s.player_trade_total(good, quantity, true)
			var buy := InterfaceTheme.button("BUY %d · %s" % [quantity, ("%d CR" % total) if total >= 0 else "NO STOCK"], _act.bind(s.trade.bind(good, quantity, true), "Cargo purchased."))
			buy.disabled = game.pilot.flying or game.aboard or total < 0
			row.add_child(buy)
		var sale: int = s.player_trade_total(good, 1, false)
		var sell := InterfaceTheme.button("SELL 1 · %s" % (("%d CR" % sale) if sale >= 0 else "FULL"), _act.bind(s.trade.bind(good, 1, false), "Cargo sold."))
		sell.disabled = game.pilot.flying or game.aboard or sale < 0
		row.add_child(sell)
	var services := _row()
	services.add_child(InterfaceTheme.button("REFUEL", _act.bind(s.refuel, "Fuel tanks replenished.")))
	services.add_child(InterfaceTheme.button("REPAIR", _act.bind(s.repair, "Hull restored.")))
	for child in services.get_children(): child.disabled = game.pilot.flying or game.aboard
	_button("INSURANCE & WRECK RECOVERY", show_page.bind("recovery"))

func _ship_stats_line(state: GameState) -> String:
	var stats := state.ship_stats()
	return "LOADED %.1f t   /   POWER %d / %d used   /   CARGO %d   /   SPEED %d m/s\nTHRUST %.2f MN   /   ACCELERATION %.2f g   /   BOOST %.2f g\nReactor reserve permits %.0f%% extra engine thrust.\nDRIVE %.0f K   /   RADIATOR AREA %.0f m²" % [stats.loaded_mass_kg / 1000.0, stats.power_demand, stats.power_generation, stats.cargo_capacity, stats.speed, stats.thrust_newtons / 1000000.0, stats.acceleration_mps2 / FlightDynamics.STANDARD_GRAVITY, stats.boost_acceleration_mps2 / FlightDynamics.STANDARD_GRAVITY, (stats.boost_multiplier - 1.0) * 100.0, state.drive_temperature_k, stats.radiator_area_m2]

func _hull_families() -> void:
	heading.text = "HULL LAYOUTS"
	_button("BACK TO SHIP ARCHITECT", show_page.bind("shipyard"))
	var choice := OptionButton.new()
	for id: String in ShipBlueprint.FAMILIES:
		choice.add_item(id.capitalize())
		choice.set_item_metadata(choice.item_count-1,id)
		if id == hull_family: choice.select(choice.item_count-1)
	choice.item_selected.connect(func(index: int):
		hull_family = str(choice.get_item_metadata(index))
		show_page("hulls"))
	content.add_child(choice)
	var blueprint := ShipBlueprint.family(hull_family)
	var preview := ShipDesigner.new()
	preview.read_only = true
	preview.modules = blueprint.modules.duplicate(true)
	preview.layout = blueprint.layout.duplicate(true)
	var rooms: Dictionary = {}
	for module: Dictionary in blueprint.modules:
		var key := ShipLayout.cell_key(Vector3i(module.x,module.y,module.z))
		var room: String = blueprint.layout.rooms.get(key,ShipLayout.default_room(module.kind))
		rooms[room] = int(rooms.get(room,0))+1
	var room_summary: Array[String] = []
	for room: String in rooms: room_summary.append("%d %s" % [rooms[room],room])
	_text("WALKABLE / " + ", ".join(room_summary),15,InterfaceTheme.CYAN)
	_text("Replaces your current assembly and room fittings. Cargo and crew transfer if capacity permits. Hull and shield condition, fuel and drive heat carry over. Custom construction remains available afterward.",15,InterfaceTheme.MUTED)
	var quote: Dictionary = game.state.hull_family_quote(hull_family)
	if not str(quote.error).is_empty():
		_text(str(quote.error),16,InterfaceTheme.GOLD)
		content.add_child(preview)
		return
	_text("Assembly %d CR / trade-in %d CR / %s %d CR" % [quote.price,quote.trade_in,"due" if quote.net >= 0 else "refund",absi(quote.net)],18,InterfaceTheme.CYAN)
	var chosen := hull_family
	var purchase := InterfaceTheme.button("REFIT TO " + chosen.to_upper(),_act.bind(game.refit_hull_family.bind(chosen),"Hull layout refitted."))
	purchase.set_meta("hull_family_refit",chosen)
	purchase.disabled = game.pilot.flying or game.aboard or game.session.connected or game.state.credits < quote.net
	content.add_child(purchase)
	content.add_child(preview)


func _shipyard() -> void:
	heading.text = "SHIP ARCHITECT"
	var s: GameState = game.state
	var stats_label := _text(_ship_stats_line(s), 15, InterfaceTheme.CYAN)
	_button("COMPARE HULL LAYOUTS", show_page.bind("hulls"))
	_text("Choose a deck and cell, then install a module. Every module must connect to the ship. Essential systems and cargo capacity are protected. Radiators cool faster when exposed; adjacent modules, armor and windows block their panels.", 15, InterfaceTheme.MUTED)
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
			stats_label.text = _ship_stats_line(s)
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
		_station_rooms(index, station)
		var recipe: Dictionary = game.crew_operations().station_recipe(index)
		var inputs: PackedStringArray = []
		for good: String in recipe.inputs: inputs.append("%d %s" % [recipe.inputs[good], good])
		_text("INDUSTRY / %s / up to %d units per 15 minutes with an assigned engineer" % [str(recipe.good).capitalize(), recipe.batch_limit], 15, InterfaceTheme.CYAN)
		_text("Per unit: " + (", ".join(inputs) if not inputs.is_empty() else "local extraction / farming") + ". Wages apply while waiting for supplies.", 14, InterfaceTheme.MUTED)
		for good: String in recipe.inputs:
			var supply := _row()
			supply.add_child(InterfaceTheme.label("%s / %d in storage" % [good.capitalize(), int(station.get("stock", {}).get(good, 0))], 16))
			for amount: int in [1, 10]:
				var button := InterfaceTheme.button("SUPPLY %d" % amount, _act.bind(game.supply_station_stock.bind(index, good, amount), "Supplies delivered to station storage."))
				button.disabled = game.pilot.flying or game.aboard or game.docked_station != index or int(station.system) != s.system_index or int(s.cargo.get(good, 0)) < amount or int(station.get("stock", {}).get(good, 0)) > CrewOrders.MAX_STOCK - amount
				supply.add_child(button)
		for good: String in station.get("stock", {}):
			var amount: int = int(station.stock[good])
			if amount <= 0: continue
			var load_amount: int = mini(amount, int(s.ship_stats().cargo_capacity) - s.cargo_total())
			_button("LOAD %d / %d %s STORED" % [load_amount, amount, good.to_upper()], _act.bind(game.collect_station_stock.bind(index, good, load_amount), "Station stock delivered to your hold."), load_amount <= 0 or game.pilot.flying or game.aboard or game.docked_station != index or int(station.system) != s.system_index)

func _station_rooms(index: int, station: Dictionary) -> void:
	var rooms := StationLayout.rooms_for(station)
	_text("CONCOURSE / %d OF %d ROOMS" % [rooms.size(), StationLayout.MAX_ROOMS], 13, InterfaceTheme.CYAN)
	var row := _row()
	var room_selector := OptionButton.new()
	room_selector.set_meta("station_room_selector", index)
	for room_index in rooms.size():
		room_selector.add_item("%02d / %s" % [room_index + 1, rooms[room_index].to_upper()])
	room_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(room_selector)
	var kind_selector := OptionButton.new()
	kind_selector.set_meta("station_room_kind", index)
	var kinds: Array[String] = ["market", "company", "shipyard", "contracts", "factions", "stations"]
	for kind in kinds: kind_selector.add_item(kind.to_upper())
	kind_selector.select(kinds.find(rooms[0]))
	row.add_child(kind_selector)
	room_selector.item_selected.connect(func(room_index: int): kind_selector.select(kinds.find(rooms[room_index])))
	var blocked: bool = game.session.connected or int(station.system) != game.state.system_index or (game.docked_station == index and not game.pilot.flying)
	var change := InterfaceTheme.button("REFIT / 250 CR", func(): _act(game.edit_station_rooms.bind(index, "set", room_selector.selected, kinds[kind_selector.selected]), "Room refitted."))
	change.set_meta("station_room_refit", index)
	change.disabled = blocked
	row.add_child(change)
	var actions := _row()
	var append := InterfaceTheme.button("ADD ROOM / 1,000 CR + 5 ALLOYS", func(): _act(game.edit_station_rooms.bind(index, "add", 0, kinds[kind_selector.selected]), "Concourse room added."))
	append.set_meta("station_room_add", index)
	append.disabled = blocked or rooms.size() >= StationLayout.MAX_ROOMS
	actions.add_child(append)
	var remove := InterfaceTheme.button("REMOVE LAST / +500 CR", func(): _act(game.edit_station_rooms.bind(index, "remove"), "Last room salvaged."))
	remove.set_meta("station_room_remove", index)
	remove.disabled = blocked or rooms.size() <= 1
	actions.add_child(remove)
	if blocked: _text("Room construction requires this system, outside the station and outside a multiplayer visit.", 14, InterfaceTheme.MUTED)

func _settings() -> void:
	heading.text = "FLIGHT SETTINGS"
	var assist := CheckButton.new()
	assist.text = "Flight assist — match speed and brake when controls are released"
	assist.button_pressed = game.pilot.flight_assist_enabled
	assist.toggled.connect(func(value: bool):
		game.pilot.flight_assist_enabled = value
		game.save_settings())
	content.add_child(assist)
	_text("Switch off for inertial flight: thrust changes velocity; releasing controls coasts without fuel use. B commands braking in either mode. Autopilot keeps its own guidance.", 16, InterfaceTheme.MUTED)
	_button("BRAKE SHIP / B", game.stop_cruise, not game.pilot.flying and not game.aboard)
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
	_text("Give named crew persistent orders. Local trade captains fly between the berth and departure point before their timed transaction can settle; distant voyages remain strategic. Patrols fight pirates in local space and use strategic simulation in distant systems; managers operate owned stations. Unpaid local patrols stop engaging but remain vulnerable. Operations advance while this world is hosted, never while closed.", 17)
	_text("FLEET REGISTRY", 13, InterfaceTheme.CYAN)
	var purchase := _row()
	var ship_name := LineEdit.new()
	ship_name.placeholder_text = "Fleet vessel name"
	ship_name.max_length = 32
	ship_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	purchase.add_child(ship_name)
	var hull_choice := OptionButton.new()
	for family_id: String in [""] + ShipBlueprint.FAMILIES:
		var quote := CrewOrders.commission_quote(family_id)
		hull_choice.add_item("%s / %d CR / %d cargo" % ["Utility" if family_id.is_empty() else family_id.capitalize(), quote.price, quote.capacity])
		hull_choice.set_item_metadata(hull_choice.item_count - 1, family_id)
	purchase.add_child(hull_choice)
	purchase.add_child(InterfaceTheme.button("COMMISSION", func(): _act(game.crew_operations().purchase_ship.bind(ship_name.text, str(hull_choice.get_item_metadata(hull_choice.selected))), "Fleet vessel commissioned.")))
	if not s.fleet_ships.is_empty():
		_text("DOCKSIDE CARGO TRANSFER", 13, InterfaceTheme.CYAN)
		var transfer_row := _row()
		var transfer_ship := _choice(transfer_row, s.fleet_ships, "name", "id")
		transfer_ship.set_meta("fleet_cargo_ship", true)
		var transfer_good := OptionButton.new()
		for good: String in GameState.GOODS:
			transfer_good.add_item(good.capitalize())
			transfer_good.set_item_metadata(transfer_good.item_count - 1, good)
		transfer_good.set_meta("fleet_cargo_good", true)
		transfer_row.add_child(transfer_good)
		var transfer_quantity := SpinBox.new()
		transfer_quantity.min_value = 1
		transfer_quantity.max_value = 10000
		transfer_quantity.value = 1
		transfer_quantity.prefix = "Units "
		transfer_quantity.set_meta("fleet_cargo_quantity", true)
		transfer_row.add_child(transfer_quantity)
		var hold_summary := _text("", 14, InterfaceTheme.MUTED)
		var update_holds := func(_index: int):
			var vessel: Dictionary = game.crew_operations()._ship(str(transfer_ship.get_selected_metadata()))
			var good := str(transfer_good.get_selected_metadata())
			hold_summary.text = "%s: your hold %d / fleet hold %d. Docked, idle vessels only; no sale or fee." % [good.capitalize(), int(s.cargo.get(good, 0)), int(vessel.cargo.get(good, 0))]
		transfer_ship.item_selected.connect(update_holds)
		transfer_good.item_selected.connect(update_holds)
		update_holds.call(0)
		var transfer_actions := _row()
		for to_fleet: bool in [true, false]:
			var transfer_button := InterfaceTheme.button("LOAD FLEET HOLD" if to_fleet else "COLLECT TO MY HOLD", func():
				_act(game.transfer_fleet_cargo.bind(str(transfer_ship.get_selected_metadata()), str(transfer_good.get_selected_metadata()), int(transfer_quantity.value), to_fleet), "Cargo transferred."))
			transfer_button.set_meta("fleet_cargo_direction", to_fleet)
			transfer_button.disabled = game.session.connected or game.pilot.flying or game.aboard or game.surface_index >= 0 or game.manual_planet >= 0
			transfer_actions.add_child(transfer_button)
	for vessel: Dictionary in s.fleet_ships:
		_text("%s / %s / system %d / hull %.0f%% / drive %.0f K" % [vessel.name, str(vessel.get("hull_family", "utility")).capitalize(), vessel.system, vessel.hull, float(vessel.get("drive_temperature_k", 450.0))], 17)
		if str(vessel.get("hull_family", "")) in ShipBlueprint.FAMILIES:
			var defense: Dictionary = vessel.get("defense", {})
			_text("Shield charge %.0f / recharge delay %.1f s" % [float(defense.get("charge", 0.0)), float(defense.get("delay", 0.0))], 14, InterfaceTheme.MUTED)
			var layout_button := _button("ROOM & HULL REFITS", func():
				fleet_layout_id = str(vessel.id)
				show_page("fleet_layout"))
			layout_button.set_meta("fleet_layout_id", str(vessel.id))
			var boarding_issue: String = game.fleet_boarding_issue(str(vessel.id))
			_button("INSPECT DOCKED INTERIOR", game.enter_interior.bind(str(vessel.id)), not boarding_issue.is_empty()).tooltip_text = boarding_issue
		if game.fleet_actors.has(str(vessel.id)):
			_button("APPROACH LOCAL VESSEL", game.approach_fleet_ship.bind(str(vessel.id)), not game.pilot.flying or game.aboard)
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
		if order.get("kind", "") == "trade":
			var cost: int = int(order.get("purchase_cost", -1))
			if order.has("delivery_station"): text += "\nSupplying " + str(s.stations[int(order.delivery_station)].name)
			text += "\nCargo purchase cost: " + (("%d CR" % cost) if cost >= 0 else "unknown / carried or legacy cargo")
		var label := InterfaceTheme.label(text, 16)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var cancel := InterfaceTheme.button("CANCEL ORDER", _act.bind(game.crew_operations().cancel.bind(str(member.id)), "Order cancelled; unused escrow returned. Fleet cargo retained."))
		cancel.disabled = order.is_empty()
		row.add_child(cancel)
	_text("ISSUE ORDER", 13, InterfaceTheme.CYAN)
	var assignment := _row()
	var crew_choice := _choice(assignment, s.crew, "name", "id")
	for index in crew_choice.item_count:
		if str(crew_choice.get_item_metadata(index)) == game.crew_focus_id: crew_choice.select(index)
	var ship_choice := _choice(assignment, s.fleet_ships, "name", "id")
	var defense := _row()
	defense.add_child(InterfaceTheme.button("DEFEND MY SHIP", func():
		_act(game.crew_operations().assign_ship_defense.bind(str(crew_choice.get_selected_metadata())), "Gunner assigned to your ship's weapons.")))
	_text("Ship defense needs a gunner and an exposed weapon module. The gunner engages hostile NPC ships while flying or walking aboard; cover and your own hull can block fire. Wages are due every five hosted minutes. Cancel the order to hold fire.", 14, InterfaceTheme.MUTED)
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
		var supply := InterfaceTheme.button("SUPPLY STATION", func():
			_act(game.crew_operations().assign_station_supply.bind(str(crew_choice.get_selected_metadata()), str(ship_choice.get_selected_metadata()), station_choice.selected, str(goods_choice.get_selected_metadata()), int(quantity.value)), "Recurring station supply route assigned."))
		supply.disabled = s.fleet_ships.is_empty()
		property_row.add_child(supply)
		property_row.add_child(InterfaceTheme.button("MANAGE STATION", func():
			_act(game.crew_operations().assign_station_manager.bind(str(crew_choice.get_selected_metadata()), station_choice.selected), "Station manager assigned.")))
		_text("Supply routes use the selected ship, commodity and cargo quantity. They buy from the ship’s starting system and deliver to the selected station. Each pickup reserves credits up to the initial cargo budget, plus normal crew wages, until cancelled.", 14, InterfaceTheme.MUTED)
	_button("REFRESH REPORTS", refresh)
	_button("BACK TO ENTERPRISE", show_page.bind("company"))

func _fleet_layout() -> void:
	heading.text = "FLEET ROOM & HULL REFITS"
	var vessel: Dictionary = {}
	for candidate: Dictionary in game.state.fleet_ships:
		if str(candidate.get("id", "")) == fleet_layout_id:
			vessel = candidate
			break
	_button("BACK TO FLEET", show_page.bind("fleet"))
	if vessel.is_empty():
		_text("Fleet vessel no longer exists.", 16, InterfaceTheme.GOLD)
		return
	var blueprint: Dictionary = ShipBlueprint.for_vessel(vessel)
	if blueprint.is_empty():
		_text("This vessel has no saved module layout.", 16, InterfaceTheme.GOLD)
		return
	_text("%s / %s hull" % [str(vessel.get("name", "Unnamed vessel")), str(vessel.get("hull_family", "custom")).capitalize()], 18, InterfaceTheme.CYAN)
	fleet_layout_designer = ShipDesigner.new()
	fleet_layout_designer.read_only = true
	fleet_layout_designer.modules = blueprint.modules.duplicate(true)
	fleet_layout_designer.layout = vessel.get("layout", blueprint.layout).duplicate(true)
	fleet_layout_reason = game.fleet_boarding_issue(fleet_layout_id)
	fleet_layout_blocked = not fleet_layout_reason.is_empty()
	if fleet_layout_blocked:
		_text(fleet_layout_reason, 16, InterfaceTheme.GOLD)
	var room_row := _row()
	room_row.add_child(InterfaceTheme.label("ROOM", 13, InterfaceTheme.CYAN))
	var room_choice := OptionButton.new()
	room_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for room_type: String in ShipLayout.ROOM_TYPES:
		room_choice.add_item(room_type.capitalize())
		room_choice.set_item_metadata(room_choice.item_count - 1, room_type)
	room_choice.set_meta("room_choice", true)
	room_row.add_child(room_choice)
	fleet_room_refit = InterfaceTheme.button("REFIT ROOM / %d CR" % ShipLayout.ROOM_REFIT_COST, func():
		var value := str(room_choice.get_selected_metadata())
		_act(game.refit_fleet_layout.bind(fleet_layout_id, fleet_layout_designer.selected_cell, value, ""), "Fleet room refitted."))
	fleet_room_refit.set_meta("fleet_room_refit", true)
	fleet_room_refit.set_meta("room_choice", room_choice)
	fleet_room_refit.disabled = fleet_layout_blocked
	room_row.add_child(fleet_room_refit)
	var panel_row := _row()
	panel_row.add_child(InterfaceTheme.label("HULL", 13, InterfaceTheme.CYAN))
	var face_choice := OptionButton.new()
	for face: String in ShipLayout.FACES:
		face_choice.add_item({"+x":"Right", "-x":"Left", "+y":"Ceiling", "-y":"Floor", "+z":"Rear", "-z":"Front"}[face] + " (" + face + ")")
		face_choice.set_item_metadata(face_choice.item_count - 1, face)
	face_choice.set_meta("face_choice", true)
	panel_row.add_child(face_choice)
	var panel_choice := OptionButton.new()
	panel_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for panel_type: String in ShipLayout.PANEL_COSTS:
		panel_choice.add_item("%s / %d CR" % [panel_type.capitalize(), ShipLayout.PANEL_COSTS[panel_type]])
		panel_choice.set_item_metadata(panel_choice.item_count - 1, panel_type)
	panel_choice.set_meta("panel_choice", true)
	panel_row.add_child(panel_choice)
	fleet_panel_refit = InterfaceTheme.button("REFIT HULL FACE", func():
		var value := str(panel_choice.get_selected_metadata())
		var face := str(face_choice.get_selected_metadata())
		_act(game.refit_fleet_layout.bind(fleet_layout_id, fleet_layout_designer.selected_cell, value, face), "Fleet hull face refitted."))
	fleet_panel_refit.set_meta("fleet_panel_refit", true)
	fleet_panel_refit.set_meta("face_choice", face_choice)
	fleet_panel_refit.set_meta("panel_choice", panel_choice)
	fleet_panel_refit.disabled = fleet_layout_blocked
	panel_row.add_child(fleet_panel_refit)
	var module_row := _row()
	module_row.add_child(InterfaceTheme.label("EQUIPMENT", 13, InterfaceTheme.CYAN))
	fleet_module_choice = OptionButton.new()
	fleet_module_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for kind: String in ShipBlueprint.FLEET_EQUIPMENT:
		var cost: int = int(GameState.MODULES[kind].cost)
		fleet_module_choice.add_item("%s / %d CR" % [kind.capitalize(), cost])
		fleet_module_choice.set_item_metadata(fleet_module_choice.item_count - 1, kind)
	fleet_module_choice.set_meta("module_choice", true)
	module_row.add_child(fleet_module_choice)
	fleet_module_refit = InterfaceTheme.button("REFIT EQUIPMENT", func():
		_act(game.refit_fleet_module.bind(fleet_layout_id, fleet_layout_designer.selected_cell, str(fleet_module_choice.get_selected_metadata())), "Fleet equipment refitted."))
	fleet_module_refit.set_meta("fleet_module_refit", true)
	fleet_module_refit.set_meta("module_choice", fleet_module_choice)
	fleet_module_refit.disabled = fleet_layout_blocked
	module_row.add_child(fleet_module_refit)
	fleet_module_refit.tooltip_text = "New module cost minus 50% of current module value, adjusted for hull condition."
	content.add_child(fleet_layout_designer)

func _recovery() -> void:
	heading.text = "RESCUE & RECOVERY"
	var s: GameState = game.state
	var recovery: Dictionary = s.recovery
	_text("Ship destruction leaves recoverable cargo and hull salvage. Insurance retains your design at partial hull; without coverage, rescue restores the same design at lower hull and a higher deductible. Unpaid deductibles remain as debt.", 17)
	_text("COVERAGE & LIABILITY", 13, InterfaceTheme.CYAN)
	var fuel_fee := maxi(500, s.price("fuel") * 4)
	_text("Empty tank? Emergency delivery supplies 20 fuel. Unpaid delivery fees become rescue debt.", 16, InterfaceTheme.MUTED)
	_button("EMERGENCY FUEL / %d CR" % fuel_fee, _act.bind(s.emergency_refuel, "Emergency fuel delivered; unpaid fees recorded as rescue debt."), s.fuel > 0.01)
	var covered: bool = int(recovery.get("insurance_until_day", -1)) >= s.day
	_text("%s / Rescue debt %d CR" % ["Covered through day %d" % recovery.insurance_until_day if covered else "No active insurance", int(recovery.get("debt", 0))], 20)
	_button("INSURE 30 DAYS / %d CR" % ShipRecovery.insurance_cost(s), _act.bind(game.purchase_insurance, "Insurance coverage purchased."), game.pilot.flying or game.aboard)
	var debt: int = int(recovery.get("debt", 0))
	_button("PAY RESCUE DEBT / %d CR" % mini(debt, s.credits), _act.bind(ShipRecovery.repay_debt.bind(s, mini(debt, s.credits)), "Rescue debt payment recorded."), debt <= 0 or s.credits <= 0)
	_text("Disabled local fleet ships leave recoverable freight caches. Repairs do not restore that cargo. Crew rescue and hull repair remain service abstractions.", 16, InterfaceTheme.MUTED)
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
