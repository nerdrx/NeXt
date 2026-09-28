class_name CrewOrders
extends RefCounted

const SHIP_PRICE: int = 4000
const MAX_SHIPS: int = 50
const TRIP_SECONDS: float = 300.0
const STATION_SECONDS: float = 900.0
const MAX_STOCK: int = 10000
# Raw outputs draw on abstract extraction/farming; manufactured outputs consume stock.
const PRODUCTION_INPUTS: Dictionary = {
	"ore": {}, "alloys": {"ore": 2, "fuel": 1}, "food": {}, "fuel": {},
	"medicine": {"food": 1, "fuel": 1}, "electronics": {"alloys": 1, "fuel": 1},
	"luxuries": {"electronics": 1, "alloys": 1},
}
const BASE: Dictionary = {"ore": 35, "alloys": 115, "food": 18, "fuel": 52, "medicine": 95, "electronics": 140, "luxuries": 210}
static var _family_combat_stats: Dictionary = {}
var occupied_ship_id: String = ""
var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

static func commission_quote(family_id: String = "") -> Dictionary:
	if family_id.is_empty(): return {"error":"", "price":SHIP_PRICE, "capacity":25}
	var blueprint := ShipBlueprint.family(family_id)
	if blueprint.is_empty(): return {"error":"Unknown hull family."}
	var modules: Array[Dictionary] = []
	modules.assign(blueprint.modules)
	var price := 0
	for module: Dictionary in modules: price += int(GameState.MODULES[module.kind].cost)
	return {"error":"", "price":price, "capacity":GameState.new()._stats_for(modules).cargo_capacity}

func purchase_ship(name: String, family_id: String = "") -> String:
	var quote := commission_quote(family_id)
	return _commission(name, quote, ShipBlueprint.family(family_id))


func custom_design_quote() -> Dictionary:
	if not ShipBlueprint.valid_custom_modules(state.ship_modules): return {"error":"This design must be connected, powered and flight-ready."}
	if not ShipLayout.validate_data(state.ship_layout, state.ship_modules): return {"error":"This design has an invalid room or panel layout."}
	var price := 0
	for module: Dictionary in state.ship_modules: price += int(GameState.MODULES[module.kind].cost)
	return {"error":"", "price":price, "capacity":state.ship_stats().cargo_capacity}


func purchase_custom_ship(name: String) -> String:
	return _commission(name, custom_design_quote(), {"family":"custom", "modules":state.ship_modules, "layout":state.ship_layout})


func _commission(name: String, quote: Dictionary, blueprint: Dictionary) -> String:
	if not str(quote.error).is_empty(): return str(quote.error)
	var clean: String = name.strip_edges()
	if clean.length() < 2 or clean.length() > 32: return "Fleet ship name must be 2 to 32 characters."
	if state.fleet_ships.size() >= MAX_SHIPS: return "Fleet limit reached."
	if state.credits < int(quote.price): return "This fleet ship costs %d credits." % int(quote.price)
	for ship: Dictionary in state.fleet_ships:
		if str(ship.name).to_lower() == clean.to_lower(): return "Fleet ship names must be unique."
	state.credits -= int(quote.price)
	var vessel := {"id": _id("ship"), "name": clean, "system": state.system_index, "hull": 100.0, "cargo": {}, "capacity": int(quote.capacity)}
	if not blueprint.is_empty():
		vessel.hull_family = str(blueprint.family)
		if vessel.hull_family == "custom":
			vessel.modules = blueprint.modules.duplicate(true)
			vessel.layout = blueprint.layout.duplicate(true)
	state.fleet_ships.append(vessel)
	return ""

func refit_layout(ship_id: String, cell: Vector3i, value: String, face: String = "") -> String:
	var vessel := _ship(ship_id)
	if vessel.is_empty(): return "Fleet vessel does not exist."
	var blueprint := ShipBlueprint.for_vessel(vessel)
	if blueprint.is_empty(): return "This vessel has no configurable family layout."
	if int(vessel.system) != state.system_index or float(vessel.hull) <= 0.0: return "Refit a local operational vessel."
	if _ship_busy(ship_id) or vessel.has("flight"): return "Recall and leave the vessel before refitting."
	var candidate := GameState.new()
	candidate.ship_modules.assign(blueprint.modules)
	candidate.ship_layout = vessel.get("layout",blueprint.layout).duplicate(true)
	candidate.credits = state.credits
	var error := ShipLayout.configure_room(candidate,cell,value) if face.is_empty() else ShipLayout.set_panel(candidate,cell,face,value)
	if not error.is_empty(): return error
	state.credits = candidate.credits
	vessel.layout = candidate.ship_layout.duplicate(true)
	return ""


# Scene code enforces dock access; this transaction never sells or merges either hold.
func exchange_helm(ship_id: String, outgoing_shield_delay: float = -1.0) -> String:
	var vessel := _ship(ship_id)
	if vessel.is_empty(): return "Fleet vessel does not exist."
	if int(vessel.system) != state.system_index or float(vessel.hull) <= 0.0: return "Choose a local operational vessel."
	if _ship_busy(ship_id) or vessel.has("flight"): return "Recall and leave the vessel before taking command."
	var blueprint := ShipBlueprint.for_vessel(vessel)
	if blueprint.is_empty(): return "This vessel has no pilotable saved design."
	var stats := vessel_combat_stats(vessel)
	if state.crew.size() > int(stats.crew_capacity): return "This vessel cannot accommodate your crew roster."
	if state.hull <= 0.0 or not ShipBlueprint.valid_custom_modules(state.ship_modules): return "Recover or repair your current design before storing it."
	if not ShipLayout.validate_data(state.ship_layout, state.ship_modules): return "Your current layout is invalid."
	if outgoing_shield_delay == -1.0: outgoing_shield_delay = state.shield_delay
	if not is_finite(outgoing_shield_delay) or outgoing_shield_delay < 0.0 or outgoing_shield_delay > 6.0: return "Invalid shield recovery state."
	for order: Dictionary in state.crew_orders.values():
		if str(order.kind) == "defend":
			var has_weapon := false
			for module: Dictionary in blueprint.modules:
				if module.kind == "weapon": has_weapon = true
			if not has_weapon: return "Cancel ship-defense orders before taking an unarmed vessel."
	var old_stats := state.ship_stats()
	var stored := {"id":str(state.ship_identity.id), "name":str(state.ship_identity.name), "system":state.system_index,
		"hull":clampf(state.hull / float(old_stats.max_hull) * 100.0, 0.0, 100.0), "cargo":state.cargo.duplicate(true),
		"capacity":int(old_stats.cargo_capacity), "hull_family":"custom", "modules":state.ship_modules.duplicate(true),
		"layout":state.ship_layout.duplicate(true), "fuel":state.fuel, "drive_temperature_k":state.drive_temperature_k,
		"defense":{"charge":state.shield, "delay":clampf(outgoing_shield_delay, 0.0, 6.0)}}
	var cells: Array[Vector3i] = []
	for module: Dictionary in state.ship_modules: cells.append(Vector3i(module.x,module.y,module.z))
	var family_id := ShipBlueprint.family_for_cells(cells)
	if ShipBlueprint.valid_equipment(family_id, state.ship_modules): stored.hull_family = family_id
	var index := state.fleet_ships.find(vessel)
	state.ship_modules.assign(blueprint.modules.duplicate(true))
	state.ship_layout = blueprint.layout.duplicate(true)
	state.ship_identity = {"id":str(vessel.id), "name":str(vessel.name)}
	state.cargo = vessel.cargo.duplicate(true)
	state.hull = float(stats.max_hull) * float(vessel.hull) / 100.0
	state.shield = float(vessel.get("defense", {}).get("charge", 0.0))
	state.shield_delay = float(vessel.get("defense", {}).get("delay", 0.0))
	state.fuel = float(vessel.get("fuel", 100.0))
	state.drive_temperature_k = float(vessel.get("drive_temperature_k", 300.0))
	state.fleet_ships[index] = stored
	return ""


static func equipment_refit_price(vessel: Dictionary, old_kind: String, new_kind: String) -> int:
	if old_kind == new_kind: return 0
	var refund := int(float(GameState.MODULES[old_kind].cost) * 0.5 * float(vessel.hull) / 100.0)
	return int(GameState.MODULES[new_kind].cost) - refund


func refit_module(ship_id: String, cell: Vector3i, kind: String) -> String:
	var vessel := _ship(ship_id)
	if vessel.is_empty(): return "Fleet vessel does not exist."
	if str(vessel.get("hull_family", "")) == "custom": return "Equipment refits currently require a designed hull family."
	if kind not in ShipBlueprint.FLEET_EQUIPMENT: return "Unknown fleet equipment."
	if int(vessel.system) != state.system_index or float(vessel.hull) <= 0.0: return "Refit a local operational vessel."
	if _ship_busy(ship_id) or vessel.has("flight"): return "Recall and leave the vessel before refitting."
	var blueprint := ShipBlueprint.for_vessel(vessel)
	if blueprint.is_empty(): return "This vessel has no configurable family equipment."
	var candidate: Array[Dictionary] = []
	candidate.assign(blueprint.modules.duplicate(true))
	var index := -1
	for i in candidate.size():
		if Vector3i(candidate[i].x,candidate[i].y,candidate[i].z) == cell: index = i
	if index < 0: return "No ship module at that cell."
	var old_kind: String = candidate[index].kind
	if old_kind == kind: return ""
	candidate[index].kind = kind
	if not ShipBlueprint.valid_equipment(str(vessel.hull_family), candidate): return "Keep structural modules, reactor power, cargo space and a walkable habitat."
	var model := GameState.new()
	model.ship_modules = candidate
	model.ship_layout = blueprint.layout.duplicate(true)
	ShipLayout.prune(model.ship_layout,candidate)
	var stats := model.ship_stats()
	if _cargo_total(vessel) > int(stats.cargo_capacity): return "Cargo exceeds the resulting hold capacity."
	var price := equipment_refit_price(vessel,old_kind,kind)
	if state.credits < price: return "Insufficient credits."
	state.credits -= price
	vessel.modules = candidate
	vessel.layout = model.ship_layout
	vessel.capacity = int(stats.cargo_capacity)
	if vessel.has("defense"): vessel.defense.charge = minf(float(vessel.defense.charge), float(stats.max_shield))
	return ""


func assign_trade_route(crew_id: String, ship_id: String, good: String, destination: int, quantity: int = 5, delivery_station: int = -1) -> String:
	var member: Dictionary = _member(crew_id)
	var ship: Dictionary = _ship(ship_id)
	var key: String = good.to_lower()
	if member.is_empty() or str(member.role) != "trader": return "A named trader is required."
	if ship.is_empty(): return "Fleet ship does not exist."
	if not BASE.has(key): return "Unknown trade good."
	if destination < 0 or destination >= GameState.SYSTEM_LIMIT: return "Choose a valid destination system."
	if delivery_station < -1: return "Invalid delivery station."
	if delivery_station >= 0:
		if delivery_station >= state.stations.size(): return "Owned station does not exist."
		if int(state.stations[delivery_station].system) != destination: return "Station destination does not match its system."
	elif destination == int(ship.system): return "Choose a different valid destination system."
	if quantity < 1 or quantity > int(ship.capacity): return "Trade quantity exceeds fleet hold capacity."
	for held_good: Variant in ship.cargo:
		if int(ship.cargo[held_good]) > 0 and str(held_good) != key: return "Unload the other commodity before changing this route."
	if _cargo_total(ship) >= int(ship.capacity): return "Fleet hold is full."
	if _crew_busy(crew_id) or _ship_busy(ship_id): return "Crew member or ship already has an order."
	var available: int = mini(mini(quantity, int(ship.capacity) - _cargo_total(ship)), state.market_stock(key, int(ship.system)))
	if available <= 0: return "Origin market is out of stock."
	var escrow: int = state.market_total(key, int(ship.system), available, true)
	if escrow < 0: return "Origin market cannot fill this order."
	if state.credits < escrow: return "Insufficient credits for trade escrow (%d required)." % escrow
	state.credits -= escrow
	ship.erase("flight")
	var order: Dictionary = {"kind": "trade", "crew_id": crew_id, "ship_id": ship_id, "good": key, "origin": int(ship.system), "destination": destination, "quantity": quantity, "escrow": escrow, "escrow_limit": escrow, "progress": 0.0, "phase": "outbound", "earned": 0, "paused": false, "purchase_cost": 0 if _cargo_total(ship) == 0 else -1}
	if delivery_station >= 0: order.delivery_station = delivery_station
	state.crew_orders[crew_id] = order
	return ""

func assign_station_supply(crew_id: String, ship_id: String, station_index: int, good: String, quantity: int = 5) -> String:
	if station_index < 0 or station_index >= state.stations.size(): return "Owned station does not exist."
	return assign_trade_route(crew_id, ship_id, good, int(state.stations[station_index].system), quantity, station_index)

func assign_patrol(crew_id: String, ship_id: String, system: int) -> String:
	var member: Dictionary = _member(crew_id)
	var ship: Dictionary = _ship(ship_id)
	if member.is_empty() or str(member.role) != "gunner": return "A named gunner is required."
	if ship.is_empty(): return "Fleet ship does not exist."
	if system < 0 or system >= GameState.SYSTEM_LIMIT: return "Patrol system is out of range."
	if _crew_busy(crew_id) or _ship_busy(ship_id): return "Crew member or ship already has an order."
	ship.erase("flight")
	state.crew_orders[crew_id] = {"kind": "patrol", "crew_id": crew_id, "ship_id": ship_id, "system": system, "progress": 0.0, "encounters": 0, "paused": false}
	return ""

func assign_ship_defense(crew_id: String) -> String:
	var member: Dictionary = _member(crew_id)
	if member.is_empty() or str(member.role) != "gunner": return "A named gunner is required."
	if _crew_busy(crew_id): return "Crew member already has an order."
	if state._count_kind("weapon") <= 0: return "Ship needs a weapon module for defense."
	for order: Dictionary in state.crew_orders.values():
		if str(order.get("kind", "")) == "defend": return "A gunner already has ship defense orders."
	state.crew_orders[crew_id] = {"kind": "defend", "crew_id": crew_id, "progress": 0.0, "paused": false}
	return ""

func assign_station_manager(crew_id: String, station_index: int) -> String:
	var member: Dictionary = _member(crew_id)
	if member.is_empty() or str(member.role) != "engineer": return "A named engineer is required."
	if station_index < 0 or station_index >= state.stations.size(): return "Owned station does not exist."
	if _crew_busy(crew_id) or _station_busy(station_index): return "Crew member or station already has an order."
	state.stations[station_index].stock = state.stations[station_index].get("stock", {})
	state.crew_orders[crew_id] = {"kind": "station", "crew_id": crew_id, "station_index": station_index, "progress": 0.0, "produced": 0, "paused": false}
	return ""

func cancel(crew_id: String) -> String:
	if not state.crew_orders.has(crew_id): return "Crew member has no active order."
	var order: Dictionary = state.crew_orders[crew_id]
	if order.kind == "trade":
		state.credits += int(order.escrow)
		var ship: Dictionary = _ship(str(order.ship_id))
		if not ship.is_empty(): ship.erase("flight")
	state.crew_orders.erase(crew_id)
	return ""

func consume_propulsion(ship_id: String, before: Vector3, commanded: Vector3, mass_kg: float) -> Vector3:
	if not before.is_finite(): return Vector3.ZERO
	if not commanded.is_finite() or not is_finite(mass_kg) or mass_kg <= 0.0: return before
	var ship := _ship(ship_id)
	if ship.is_empty() or float(ship.hull) <= 0.0: return before
	var change := commanded - before
	var required := mass_kg * change.length() / GameState.IMPULSE_PER_FUEL
	if not is_finite(required): return before
	if required <= 0.0: return before
	var available := clampf(float(ship.get("fuel", 100.0)), 0.0, 100.0)
	var used := minf(required, available)
	ship.fuel = maxf(0.0, available - used)
	return before + change * (used / required)


func refuel_fleet_ship(ship_id: String) -> String:
	var ship := _ship(ship_id)
	if ship.is_empty(): return "Fleet ship does not exist."
	if float(ship.hull) <= 0.0: return "Repair the disabled vessel before requesting fuel."
	var units := ceili((100.0 - float(ship.get("fuel", 100.0))) / 10.0)
	if units <= 0: return "Fleet fuel tank is full."
	var cost := state.market_total("fuel", int(ship.system), units, true)
	if cost < 0: return "The vessel's market cannot supply enough fuel."
	if state.credits < cost: return "Fleet fuel service costs %d credits." % cost
	var issue := state.market_transfer("fuel", int(ship.system), units, true)
	if not issue.is_empty(): return issue
	state.credits -= cost
	ship.fuel = minf(100.0, float(ship.get("fuel", 100.0)) + float(units) * 10.0)
	return ""


func repair_fleet_ship(ship_id: String) -> String:
	var ship: Dictionary = _ship(ship_id)
	if ship.is_empty(): return "Fleet ship does not exist."
	var missing: float = 100.0 - float(ship.hull)
	if missing <= 0.0: return "Fleet ship is already at full hull."
	var cost: int = ceili(missing * 4.0)
	if state.credits < cost: return "Fleet repairs cost %d credits." % cost
	state.credits -= cost
	ship.hull = 100.0
	return ""

func route_quote(good: String, destination: int, quantity: int, ship_id: String = "") -> Dictionary:
	var key: String = good.to_lower()
	var ship: Dictionary = _ship(ship_id) if not ship_id.is_empty() else {}
	var origin: int = int(ship.system) if not ship.is_empty() else state.system_index
	if not GameState.GOODS.has(key) or destination < 0 or destination >= GameState.SYSTEM_LIMIT or destination == origin or quantity < 1 or quantity > 100:
		return {"ok": false, "message": "Invalid route quote."}
	var buy_unit: int = state.price_at(key, origin)
	var sale_unit: int = state.market_total(key, destination, 1, false, 0.85)
	var purchase: int = state.market_total(key, origin, quantity, true)
	var sale: int = state.market_total(key, destination, quantity, false, 0.85)
	if purchase < 0 or sale < 0: return {"ok": false, "message": "Market stock or receiving capacity cannot fill this quantity."}
	# Two jump legs and two trader wages. Local thrust and delayed attempts cost extra.
	var wages: int = int(GameState.CREW_ROLES.trader.salary) * 2
	var fuel_cost: int = state.market_total("fuel", origin, 2, true)
	return {"ok": true, "good": key, "origin": origin, "destination": destination, "quantity": quantity, "buy_unit": buy_unit, "sale_unit": sale_unit, "escrow": purchase, "expected_profit": sale - purchase,
		"round_trip_wages": wages, "round_trip_fuel": 20.0, "fuel_replacement_cost": fuel_cost if fuel_cost >= 0 else null,
		"estimated_operating_margin": sale - purchase - wages - fuel_cost if fuel_cost >= 0 else null}

# Fleet menu calls this only when the ship is at the player's current dock.
func unload_fleet_cargo(ship_id: String, good: String, quantity: int) -> String:
	var ship: Dictionary = _ship(ship_id)
	var key: String = good.to_lower()
	if ship.is_empty(): return "Fleet ship does not exist."
	if _ship_busy(ship_id): return "Cancel the fleet ship's current order first."
	if int(ship.system) != state.system_index: return "Fleet ship must be in the current system."
	if not GameState.GOODS.has(key) or quantity <= 0 or quantity > int(ship.cargo.get(key, 0)): return "Invalid fleet cargo sale."
	var revenue: int = state.market_total(key, state.system_index, quantity, false, 0.85)
	if revenue < 0: return "Market has insufficient receiving capacity."
	var transfer_error: String = state.market_transfer(key, state.system_index, quantity, false)
	if not transfer_error.is_empty(): return transfer_error
	ship.cargo[key] = int(ship.cargo[key]) - quantity
	state.credits += revenue
	return ""

# The scene must enforce docking/visiting before cargo transfer.
func transfer_fleet_cargo(ship_id: String, good: String, quantity: int, to_fleet: bool) -> String:
	var ship: Dictionary = _ship(ship_id)
	var key: String = good.to_lower()
	if ship.is_empty(): return "Fleet ship does not exist."
	if not GameState.GOODS.has(key) or quantity <= 0: return "Invalid cargo transfer."
	if int(ship.system) != state.system_index: return "Fleet ship must be in the current system."
	if float(ship.hull) <= 0.0: return "Disabled fleet ship cannot transfer cargo."
	if _ship_busy(ship_id): return "Cancel the fleet ship's current order first."
	if ship.has("flight"): return "Fleet ship must be landed before transferring cargo."
	var fleet_cargo: Dictionary = ship.get("cargo", {})
	if to_fleet:
		if quantity > int(state.cargo.get(key, 0)): return "Insufficient personal cargo."
		if _cargo_total(ship) + quantity > int(ship.capacity): return "Insufficient fleet cargo capacity."
		state.cargo[key] = int(state.cargo.get(key, 0)) - quantity
		fleet_cargo[key] = int(fleet_cargo.get(key, 0)) + quantity
	else:
		if quantity > int(fleet_cargo.get(key, 0)): return "Insufficient fleet cargo."
		if state.cargo_total() + quantity > int(state.ship_stats().cargo_capacity): return "Insufficient personal cargo capacity."
		fleet_cargo[key] = int(fleet_cargo.get(key, 0)) - quantity
		state.cargo[key] = int(state.cargo.get(key, 0)) + quantity
	ship.cargo = fleet_cargo
	return ""

# The scene must enforce docking at this station before cargo transfer.
func deposit_station_stock(station_index: int, good: String, quantity: int) -> String:
	if station_index < 0 or station_index >= state.stations.size(): return "Owned station does not exist."
	var station: Dictionary = state.stations[station_index]
	var key: String = good.to_lower()
	if int(station.system) != state.system_index: return "Station is in a different system."
	if not GameState.GOODS.has(key) or quantity <= 0 or quantity > int(state.cargo.get(key, 0)): return "Invalid station supply quantity."
	var stock: Dictionary = station.get("stock", {})
	if quantity > MAX_STOCK - int(stock.get(key, 0)): return "Station storage is full."
	stock[key] = int(stock.get(key, 0)) + quantity
	station.stock = stock
	state.cargo[key] = int(state.cargo[key]) - quantity
	return ""

func station_recipe(station_index: int) -> Dictionary:
	if station_index < 0 or station_index >= state.stations.size(): return {}
	var station: Dictionary = state.stations[station_index]
	var good: String = str(PRODUCTION_INPUTS.keys()[int(station.system) % PRODUCTION_INPUTS.size()])
	return {"good": good, "inputs": PRODUCTION_INPUTS[good].duplicate(), "batch_limit": int(station.level)}

# Station UI must gate this action on being docked at the owned station.
func withdraw_station_stock(station_index: int, good: String, quantity: int) -> String:
	if station_index < 0 or station_index >= state.stations.size(): return "Owned station does not exist."
	var station: Dictionary = state.stations[station_index]
	var key: String = good.to_lower()
	if int(station.system) != state.system_index: return "Station is in a different system."
	if not GameState.GOODS.has(key) or quantity <= 0 or quantity > int(station.get("stock", {}).get(key, 0)): return "Invalid station stock withdrawal."
	if state.cargo_total() + quantity > int(state.ship_stats().cargo_capacity): return "Insufficient personal cargo capacity."
	station.stock[key] = int(station.stock[key]) - quantity
	state.cargo[key] = int(state.cargo.get(key, 0)) + quantity
	return ""

# Call only with elapsed hosted gameplay time. Paused worlds never accrue work.
func tick(elapsed_seconds: float, local_patrol_ship_ids: Array[String] = [], local_trade_status: Dictionary = {}) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	if not is_finite(elapsed_seconds) or elapsed_seconds <= 0: return reports
	var shield_elapsed: Dictionary = {}
	for crew_id: String in state.crew_orders.keys():
		var order: Dictionary = state.crew_orders[crew_id]
		if _member(crew_id).is_empty(): continue
		if order.has("ship_id"):
			var assigned_ship: Dictionary = _ship(str(order.ship_id))
			if assigned_ship.is_empty() or float(assigned_ship.hull) <= 0.0:
				if not bool(order.paused): reports.append({"kind": str(order.kind), "status": "paused: ship disabled", "crew_id": crew_id, "ship_id": str(order.ship_id)})
				order.paused = true
				continue
		var previous_progress := float(order.progress)
		order.progress = minf(previous_progress + elapsed_seconds, 86400.0 * 365.0)
		var interval: float = STATION_SECONDS if order.kind == "station" else TRIP_SECONDS * (2.0 if order.kind == "trade" else 1.0)
		var event_time := interval - previous_progress
		var local_trade: bool = order.kind == "trade" and local_trade_status.has(str(order.ship_id))
		if local_trade: order.progress = minf(float(order.progress), interval)
		while float(order.progress) >= interval:
			# A represented trader must actually reach its departure/berth point.
			if local_trade and not bool(local_trade_status[str(order.ship_id)]): break
			var fuel_cost := 0.0
			if order.has("ship_id"):
				var vessel := _ship(str(order.ship_id))
				if float(vessel.hull) <= 0.0:
					order.paused = true
					break
				var until_event := clampf(event_time, 0.0, elapsed_seconds)
				_recharge_shields(vessel, maxf(0.0, until_event - float(shield_elapsed.get(str(vessel.id), 0.0))))
				shield_elapsed[str(vessel.id)] = until_event
				if str(order.kind) == "patrol":
					var local_patrol := str(order.ship_id) in local_patrol_ship_ids and int(vessel.system) == int(order.system) and int(order.system) == state.system_index
					if not local_patrol:
						fuel_cost = 10.0 if int(vessel.system) != int(order.system) else 2.0
				elif str(order.kind) == "trade":
					var target_system := int(order.origin)
					if str(order.phase) == "outbound" and int(vessel.system) == int(order.origin):
						target_system = int(order.destination)
					var represented_same_system_trade := local_trade and int(vessel.system) == target_system
					if int(vessel.system) != target_system:
						fuel_cost = 10.0
					elif not represented_same_system_trade:
						fuel_cost = 2.0
				if float(vessel.get("fuel", 100.0)) < fuel_cost:
					order.progress = interval
					var was_paused := bool(order.paused)
					order.paused = true
					if not was_paused:
						reports.append({"kind": str(order.kind), "status": "paused: fuel insufficient", "crew_id": crew_id, "ship_id": str(vessel.id), "fuel_required": fuel_cost})
					break
			event_time += interval
			order.progress = float(order.progress) - interval
			var member: Dictionary = _member(crew_id)
			var wage: int = int(member.salary)
			if state.credits < wage:
				order.progress = interval - 1.0
				if not bool(order.paused):
					reports.append({"kind": str(order.kind), "status": "paused: wages unpaid", "crew_id": crew_id, "wages_due": wage})
				order.paused = true
				break
			state.credits -= wage
			order.paused = false
			if str(order.kind) == "defend":
				reports.append({"kind": "defend", "status": "defense wages paid", "crew_id": crew_id, "wages": wage})
				continue
			if str(order.kind) == "patrol" and str(order.ship_id) in local_patrol_ship_ids:
				var patrol_ship: Dictionary = _ship(str(order.ship_id))
				if not patrol_ship.is_empty() and int(patrol_ship.system) == int(order.system) and int(order.system) == state.system_index:
					reports.append({"kind": "patrol", "status": "local patrol wages paid", "crew_id": crew_id, "ship_id": str(order.ship_id), "system": int(order.system), "wages": wage})
					continue
			var report: Dictionary = _complete_order(order, fuel_cost)
			if not report.is_empty(): reports.append(report)
			# The scene's readiness describes this leg only, never a second leg.
			if local_trade: break
	for vessel: Dictionary in state.fleet_ships:
		_recharge_shields(vessel, maxf(0.0, elapsed_seconds - float(shield_elapsed.get(str(vessel.id), 0.0))))
	return reports

static func family_combat_stats(family_id: String) -> Dictionary:
	if family_id not in ShipBlueprint.FAMILIES: return {}
	if not _family_combat_stats.has(family_id):
		var model := GameState.new()
		model.ship_modules.assign(ShipBlueprint.family(family_id).modules)
		_family_combat_stats[family_id] = model.ship_stats()
	return _family_combat_stats[family_id]

static func vessel_combat_stats(vessel: Dictionary) -> Dictionary:
	if not vessel.has("modules"): return family_combat_stats(str(vessel.get("hull_family", "")))
	var key := JSON.stringify(vessel.modules)
	if not _family_combat_stats.has(key):
		if _family_combat_stats.size() >= 64: _family_combat_stats.clear()
		var model := GameState.new()
		model.ship_modules.assign(vessel.modules)
		_family_combat_stats[key] = model.ship_stats()
	return _family_combat_stats[key]

func _recharge_shields(vessel: Dictionary, elapsed_seconds: float) -> void:
	if float(vessel.hull) <= 0.0: return
	var stats := vessel_combat_stats(vessel)
	if stats.is_empty(): return
	var defense: Dictionary = vessel.get("defense", {"charge": 0.0, "delay": 0.0})
	var recharge_time := maxf(0.0, elapsed_seconds - float(defense.delay))
	defense.delay = maxf(0.0, float(defense.delay) - elapsed_seconds)
	defense.charge = minf(float(stats.max_shield), float(defense.charge) + recharge_time * 5.0)
	vessel.defense = defense

func _complete_order(order: Dictionary, fuel_cost: float = 0.0) -> Dictionary:
	match str(order.kind):
		"trade":
			var ship := _ship(str(order.ship_id))
			var previous_phase := str(order.phase)
			var previous_system := int(ship.get("system", -1)) if not ship.is_empty() else -1
			var report := _trade_leg(order)
			if not ship.is_empty() and (str(order.get("phase", "")) != previous_phase or int(ship.get("system", -1)) != previous_system):
				ship.fuel = maxf(0.0, float(ship.get("fuel", 100.0)) - fuel_cost)
			return report
		"patrol":
			var ship := _ship(str(order.ship_id))
			var report := _patrol_leg(order)
			if not ship.is_empty() and (str(report.get("status", "")) == "quiet patrol" or str(report.get("status", "")) == "hostile intercepted"):
				ship.fuel = maxf(0.0, float(ship.get("fuel", 100.0)) - fuel_cost)
			return report
		"station": return _station_leg(order)
	return {}

func _trade_leg(order: Dictionary) -> Dictionary:
	var ship: Dictionary = _ship(str(order.ship_id))
	if ship.is_empty(): return {"kind": "trade", "status": "fleet ship missing", "crew_id": order.crew_id}
	var good: String = str(order.good)
	if order.phase == "outbound":
		if int(ship.system) != int(order.origin):
			ship.erase("flight")
			ship.system = int(order.origin)
			return {"kind": "trade", "status": "returned to origin", "crew_id": order.crew_id, "ship_id": ship.id, "system": ship.system}
		var quantity: int = mini(int(order.quantity), int(ship.capacity) - _cargo_total(ship))
		quantity = mini(quantity, state.market_stock(good, int(order.origin)))
		if quantity <= 0: return {"kind": "trade", "status": "waiting: origin stock unavailable", "crew_id": order.crew_id}
		var escrow_top_up: int = 0
		if order.has("delivery_station"):
			escrow_top_up = mini(int(state.credits), maxi(0, int(order.escrow_limit) - int(order.escrow)))
			state.credits -= escrow_top_up
			order.escrow = int(order.escrow) + escrow_top_up
		var cost: int = state.market_total(good, int(order.origin), quantity, true)
		while quantity > 0 and (cost < 0 or cost > int(order.escrow)):
			quantity -= 1
			cost = state.market_total(good, int(order.origin), quantity, true)
		if quantity <= 0: return {"kind": "trade", "status": "escrow exhausted", "crew_id": order.crew_id}
		var transfer_error: String = state.market_transfer(good, int(order.origin), quantity, true)
		if not transfer_error.is_empty():
			if escrow_top_up > 0:
				state.credits += escrow_top_up
				order.escrow = int(order.escrow) - escrow_top_up
			return {"kind": "trade", "status": transfer_error, "crew_id": order.crew_id}
		var prior_cost: int = int(order.get("purchase_cost", 0 if int(ship.cargo.get(good, 0)) == 0 else -1))
		order.purchase_cost = prior_cost + cost if prior_cost >= 0 else -1
		order.escrow = int(order.escrow) - cost
		ship.cargo[good] = int(ship.cargo.get(good, 0)) + quantity
		ship.erase("flight")
		ship.system = int(order.destination)
		order.phase = "inbound"
		return {"kind": "trade", "status": "cargo bought", "crew_id": order.crew_id, "ship_id": ship.id, "good": good, "quantity": quantity, "cost": cost, "system": ship.system}
	var sold: int = int(ship.cargo.get(good, 0))
	if sold <= 0:
		order.purchase_cost = 0
		ship.erase("flight")
		ship.system = int(order.origin)
		order.phase = "outbound"
		return {"kind": "trade", "status": "no cargo to sell", "crew_id": order.crew_id}
	if order.has("delivery_station"):
		var station_index: int = int(order.delivery_station)
		if station_index < 0 or station_index >= state.stations.size(): return {"kind": "trade", "status": "station missing", "crew_id": order.crew_id, "ship_id": ship.id}
		var station: Dictionary = state.stations[station_index]
		if int(station.system) != int(order.destination): return {"kind": "trade", "status": "station destination changed", "crew_id": order.crew_id, "ship_id": ship.id}
		var stock: Dictionary = station.get("stock", {})
		if sold > MAX_STOCK - int(stock.get(good, 0)): return {"kind": "trade", "status": "waiting: station storage full", "crew_id": order.crew_id, "ship_id": ship.id, "station": station.name}
		var purchase_cost: int = int(order.get("purchase_cost", -1))
		stock[good] = int(stock.get(good, 0)) + sold
		station.stock = stock
		ship.cargo[good] = 0
		ship.erase("flight")
		ship.system = int(order.origin)
		order.phase = "outbound"
		order.purchase_cost = 0
		return {"kind": "trade", "status": "cargo delivered", "crew_id": order.crew_id, "ship_id": ship.id, "good": good, "quantity": sold, "station": station.name, "station_index": station_index, "cost": purchase_cost if purchase_cost >= 0 else null, "system": ship.system}
	var revenue: int = state.market_total(good, int(order.destination), sold, false, 0.85)
	if revenue < 0: return {"kind": "trade", "status": "waiting: destination market full", "crew_id": order.crew_id}
	var transfer_error: String = state.market_transfer(good, int(order.destination), sold, false)
	if not transfer_error.is_empty(): return {"kind": "trade", "status": transfer_error, "crew_id": order.crew_id}
	ship.cargo[good] = 0
	ship.erase("flight")
	var refill: int = mini(revenue, int(order.escrow_limit) - int(order.escrow))
	order.escrow = int(order.escrow) + refill
	state.credits += revenue - refill
	var purchase_cost: int = int(order.get("purchase_cost", -1))
	var profit: Variant = revenue - purchase_cost if purchase_cost >= 0 else null
	if profit != null: order.earned = int(order.earned) + int(profit)
	order.purchase_cost = 0
	ship.system = int(order.origin)
	order.phase = "outbound"
	return {"kind": "trade", "status": "cargo sold", "crew_id": order.crew_id, "ship_id": ship.id, "good": good, "quantity": sold, "revenue": revenue, "purchase_cost": purchase_cost if purchase_cost >= 0 else null, "profit": profit, "system": ship.system}

func _patrol_leg(order: Dictionary) -> Dictionary:
	var ship: Dictionary = _ship(str(order.ship_id))
	if ship.is_empty(): return {"kind": "patrol", "status": "fleet ship missing", "crew_id": order.crew_id}
	ship.system = int(order.system)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(order.encounters) * 97 + int(order.system) * 31 + int(state.day) * 13 + int(str(ship.id).hash())
	order.encounters = int(order.encounters) + 1
	if rng.randf() < 0.62:
		var damage: float = rng.randf_range(3.0, 16.0)
		var hull_damage := damage
		var stats := vessel_combat_stats(ship)
		if not stats.is_empty():
			var defense: Dictionary = ship.get("defense", {"charge": 0.0, "delay": 0.0})
			var absorbed := minf(float(defense.charge), damage)
			defense.charge = float(defense.charge) - absorbed
			defense.delay = 6.0
			ship.defense = defense
			hull_damage = (damage - absorbed) * 100.0 / float(stats.max_hull)
		ship.hull = maxf(0.0, float(ship.hull) - hull_damage) if not stats.is_empty() else snappedf(maxf(0.0, float(ship.hull) - hull_damage), 0.1)
		var reward: int = roundi(rng.randf_range(180.0, 420.0))
		state.credits += reward
		return {"kind": "patrol", "status": "hostile intercepted", "crew_id": order.crew_id, "ship_id": ship.id, "system": ship.system, "damage": damage, "reward": reward, "hull": ship.hull}
	return {"kind": "patrol", "status": "quiet patrol", "crew_id": order.crew_id, "ship_id": ship.id, "system": ship.system, "hull": ship.hull}

func _station_leg(order: Dictionary) -> Dictionary:
	var index: int = int(order.station_index)
	if index < 0 or index >= state.stations.size(): return {"kind": "station", "status": "station missing", "crew_id": order.crew_id}
	var station: Dictionary = state.stations[index]
	var stock: Dictionary = station.get("stock", {})
	var recipe := station_recipe(index)
	var good: String = recipe.good
	var amount: int = mini(int(recipe.batch_limit), MAX_STOCK - int(stock.get(good, 0)))
	if amount <= 0: return {"kind": "station", "status": "storage full", "crew_id": order.crew_id, "station": station.name}
	for input: String in recipe.inputs:
		amount = mini(amount, int(stock.get(input, 0)) / int(recipe.inputs[input]))
	if amount <= 0: return {"kind": "station", "status": "waiting: production inputs missing", "crew_id": order.crew_id, "station": station.name}
	for input: String in recipe.inputs:
		stock[input] = int(stock[input]) - int(recipe.inputs[input]) * amount
	stock[good] = int(stock.get(good, 0)) + amount
	station.stock = stock
	order.produced = mini(int(order.produced), 9223372036854775807 - amount) + amount
	return {"kind": "station", "status": "production complete", "crew_id": order.crew_id, "station": station.name, "good": good, "quantity": amount, "stock": int(stock[good])}

func _member(id: String) -> Dictionary:
	for member: Dictionary in state.crew:
		if str(member.get("id", "")) == id: return member
	return {}

func _ship(id: String) -> Dictionary:
	for ship: Dictionary in state.fleet_ships:
		if str(ship.get("id", "")) == id: return ship
	return {}

func _crew_busy(id: String) -> bool: return state.crew_orders.has(id)

func _ship_busy(id: String) -> bool:
	if id == occupied_ship_id: return true
	for order: Dictionary in state.crew_orders.values():
		if str(order.get("ship_id", "")) == id: return true
	return false

func _station_busy(index: int) -> bool:
	for order: Dictionary in state.crew_orders.values():
		if order.kind == "station" and int(order.get("station_index", -1)) == index: return true
	return false

func _price(good: String, system: int) -> int:
	return state.price_at(good, system)

func _cargo_total(ship: Dictionary) -> int:
	var total: int = 0
	for value: Variant in ship.cargo.values(): total += int(value)
	return total

func _id(prefix: String) -> String: return "%s-%s" % [prefix, Crypto.new().generate_random_bytes(12).hex_encode()]
