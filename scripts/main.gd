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
var return_view := Vector3.ZERO
var return_basis := Basis.IDENTITY
var return_up := Vector3.UP
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
var wreck_root: Node3D
var _rescuing: bool = false
var pending_steam_lobby: int = 0
var docked_station: int = -1
var fleet_actors: Dictionary = {}
var flight_origin := SectorPosition.new()
var flight_frame := FlightFrame.new()
var cruise_waypoints: Array[SectorPosition] = []
var cruise_address: SectorPosition
var colonies: Array[Node3D] = []
var planet_terrain: PlanetTerrain
var terrain_planet: int = -1
var cockpit_instruments: CockpitInstruments
var manual_planet: int = -1
var landed_ship_address: SectorPosition
var landed_ship_normal := Vector3.UP

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
	cockpit_instruments = CockpitInstruments.new()
	cockpit_instruments.game = self
	add_child(cockpit_instruments)
	pilot.fired.connect(_player_fire)
	pilot.autopilot_arrived.connect(_cruise_arrived)
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
	session.name = "NetworkSession"
	session.system_index = state.system_index
	session.ship_modules = state.ship_modules.duplicate(true)
	session.ship_layout = state.ship_layout.duplicate(true)
	add_child(session)
	session.world_joined.connect(_visit_host)
	session.peers_changed.connect(_sync_visitors)
	session.pvp_damage_received.connect(_receive_pvp_damage)
	session.pvp_hit_confirmed.connect(_receive_pvp_hit)
	session.pvp_occlusion_check = _pvp_clear_shot
	session.session_message.connect(notify)
	session.steam_invitation_ready.connect(func(lobby_id: int):
		pending_steam_lobby = lobby_id
		open_menu("settings")
		notify("Steam invitation received. Choose Join Invitation to travel with your ship."))
	_build_system()
	apply_ship_stats()
	_restore_flight_location()
	deck.show_page("overview")
	if not automation and steam_app_id() > 0 and steam_available():
		var steam_error: String = session.enable_steam(steam_app_id())
		if not steam_error.is_empty(): notify(steam_error)
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
	_clear_planet_terrain()
	manual_planet = -1
	landed_ship_address = null
	flight_frame.clear()
	flight_origin = SectorPosition.new()
	cruise_address = null
	cruise_waypoints.clear()
	world.position = Vector3.ZERO
	_clear_actors()
	surface_index = -1
	docked_station = -1
	world.build(state.system_index)
	_rebuild_colonies()
	pilot.set_flight(false)
	pilot.teleport(world.to_global(world.spawn_position))
	pilot.reset_view()
	_spawn_actors()
	rebuild_player_ship()
	rebuild_owned_stations()
	rebuild_wrecks()
	_register_spatial_nodes()

func _register_spatial_nodes() -> void:
	for node in get_children():
		if not node is Node3D or node == pilot or node == interior or node in remote_ships.values(): continue
		if not flight_frame.has_node(node): flight_frame.track(node, flight_origin)

func _rebase_flight() -> void:
	if surface_index >= 0 or aboard or not pilot.flying or maxf(absf(pilot.position.x), maxf(absf(pilot.position.y), absf(pilot.position.z))) < SectorPosition.HALF_SECTOR: return
	var address := SectorPosition.new(flight_origin.sector, flight_origin.local)
	if not address.move_delta(pilot.position): return
	var new_origin := SectorPosition.new(address.sector)
	var shift: Variant = new_origin.relative_to(flight_origin, SectorPosition.MAX_RELATIVE_DISTANCE)
	if shift == null: return
	_register_spatial_nodes()
	flight_frame.rebase(flight_origin, new_origin)
	pilot.position -= shift
	pilot.autopilot_target -= shift
	pilot.reset_physics_interpolation()
	flight_origin = new_origin
	rebuild_wrecks()
	_update_remote_positions()

func _capture_flight_location() -> void:
	state.location = {}
	if surface_index >= 0 or (manual_planet < 0 and docked_station < 0 and not pilot.flying and not (aboard and return_flying)): return
	var address := SectorPosition.new(flight_origin.sector, flight_origin.local)
	if not address.move_delta(return_position if aboard else pilot.position): return
	var angles: Vector3 = return_view if aboard else Vector3(pilot.camera.rotation.x, pilot.rotation.y, pilot.camera.rotation.z)
	state.location = {"system": state.system_index, "surface": -1, "address": address.to_save(), "rotation": [angles.x, angles.y, angles.z], "flying": true}
	if docked_station >= 0 and not pilot.flying:
		state.location.flying = false
		state.location.station_index = docked_station
	if manual_planet >= 0 and landed_ship_address != null:
		var up: Vector3 = return_up if aboard else pilot.up_direction
		var body_basis: Basis = return_basis if aboard else pilot.basis
		angles.y = (Basis(Quaternion(Vector3.UP, up)).inverse() * body_basis).get_euler().y
		state.location.surface = manual_planet
		state.location.flying = false
		state.location.rotation = [angles.x, angles.y, angles.z]
		state.location.ship_address = landed_ship_address.to_save()

func _restore_flight_location() -> void:
	var location: Dictionary = state.location
	if location.is_empty(): return
	if location.has("station_index"):
		_restore_station_location(location)
		return
	if int(location.surface) >= world.planets.size(): return
	if not bool(location.flying) and not location.has("ship_address"): return
	var address: SectorPosition = SectorPosition.from_save(location.address)
	if address == null: return
	var new_origin := SectorPosition.new(address.sector)
	if not bool(location.flying):
		var index: int = int(location.surface)
		if index < 0: return
		var body: Dictionary = world.planets[index]
		var center_check: Variant = SectorPosition.new(Vector3i.ZERO, body.position).relative_to(new_origin, 60000)
		var ship_check: SectorPosition = SectorPosition.from_save(location.ship_address)
		if center_check == null or ship_check == null: return
		var ship_point: Variant = ship_check.relative_to(new_origin, 60000)
		if ship_point == null: return
		var radius: float = float(body.visual_radius)
		if absf(address.local.distance_to(center_check) - radius) > 100 or absf(ship_point.distance_to(center_check) - radius) > 100: return
	_register_spatial_nodes()
	flight_frame.rebase(flight_origin, new_origin)
	flight_origin = new_origin
	pilot.set_flight(bool(location.flying))
	pilot.teleport(address.local)
	pilot.restore_view(Vector3(location.rotation[0], location.rotation[1], location.rotation[2]))
	if bool(location.flying):
		ship_display.hide()
	else:
		manual_planet = int(location.surface)
		landed_ship_address = SectorPosition.from_save(location.ship_address)
		var center: Variant = _planet_center(manual_planet)
		landed_ship_normal = (landed_ship_address.relative_to(flight_origin, 60000) - center).normalized()
		var up: Vector3 = (pilot.position - center).normalized()
		pilot.set_walk_up(up)
		pilot.basis = Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, float(location.rotation[1]))
		_update_planet_terrain()
		rebuild_player_ship()
	rebuild_wrecks()

func _restore_station_location(location: Dictionary) -> void:
	var index := int(location.station_index)
	var station: OwnedStation = _station_node(index)
	var address: SectorPosition = SectorPosition.from_save(location.address)
	if station == null or address == null: return
	# Stations are generated in system coordinates before the scene origin shifts.
	var system_point: Variant = address.relative_to(SectorPosition.new(), SectorPosition.MAX_RELATIVE_DISTANCE)
	if system_point == null or not station.contains_walk_position(station.to_local(system_point)): return
	var new_origin := SectorPosition.new(address.sector)
	_register_spatial_nodes()
	flight_frame.rebase(flight_origin, new_origin)
	flight_origin = new_origin
	docked_station = index
	pilot.set_flight(false)
	pilot.set_walk_up(Vector3.UP)
	pilot.teleport(address.local)
	pilot.restore_view(Vector3(location.rotation[0], location.rotation[1], location.rotation[2]))
	rebuild_player_ship()
	rebuild_wrecks()

func _cruise_point(address: SectorPosition) -> Vector3:
	var point: Variant = address.relative_to(flight_origin, 60000)
	if point != null: return point
	var direction := Vector3(float(address.sector.x) - flight_origin.sector.x, float(address.sector.y) - flight_origin.sector.y, float(address.sector.z) - flight_origin.sector.z).normalized()
	return pilot.position + direction * 20000

func cruise_system_to(point: Vector3) -> void:
	_start_address_cruise(SectorPosition.new(Vector3i.ZERO, point))

func _start_address_cruise(address: SectorPosition) -> void:
	if not pilot.flying or aboard:
		notify("Launch your ship before engaging cruise autopilot.")
		return
	cruise_address = address
	close_menu()
	if _plan_cruise_leg():
		notify("Cruise route engaged. Movement or mouse input returns manual control.")

func _plan_cruise_leg() -> bool:
	cruise_waypoints.clear()
	if cruise_address == null: return false
	var obstacles: Array[Dictionary] = []
	for index in world.planets.size():
		var center: Variant = _planet_center(index)
		if center != null: obstacles.append({"center": center, "radius": float(world.planets[index].visual_radius)})
	var route: Dictionary = CruiseRoute.plan(pilot.position, _cruise_point(cruise_address), obstacles)
	if not bool(route.ok):
		pilot.cancel_autopilot()
		cruise_address = null
		notify("Cruise cannot find a clear planetary route. Reposition manually and retry.")
		return false
	for point: Vector3 in route.points:
		var waypoint := SectorPosition.new(flight_origin.sector, flight_origin.local)
		if not waypoint.move_delta(point):
			cruise_address = null
			cruise_waypoints.clear()
			pilot.cancel_autopilot()
			return false
		cruise_waypoints.append(waypoint)
	if cruise_waypoints.is_empty():
		cruise_address = null
		return false
	pilot.autopilot_to(cruise_waypoints[0].relative_to(flight_origin, SectorPosition.MAX_RELATIVE_DISTANCE))
	return true

func _cruise_arrived() -> void:
	if cruise_address != null:
		if not cruise_waypoints.is_empty(): cruise_waypoints.pop_front()
		if not cruise_waypoints.is_empty():
			pilot.autopilot_to(cruise_waypoints[0].relative_to(flight_origin, SectorPosition.MAX_RELATIVE_DISTANCE))
			return
		var destination: Variant = cruise_address.relative_to(flight_origin, 60000)
		if destination == null or pilot.position.distance_to(destination) > 2.1:
			_plan_cruise_leg()
			return
		cruise_address = null
	notify("Cruise approach complete. Manual control restored.")

func _clear_colonies() -> void:
	for colony in colonies:
		if is_instance_valid(colony):
			remove_child(colony)
			colony.queue_free()
	colonies.clear()

func _rebuild_colonies() -> void:
	_clear_colonies()
	for index in world.planets.size():
		var body: Dictionary = world.planets[index]
		var colony := SurfaceColony.new()
		add_child(colony)
		colony.build(float(body.visual_radius), _terrain_seed(index), str(body.name) + " PORT")
		flight_frame.track(colony, flight_origin, SectorPosition.new(Vector3i.ZERO, Vector3(body.position) + Vector3.UP * (float(body.visual_radius) + 14.0)))
		colonies.append(colony)

func approach_colony(index: int) -> void:
	if index < 0 or index >= world.planets.size(): return
	var body: Dictionary = world.planets[index]
	cruise_system_to(Vector3(body.position) + Vector3.UP * (float(body.visual_radius) + 39.0))

func _try_colony_landing() -> bool:
	for index in colonies.size():
		var colony: Node3D = colonies[index]
		if bool(colony.get_meta("spatial_culled", false)): continue
		var pad: Vector3 = colony.to_global(colony.landing_position)
		if pilot.position.distance_to(pad + colony.basis.y * 25) > 40: continue
		if session.connected:
			notify("Leave the current multiplayer visit before docking at a surface port.")
			return true
		if pilot.velocity.length() > 20:
			notify("Reduce speed below 20 m/s to dock at the surface port.")
			return true
		manual_planet = index
		landed_ship_normal = colony.basis.y
		landed_ship_address = SectorPosition.new(flight_origin.sector, flight_origin.local)
		landed_ship_address.move_delta(pad)
		pilot.set_flight(false)
		pilot.teleport(colony.to_global(colony.stand_position))
		pilot.set_walk_up((pilot.position - _planet_center(index)).normalized())
		docked_station = -1
		_update_planet_terrain()
		rebuild_player_ship()
		save_commander(false)
		notify("Docked at %s port. Walk the streets or visit the service terminal." % world.planets[index].name)
		return true
	return false

func _near_colony_terminal() -> bool:
	return not _colony_service().is_empty()

func _colony_service() -> Dictionary:
	if manual_planet < 0 or manual_planet >= colonies.size() or aboard: return {}
	var colony: Node3D = colonies[manual_planet]
	if pilot.position.distance_to(colony.to_global(colony.service_position)) < 4.0:
		return {"page": "market", "label": "Port services"}
	for service: Dictionary in colony.interior_services:
		var target: Vector3 = colony.to_global(service.position + Vector3.UP * 1.5)
		if pilot.position.distance_to(target) > 3.5: continue
		var ray := PhysicsRayQueryParameters3D.create(pilot.camera.global_position, target, 1, [pilot.get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			var staffed_service: Dictionary = service.duplicate()
			for actor in actors:
				if actor.get_meta("colony_index", -1) == manual_planet and actor.get_meta("service", "") == service.page:
					staffed_service.label = str(service.label) + " / " + actor.display_name
					break
			return staffed_service
	return {}

func _station_service() -> Dictionary:
	if aboard or pilot.flying: return {}
	var station: OwnedStation = _station_node(docked_station)
	if station == null: return {}
	for service: Dictionary in station.interior_services:
		var target := station.to_global(service.position + Vector3.UP * 1.5)
		if pilot.position.distance_to(target) > 3.5: continue
		var ray := PhysicsRayQueryParameters3D.create(pilot.camera.global_position, target, 1, [pilot.get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return service
	return {}

func _planet_center(index: int) -> Variant:
	if index < 0 or index >= world.planets.size(): return null
	return SectorPosition.new(Vector3i.ZERO, world.planets[index].position).relative_to(flight_origin, 60000)

func _terrain_seed(index: int) -> int:
	return Universe._seed_for(state.system_index, 900 + index)

func _clear_planet_terrain() -> void:
	if is_instance_valid(planet_terrain):
		remove_child(planet_terrain)
		planet_terrain.queue_free()
	planet_terrain = null
	terrain_planet = -1

func _update_planet_terrain() -> void:
	if surface_index >= 0 or aboard: return
	var chosen: int = -1
	var altitude: float = INF
	var radial := Vector3.UP
	for index in world.planets.size():
		var center: Variant = _planet_center(index)
		if center == null: continue
		var offset: Vector3 = pilot.position - center
		var candidate: float = offset.length() - float(world.planets[index].visual_radius)
		if candidate < altitude and candidate > -80:
			chosen = index
			altitude = candidate
			radial = offset.normalized()
	var atmosphere: float = 0.0
	if chosen >= 0 and bool(world.planets[chosen].atmosphere): atmosphere = clampf(1.0 - altitude / 220.0, 0.0, 1.0)
	world.set_flight_atmosphere(atmosphere, Color("829eae"))
	if chosen < 0 or altitude > 250:
		_clear_planet_terrain()
		return
	if manual_planet >= 0 and not pilot.flying:
		pilot.set_walk_up(radial)
	var body: Dictionary = world.planets[chosen]
	var refresh_distance: float = minf(60.0, float(body.visual_radius) * 0.10)
	if not is_instance_valid(planet_terrain) or terrain_planet != chosen or planet_terrain.normal_at_patch.distance_to(radial) * float(body.visual_radius) > refresh_distance:
		_clear_planet_terrain()
		terrain_planet = chosen
		planet_terrain = PlanetTerrain.new()
		add_child(planet_terrain)
		planet_terrain.build(float(body.visual_radius), radial, _terrain_seed(chosen), Color(body.color).lerp(Color("7d8174"), 0.55))
		flight_frame.track(planet_terrain, flight_origin, SectorPosition.new(Vector3i.ZERO, Vector3(body.position) + planet_terrain.anchor))

func _try_planet_landing() -> bool:
	if terrain_planet < 0 or not is_instance_valid(planet_terrain): return false
	var center: Variant = _planet_center(terrain_planet)
	if center == null: return false
	var up: Vector3 = (pilot.position - center).normalized()
	var body: Dictionary = world.planets[terrain_planet]
	var height: float = PlanetTerrain.surface_height(up, _terrain_seed(terrain_planet))
	var altitude: float = pilot.position.distance_to(center) - float(body.visual_radius) - height
	if altitude > 35: return false
	if session.connected:
		notify("Leave the current multiplayer visit before walking a planetary surface.")
		return true
	if pilot.velocity.length() > 20:
		notify("Reduce speed below 20 m/s for surface landing.")
		return true
	manual_planet = terrain_planet
	landed_ship_normal = up
	landed_ship_address = SectorPosition.new(Vector3i.ZERO, Vector3(body.position) + up * (float(body.visual_radius) + height))
	var tangent := up.cross(Vector3.FORWARD).normalized()
	if tangent.length_squared() < 0.1: tangent = up.cross(Vector3.RIGHT).normalized()
	var stand_up: Vector3 = (up * float(body.visual_radius) + tangent * 13).normalized()
	var stand_height: float = PlanetTerrain.surface_height(stand_up, _terrain_seed(manual_planet))
	pilot.set_flight(false)
	pilot.teleport(center + stand_up * (float(body.visual_radius) + stand_height + 0.5))
	pilot.set_walk_up(stand_up)
	docked_station = -1
	rebuild_player_ship()
	save_commander(false)
	notify("Landed on %s. Walk the terrain; return to your ship to lift off." % body.name)
	return true

func approach_planet_surface(index: int) -> void:
	if index < 0 or index >= world.planets.size(): return
	var body: Dictionary = world.planets[index]
	var center: Variant = _planet_center(index)
	var up: Vector3 = (pilot.position - center).normalized() if center != null else Vector3.BACK
	var height: float = PlanetTerrain.surface_height(up, _terrain_seed(index))
	cruise_system_to(Vector3(body.position) + up * (float(body.visual_radius) + height + 25))

func _clear_actors() -> void:
	for actor in actors:
		if is_instance_valid(actor):
			actor.active = false
			remove_child(actor)
			actor.queue_free()
	actors.clear()
	fleet_actors.clear()

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
			actor.hostile = PlayerFaction.police_hostile(state.faction, str(world.data.faction), state.wanted)
			actor.target = pilot
			actor.position = Vector3(-230 + i * 460, 45, -400)
			actor.destroyed.connect(_actor_destroyed)
			actor.fired.connect(_enemy_fire)
			add_child(actor)
			actors.append(actor)
	_spawn_people(eliminated)
	if surface_index < 0: _spawn_colony_people(eliminated)
	_sync_fleet_actors()

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

func _spawn_colony_people(eliminated: Array) -> void:
	var first_names := ["Ada", "Mara", "Tomas", "Ivo", "Sera", "Niko", "Lena", "Ren"]
	var last_names := ["Voss", "Kade", "Vale", "Chen", "Okoro", "Singh", "Reyes", "Malik"]
	for index in colonies.size():
		var colony: Node3D = colonies[index]
		var rng := RandomNumberGenerator.new()
		rng.seed = _terrain_seed(index)
		for slot in 6:
			var person := GroundActor.new()
			person.actor_id = "port_%d_resident_%d" % [index, slot]
			person.display_name = str(first_names[rng.randi_range(0, first_names.size() - 1)]) + " " + str(last_names[rng.randi_range(0, last_names.size() - 1)])
			if person.actor_id in eliminated:
				person.free()
				continue
			person.set_meta("colony_index", index)
			person.target = pilot
			person.hostile = false
			person.follow_when_friendly = false
			person.patrol_radius = 3.0
			person.pursuit_radius = 100.0
			person.navigation_source = colony
			if slot < 4:
				person.faction = "civilian"
				person.role = str(colony.interior_services[slot].label)
				person.hold_position = true
				person.set_meta("service", str(colony.interior_services[slot].page))
				person.position = colony.to_global(colony.interior_positions[slot] + Vector3(0, 0.3, -4))
				person.rotation.y = PI
			else:
				person.faction = "police"
				person.role = "Port security"
				person.position = colony.to_global(Vector3(-12 if slot == 4 else 12, 0.3, 12))
			person.destroyed.connect(_actor_destroyed)
			person.fired.connect(_enemy_fire)
			add_child(person)
			actors.append(person)

func _fleet_record(ship_id: String) -> Dictionary:
	for ship: Dictionary in state.fleet_ships:
		if str(ship.id) == ship_id: return ship
	return {}

func _patrol_order(ship_id: String) -> Dictionary:
	for order: Dictionary in state.crew_orders.values():
		if order.kind == "patrol" and str(order.get("ship_id", "")) == ship_id: return order
	return {}

func _sync_fleet_actors() -> Array[String]:
	var local_ids: Array[String] = []
	if surface_index < 0:
		for ship: Dictionary in state.fleet_ships:
			var id: String = str(ship.id)
			var order := _patrol_order(id)
			if int(ship.system) != state.system_index or float(ship.hull) <= 0 or order.is_empty() or int(order.system) != state.system_index: continue
			local_ids.append(id)
			if not fleet_actors.has(id):
				var actor := ShipActor.new()
				actor.actor_id = id
				actor.faction = "player_fleet"
				actor.set_meta("fleet_ship_id", id)
				actor.set_meta("contact_name", str(ship.name))
				actor.hp = float(ship.hull)
				actor.shields = 0
				actor.position = Vector3(-420 + (local_ids.size() - 1) * 25, 100, -650)
				actor.damaged.connect(_persist_fleet_damage)
				actor.destroyed.connect(_actor_destroyed)
				actor.fired.connect(_enemy_fire)
				add_child(actor)
				flight_frame.track(actor, flight_origin, SectorPosition.new(Vector3i.ZERO, actor.position))
				actors.append(actor)
				fleet_actors[id] = actor
				var label := Label3D.new()
				label.text = str(ship.name)
				for member: Dictionary in state.crew:
					if str(member.id) == str(order.crew_id): label.text += "\n" + str(member.name)
				label.position.y = 5
				label.pixel_size = 0.03
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.modulate = Color("68e8db")
				actor.add_child(label)
			else:
				fleet_actors[id].hp = float(ship.hull)
	for id: String in fleet_actors.keys():
		if id in local_ids: continue
		var actor: Node = fleet_actors[id]
		if is_instance_valid(actor):
			actors.erase(actor)
			remove_child(actor)
			actor.queue_free()
		fleet_actors.erase(id)
	var simulated: Array[String] = []
	for id: String in local_ids:
		if not bool(fleet_actors[id].get_meta("spatial_culled", false)): simulated.append(id)
	return simulated

func approach_fleet_ship(ship_id: String) -> void:
	var actor: Node3D = fleet_actors.get(ship_id)
	if not is_instance_valid(actor):
		notify("That vessel is not patrolling this local space.")
		return
	cruise_to(actor.position + Vector3(0, 20, 60))

func _persist_fleet_damage(actor: ShipActor) -> void:
	var ship := _fleet_record(str(actor.get_meta("fleet_ship_id", "")))
	if not ship.is_empty(): ship.hull = actor.hp

func _nearest_ship(origin: ShipActor, faction: String) -> Node3D:
	var nearest: Node3D = null
	var distance: float = 2500.0
	for other in actors:
		if not is_instance_valid(other) or bool(other.get_meta("spatial_culled", false)) or not other is ShipActor or other == origin or other.faction != faction or other.hp <= 0: continue
		var candidate: float = origin.position.distance_to(other.position)
		if candidate < distance:
			nearest = other
			distance = candidate
	return nearest

func _update_combat_targets() -> void:
	for actor in actors:
		if not actor is ShipActor: continue
		if actor.faction == "player_fleet":
			actor.target = _nearest_ship(actor, "pirate")
			actor.hostile = actor.target != null
			var order := _patrol_order(str(actor.get_meta("fleet_ship_id", "")))
			if bool(order.get("paused", true)):
				actor.target = null
				actor.hostile = false
		elif actor.faction == "pirate":
			var fleet_target := _nearest_ship(actor, "player_fleet")
			actor.target = pilot if pilot.flying else null
			if fleet_target != null and (actor.target == null or actor.position.distance_squared_to(fleet_target.position) < actor.position.distance_squared_to(pilot.position)):
				actor.target = fleet_target

func rebuild_player_ship() -> void:
	if is_instance_valid(ship_display):
		remove_child(ship_display)
		ship_display.queue_free()
	ship_display = ShipVisual.new()
	add_child(ship_display)
	ship_display.build(state.ship_modules, "player", state.ship_layout)
	var low := Vector3(16, 16, 16)
	var high := Vector3(-16, -16, -16)
	for module: Dictionary in state.ship_modules:
		var cell := Vector3(module.x, module.y, module.z)
		low = low.min(cell)
		high = high.max(cell)
	var center := (low + high) * 0.5 * ShipVisual.CELL_SIZE
	var bottom := (high.y - low.y) * 0.5 * ShipVisual.CELL_SIZE + 1.28
	var pad_up: Vector3 = landed_ship_normal if manual_planet >= 0 else Vector3.UP
	ship_display.position = _ship_pad() + pad_up * (bottom + 0.7)
	ship_display.basis = Basis(Quaternion(Vector3.UP, pad_up))
	for module: Dictionary in state.ship_modules:
		if float(module.y) != low.y: continue
		var cell := Vector3(module.x, module.y, module.z) * ShipVisual.CELL_SIZE - center
		for side in [-1.0, 1.0]:
			_box(ship_display, cell + Vector3(side * 0.9, -1.58, 0), Vector3(0.12, 0.6, 0.15), Color("a6acaf"))
			_box(ship_display, cell + Vector3(side * 0.9, -1.9, 0), Vector3(0.4, 0.16, 1.9), Color("252b30"))
	ship_display.visible = not pilot.flying
	flight_frame.track(ship_display, flight_origin)

func apply_ship_stats() -> void:
	_last_stats = state.ship_stats()
	pilot.flight_speed = float(_last_stats.speed)
	state.hull = minf(state.hull, float(_last_stats.max_hull))
	state.shield = minf(state.shield, float(_last_stats.max_shield))
	if session != null:
		session.ship_modules = state.ship_modules.duplicate(true)
		session.ship_layout = state.ship_layout.duplicate(true)

func rebuild_owned_stations() -> void:
	if is_instance_valid(owned_root):
		remove_child(owned_root)
		owned_root.queue_free()
	owned_root = Node3D.new()
	add_child(owned_root)
	if surface_index >= 0: return
	var count: int = 0
	for station_index: int in state.stations.size():
		var station: Dictionary = state.stations[station_index]
		if int(station.get("system", station.get("system_index", -1))) != state.system_index: continue
		var base := OwnedStation.new()
		owned_root.add_child(base)
		base.position = Vector3(600 + (count % 25) * 650, 60, -500 - (count / 25) * 500)
		base.set_meta("station_index", station_index)
		base.build(station)
		count += 1
	flight_frame.track(owned_root, flight_origin, SectorPosition.new())

func _station_node(index: int) -> Node3D:
	if index < 0 or not is_instance_valid(owned_root): return null
	for node in owned_root.get_children():
		if int(node.get_meta("station_index", -1)) == index: return node
	return null

func _ship_pad() -> Vector3:
	if manual_planet >= 0 and landed_ship_address != null:
		var point: Variant = landed_ship_address.relative_to(flight_origin, 60000)
		if point != null: return point
	var station := _station_node(docked_station)
	return station.to_global(station.dock_position) if station != null else world.to_global(Vector3(0, 0, -22))

func approach_owned_station(index: int) -> void:
	var station := _station_node(index)
	if station == null:
		notify("That station is in another system.")
		return
	cruise_system_to(station.position + station.launch_position)

func _dock_owned_station() -> bool:
	if surface_index >= 0 or not is_instance_valid(owned_root) or bool(owned_root.get_meta("spatial_culled", false)): return false
	for station in owned_root.get_children():
		if pilot.position.distance_to(station.to_global(station.dock_position)) > 65: continue
		if pilot.velocity.length() > 35:
			notify("Reduce speed below 35 m/s to engage docking clamps.")
			return true
		docked_station = int(station.get_meta("station_index"))
		pilot.set_flight(false)
		pilot.teleport(station.to_global(station.stand_position))
		pilot.reset_view()
		rebuild_player_ship()
		save_commander(false)
		notify("Docked at %s. Follow the concourse signs for station services." % state.stations[docked_station].name)
		return true
	return false

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
	if session.connected and pilot.flying: session.request_pvp_shot(direction)
	sound.play_sound("shot")
	var distance: float = 2200 if pilot.flying else 150
	var hit: Dictionary = _ray(origin, direction, distance, [pilot.get_rid()])
	var endpoint: Vector3 = hit.get("position", origin + direction * distance)
	_beam(origin + pilot.camera.global_basis.x * 0.18 - pilot.camera.global_basis.y * 0.12, endpoint, Color("75f6e7"))
	if not hit.is_empty():
		var victim: Object = hit.collider
		if victim.has_method("take_damage"):
			if victim.has_meta("colony_index"): victim.active = true
			if victim.faction not in ["pirate", "player_fleet"] and not victim.get_meta("assault_reported", false):
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
	var struck: Object = hit.get("collider")
	if struck is ShipActor and ((actor.faction == "pirate" and struck.faction == "player_fleet") or (actor.faction == "player_fleet" and struck.faction == "pirate")):
		if actor.has_meta("fleet_ship_id") and struck.faction == "pirate":
			struck.set_meta("fleet_hit", actor.get_meta("fleet_ship_id"))
		struck.take_damage(9.0)
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
	if actor.has_meta("fleet_ship_id"):
		_persist_fleet_damage(actor)
		fleet_actors.erase(str(actor.get_meta("fleet_ship_id")))
		actors.erase(actor)
		_explosion(actor.global_position, 8)
		var saved: bool = save_commander(false)
		notify("Fleet ship disabled. Arrange repairs in Crew Operations." if saved else "Fleet ship disabled; damage NOT SAVED. Check storage and save again.")
		return
	var eliminated: Array = state.world_flags.get(_location_key(), [])
	if actor.actor_id not in eliminated: eliminated.append(actor.actor_id)
	state.world_flags[_location_key()] = eliminated
	if actor.get_meta("player_hit", false):
		state.record_kill(actor.faction)
		notify("Pirate neutralized. Bounty credited." if actor.faction == "pirate" else "Civilian/security casualty recorded. Wanted status updated.")
	elif actor.faction == "pirate" and actor.has_meta("fleet_hit"):
		state.credits += 250
		var order := _patrol_order(str(actor.get_meta("fleet_hit")))
		if not order.is_empty(): order.encounters = int(order.encounters) + 1
		notify("Fleet patrol neutralized a pirate. 250 CR bounty credited.")
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
	if _rescuing or (state.hull > 0 and suit_health > 0): return
	_rescuing = true
	var message: String
	if pilot.flying and state.hull <= 0:
		var report: Dictionary = ShipRecovery.destroy_ship(state, pilot.position, surface_index, flight_origin.to_save())
		if not bool(report.get("ok", false)):
			_rescuing = false
			open_menu("recovery")
			notify(str(report.get("message", "Recovery failed; no assets changed.")))
			return
		message = str(report.get("message", "Rescue completed. Wreck beacon recorded in Navigation."))
	else:
		var fee := mini(state.credits, 250)
		state.credits -= fee
		message = "Medical rescue complete. %d CR paid; your docked ship remains intact." % fee
	suit_health = 100
	apply_ship_stats()
	_build_system()
	close_menu()
	var saved: bool = save_commander(false)
	notify(message if saved else message + " Recovery is NOT SAVED. Check storage.")
	_rescuing = false

func interaction_hint() -> String:
	var service := _station_service() if docked_station >= 0 else _colony_service()
	if not service.is_empty(): return str(service.label)
	if aboard: return "Return to helm  /  PgUp/PgDn change deck"
	if surface_index >= 0: return "Board ship / return to orbit" if _near_person() == null else "Talk to " + _near_person().display_name
	var person: Node3D = _near_person()
	if person != null: return "Talk to " + person.display_name
	return "Board ship" if pilot.position.distance_to(_ship_pad()) < 20 else "Approach your ship or a service officer"

func _near_person() -> Node3D:
	for actor in actors:
		if not bool(actor.get_meta("spatial_culled", false)) and actor is GroundActor and actor.has_meta("service") and actor.position.distance_to(pilot.position) < 6:
			var ray := PhysicsRayQueryParameters3D.create(pilot.camera.global_position, actor.global_position + Vector3.UP * 1.5, 1, [pilot.get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return actor
	return null

func _interact() -> void:
	if aboard:
		exit_interior()
		return
	if jump_charge > 0: return
	if pilot.flying:
		if _dock_owned_station(): return
		if _try_colony_landing(): return
		if _try_planet_landing(): return
		if bool(world.get_meta("spatial_culled", false)) or pilot.position.distance_to(world.to_global(world.launch_position)) > 250:
			notify("Approach the orbital dock to within 250 m.")
			return
		docked_station = -1
		pilot.set_flight(false)
		pilot.teleport(world.to_global(world.spawn_position))
		pilot.reset_view()
		rebuild_player_ship()
		save_commander(false)
		notify("Docking complete. Welcome aboard.")
		return
	var service := _station_service() if docked_station >= 0 else _colony_service()
	if not service.is_empty():
		open_menu(str(service.page))
		return
	var person: Node3D = _near_person()
	if person != null:
		open_menu(str(person.get_meta("service")))
		return
	if pilot.position.distance_to(_ship_pad()) > 20:
		notify("Approach your ship on the landing pad to board.")
		return
	if manual_planet >= 0:
		var departure: Vector3 = _ship_pad() + landed_ship_normal * 25
		manual_planet = -1
		landed_ship_address = null
		pilot.set_flight(true)
		pilot.teleport(departure)
		pilot.reset_view()
		ship_display.hide()
		save_commander(false)
		notify("Lift-off complete. Manual flight control restored.")
		return
	if surface_index >= 0:
		_build_system()
	var station := _station_node(docked_station)
	var departure: Vector3 = station.to_global(station.launch_position) if station != null else world.to_global(world.launch_position)
	docked_station = -1
	pilot.set_flight(true)
	pilot.teleport(departure)
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
	_clear_planet_terrain()
	manual_planet = -1
	landed_ship_address = null
	flight_frame.clear()
	flight_origin = SectorPosition.new()
	world.position = Vector3.ZERO
	cruise_address = null
	cruise_waypoints.clear()
	docked_station = -1
	surface_index = planet_index
	_clear_colonies()
	world.build_surface(planet_index)
	pilot.set_flight(false)
	pilot.teleport(world.to_global(world.spawn_position))
	pilot.reset_view()
	suit_health = 100
	_spawn_actors()
	rebuild_player_ship()
	rebuild_owned_stations()
	rebuild_wrecks()
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
	if manual_planet >= 0: return str(world.planets[manual_planet].name) + " surface"
	if surface_index >= 0 and surface_index < world.planets.size(): return str(world.planets[surface_index].name) + " colony"
	if not pilot.flying and docked_station >= 0: return str(state.stations[docked_station].name)
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
				pilot.set_walk_up(Vector3.UP)
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
	_register_spatial_nodes()
	_rebase_flight()
	_update_planet_terrain()
	if cruise_address != null:
		if pilot.autopilot_active and not cruise_waypoints.is_empty():
			pilot.autopilot_target = cruise_waypoints[0].relative_to(flight_origin, SectorPosition.MAX_RELATIVE_DISTANCE)
		else:
			cruise_address = null
			cruise_waypoints.clear()
	var local_patrols: Array[String] = _sync_fleet_actors()
	var reports: Array = crew_operations().tick(delta, local_patrols)
	if not reports.is_empty():
		notify("Crew / %s: %s" % [reports.back().get("kind", "operation"), reports.back().get("status", "updated")])
	for actor in actors:
		if not is_instance_valid(actor): continue
		actor.active = not ui_open and jump_charge <= 0 and not aboard and not bool(actor.get_meta("spatial_culled", false))
		if actor.has_meta("colony_index") and actor.position.distance_to(pilot.position) > 250: actor.active = false
		if actor.faction == "police": actor.hostile = PlayerFaction.police_hostile(state.faction, str(world.data.faction), state.wanted)
	_update_combat_targets()
	if jump_charge > 0:
		jump_charge = maxf(0, jump_charge - delta)
		if jump_charge == 0: _complete_jump()
	if not ui_open and jump_charge <= 0:
		shield_delay -= delta
		if shield_delay <= 0: state.shield = minf(float(_last_stats.get("max_shield", 100)), state.shield + delta * 5)
		if not pilot.flying and manual_planet < 0:
			var safe_spawn: Vector3 = world.to_global(world.spawn_position)
			var dock := _station_node(docked_station)
			if dock != null: safe_spawn = dock.to_global(dock.stand_position)
			if aboard: safe_spawn = interior.spawn_on_deck(interior_deck)
			if pilot.position.y < safe_spawn.y - 150: pilot.teleport(safe_spawn)

		autosave_clock += delta
		if autosave_clock > 60 and not automation:
			autosave_clock = 0
			save_commander(false)
	sound.flight(pilot.velocity.length() / maxf(pilot.flight_speed, 1), pilot.flying)
	_network_clock += delta
	if session != null and session.connected and _network_clock > 0.05:
		_network_clock = 0
		session.publish_pose(pilot.position, Vector3(pilot.camera.rotation.x, pilot.rotation.y, pilot.camera.rotation.z) if pilot.flying else pilot.rotation, flight_origin.to_save(), pilot.flying and not aboard)
		_update_remote_positions()

func save_commander(show_message: bool = true) -> bool:
	_capture_flight_location()
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
	_restore_flight_location()
	open_menu()
	notify("Commander restored on " + location_title() + "." if manual_planet >= 0 or docked_station >= 0 else ("Commander restored at the saved flight location." if pilot.flying else "Commander restored at the orbital station."))

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
		if visitor.crew.size() > int(state.ship_stats().crew_capacity):
			session.leave()
			notify("This world's crew requires more quarters than your incoming ship has. Bring a larger ship.")
			return
		home_state = state
		home_save_path = save_path
		visitor.ship_modules = state.ship_modules.duplicate(true)
		visitor.ship_layout = state.ship_layout.duplicate(true)
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

func _build_peer_collision(visual: ShipVisual, modules: Array, peer_id: int) -> void:
	var previous: StaticBody3D = visual.get_meta("hit_body") if visual.has_meta("hit_body") else null
	if is_instance_valid(previous):
		previous.collision_layer = 0
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("peer_id", peer_id)
	visual.add_child(body)
	visual.set_meta("hit_body", body)
	var low := Vector3(99999, 99999, 99999)
	var high := -low
	for module: Dictionary in modules:
		low = low.min(Vector3(module.x, module.y, module.z))
		high = high.max(Vector3(module.x, module.y, module.z))
	var center := (low + high) * 0.5 * ShipVisual.CELL_SIZE
	for module: Dictionary in modules:
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3.ONE * ShipVisual.CELL_SIZE
		collision.shape = box
		collision.position = Vector3(module.x, module.y, module.z) * ShipVisual.CELL_SIZE - center
		body.add_child(collision)

func _pvp_clear_shot(attacker: int, target_id: int, direction: Vector3, distance: float) -> bool:
	if not session.presence.has(attacker): return false
	var address: SectorPosition = SectorPosition.from_save(session.presence[attacker].address)
	if address == null: return false
	var point: Variant = address.relative_to(flight_origin, 30000)
	if point == null: return false
	var excluded: Array[RID] = []
	for id in [attacker, target_id]:
		if id == multiplayer.get_unique_id(): excluded.append(pilot.get_rid())
		if remote_ships.has(id):
			var body: StaticBody3D = remote_ships[id].get_meta("hit_body") if remote_ships[id].has_meta("hit_body") else null
			if is_instance_valid(body): excluded.append(body.get_rid())
	var origin: Vector3 = point + Vector3.UP * 1.55
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * maxf(0.0, distance - 0.01), 7, excluded)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _receive_pvp_damage(attacker: int, damage: float) -> void:
	if not pilot.flying or aboard or not is_finite(damage) or damage <= 0: return
	shield_delay = 6
	var absorbed: float = minf(state.shield, damage)
	state.shield -= absorbed
	state.hull = maxf(0, state.hull - (damage - absorbed))
	pilot.kick(0.5)
	hud.flash = 0.5
	notify("Ship hit by %s." % str(session.presence.get(attacker, {}).get("name", "visitor")))
	if state.hull <= 0: _rescue()

func _receive_pvp_hit(attacker: int, _target_id: int, origin_data: Dictionary, end_data: Dictionary) -> void:
	var origin_address: SectorPosition = SectorPosition.from_save(origin_data)
	var end_address: SectorPosition = SectorPosition.from_save(end_data)
	if origin_address == null or end_address == null: return
	var origin: Variant = origin_address.relative_to(flight_origin, 30000)
	var endpoint: Variant = end_address.relative_to(flight_origin, 30000)
	if origin == null or endpoint == null: return
	if attacker == multiplayer.get_unique_id():
		hud.hit_confirmation = 0.3
	else:
		_beam(origin, endpoint, Color("ff9673"))
	_explosion(endpoint, 0.18)

func _sync_visitors() -> void:
	# Transform presence is independent of local commander economics.
	for peer_id: int in remote_ships.keys():
		if not session.presence.has(peer_id):
			remote_ships[peer_id].queue_free()
			remote_ships.erase(peer_id)
	for peer_id: int in session.presence:
		if peer_id == multiplayer.get_unique_id(): continue
		var profile: Dictionary = session.presence[peer_id]
		if not remote_ships.has(peer_id):
			var visual := ShipVisual.new()
			add_child(visual)
			remote_ships[peer_id] = visual
		var design_hash: int = hash([profile.ship_modules, profile.get("ship_layout", {})])
		var visual: ShipVisual = remote_ships[peer_id]
		if not visual.has_meta("design_hash") or visual.get_meta("design_hash") != design_hash:
			visual.build(profile.ship_modules, "player", profile.get("ship_layout", {}))
			_build_peer_collision(visual, profile.ship_modules, peer_id)
			visual.set_meta("design_hash", design_hash)

func _update_remote_positions() -> void:
	for peer_id: int in remote_ships:
		if session.presence.has(peer_id):
			var player: Dictionary = session.presence[peer_id]
			var address: SectorPosition = SectorPosition.from_save(player.get("address", {}))
			var point: Variant = address.relative_to(flight_origin, 30000) if address != null else null
			remote_ships[peer_id].visible = point != null
			var body: StaticBody3D = remote_ships[peer_id].get_meta("hit_body") if remote_ships[peer_id].has_meta("hit_body") else null
			if is_instance_valid(body): body.collision_layer = 2 if point != null else 0
			if point != null: remote_ships[peer_id].position = point
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
	# Exercise new systems through the exported main scene as well as standalone tests.
	state.credits = 50000
	if not _check(state.hire("trader").is_empty(), "hire named captain"): return
	if not _check(crew_operations().purchase_ship("Integration Courier").is_empty(), "commission fleet vessel"): return
	var member_id: String = state.crew.back().id
	var fleet_id: String = state.fleet_ships.back().id
	if not _check(crew_operations().assign_trade_route(member_id, fleet_id, "food", state.system_index + 1, 5).is_empty(), "assign fleet route"): return
	crew_operations().tick(CrewOrders.TRIP_SECONDS * 2.0)
	if not _check(int(state.fleet_ships.back().cargo.get("food", 0)) == 5, "fleet purchases actual cargo"): return
	open_menu("fleet")
	await _capture("fleet")
	_build_system()
	if not _check(purchase_insurance().is_empty(), "insurance service"): return
	state.cargo.food = 5
	pilot.set_flight(true)
	pilot.teleport(Vector3(100, 80, -300))
	state.hull = 0
	_rescue()
	if not _check(state.recovery.wrecks.size() == 1 and state.cargo_total() == 0 and state.hull > 0, "insured rescue and wreck creation"): return
	open_menu("recovery")
	await _capture("recovery")
	var wreck_id: String = state.recovery.wrecks[0].id
	pilot.set_flight(true)
	pilot.teleport(_wreck_position(state.recovery.wrecks[0]))
	if not _check(recover_wreck(wreck_id).is_empty() and state.cargo.food == 5, "cargo recovery at beacon"): return
	if not _check(recover_wreck(wreck_id, true).is_empty(), "wreck salvage"): return
	var salvage_balance: int = state.credits
	if not _check(not recover_wreck(wreck_id, true).is_empty() and state.credits == salvage_balance, "duplicate salvage blocked"): return
	if not _check(save_commander(false) and restored.load_save(save_path).is_empty() and restored.recovery.wrecks[0].salvaged and restored.crew_orders.size() == 1, "operations save round trip"): return
	state.credits = 50000
	state.cargo.alloys = 20
	if not _check(state.build_station("Horizon Anchorage").is_empty(), "owned station construction"): return
	if not _check(state.found_faction("Horizon League").is_empty() and state.faction_deposit(5000).is_empty() and state.claim_station_faction(0).is_empty(), "faction charter and station affiliation"): return
	rebuild_owned_stations()
	var owned_station: Node3D = _station_node(0)
	pilot.teleport(owned_station.to_global(owned_station.launch_position))
	close_menu()
	_interact()
	if not _check(docked_station == 0 and not pilot.flying, "owned outpost docking"): return
	await _capture("owned-station")
	var station_service: Dictionary = owned_station.interior_services[0]
	pilot.teleport(owned_station.to_global(station_service.position))
	await get_tree().physics_frame
	_interact()
	if not _check(ui_open and deck.page == station_service.page, "owned station room service"): return
	if not _check(save_commander(false), "save owned station interior"): return
	load_commander()
	close_menu()
	if not _check(docked_station == 0 and not pilot.flying, "restore owned station interior"): return
	pilot.rotation.y = -PI / 2
	await _capture("station-interior")
	open_menu("factions")
	await _capture("factions")
	if not _check(save_commander(false) and restored.load_save(save_path).is_empty() and restored.faction == state.faction, "faction save round trip"): return
	if not _check(state.hire("gunner").is_empty(), "hire patrol pilot"): return
	if not _check(crew_operations().purchase_ship("Integration Guardian").is_empty(), "commission patrol ship"): return
	var patrol_id: String = state.fleet_ships.back().id
	if not _check(crew_operations().assign_patrol(state.crew.back().id, patrol_id, state.system_index).is_empty(), "assign local patrol"): return
	_sync_fleet_actors()
	if not _check(fleet_actors.has(patrol_id), "materialized local patrol"): return
	fleet_actors[patrol_id].active = true
	fleet_actors[patrol_id].take_damage(9)
	if not _check(state.fleet_ships.back().hull == 91, "physical fleet damage persists"): return
	if not _check(save_commander(false) and restored.load_save(save_path).is_empty() and restored.fleet_ships.back().hull == 91, "local fleet damage save round trip"): return
	close_menu()
	docked_station = -1
	pilot.set_flight(true)
	pilot.teleport(fleet_actors[patrol_id].position + Vector3(20, 8, 50))
	pilot.reset_view()
	ship_display.hide()
	await _capture("local-patrol")
	var money_before_menu: int = state.credits
	for menu_page in ["overview", "navigation", "market", "shipyard", "contracts", "company", "fleet", "recovery", "factions", "stations", "settings"]:
		open_menu(menu_page)
		await get_tree().process_frame
	if not _check(state.credits == money_before_menu, "menu browsing must not change finances"): return
	_build_system()
	pilot.set_flight(true)
	pilot.teleport(Vector3(5000, 300, 0))
	_rebase_flight()
	if not _check(flight_origin.sector.x == 1 and pilot.position.x == -3192, "origin rebase preserves physical flight"): return
	if not _check(save_commander(false), "save rebased flight"): return
	load_commander()
	if not _check(flight_origin.sector.x == 1 and pilot.flying, "restore rebased flight"): return
	close_menu()
	await _capture("rebase-flight")
	_build_system()
	_clear_actors()
	close_menu()
	var landing_body: Dictionary = world.planets[0]
	var landing_center: Vector3 = _planet_center(0)
	var landing_height: float = PlanetTerrain.surface_height(Vector3.RIGHT, _terrain_seed(0))
	pilot.set_flight(true)
	pilot.teleport(landing_center + Vector3.RIGHT * (float(landing_body.visual_radius) + landing_height + 25))
	_update_planet_terrain()
	var landing_world_id: int = world.get_instance_id()
	_interact()
	if not _check(manual_planet == 0 and not pilot.flying and world.get_instance_id() == landing_world_id, "same-scene manual planetary landing"): return
	await get_tree().create_timer(0.7).timeout
	if not _check(pilot.is_on_floor() and pilot.up_direction.dot(Vector3.RIGHT) > 0.99, "radial planetary floor contact"): return
	if not _check(save_commander(false), "save manual planetary landing"): return
	load_commander()
	_clear_actors()
	close_menu()
	if not _check(manual_planet == 0 and landed_ship_address != null and not pilot.flying, "restore manual planetary landing"): return
	await _capture("manual-planet")
	landing_world_id = world.get_instance_id()
	pilot.teleport(_ship_pad() + landed_ship_normal * 2)
	_interact()
	if not _check(pilot.flying and manual_planet == -1 and world.get_instance_id() == landing_world_id, "same-scene planetary liftoff"): return
	var port: Node3D = colonies[0]
	pilot.teleport(port.to_global(port.landing_position + Vector3.UP * 25))
	_interact()
	if not _check(manual_planet == 0 and not pilot.flying, "surface port docking"): return
	await get_tree().create_timer(0.5).timeout
	if not _check(pilot.is_on_floor(), "surface port deck collision"): return
	pilot.teleport(port.to_global(port.service_position + Vector3(0, 1, 2)))
	_interact()
	if not _check(ui_open, "surface port service terminal"): return
	close_menu()
	pilot.teleport(port.to_global(port.stand_position))
	pilot.reset_view()
	await _capture("surface-city")
	if not _check(save_commander(false), "save surface port"): return
	load_commander()
	close_menu()
	if not _check(manual_planet == 0 and _ship_pad().distance_to(colonies[0].to_global(colonies[0].landing_position)) < 0.1, "restore surface port ship"): return
	port = colonies[0]
	pilot.teleport(port.to_global(port.interior_positions[0] + Vector3(0, 0.3, 0)))
	pilot.reset_view()
	await get_tree().create_timer(0.3).timeout
	if not _check(pilot.is_on_floor(), "port interior floor"): return
	_interact()
	if not _check(ui_open and deck.page == str(port.interior_services[0].page), "port interior service interaction"): return
	close_menu()
	await _capture("port-interior")
	pilot.teleport(_ship_pad() + landed_ship_normal * 2)
	_interact()
	if not _check(pilot.flying and manual_planet == -1, "surface port departure"): return
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".bak")
	await get_tree().create_timer(0.5).timeout
	print("NEXT_INTEGRATION_OK: trading, stock, construction, persistent combat, save/load, hyperdrive, landing, walkable interior, crew orders, insured wreck recovery, factions, owned docks, local fleet, spatial rebasing, manual planetary landing, surface ports, menu safety")
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
		if is_instance_valid(actor) and not bool(actor.get_meta("spatial_culled", false)) and actor.hostile and actor.position.distance_to(pilot.position) < 1000 and pilot.flying:
			notify("Leave the combat zone before leaving the helm.")
			return
	if not bool(state.ship_stats().get("walkable", false)):
		notify("Install a habitat and at least eight connected modules to support walkable decks.")
		return
	return_position = pilot.position
	return_flying = pilot.flying
	return_view = Vector3(pilot.camera.rotation.x, pilot.rotation.y, pilot.camera.rotation.z)
	return_basis = pilot.basis
	return_up = pilot.up_direction
	interior = ShipInterior.new()
	add_child(interior)
	interior.position = Vector3(0, 6000, 0)
	interior.build(state.ship_modules, state.ship_layout)
	aboard = true
	interior_deck = 0 if 0 in interior.decks else interior.decks[0]
	pilot.set_flight(false)
	pilot.set_walk_up(Vector3.UP)
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
	pilot.restore_view(return_view)
	pilot.set_walk_up(return_up)
	pilot.basis = return_basis
	close_menu()

func _copy_carried_ship(source: GameState, destination: GameState) -> void:
	destination.ship_modules = source.ship_modules.duplicate(true)
	destination.ship_layout = source.ship_layout.duplicate(true)
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
	_restore_flight_location()
	open_menu()
	notify("Returned home with your ship and cargo. World finances stayed separate." if saved else "Returned home; previous save failed. Save again before quitting.")

func cruise_to(point: Vector3) -> void:
	var address := SectorPosition.new(flight_origin.sector, flight_origin.local)
	if address.move_delta(point): _start_address_cruise(address)

func approach_planet(index: int) -> void:
	if index < 0 or index >= world.planets.size(): return
	var body: Dictionary = world.planets[index]
	var center: Variant = SectorPosition.new(Vector3i.ZERO, body.position).relative_to(flight_origin, 60000)
	var radial: Vector3 = (pilot.position - center).normalized() if center != null else Vector3.BACK
	cruise_system_to(Vector3(body.position) + radial * (float(body.visual_radius) + 160.0))

func crew_operations() -> RefCounted:
	return CrewOrders.new(state)

func rebuild_wrecks() -> void:
	if is_instance_valid(wreck_root):
		remove_child(wreck_root)
		wreck_root.queue_free()
	wreck_root = Node3D.new()
	add_child(wreck_root)
	for wreck: Dictionary in state.recovery.get("wrecks", []):
		if int(wreck.system) != state.system_index or int(wreck.surface) != surface_index: continue
		if bool(wreck.get("salvaged", false)) and bool(wreck.get("cargo_recovered", false)): continue
		var position: Variant = _wreck_position(wreck)
		if position == null: continue
		var hull := ShipVisual.new()
		wreck_root.add_child(hull)
		hull.build(wreck.get("modules", state.ship_modules), "wreck")
		hull.position = position
		hull.rotation = Vector3(0.25, 0.7, -0.35)
		hull.scale = Vector3.ONE * 0.85
		var beacon := Label3D.new()
		beacon.text = "RECOVERY BEACON / " + str(wreck.id)
		beacon.font_size = 32
		beacon.pixel_size = 0.025
		beacon.position = position + Vector3(0, 6, 0)
		beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		beacon.modulate = Color("e0b96e")
		wreck_root.add_child(beacon)

func _wreck_position(wreck: Dictionary) -> Variant:
	return ShipRecovery.wreck_relative(wreck, flight_origin.to_save())

func approach_wreck(id: String) -> void:
	for wreck: Dictionary in state.recovery.wrecks:
		if str(wreck.id) != id or int(wreck.system) != state.system_index or int(wreck.surface) != surface_index: continue
		var address: SectorPosition = SectorPosition.from_save(wreck.get("address", {}))
		if address == null:
			var p: Array = wreck.position
			address = SectorPosition.new(Vector3i.ZERO, Vector3(p[0], p[1], p[2]))
		address.move_delta(Vector3(0, 0, 25))
		_start_address_cruise(address)
		return

func recover_wreck(id: String, salvage: bool = false) -> String:
	if aboard: return "Return to the helm or approach the wreck on foot."
	var error: String = ShipRecovery.salvage_wreck(state, id, surface_index, pilot.position, 80.0 if pilot.flying else 8.0, flight_origin.to_save()) if salvage else ShipRecovery.recover_cargo(state, id, surface_index, pilot.position, 80.0 if pilot.flying else 8.0, flight_origin.to_save())
	if error.is_empty(): rebuild_wrecks()
	return error

func purchase_insurance() -> String:
	if pilot.flying or aboard: return "Dock at a station to arrange insurance."
	return ShipRecovery.buy_insurance(state)

func sell_fleet_cargo(ship_id: String, good: String, amount: int) -> String:
	if pilot.flying or aboard: return "Dock to arrange fleet cargo clearance."
	return crew_operations().unload_fleet_cargo(ship_id, good, amount)

func collect_station_stock(station_index: int, good: String, amount: int) -> String:
	if pilot.flying or aboard: return "Dock to request a station cargo delivery."
	return crew_operations().withdraw_station_stock(station_index, good, amount)

func steam_app_id() -> int:
	return int(ProjectSettings.get_setting("steam/app_id", 0))

func steam_available() -> bool:
	return Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")

func start_steam_host() -> String:
	if session.connected: return "Leave your current session before hosting another world."
	session.ship_modules = state.ship_modules.duplicate(true)
	session.ship_layout = state.ship_layout.duplicate(true)
	session.system_index = state.system_index
	session.world_id = state.world_id
	return session.host_steam(steam_app_id())

func join_steam_invitation() -> String:
	if pending_steam_lobby <= 0: return "No Steam invitation is pending."
	if session.connected: return "Leave your current session before joining the invitation."
	if not save_commander(false): return "Save failed; invitation was not joined."
	session.ship_modules = state.ship_modules.duplicate(true)
	session.ship_layout = state.ship_layout.duplicate(true)
	var error: String = session.join_steam(steam_app_id(), pending_steam_lobby)
	if error.is_empty(): pending_steam_lobby = 0
	return error
