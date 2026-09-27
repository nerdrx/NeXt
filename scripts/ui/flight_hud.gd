class_name FlightHUD
extends Control

var game: Node3D
var flash: float = 0.0
var hit_confirmation: float = 0.0
var message: String = ""
var message_time: float = 0.0
var flight_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func notify(text: String) -> void:
	message = text
	message_time = 6.0

func _process(delta: float) -> void:
	message_time = maxf(0, message_time - delta)
	flash = maxf(0, flash - delta * 2)
	hit_confirmation = maxf(0, hit_confirmation - delta)
	flight_time += delta
	queue_redraw()

func _word(at: Vector2, text: String, font_size: int = 16, color: Color = InterfaceTheme.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if game == null or game.state == null or game.pilot == null: return
	var state: GameState = game.state
	var pilot: Pilot = game.pilot
	var w: float = size.x
	var h: float = size.y
	var data: Dictionary = Universe.system_data(state.system_index)
	draw_rect(Rect2(0, 0, w, 88), Color(0.012, 0.028, 0.05, 0.73))
	_word(Vector2(32, 35), "N E X T", 25, InterfaceTheme.CYAN)
	_word(Vector2(178, 33), str(data.name).to_upper(), 18)
	_word(Vector2(178, 58), "%s   /   %s" % [data.star_type, data.faction], 13, InterfaceTheme.MUTED)
	_word(Vector2(w - 365, 32), "%s CR" % String.num_int64(state.credits), 21, InterfaceTheme.GOLD)
	_word(Vector2(w - 365, 57), "DAY %03d  %s   •   %d SYSTEMS CHARTED" % [state.day, state.clock_text(), state.visited.size()], 12, InterfaceTheme.MUTED)
	if game.ui_open: return
	var center := size * 0.5
	draw_line(center + Vector2(-10, 0), center + Vector2(-4, 0), InterfaceTheme.CYAN, 1.2)
	draw_line(center + Vector2(4, 0), center + Vector2(10, 0), InterfaceTheme.CYAN, 1.2)
	draw_line(center + Vector2(0, -10), center + Vector2(0, -4), InterfaceTheme.CYAN, 1.2)
	draw_circle(center, 1.5, InterfaceTheme.WHITE)
	if hit_confirmation > 0:
		for x in [-1, 1]:
			for y in [-1, 1]:
				var direction := Vector2(x, y)
				draw_line(center + direction * 9, center + direction * 16, InterfaceTheme.GOLD, 2.0)
	var stats: Dictionary = state.ship_stats()
	var hull_max: float = maxf(1.0, float(stats.max_hull))
	var shield_max: float = maxf(1.0, float(stats.max_shield))
	_draw_meter(Vector2(35, h - 131), "HULL" if pilot.flying else "SUIT", (game.suit_health / 100.0 if not pilot.flying else state.hull / hull_max), InterfaceTheme.GOLD)
	_draw_meter(Vector2(35, h - 98), "SHIELD", state.shield / shield_max, InterfaceTheme.CYAN)
	_draw_meter(Vector2(35, h - 65), "FUEL", state.fuel / 100.0, Color("b9bbf5"))
	_word(Vector2(w - 250, h - 105), "%03d m/s" % int(pilot.velocity.length()), 30, InterfaceTheme.CYAN)
	if pilot.flying or (game.aboard and is_instance_valid(game.coasting_hull)):
		var thrust_g: float = pilot.thrust_g if pilot.flying else game.coasting_hull.thrust_g
		_word(Vector2(w - 250, h - 131), "THRUST %.1f g" % thrust_g, 14, InterfaceTheme.GOLD)
	_word(Vector2(w - 250, h - 78), "CARGO  %d / %d" % [state.cargo_total(), int(stats.cargo_capacity)], 14, InterfaceTheme.MUTED)
	_word(Vector2(w - 250, h - 54), ("BRAKING" if pilot.braking else ("CRUISE AUTOPILOT" if pilot.autopilot_active else "FLIGHT ASSIST  ON")) if pilot.flying else "MAG BOOTS  ACTIVE", 13, InterfaceTheme.MUTED)
	_word(Vector2(w * 0.5 - 260, h - 24), "TAB  Command    E  Interact / dock    J  Navigation    F5  Save", 14, InterfaceTheme.MUTED)
	if pilot.flying:
		_draw_radar(Vector2(w - 130, 220))
		for peer_id: int in game.remote_ships:
			var ship: Node3D = game.remote_ships[peer_id]
			if not ship.visible: continue
			var profile: Dictionary = game.session.presence.get(peer_id, {})
			var agreed: bool = game.session.is_pvp_allowed() and bool(profile.get("pvp", false)) and bool(profile.get("flying", false))
			_draw_marker(ship.position, str(profile.get("name", "Pilot")) + (" / PVP" if agreed else " / PROTECTED"), Color("f08670") if agreed else InterfaceTheme.CYAN, pilot.camera)
		for index in game.colonies.size():
			var colony: Node3D = game.colonies[index]
			if not bool(colony.get_meta("spatial_culled", false)):
				_draw_marker(colony.to_global(colony.landing_position), str(game.world.planets[index].name).to_upper() + " PORT", InterfaceTheme.GOLD, pilot.camera)
		if game.terrain_planet >= 0:
			var body: Dictionary = game.world.planets[game.terrain_planet]
			var planet_center: Variant = game._planet_center(game.terrain_planet)
			if planet_center != null:
				var up: Vector3 = (pilot.position - planet_center).normalized()
				var altitude: float = pilot.position.distance_to(planet_center) - float(body.visual_radius) - PlanetTerrain.surface_height(up, game._terrain_seed(game.terrain_planet))
				_word(Vector2(w * 0.5 - 180, h - 120), "%s   ALT %d m" % [str(body.name).to_upper(), maxi(0, int(altitude))], 16, InterfaceTheme.CYAN)
				var landing_hint: String = "DESCEND BELOW 35 m TO LAND"
				if altitude <= 35:
					landing_hint = "REDUCE SPEED BELOW 20 m/s" if pilot.velocity.length() > 20 else "[E] LAND ON SURFACE"
				_word(Vector2(w * 0.5 - 180, h - 90), landing_hint, 16, InterfaceTheme.CYAN)
		if not bool(game.world.get_meta("spatial_culled", false)):
			_draw_marker(game.world.to_global(Vector3(0, 12, -70)), "ORBITAL DOCK", InterfaceTheme.CYAN, pilot.camera)
		for actor: Node3D in game.actors:
			if is_instance_valid(actor) and not bool(actor.get_meta("spatial_culled", false)) and actor.position.distance_to(pilot.position) < 2800:
				_draw_marker(actor.position, str(actor.get_meta("contact_name", actor.faction)).to_upper(), Color("f08670") if actor.faction == "pirate" else Color("75b9f1"), pilot.camera)
	else:
		_word(Vector2(w * 0.5 - 180, h - 90), ("" if game.aboard else "[E] ") + game.interaction_hint(), 17, InterfaceTheme.CYAN)
	if state.wanted > 0:
		_word(Vector2(w * 0.5 - 100, 113), "WANTED  /  %d" % state.wanted, 17, Color("ff8a70"))
	if message_time > 0:
		var width: float = minf(1000, message.length() * 9 + 40)
		var rect := Rect2(Vector2((w - width) * 0.5, 112), Vector2(width, 46))
		draw_style_box(InterfaceTheme.box(InterfaceTheme.PANEL, Color("376572"), 6, 8), rect)
		_word(rect.position + Vector2(18, 29), message, 16, InterfaceTheme.CYAN)
	if flash > 0: draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.15, 0.07, flash * 0.18))
	if game.jump_charge > 0:
		var amount: float = 1.0 - game.jump_charge / 3.0
		_word(center + Vector2(-145, 120), "FRAME SHIFT  /  CHARGING", 19, InterfaceTheme.CYAN)
		draw_rect(Rect2(center + Vector2(-180, 137), Vector2(360 * amount, 3)), InterfaceTheme.CYAN)
		for i in range(24):
			var angle: float = float(i) * TAU / 24.0 + flight_time * 0.03
			var dir := Vector2(cos(angle), sin(angle))
			draw_line(center + dir * (140 + i % 3 * 40), center + dir * (220 + amount * 300), Color(0.5, 0.8, 1, amount * 0.45), 1.2)

func _draw_meter(pos: Vector2, title: String, value: float, color: Color) -> void:
	_word(pos, title, 12, InterfaceTheme.MUTED)
	draw_rect(Rect2(pos + Vector2(68, -9), Vector2(180, 5)), Color("24374a"))
	draw_rect(Rect2(pos + Vector2(68, -9), Vector2(clampf(value, 0, 1) * 180, 5)), color)
	_word(pos + Vector2(258, 0), "%d%%" % int(value * 100), 12, color)

func _draw_marker(point: Vector3, title: String, color: Color, camera: Camera3D) -> void:
	if camera.is_position_behind(point): return
	var pos: Vector2 = camera.unproject_position(point)
	if pos.x < 20 or pos.y < 100 or pos.x > size.x - 20 or pos.y > size.y - 150: return
	var r: float = 13.0
	for side in [-1, 1]:
		draw_line(pos + Vector2(side * r, -r), pos + Vector2(side * r, r), color, 1)
		draw_line(pos + Vector2(side * r, -r), pos + Vector2(side * (r - 5), -r), color, 1)
		draw_line(pos + Vector2(side * r, r), pos + Vector2(side * (r - 5), r), color, 1)
	_word(pos + Vector2(18, 0), title, 11, color)
	_word(pos + Vector2(18, 16), "%d m" % int(camera.global_position.distance_to(point)), 11, InterfaceTheme.MUTED)

func _draw_radar(pos: Vector2) -> void:
	var radius: float = 75.0
	draw_circle(pos, radius, Color(0.02, 0.05, 0.08, 0.7))
	for r in [25, 50, 75]: draw_arc(pos, r, 0, TAU, 64, Color(0.2, 0.5, 0.55, 0.3), 1, true)
	draw_line(pos - Vector2(radius, 0), pos + Vector2(radius, 0), Color(0.2, 0.5, 0.55, 0.3))
	draw_line(pos - Vector2(0, radius), pos + Vector2(0, radius), Color(0.2, 0.5, 0.55, 0.3))
	for actor: Node3D in game.actors:
		if not is_instance_valid(actor) or bool(actor.get_meta("spatial_culled", false)): continue
		var relative: Vector3 = game.pilot.global_basis.inverse() * (actor.position - game.pilot.position)
		var flat := Vector2(relative.x, relative.z) / 20
		if flat.length() > radius - 5: flat = flat.normalized() * (radius - 5)
		draw_circle(pos + flat, 3, Color("f28d72") if actor.faction == "pirate" else InterfaceTheme.CYAN)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -5), pos + Vector2(-4, 4), pos + Vector2(4, 4)]), InterfaceTheme.WHITE)
	_word(pos + Vector2(-40, 94), "CONTACTS", 12, InterfaceTheme.MUTED)
