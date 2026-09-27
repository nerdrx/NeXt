class_name CrewOrders
extends RefCounted

const SHIP_PRICE: int = 4000
const MAX_SHIPS: int = 50
const TRIP_SECONDS: float = 300.0
const STATION_SECONDS: float = 900.0
const MAX_STOCK: int = 10000
const BASE: Dictionary = {"ore": 35, "alloys": 115, "food": 18, "fuel": 52, "medicine": 95, "electronics": 140, "luxuries": 210}
var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

func purchase_ship(name: String) -> String:
	var clean: String = name.strip_edges()
	if clean.length() < 2 or clean.length() > 32: return "Fleet ship name must be 2 to 32 characters."
	if state.fleet_ships.size() >= MAX_SHIPS: return "Fleet limit reached."
	if state.credits < SHIP_PRICE: return "A fleet ship costs %d credits." % SHIP_PRICE
	for ship: Dictionary in state.fleet_ships:
		if str(ship.name).to_lower() == clean.to_lower(): return "Fleet ship names must be unique."
	state.credits -= SHIP_PRICE
	state.fleet_ships.append({"id": _id("ship"), "name": clean, "system": state.system_index, "hull": 100.0, "cargo": {}, "capacity": 25})
	return ""

func assign_trade_route(crew_id: String, ship_id: String, good: String, destination: int, quantity: int = 5) -> String:
	var member: Dictionary = _member(crew_id)
	var ship: Dictionary = _ship(ship_id)
	var key: String = good.to_lower()
	if member.is_empty() or str(member.role) != "trader": return "A named trader is required."
	if ship.is_empty(): return "Fleet ship does not exist."
	if not BASE.has(key): return "Unknown trade good."
	if destination < 0 or destination >= GameState.SYSTEM_LIMIT or destination == int(ship.system): return "Choose a different valid destination system."
	if quantity < 1 or quantity > int(ship.capacity): return "Trade quantity exceeds fleet hold capacity."
	for held_good: Variant in ship.cargo:
		if int(ship.cargo[held_good]) > 0 and str(held_good) != key: return "Unload the other commodity before changing this route."
	if _cargo_total(ship) >= int(ship.capacity): return "Fleet hold is full."
	if _crew_busy(crew_id) or _ship_busy(ship_id): return "Crew member or ship already has an order."
	var escrow: int = _price(key, int(ship.system)) * mini(quantity, int(ship.capacity) - _cargo_total(ship))
	if state.credits < escrow: return "Insufficient credits for trade escrow (%d required)." % escrow
	state.credits -= escrow
	ship.erase("flight")
	state.crew_orders[crew_id] = {"kind": "trade", "crew_id": crew_id, "ship_id": ship_id, "good": key, "origin": int(ship.system), "destination": destination, "quantity": quantity, "escrow": escrow, "escrow_limit": escrow, "progress": 0.0, "phase": "outbound", "earned": 0, "paused": false}
	return ""

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
	var sale_unit: int = floori(float(state.price_at(key, destination)) * 0.85)
	return {"ok": true, "good": key, "origin": origin, "destination": destination, "quantity": quantity, "buy_unit": buy_unit, "sale_unit": sale_unit, "escrow": buy_unit * quantity, "expected_profit": (sale_unit - buy_unit) * quantity}

# Fleet menu calls this only when the ship is at the player's current dock.
func unload_fleet_cargo(ship_id: String, good: String, quantity: int) -> String:
	var ship: Dictionary = _ship(ship_id)
	var key: String = good.to_lower()
	if ship.is_empty(): return "Fleet ship does not exist."
	if _ship_busy(ship_id): return "Cancel the fleet ship's current order first."
	if int(ship.system) != state.system_index: return "Fleet ship must be in the current system."
	if not GameState.GOODS.has(key) or quantity <= 0 or quantity > int(ship.cargo.get(key, 0)): return "Invalid fleet cargo sale."
	var revenue: int = floori(float(state.price_at(key, state.system_index)) * quantity * 0.85)
	ship.cargo[key] = int(ship.cargo[key]) - quantity
	state.credits += revenue
	return ""

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
	for crew_id: String in state.crew_orders.keys():
		var order: Dictionary = state.crew_orders[crew_id]
		if _member(crew_id).is_empty(): continue
		if order.has("ship_id"):
			var assigned_ship: Dictionary = _ship(str(order.ship_id))
			if assigned_ship.is_empty() or float(assigned_ship.hull) <= 0.0:
				if not bool(order.paused): reports.append({"kind": str(order.kind), "status": "paused: ship disabled", "crew_id": crew_id, "ship_id": str(order.ship_id)})
				order.paused = true
				continue
		order.progress = minf(float(order.progress) + elapsed_seconds, 86400.0 * 365.0)
		var interval: float = STATION_SECONDS if order.kind == "station" else TRIP_SECONDS * (2.0 if order.kind == "trade" else 1.0)
		var local_trade: bool = order.kind == "trade" and local_trade_status.has(str(order.ship_id))
		if local_trade: order.progress = minf(float(order.progress), interval)
		while float(order.progress) >= interval:
			# A represented trader must actually reach its departure/berth point.
			if local_trade and not bool(local_trade_status[str(order.ship_id)]): break
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
			var report: Dictionary = _complete_order(order)
			if not report.is_empty(): reports.append(report)
			# The scene's readiness describes this leg only, never a second leg.
			if local_trade: break
	return reports

func _complete_order(order: Dictionary) -> Dictionary:
	match str(order.kind):
		"trade": return _trade_leg(order)
		"patrol": return _patrol_leg(order)
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
		var unit_price: int = _price(good, int(order.origin))
		var quantity: int = mini(int(order.quantity), int(ship.capacity) - _cargo_total(ship))
		quantity = mini(quantity, int(order.escrow) / unit_price)
		if quantity <= 0: return {"kind": "trade", "status": "escrow exhausted", "crew_id": order.crew_id}
		var cost: int = unit_price * quantity
		order.escrow = int(order.escrow) - cost
		ship.cargo[good] = int(ship.cargo.get(good, 0)) + quantity
		ship.erase("flight")
		ship.system = int(order.destination)
		order.phase = "inbound"
		return {"kind": "trade", "status": "cargo bought", "crew_id": order.crew_id, "ship_id": ship.id, "good": good, "quantity": quantity, "system": ship.system}
	var sold: int = int(ship.cargo.get(good, 0))
	if sold <= 0:
		ship.erase("flight")
		ship.system = int(order.origin)
		order.phase = "outbound"
		return {"kind": "trade", "status": "no cargo to sell", "crew_id": order.crew_id}
	var gross: int = _price(good, int(order.destination)) * sold
	var revenue: int = floori(float(gross) * 0.85)
	ship.cargo[good] = 0
	ship.erase("flight")
	var refill: int = mini(revenue, int(order.escrow_limit) - int(order.escrow))
	order.escrow = int(order.escrow) + refill
	state.credits += revenue - refill
	order.earned = int(order.earned) + revenue - _price(good, int(order.origin)) * sold
	ship.system = int(order.origin)
	order.phase = "outbound"
	return {"kind": "trade", "status": "cargo sold", "crew_id": order.crew_id, "ship_id": ship.id, "good": good, "quantity": sold, "revenue": revenue, "profit": revenue - _price(good, int(order.origin)) * sold, "system": ship.system}

func _patrol_leg(order: Dictionary) -> Dictionary:
	var ship: Dictionary = _ship(str(order.ship_id))
	if ship.is_empty(): return {"kind": "patrol", "status": "fleet ship missing", "crew_id": order.crew_id}
	ship.system = int(order.system)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(order.encounters) * 97 + int(order.system) * 31 + int(state.day) * 13 + int(str(ship.id).hash())
	order.encounters = int(order.encounters) + 1
	if rng.randf() < 0.62:
		var damage: float = rng.randf_range(3.0, 16.0)
		ship.hull = snappedf(maxf(0.0, float(ship.hull) - damage), 0.1)
		var reward: int = roundi(rng.randf_range(180.0, 420.0))
		state.credits += reward
		return {"kind": "patrol", "status": "hostile intercepted", "crew_id": order.crew_id, "ship_id": ship.id, "system": ship.system, "damage": damage, "reward": reward, "hull": ship.hull}
	return {"kind": "patrol", "status": "quiet patrol", "crew_id": order.crew_id, "ship_id": ship.id, "system": ship.system, "hull": ship.hull}

func _station_leg(order: Dictionary) -> Dictionary:
	var index: int = int(order.station_index)
	if index < 0 or index >= state.stations.size(): return {"kind": "station", "status": "station missing", "crew_id": order.crew_id}
	var station: Dictionary = state.stations[index]
	var stock: Dictionary = station.get("stock", {})
	var good: String = str(["ore", "alloys", "food", "fuel", "medicine", "electronics", "luxuries"][int(station.system) % 7])
	var amount: int = mini(int(station.level), MAX_STOCK - int(stock.get(good, 0)))
	if amount <= 0: return {"kind": "station", "status": "storage full", "crew_id": order.crew_id, "station": station.name}
	stock[good] = int(stock.get(good, 0)) + amount
	station.stock = stock
	order.produced = int(order.produced) + amount
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
