class_name GameState
extends RefCounted

const SAVE_VERSION: int = 3
const ShipRecovery = preload("res://scripts/ship_recovery.gd")
const ShipLayout = preload("res://scripts/ship_layout.gd")
const StationLayoutDomain = preload("res://scripts/station_layout.gd")
const PlayerFactionDomain = preload("res://scripts/player_faction.gd")
const SYSTEM_LIMIT: int = 1_000_000_000
const DAY_SECONDS: float = 1200.0
const MAX_ELAPSED_SECONDS: float = 86400.0
const MAX_EPHEMERIS_SECONDS: float = 1.0e12
const IMPULSE_PER_FUEL: float = 5.0e6 # Newton-seconds per abstract tank unit.
const MAX_ITEMS: int = 1000
const SHIP_CELL_LIMIT: int = 16
const MAX_SHIP_MODULES: int = 100
const MAX_WORLD_FLAGS: int = 10000
const MARKET_CAPACITY: int = 100000
const MAX_MARKETS: int = 10000
const MAX_SCARCITY_MULTIPLIER: float = 3.0
const GOODS: Dictionary = {"ore": 35, "alloys": 115, "food": 18, "fuel": 52, "medicine": 95, "electronics": 140, "luxuries": 210}
const MODULES: Dictionary = {
	"core": {"cost": 0, "mass": 8, "power": -1, "cargo": 0, "hull": 20, "thrust": 0},
	"cockpit": {"cost": 800, "mass": 4, "power": -1, "cargo": 0, "hull": 15, "thrust": 0},
	"engine": {"cost": 1200, "mass": 5, "power": -2, "cargo": 0, "hull": 10, "thrust": 18},
	"reactor": {"cost": 1400, "mass": 6, "power": 12, "cargo": 0, "hull": 15, "thrust": 0},
	"cargo": {"cost": 650, "mass": 3, "power": 0, "cargo": 15, "hull": 10, "thrust": 0},
	"weapon": {"cost": 1000, "mass": 4, "power": -2, "cargo": 0, "hull": 10, "thrust": 0},
	"shield": {"cost": 900, "mass": 4, "power": -2, "cargo": 0, "hull": 5, "thrust": 0},
	"habitat": {"cost": 750, "mass": 5, "power": -1, "cargo": 5, "hull": 10, "thrust": 0},
	"radiator": {"cost": 900, "mass": 2, "power": 0, "cargo": 0, "hull": 5, "thrust": 0},
}
const COMPANIES: Dictionary = {
	"NOVA": {"name": "Nova Freight", "base": 85, "sector": "Logistics"},
	"HELI": {"name": "Helios Mining", "base": 120, "sector": "Mining"},
	"VITA": {"name": "Vita Systems", "base": 150, "sector": "Medicine"},
}
const CREW_ROLES: Dictionary = {
	"engineer": {"name": "Chief Engineer", "salary": 90, "hire_cost": 500},
	"gunner": {"name": "Combat Gunner", "salary": 110, "hire_cost": 500},
	"trader": {"name": "Trade Specialist", "salary": 75, "hire_cost": 500},
}
const CREW_FIRST_NAMES: Array[String] = ["Ari", "Mara", "Jonas", "Leila", "Tomas", "Nia", "Elias", "Rhea", "Sana", "Milo", "Kira", "Dara", "Noah", "Imani", "Luca", "Mei", "Ravi", "Anika", "Omar", "Vera", "Idris", "Lina", "Mateo", "Yara", "Amir", "Talia", "Felix", "Zuri", "Theo", "Esme"]
const CREW_LAST_NAMES: Array[String] = ["Voss", "Okafor", "Chen", "Navarro", "Petrov", "Haddad", "Kowalski", "Singh", "Sato", "Mensah", "Moreau", "Rossi", "Bauer", "Costa", "Kim", "Nakamura", "Alvarez", "Rahman", "Svensson", "Dlamini", "Ivanov", "Dubois", "Mori", "Khan", "Weber", "Silva", "Bennett", "Tanaka", "Fischer", "Adeyemi"]

var system_index: int = 0
var location: Dictionary = {}
var world_id: String = ""
var credits: int = 18000
var cargo: Dictionary = {}
var hull: float = 100.0
var shield: float = 100.0
var fuel: float = 100.0
var drive_temperature_k: float = 300.0
var kills: int = 0
var day: int = 0
var day_progress: float = 0.0
var ephemeris_seconds: float = 0.0
var visited: Array[int] = [0]
var reputation: Dictionary = {}
var wanted: int = 0
var ship_modules: Array[Dictionary] = []
var stations: Array[Dictionary] = []
var shares: Dictionary = {}
var crew: Array[Dictionary] = []
var fleet_ships: Array[Dictionary] = []
var crew_orders: Dictionary = {}
var recovery: Dictionary = {}
var ship_layout: Dictionary = {}
var faction: Dictionary = {}
var world_flags: Dictionary = {}
var company_name: String = ""
var company_balance: int = 0
var crew_paid: bool = false
var contracts: Array[Dictionary] = []
# Persist changed market stocks; there is no passive restock/consumption yet.
var market_stocks: Dictionary = {}

func _init() -> void:
	world_id = _new_world_id()
	cargo = {"ore": 0, "alloys": 0, "food": 0, "fuel": 0, "medicine": 0, "electronics": 0, "luxuries": 0}
	ship_modules = [
		{"kind": "core", "x": 0, "y": 0, "z": 2},
		{"kind": "cockpit", "x": 0, "y": 0, "z": 0},
		{"kind": "reactor", "x": 1, "y": 0, "z": 0},
		{"kind": "engine", "x": -1, "y": 0, "z": 0},
		{"kind": "cargo", "x": -1, "y": 0, "z": 1},
		{"kind": "weapon", "x": 1, "y": 0, "z": 1},
		{"kind": "shield", "x": 0, "y": 0, "z": 1},
	]
	var initial_stats: Dictionary = ship_stats()
	hull = float(initial_stats.max_hull)
	shield = float(initial_stats.max_shield)
	contracts = contract_board()
	recovery = ShipRecovery.empty_data()
	ship_layout = ShipLayout.empty_data()
	faction = PlayerFactionDomain.empty_data()

func cargo_total() -> int:
	var total: int = 0
	for quantity: Variant in cargo.values():
		if quantity is int: total += quantity
	return total

func ship_stats() -> Dictionary:
	var result: Dictionary = _stats_for(ship_modules)
	result.radiator_area_m2 = radiator_area_m2()
	result.thermal_emission_w = ThermalSignature.emitted_power_w(drive_temperature_k, result.radiator_area_m2)
	result.thermal_detection_range_m = ThermalSignature.detection_range_m(result.thermal_emission_w)
	result.drive_thrust_factor = clampf((700.0 - drive_temperature_k) / 200.0, 0.0, 1.0)
	result.loaded_mass_kg = int(result.dry_mass_kg) + cargo_total() * 1000
	result.acceleration_mps2 = minf(3.0 * 9.80665, float(result.thrust_newtons) * float(result.drive_thrust_factor) / maxf(float(result.loaded_mass_kg), 1.0))
	result.boost_acceleration_mps2 = minf(6.0 * 9.80665, float(result.thrust_newtons) * float(result.drive_thrust_factor) * float(result.boost_multiplier) / maxf(float(result.loaded_mass_kg), 1.0))
	return result

func radiator_area_m2() -> float:
	# Retain the starter's abstract 40 m2 loop; modular panels add exposed area.
	var area: float = 40.0
	var occupied: Dictionary = {}
	for module: Dictionary in ship_modules:
		occupied[Vector3i(module.x, module.y, module.z)] = true
	for module: Dictionary in ship_modules:
		if module.kind != "radiator": continue
		var cell := Vector3i(module.x, module.y, module.z)
		var panels: Dictionary = ship_layout.panels.get(ShipLayout.cell_key(cell), {})
		area += 5.0 * ShipLayout.exposed_radiator_faces(cell, occupied, panels).size()
	return area

func cool_drive(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or delta > 1.0: return
	if not is_finite(drive_temperature_k): return
	# Tuned shared drive loop: 2.5 MJ/K, layout-dependent area, emissivity 0.8.
	# 300 K is a regulated floor, not the temperature of space.
	var area := radiator_area_m2()
	var watts := ThermalSignature.emitted_power_w(drive_temperature_k, area) - ThermalSignature.emitted_power_w(300.0, area)
	drive_temperature_k = maxf(300.0, drive_temperature_k - maxf(0.0, watts) * delta / 2.5e6)

func consume_propulsion(before: Vector3, commanded: Vector3) -> Vector3:
	if not before.is_finite(): return Vector3.ZERO
	if not commanded.is_finite() or not is_finite(fuel) or fuel <= 0.0: return before
	var delta_velocity := commanded - before
	var speed_change := delta_velocity.length()
	if not is_finite(speed_change) or speed_change <= 0.0: return before
	var mass := maxf(float(ship_stats().loaded_mass_kg), 1.0)
	var required := speed_change * mass / IMPULSE_PER_FUEL
	if not is_finite(drive_temperature_k) or drive_temperature_k < 300.0: return before
	var thermal_budget := maxf(0.0, (700.0 - drive_temperature_k) / 20.0)
	var used := minf(minf(fuel, thermal_budget), required)
	var result := before + delta_velocity * (used / required)
	if not result.is_finite(): return before
	fuel = maxf(0.0, fuel - used)
	# 50 MJ waste heat per tank unit into the shared 2.5 MJ/K loop.
	drive_temperature_k = minf(700.0, drive_temperature_k + used * 20.0)
	return result

func emergency_refuel() -> String:
	if not is_finite(fuel) or fuel < 0.0: return "Invalid fuel level."
	if fuel > 0.01: return "Emergency delivery is reserved for empty tanks."
	var fee := maxi(500, price("fuel") * 4)
	var paid := mini(credits, fee)
	credits -= paid
	recovery.debt += fee - paid
	fuel = 20.0
	return ""

func price(good: String) -> int:
	return price_at(good, system_index, day)

func price_at(good: String, system: int, simulation_day: int = -1) -> int:
	var key: String = good.to_lower()
	if not GOODS.has(key): return 0
	if system < 0 or system >= SYSTEM_LIMIT: return 0
	return _stock_price(key, system, market_stock(key, system), _base_price_at(key, system, simulation_day))

func _base_price_at(key: String, system: int, simulation_day: int) -> int:
	var salt: int = 0
	for byte: int in key.to_ascii_buffer(): salt = (salt * 31 + byte) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	var price_day: int = day if simulation_day < 0 else simulation_day
	rng.seed = ((system * 1103515245 + salt * 12345 + price_day * 7919) & 0x7fffffff)
	return maxi(1, roundi(float(GOODS[key]) * rng.randf_range(0.65, 1.45)))

func _stock_price(good: String, system: int, stock: int, base: int) -> int:
	var initial: int = _initial_market_stock(good, system)
	var scarcity: float = pow(float(initial + 1) / float(stock + 1), 0.35)
	return maxi(1, roundi(float(base) * clampf(scarcity, 0.5, MAX_SCARCITY_MULTIPLIER)))

func _initial_market_stock(good: String, system: int) -> int:
	var salt: int = 0
	for byte: int in good.to_ascii_buffer(): salt = (salt * 31 + byte) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = ((system * 1103515245 + salt * 12345 + 0x4D41524B) & 0x7fffffff)
	return rng.randi_range(200, 600)

func market_stock(good: String, system: int = -1) -> int:
	var key: String = good.to_lower()
	var index: int = system_index if system == -1 else system
	if not GOODS.has(key) or index < 0 or index >= SYSTEM_LIMIT: return -1
	return int(market_stocks.get(str(index), {}).get(key, _initial_market_stock(key, index)))

func market_total(good: String, system: int, quantity: int, buy: bool, multiplier: float = 1.0) -> int:
	var key: String = good.to_lower()
	if not GOODS.has(key) or system < 0 or system >= SYSTEM_LIMIT or quantity <= 0 or quantity > MARKET_CAPACITY or not is_finite(multiplier) or multiplier <= 0.0 or multiplier > 1000000.0: return -1
	var stock: int = market_stock(key, system)
	if buy and stock < quantity or not buy and stock > MARKET_CAPACITY - quantity: return -1
	var total: int = 0
	var initial: int = _initial_market_stock(key, system)
	var base: int = _base_price_at(key, system, day)
	for i: int in range(quantity):
		var marginal_stock: int = stock - i if buy else stock + i + 1
		var scarcity: float = pow(float(initial + 1) / float(marginal_stock + 1), 0.35)
		var unit: int = maxi(1, roundi(float(base) * clampf(scarcity, 0.5, MAX_SCARCITY_MULTIPLIER)))
		unit = maxi(1, roundi(float(unit) * multiplier))
		total += unit
	return total

func market_transfer(good: String, system: int, quantity: int, buy: bool) -> String:
	var key: String = good.to_lower()
	if not GOODS.has(key): return "Unknown good."
	if system < 0 or system >= SYSTEM_LIMIT or quantity <= 0 or quantity > MARKET_CAPACITY: return "Invalid market transfer."
	var stock: int = market_stock(key, system)
	var next_stock: int = stock - quantity if buy else stock + quantity
	if next_stock < 0: return "Insufficient market stock."
	if next_stock > MARKET_CAPACITY: return "Market has insufficient capacity."
	var system_key: String = str(system)
	var updated: Dictionary = market_stocks.get(system_key, {}).duplicate(true)
	if next_stock == _initial_market_stock(key, system): updated.erase(key)
	else: updated[key] = next_stock
	if updated.is_empty():
		market_stocks.erase(system_key)
	else:
		if not market_stocks.has(system_key) and market_stocks.size() >= MAX_MARKETS: return "Market record limit reached."
		market_stocks[system_key] = updated
	return ""

func trade(good: String, quantity: int, buy: bool) -> String:
	var key: String = good.to_lower()
	if not GOODS.has(key): return "Unknown good."
	if quantity <= 0 or quantity > 100000: return "Quantity must be between 1 and 100000."
	var total: int = player_trade_total(key, quantity, buy)
	if total < 0: return "Insufficient market stock." if buy else "Market has insufficient capacity."
	if buy:
		if quantity > int(ship_stats().cargo_capacity) - cargo_total(): return "Insufficient cargo capacity."
		if total > credits: return "Insufficient credits."
		var transfer_error: String = market_transfer(key, system_index, quantity, true)
		if transfer_error != "": return transfer_error
		credits -= total
		cargo[key] = int(cargo.get(key, 0)) + quantity
	else:
		if int(cargo.get(key, 0)) < quantity: return "Insufficient cargo."
		var transfer_error: String = market_transfer(key, system_index, quantity, false)
		if transfer_error != "": return transfer_error
		cargo[key] = int(cargo.get(key, 0)) - quantity
		credits += total
	return ""


func player_trade_total(good: String, quantity: int, buy: bool) -> int:
	var key := good.to_lower()
	if not GOODS.has(key): return -1
	var discount: int = mini(15, _paid_crew_count("trader") * 2)
	var system_faction: String = str(Universe.system_data(system_index).faction)
	var multiplier: float = PlayerFactionDomain.trade_multiplier(faction, system_faction, buy)
	var sale_factor: float = 1.0 if buy else 0.85
	var total: int = market_total(key, system_index, quantity, buy, float(100 - discount) / 100.0 * sale_factor * multiplier)
	return total

func trade_quote(good: String, buy: bool) -> int:
	return maxi(0, player_trade_total(good, 1, buy))

func add_module(kind: String, cell: Vector3i) -> String:
	if not MODULES.has(kind) or kind == "core": return "Unknown or unavailable module."
	if ship_modules.size() >= MAX_SHIP_MODULES: return "Ship module limit reached."
	if absi(cell.x) > SHIP_CELL_LIMIT or absi(cell.z) > SHIP_CELL_LIMIT or absi(cell.y) > SHIP_CELL_LIMIT: return "Cell is outside the construction grid."
	if _module_at(cell) >= 0: return "That ship cell is occupied."
	if ship_modules.is_empty() or not _adjacent_to_ship(cell): return "Module must attach to the ship."
	var spec: Dictionary = MODULES[kind]
	if credits < int(spec.cost): return "Insufficient credits."
	var trial := ship_modules.duplicate(true)
	trial.append(_module_record(kind, cell))
	if _stats_for(trial).power_balance < 0: return "Ship has insufficient reactor power."
	credits -= int(spec.cost)
	ship_modules.append(_module_record(kind, cell))
	ShipLayout.prune(ship_layout, ship_modules)
	return ""

func remove_module(cell: Vector3i) -> String:
	var index: int = _module_at(cell)
	if index < 0: return "No module at that cell."
	if ship_modules[index].kind in ["core", "cockpit", "reactor", "engine"]: return "Required ship module cannot be removed."
	if ship_modules[index].kind == "cargo" and _count_kind("cargo") <= 1: return "At least one cargo module is required."
	var trial := ship_modules.duplicate(true)
	var removed: Dictionary = trial[index]
	trial.remove_at(index)
	if not _connected(trial): return "Removal would split the ship."
	var stats: Dictionary = _stats_for(trial)
	if crew.size() > int(stats.crew_capacity): return "Ship cannot support its current crew."
	if cargo_total() > int(stats.cargo_capacity): return "Cargo exceeds the resulting hold capacity."
	if int(stats.power_balance) < 0: return "Ship would have insufficient power."
	ship_modules = trial
	ShipLayout.prune(ship_layout, ship_modules)
	credits += int(MODULES[removed.kind].cost) / 2
	hull = minf(hull, float(stats.max_hull))
	shield = minf(shield, float(stats.max_shield))
	return ""

func jump(destination: int) -> String:
	if destination < 0 or destination >= SYSTEM_LIMIT: return "Destination is out of range."
	if destination == system_index: return "Already in that system."
	if fuel < 10.0: return "Insufficient fuel."
	fuel -= 10.0
	system_index = destination
	location = {}
	if not visited.has(destination):
		visited.append(destination)
		if visited.size() > MAX_ITEMS: visited.pop_front()
	_advance_day()
	return ""

func advance_time(elapsed_seconds: float) -> int:
	if not is_finite(elapsed_seconds) or elapsed_seconds < 0.0 or elapsed_seconds > MAX_ELAPSED_SECONDS: return 0
	if not is_finite(ephemeris_seconds) or ephemeris_seconds < 0.0 or ephemeris_seconds > MAX_EPHEMERIS_SECONDS - elapsed_seconds: return 0
	ephemeris_seconds += elapsed_seconds
	var total: float = day_progress + elapsed_seconds
	var days_elapsed: int = int(floor(total / DAY_SECONDS))
	day_progress = fmod(total, DAY_SECONDS)
	for _index: int in range(days_elapsed): _advance_day()
	return days_elapsed

func clock_text() -> String:
	var minute_of_day: int = int(floor(day_progress / DAY_SECONDS * 1440.0))
	return "%02d:%02d" % [minute_of_day / 60, minute_of_day % 60]

func _advance_day() -> void:
	day += 1
	_pay_crew_and_company()
	_refresh_contracts()

func refuel() -> String:
	var units: int = ceili((100.0 - fuel) / 10.0)
	if units <= 0: return "Fuel tank is full."
	var cost: int = units * price("fuel")
	if credits < cost: return "Insufficient credits."
	credits -= cost
	fuel = minf(100.0, fuel + float(units) * 10.0)
	return ""

func repair() -> String:
	var deficit: float = maxf(0, float(ship_stats().max_hull) - hull)
	var cost: int = ceili(deficit * 4.0)
	if cost == 0: return "Hull is already at maximum."
	if credits < cost: return "Insufficient credits."
	credits -= cost
	hull = float(ship_stats().max_hull)
	return ""

func stock_price(ticker: String) -> int:
	var key: String = ticker.to_upper()
	if not COMPANIES.has(key): return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(COMPANIES[key].base) * 65537 + system_index * 31 + day * 997
	return maxi(1, roundi(float(COMPANIES[key].base) * rng.randf_range(0.7, 1.35)))

func trade_stock(ticker: String, quantity: int, buy: bool) -> String:
	var key: String = ticker.to_upper()
	if not COMPANIES.has(key): return "Unknown company ticker."
	if quantity <= 0 or quantity > 100000: return "Quantity must be between 1 and 100000."
	var unit: int = stock_price(key)
	if buy:
		if quantity > credits / unit: return "Insufficient credits."
		credits -= unit * quantity
		shares[key] = int(shares.get(key, 0)) + quantity
	else:
		if int(shares.get(key, 0)) < quantity: return "Insufficient shares."
		shares[key] = int(shares[key]) - quantity
		credits += unit * quantity
	return ""

func hire(role: String) -> String:
	var key: String = role.to_lower()
	if not CREW_ROLES.has(key): return "Unknown crew role."
	if crew.size() >= int(ship_stats().crew_capacity): return "Crew quarters are full. Add a habitat module."
	var spec: Dictionary = CREW_ROLES[key]
	if credits < int(spec.hire_cost): return "Hiring requires %d credits." % int(spec.hire_cost)
	credits -= int(spec.hire_cost)
	crew.append({"role": key, "name": _new_crew_name(), "salary": int(spec.salary), "id": "crew-%s" % Crypto.new().generate_random_bytes(12).hex_encode()})
	crew_paid = false
	return ""

func dismiss_crew(index: int) -> String:
	if index < 0 or index >= crew.size(): return "Crew member does not exist."
	if crew_orders.has(str(crew[index].id)): return "Cancel this crew member's order before ending their contract."
	crew.remove_at(index)
	crew_paid = false
	return ""

func found_company(name: String) -> String:
	var clean: String = name.strip_edges()
	if company_name != "": return "You already own a company."
	if clean.length() < 2 or clean.length() > 40: return "Company name must be 2 to 40 characters."
	if credits < 5000: return "Founding requires 5000 credits."
	credits -= 5000
	company_name = clean
	company_balance = 0
	return ""

func withdraw_company(amount: int) -> String:
	if company_name.is_empty(): return "You do not own a company."
	if amount <= 0: return "Withdrawal must be positive."
	if amount > company_balance: return "Insufficient company funds."
	company_balance -= amount
	credits += amount
	return ""


func found_faction(name: String) -> String:
	return PlayerFactionDomain.found(self, name)


func faction_deposit(amount: int) -> String:
	return PlayerFactionDomain.deposit(self, amount)


func faction_withdraw(amount: int) -> String:
	return PlayerFactionDomain.withdraw(self, amount)


func claim_station_faction(index: int) -> String:
	return PlayerFactionDomain.claim_station(self, index)


func set_diplomatic_stance(faction_name: String, new_stance: String) -> String:
	return PlayerFactionDomain.set_stance(self, faction_name, new_stance)


func diplomatic_stance(faction_name: String) -> String:
	return PlayerFactionDomain.stance(faction, faction_name)


func faction_trade_multiplier(faction_name: String, buy: bool) -> float:
	return PlayerFactionDomain.trade_multiplier(faction, faction_name, buy)


func police_hostile() -> bool:
	var local_faction := str(Universe.system_data(system_index).faction)
	return PlayerFactionDomain.police_hostile(faction, local_faction, wanted)


func station_affiliation(index: int) -> String:
	return PlayerFactionDomain.station_affiliation(faction, index)

func build_station(name: String) -> String:
	var clean: String = name.strip_edges()
	if clean.length() < 2 or clean.length() > 40: return "Station name must be 2 to 40 characters."
	if stations.size() >= MAX_ITEMS: return "Station limit reached."
	if credits < 3000 or int(cargo.get("alloys", 0)) < 20: return "Station requires 3000 credits and 20 alloys."
	credits -= 3000
	cargo.alloys -= 20
	stations.append({"name": clean, "system": system_index, "level": 1})
	return ""

func upgrade_station(index: int) -> String:
	if index < 0 or index >= stations.size(): return "Station does not exist."
	if int(stations[index].level) >= 100: return "Station is at maximum level."
	if credits < 2000 or int(cargo.get("alloys", 0)) < 10: return "Upgrade requires 2000 credits and 10 alloys."
	credits -= 2000
	cargo.alloys -= 10
	stations[index].level = int(stations[index].level) + 1
	return ""

func add_station_room(index: int, kind: String) -> String:
	if index < 0 or index >= stations.size(): return "Station does not exist."
	if not StationLayoutDomain.ROOM_KINDS.has(kind): return "Unknown station room."
	var rooms: Array[String] = StationLayoutDomain.rooms_for(stations[index])
	if rooms.size() >= StationLayoutDomain.MAX_ROOMS: return "Station room limit reached."
	if credits < 1000 or int(cargo.get("alloys", 0)) < 5: return "Adding a room requires 1000 credits and 5 alloys."
	stations[index].rooms = rooms
	stations[index].rooms.append(kind)
	credits -= 1000
	cargo.alloys -= 5
	return ""

func set_station_room(index: int, room_index: int, kind: String) -> String:
	if index < 0 or index >= stations.size(): return "Station does not exist."
	if not StationLayoutDomain.ROOM_KINDS.has(kind): return "Unknown station room."
	var rooms: Array[String] = StationLayoutDomain.rooms_for(stations[index])
	if room_index < 0 or room_index >= rooms.size(): return "Station room does not exist."
	if rooms[room_index] == kind: return ""
	if credits < 250: return "Changing a room requires 250 credits."
	stations[index].rooms = rooms
	stations[index].rooms[room_index] = kind
	credits -= 250
	return ""

func remove_station_room(index: int) -> String:
	if index < 0 or index >= stations.size(): return "Station does not exist."
	var rooms: Array[String] = StationLayoutDomain.rooms_for(stations[index])
	if rooms.size() <= 1: return "A station must keep at least one room."
	stations[index].rooms = rooms
	stations[index].rooms.pop_back()
	credits += 500
	return ""

func contract_board() -> Array[Dictionary]:
	var board: Array[Dictionary] = []
	for i: int in range(3):
		var target: int = (system_index + 7919 * (i + 1) + day * 104729) % SYSTEM_LIMIT
		var id: String = "d%d-s%d-%d" % [day, system_index, i]
		var kind: String = ["delivery", "exploration", "bounty"][i]
		var offer: Dictionary = {"id": id, "kind": kind, "origin": system_index, "destination": target, "good": "food", "quantity": 3, "reward": 500 + i * 250, "accepted": false, "completed": false, "baseline_kills": kills}
		match kind:
			"delivery":
				offer.title = "Deliver food"
				offer.description = "Deliver 3 food to system %d." % target
			"exploration":
				offer.title = "Explore a system"
				offer.description = "Visit system %d." % target
			"bounty":
				offer.title = "Bounty contract"
				offer.description = "Destroy one hostile ship, then claim here."
		board.append(offer)
	return board

func accept_contract(id: String) -> String:
	var index: int = _contract_index(id)
	if index < 0: return "Contract is unavailable."
	if contracts[index].completed: return "Contract is already completed."
	if contracts[index].accepted: return "Contract is already accepted."
	var active_count: int = 0
	for offer: Dictionary in contracts:
		if bool(offer.get("accepted", false)) and not bool(offer.get("completed", false)): active_count += 1
	if active_count >= 200: return "Accepted contract limit reached."
	contracts[index].accepted = true
	contracts[index].baseline_kills = kills
	contracts[index].accepted_visited = visited.duplicate()
	return ""

func claim_contract(id: String) -> String:
	var index: int = _contract_index(id)
	if index < 0 or not contracts[index].accepted: return "Accepted contract not found."
	var item: Dictionary = contracts[index]
	if item.completed: return "Contract is already claimed."
	match str(item.kind):
		"delivery":
			if system_index != int(item.destination): return "Deliver at the contract destination."
			if int(cargo.get(item.good, 0)) < int(item.quantity): return "Required cargo is missing."
			cargo[item.good] = int(cargo[item.good]) - int(item.quantity)
		"exploration":
			if not visited.has(int(item.destination)) or item.get("accepted_visited", []).has(int(item.destination)): return "Visit the contract destination after accepting it."
		"bounty":
			if kills <= int(item.baseline_kills): return "Neutralize a hostile target first."
	item.completed = true
	credits += int(item.reward)
	return ""

func record_kill(faction: String) -> void:
	var home_faction: String = str(Universe.system_data(system_index).faction)
	if faction.to_lower() == "pirate":
		kills += 1
		credits += 250
		reputation[home_faction] = int(reputation.get(home_faction, 0)) + 1
	else:
		wanted += 1
		reputation[home_faction] = int(reputation.get(home_faction, 0)) - 5

func save(path: String) -> String:
	if path.strip_edges().is_empty(): return "Save path is empty."
	var file_path: String = ProjectSettings.globalize_path(path)
	var temp_path: String = file_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null: return "Could not open temporary save file."
	file.store_string(JSON.stringify(_save_data()))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temp_path)
		return "Could not write save file."
	if DirAccess.rename_absolute(temp_path, file_path) != OK:
		DirAccess.remove_absolute(temp_path)
		return "Could not replace save file."
	return ""

func load_save(path: String) -> String:
	if not FileAccess.file_exists(path): return "Save file does not exist."
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return "Save data is malformed."
	var data: Dictionary = parsed
	var candidate: GameState = GameState.new()
	var version: Variant = data.get("version")
	if version == 1:
		var error: String = candidate._load_v1(data)
		if error != "": return error
	else:
		if version != SAVE_VERSION and version != 2: return "Unsupported save version."
		var error: String = candidate._load_v2(data)
		if error != "": return error
	_copy_from(candidate)
	return ""

func _load_v1(data: Dictionary) -> String:
	if data.has("day_progress") and (not _is_number(data.day_progress) or not is_finite(float(data.day_progress)) or float(data.day_progress) < 0.0 or float(data.day_progress) >= DAY_SECONDS): return "Invalid day progress."
	if data.has("day_progress"): day_progress = float(data.day_progress)
	ephemeris_seconds = day_progress / DAY_SECONDS * 86400.0
	for key: String in ["system", "credits", "modules", "hull", "kills", "cargo"]:
		if not data.has(key): return "Legacy save is missing required fields."
	if not _is_int(data.system) or not _is_int(data.credits) or not _is_int(data.modules) or not _is_number(data.hull) or not _is_int(data.kills) or not data.cargo is Dictionary:
		return "Legacy save has invalid field types."
	if int(data.system) < 0 or int(data.system) >= SYSTEM_LIMIT or int(data.credits) < 0 or int(data.kills) < 0: return "Legacy save values are out of range."
	system_index = int(data.system)
	credits = int(data.credits)
	kills = int(data.kills)
	hull = clampf(float(data.hull), 1.0, 100.0)
	var count: int = clampi(int(data.modules), 0, 8)
	for i: int in range(count): ship_modules.append(_module_record("cargo", Vector3i(-1, i + 1, 1)))
	for key: Variant in data.cargo:
		if not key is String or not _is_int(data.cargo[key]) or int(data.cargo[key]) < 0: return "Legacy cargo is invalid."
		var normalized: String = str(key).to_lower()
		if not GOODS.has(normalized): continue
		cargo[normalized] = int(data.cargo[key])
	if cargo_total() > int(ship_stats().cargo_capacity): return "Legacy cargo exceeds hold capacity."
	visited = [0]
	if system_index != 0: visited.append(system_index)
	return ""

func _load_v2(data: Dictionary) -> String:
	var expected: Array[String] = ["version", "system_index", "world_id", "location", "credits", "cargo", "hull", "shield", "fuel", "kills", "day", "visited", "reputation", "wanted", "ship_modules", "stations", "shares", "crew", "world_flags", "company_name", "company_balance", "crew_paid", "contracts", "fleet_ships", "crew_orders", "recovery", "ship_layout", "faction"]
	var missing_world_id: bool = not data.has("world_id")
	var missing_faction: bool = not data.has("faction")
	var missing_location: bool = not data.has("location")
	var legacy: bool = int(data.get("version", -1)) == 2
	var has_market_stocks: bool = data.has("market_stocks")
	if legacy:
		for extra: String in ["fleet_ships", "crew_orders", "recovery", "ship_layout"]: expected.erase(extra)
	if missing_faction:
		expected.erase("faction")
	if missing_location:
		expected.erase("location")
	var has_drive_temperature: bool = data.has("drive_temperature_k")
	var loaded_drive_temperature: float = 300.0
	if has_drive_temperature:
		if not _is_number(data.drive_temperature_k) or not is_finite(float(data.drive_temperature_k)) or float(data.drive_temperature_k) < 300.0 or float(data.drive_temperature_k) > 700.0: return "Invalid drive temperature."
		loaded_drive_temperature = float(data.drive_temperature_k)
	var has_ephemeris: bool = data.has("ephemeris_seconds")
	var has_day_progress: bool = data.has("day_progress")
	if data.size() != expected.size() - (1 if missing_world_id else 0) + (1 if has_day_progress else 0) + (1 if has_ephemeris else 0) + (1 if has_drive_temperature else 0) + (1 if has_market_stocks else 0): return "Save fields do not match schema."
	for key: String in expected:
		if key == "world_id" and missing_world_id: continue
		if not data.has(key): return "Save is missing %s." % key
	if not missing_world_id and not _valid_world_id(data.world_id): return "Invalid world identity."
	var loaded_market_stocks: Dictionary = {}
	if has_market_stocks:
		if not data.market_stocks is Dictionary or data.market_stocks.size() > MAX_MARKETS: return "Invalid market stocks."
		for system_key: Variant in data.market_stocks:
			if not system_key is String or not _canonical_system_key(system_key): return "Invalid market system id."
			var system_id: int = int(system_key)
			var goods: Variant = data.market_stocks[system_key]
			if not goods is Dictionary or goods.is_empty() or goods.size() > GOODS.size(): return "Invalid market stocks."
			var loaded_goods: Dictionary = {}
			for good: Variant in goods:
				if not good is String or not GOODS.has(good) or not _is_int(goods[good]) or int(goods[good]) < 0 or int(goods[good]) > MARKET_CAPACITY or int(goods[good]) == _initial_market_stock(good, system_id): return "Invalid market stock record."
				loaded_goods[good] = int(goods[good])
			loaded_market_stocks[system_key] = loaded_goods
	var loaded_day_progress: float = 0.0
	if has_day_progress:
		if not _is_number(data.day_progress) or not is_finite(float(data.day_progress)) or float(data.day_progress) < 0.0 or float(data.day_progress) >= DAY_SECONDS: return "Invalid day progress."
		loaded_day_progress = float(data.day_progress)
	for key: String in ["system_index", "credits", "kills", "day", "wanted", "company_balance"]:
		if not _is_int(data[key]): return "Invalid integer field: %s." % key
	for key: String in ["hull", "shield", "fuel"]:
		if not _is_number(data[key]) or not is_finite(float(data[key])): return "Invalid numeric field: %s." % key
	if not data.crew_paid is bool: return "Invalid crew payroll status."
	if int(data.system_index) < 0 or int(data.system_index) >= SYSTEM_LIMIT or int(data.credits) < 0 or int(data.kills) < 0 or int(data.day) < 0 or int(data.wanted) < 0 or int(data.company_balance) < 0: return "Save values are out of range."
	var loaded_ephemeris: float = (float(data.day) + loaded_day_progress / DAY_SECONDS) * 86400.0
	if has_ephemeris:
		if not _is_number(data.ephemeris_seconds): return "Invalid physical simulation time."
		loaded_ephemeris = float(data.ephemeris_seconds)
	if not is_finite(loaded_ephemeris) or loaded_ephemeris < 0.0 or loaded_ephemeris > MAX_EPHEMERIS_SECONDS: return "Invalid physical simulation time."
	if not missing_location and not _valid_location(data.location, int(data.system_index)): return "Invalid saved location."
	if float(data.hull) < 0 or float(data.hull) > 10000 or float(data.shield) < 0 or float(data.shield) > 10000 or float(data.fuel) < 0 or float(data.fuel) > 100: return "Save vitals are out of range."
	if not data.cargo is Dictionary or not data.reputation is Dictionary or not data.shares is Dictionary or not data.world_flags is Dictionary or not data.visited is Array: return "Invalid collection field."
	if not data.ship_modules is Array or not data.stations is Array or not data.crew is Array or not data.contracts is Array: return "Invalid collection field."
	if not legacy and (not data.fleet_ships is Array or not data.crew_orders is Dictionary or not data.ship_layout is Dictionary or not ShipRecovery.validate_data(data.recovery)): return "Invalid fleet, crew orders, layout, or recovery state."
	if data.cargo.size() > GOODS.size() or data.reputation.size() > 100 or data.shares.size() > COMPANIES.size() or data.world_flags.size() > MAX_WORLD_FLAGS or data.visited.size() > MAX_ITEMS or data.ship_modules.size() > MAX_SHIP_MODULES or data.stations.size() > MAX_ITEMS or data.crew.size() > 12 or data.contracts.size() > MAX_ITEMS: return "Save collection exceeds limits."
	for key: Variant in data.cargo:
		if not key is String or not GOODS.has(key) or not _is_int(data.cargo[key]) or int(data.cargo[key]) < 0: return "Invalid cargo record."
		data.cargo[key] = int(data.cargo[key])
	for key: Variant in data.reputation:
		if not key is String or not _is_int(data.reputation[key]): return "Invalid reputation record."
		data.reputation[key] = int(data.reputation[key])
	for key: Variant in data.shares:
		if not key is String or not COMPANIES.has(key) or not _is_int(data.shares[key]) or int(data.shares[key]) < 0: return "Invalid shares record."
		data.shares[key] = int(data.shares[key])
	for key: Variant in data.world_flags:
		if not key is String or not _valid_world_key(key) or not data.world_flags[key] is Array or data.world_flags[key].size() > 10000: return "Invalid world flags."
		var actors: Array[String] = []
		for actor: Variant in data.world_flags[key]:
			if not actor is String or actor.length() > 128 or actors.has(actor): return "Invalid world flag actor id."
			actors.append(actor)
		data.world_flags[key] = actors
	var loaded_visited: Array[int] = []
	for value: Variant in data.visited:
		if not _is_int(value) or int(value) < 0 or int(value) >= SYSTEM_LIMIT or loaded_visited.has(int(value)): return "Invalid visited systems."
		loaded_visited.append(int(value))
	if not loaded_visited.has(int(data.system_index)): return "Current system is absent from visited systems."
	var loaded_modules: Array[Dictionary] = []
	for value: Variant in data.ship_modules:
		if not value is Dictionary or not _valid_module(value): return "Invalid ship module record."
		loaded_modules.append(_module_record(value.kind, Vector3i(int(value.x), int(value.y), int(value.z))))
	if loaded_modules.is_empty() or not _connected(loaded_modules) or not _has_required_modules(loaded_modules): return "Ship layout is invalid."
	var loaded_layout: Dictionary = ShipLayout.empty_data()
	if not legacy:
		loaded_layout = data.ship_layout.duplicate(true)
		if _is_int(loaded_layout.get("version")): loaded_layout.version = int(loaded_layout.version)
		if not ShipLayout.validate_data(loaded_layout, loaded_modules): return "Invalid ship layout."
	var loaded_stats: Dictionary = _stats_for(loaded_modules)
	if int(loaded_stats.power_balance) < 0 or _module_cells_duplicate(loaded_modules): return "Ship layout is invalid."
	if float(data.hull) > float(loaded_stats.max_hull) or float(data.shield) > float(loaded_stats.max_shield): return "Save vitals exceed ship capacity."
	var loaded_cargo: Dictionary = data.cargo.duplicate(true)
	for good: String in GOODS:
		if not loaded_cargo.has(good): loaded_cargo[good] = 0
	var old_cargo: Dictionary = cargo
	cargo = loaded_cargo
	var over_capacity: bool = cargo_total() > int(loaded_stats.cargo_capacity)
	cargo = old_cargo
	if over_capacity: return "Cargo exceeds hold capacity."
	var loaded_stations: Array[Dictionary] = []
	for value: Variant in data.stations:
		if not value is Dictionary or not value.has_all(["name", "system", "level"]) or value.size() > 5 or not value.name is String or value.name.length() < 2 or value.name.length() > 40 or not _is_int(value.system) or not _is_int(value.level) or int(value.system) < 0 or int(value.system) >= SYSTEM_LIMIT or int(value.level) < 1 or int(value.level) > 100: return "Invalid station record."
		for key: Variant in value:
			if not str(key) in ["name", "system", "level", "stock", "rooms"]: return "Invalid station record."
		var station: Dictionary = {"name": value.name, "system": int(value.system), "level": int(value.level)}
		if value.has("rooms"):
			if not StationLayoutDomain.validate_data(value.rooms): return "Invalid station rooms."
			var station_rooms: Array[String] = []
			for room: Variant in value.rooms: station_rooms.append(room)
			station.rooms = station_rooms
		var stock: Dictionary = value.get("stock", {})
		if not stock is Dictionary or stock.size() > GOODS.size(): return "Invalid station stock."
		for good: Variant in stock:
			if not good is String or not GOODS.has(good) or not _is_int(stock[good]) or int(stock[good]) < 0 or int(stock[good]) > 10000: return "Invalid station stock."
			stock[good] = int(stock[good])
		if value.has("stock"): station.stock = stock.duplicate(true)
		loaded_stations.append(station)
	if not missing_location and data.location.has("station_index"):
		var station_index: int = int(data.location.station_index)
		if station_index >= loaded_stations.size() or int(loaded_stations[station_index].system) != int(data.system_index): return "Invalid saved station location."
	var loaded_faction: Dictionary = PlayerFactionDomain.empty_data()
	if not missing_faction:
		if not PlayerFactionDomain.validate_data(data.faction, loaded_stations.size()): return "Invalid player faction state."
		loaded_faction = data.faction.duplicate(true)
		loaded_faction.treasury = int(loaded_faction.treasury)
		var station_claims: Array[int] = []
		for station_index: Variant in loaded_faction.claimed_stations: station_claims.append(int(station_index))
		loaded_faction.claimed_stations = station_claims
	var loaded_crew: Array[Dictionary] = []
	var crew_ids: Dictionary = {}
	var names_seen: Dictionary = {}
	for value: Variant in data.crew:
		if not value is Dictionary or value.size() != 4 or not value.has_all(["id", "role", "name", "salary"]) or not value.id is String or value.id.length() < 4 or value.id.length() > 64 or crew_ids.has(value.id) or not CREW_ROLES.has(value.role) or not value.name is String or value.name.strip_edges().length() < 2 or value.name.length() > 64 or names_seen.has(value.name) or not _is_int(value.salary) or int(value.salary) != int(CREW_ROLES[value.role].salary): return "Invalid crew record."
		crew_ids[value.id] = true
		names_seen[value.name] = true
		loaded_crew.append({"id": value.id, "role": value.role, "name": value.name, "salary": int(value.salary)})
	var loaded_fleet: Array[Dictionary] = []
	var loaded_orders: Dictionary = {}
	if not legacy:
		if data.fleet_ships.size() > 50 or data.crew_orders.size() > 12: return "Fleet or crew order limit exceeded."
		var ship_ids: Dictionary = {}
		for value: Variant in data.fleet_ships:
			if not value is Dictionary or value.size() not in [6, 7] or not value.has_all(["id", "name", "system", "hull", "cargo", "capacity"]): return "Invalid fleet ship record."
			for field: Variant in value:
				if not str(field) in ["id", "name", "system", "hull", "cargo", "capacity", "flight"]: return "Invalid fleet ship field."
			if not value.id is String or value.id.length() < 4 or value.id.length() > 64 or ship_ids.has(value.id) or not value.name is String or value.name.length() < 2 or value.name.length() > 32 or not _is_int(value.system) or int(value.system) < 0 or int(value.system) >= SYSTEM_LIMIT or not _is_number(value.hull) or not is_finite(float(value.hull)) or float(value.hull) < 0 or float(value.hull) > 100 or not _is_int(value.capacity) or int(value.capacity) < 1 or int(value.capacity) > 100 or not value.cargo is Dictionary: return "Invalid fleet ship values."
			var ship_cargo: Dictionary = {}
			for good: Variant in value.cargo:
				if not good is String or not GOODS.has(good) or not _is_int(value.cargo[good]) or int(value.cargo[good]) < 0: return "Invalid fleet cargo."
				ship_cargo[good] = int(value.cargo[good])
			var loaded_ship: Dictionary = {"id": value.id, "name": value.name, "system": int(value.system), "hull": float(value.hull), "cargo": ship_cargo, "capacity": int(value.capacity)}
			if value.has("flight"):
				var flight: Variant = value.flight
				if not flight is Dictionary or flight.size() != 3 or not flight.has_all(["phase", "address", "velocity"]) or not flight.phase is String or not flight.phase in ["outbound", "inbound"] or not flight.velocity is Array or flight.velocity.size() != 3: return "Invalid fleet flight record."
				var address: Variant = SectorPosition.from_save(flight.address)
				if not address is SectorPosition or address.relative_to(SectorPosition.new(), SectorPosition.MAX_RELATIVE_DISTANCE) == null: return "Invalid fleet flight address."
				var velocity: Array[float] = []
				for component: Variant in flight.velocity:
					if not _is_number(component) or not is_finite(float(component)) or absf(float(component)) > 1000.0: return "Invalid fleet flight velocity."
					velocity.append(float(component))
				if Vector3(velocity[0], velocity[1], velocity[2]).length() > 1000.0: return "Invalid fleet flight velocity."
				loaded_ship.flight = {"phase": flight.phase, "address": address.to_save(), "velocity": velocity}
			if _fleet_cargo_total(loaded_ship) > int(value.capacity): return "Fleet cargo exceeds capacity."
			ship_ids[value.id] = true
			loaded_fleet.append(loaded_ship)
		var assigned_ships: Dictionary = {}
		var assigned_stations: Dictionary = {}
		var assigned_ship_defense: bool = false
		for key: Variant in data.crew_orders:
			if not key is String or not crew_ids.has(key) or not _valid_order(data.crew_orders[key], key, ship_ids, loaded_stations): return "Invalid crew order."
			var order: Dictionary = data.crew_orders[key].duplicate(true)
			var expected_role: String = "trader" if order.kind == "trade" else ("gunner" if order.kind in ["patrol", "defend"] else "engineer")
			if _crew_role(loaded_crew, key) != expected_role: return "Crew role does not match assigned order."
			if order.kind == "defend":
				if assigned_ship_defense: return "Ship defense has duplicate gunners."
				assigned_ship_defense = true
			if order.has("ship_id"):
				if assigned_ships.has(order.ship_id): return "A fleet ship has duplicate orders."
				assigned_ships[order.ship_id] = true
			if order.kind == "station":
				if assigned_stations.has(order.station_index): return "A station has duplicate managers."
				assigned_stations[order.station_index] = true
			order.progress = float(order.progress)
			match str(order.kind):
				"trade":
					for numeric: String in ["origin", "destination", "quantity", "escrow", "escrow_limit", "earned"]: order[numeric] = int(order[numeric])
					if order.has("purchase_cost"): order.purchase_cost = int(order.purchase_cost)
					if order.has("delivery_station"): order.delivery_station = int(order.delivery_station)
				"patrol":
					order.system = int(order.system)
					order.encounters = int(order.encounters)
				"station":
					order.station_index = int(order.station_index)
					order.produced = int(order.produced)
				"defend": pass
			loaded_orders[key] = order
	for ship: Dictionary in loaded_fleet:
		if not ship.has("flight"): continue
		var assigned_trade: Dictionary = {}
		for order: Dictionary in loaded_orders.values():
			if order.kind == "trade" and str(order.ship_id) == str(ship.id): assigned_trade = order; break
		if assigned_trade.is_empty() or str(ship.flight.phase) != str(assigned_trade.phase) or int(ship.system) != int(assigned_trade.origin if assigned_trade.phase == "outbound" else assigned_trade.destination): return "Fleet flight does not match its trade route."
	var loaded_contracts: Array[Dictionary] = []
	for value: Variant in data.contracts:
		if not _valid_contract(value): return "Invalid contract record."
		var contract_copy: Dictionary = value.duplicate(true)
		for key: String in ["origin", "destination", "quantity", "reward", "baseline_kills"]: contract_copy[key] = int(contract_copy[key])
		if contract_copy.has("accepted_visited"):
			if not contract_copy.accepted_visited is Array or contract_copy.accepted_visited.size() > MAX_ITEMS: return "Invalid contract visit proof."
			var proof: Array[int] = []
			for system: Variant in contract_copy.accepted_visited:
				if not _is_int(system) or int(system) < 0 or int(system) >= SYSTEM_LIMIT: return "Invalid contract visit proof."
				proof.append(int(system))
			contract_copy.accepted_visited = proof
		loaded_contracts.append(contract_copy)
	if not data.company_name is String or data.company_name.length() > 40 or loaded_crew.size() > int(loaded_stats.crew_capacity) or (data.crew_paid and loaded_crew.is_empty()): return "Invalid company or crew size."
	system_index = int(data.system_index)
	location = {} if missing_location else _normalize_location(data.location)
	world_id = _new_world_id() if missing_world_id else data.world_id
	credits = int(data.credits)
	cargo = loaded_cargo
	hull = float(data.hull)
	shield = float(data.shield)
	fuel = float(data.fuel)
	drive_temperature_k = loaded_drive_temperature
	kills = int(data.kills)
	day = int(data.day)
	day_progress = loaded_day_progress
	ephemeris_seconds = loaded_ephemeris
	visited = loaded_visited
	reputation = data.reputation.duplicate(true)
	wanted = int(data.wanted)
	ship_modules = loaded_modules
	stations = loaded_stations
	shares = data.shares.duplicate(true)
	crew = loaded_crew
	world_flags = data.world_flags.duplicate(true)
	company_name = data.company_name
	company_balance = int(data.company_balance)
	crew_paid = data.crew_paid
	contracts = loaded_contracts
	fleet_ships = loaded_fleet
	crew_orders = loaded_orders
	recovery = ShipRecovery.empty_data() if legacy else _normalize_recovery(data.recovery)
	ship_layout = loaded_layout
	faction = loaded_faction
	market_stocks = loaded_market_stocks
	return ""

func _canonical_system_key(value: String) -> bool:
	if value.is_empty() or (value.length() > 1 and value.begins_with("0")): return false
	for index: int in range(value.length()):
		if value.unicode_at(index) < 48 or value.unicode_at(index) > 57: return false
	if value.length() > 10: return false
	return int(value) < SYSTEM_LIMIT

func _valid_contract(value: Variant) -> bool:
	if not value is Dictionary or not value.has_all(["id", "kind", "origin", "destination", "good", "quantity", "reward", "accepted", "completed", "baseline_kills", "title", "description"]): return false
	var allowed: Array[String] = ["id", "kind", "origin", "destination", "good", "quantity", "reward", "accepted", "completed", "baseline_kills", "title", "description", "accepted_visited"]
	for key: Variant in value:
		if not allowed.has(str(key)): return false
	if not value.id is String or not value.kind in ["delivery", "exploration", "bounty"] or not value.good is String: return false
	if not value.title is String or not value.description is String or value.title.length() > 100 or value.description.length() > 500: return false
	for key: String in ["origin", "destination", "quantity", "reward", "baseline_kills"]:
		if not _is_int(value[key]): return false
	if not value.accepted is bool or not value.completed is bool: return false
	return int(value.origin) >= 0 and int(value.origin) < SYSTEM_LIMIT and int(value.destination) >= 0 and int(value.destination) < SYSTEM_LIMIT and int(value.quantity) >= 0 and int(value.reward) >= 0 and int(value.baseline_kills) >= 0

func _valid_order(value: Variant, crew_id: String, ship_ids: Dictionary, stations_to_validate: Array[Dictionary]) -> bool:
	if not value is Dictionary or str(value.get("crew_id", "")) != crew_id or not _is_number(value.get("progress")) or not is_finite(float(value.progress)) or float(value.progress) < 0 or float(value.progress) > 31536000.0 or not value.get("paused", false) is bool: return false
	var kind: String = str(value.get("kind", ""))
	if kind == "trade":
		var has_delivery_station: bool = value.has("delivery_station")
		if value.size() != 13 + (1 if value.has("purchase_cost") else 0) + (1 if has_delivery_station else 0) or not value.has_all(["kind", "crew_id", "ship_id", "good", "origin", "destination", "quantity", "escrow", "escrow_limit", "progress", "phase", "earned", "paused"]): return false
		if value.has("purchase_cost") and (not GOODS.has(value.good) or not _is_int(value.purchase_cost) or int(value.purchase_cost) < -1 or int(value.purchase_cost) > 100 * ceili(float(GOODS[value.good]) * 1.45 * MAX_SCARCITY_MULTIPLIER)): return false
		var valid_trade: bool = ship_ids.has(value.ship_id) and GOODS.has(value.good) and _is_int(value.origin) and _is_int(value.destination) and int(value.origin) >= 0 and int(value.origin) < SYSTEM_LIMIT and int(value.destination) >= 0 and int(value.destination) < SYSTEM_LIMIT and _is_int(value.quantity) and int(value.quantity) > 0 and int(value.quantity) <= 100 and _is_int(value.escrow) and int(value.escrow) >= 0 and _is_int(value.escrow_limit) and int(value.escrow_limit) >= int(value.escrow) and int(value.escrow_limit) <= int(value.quantity) * ceili(float(GOODS[value.good]) * 1.45 * MAX_SCARCITY_MULTIPLIER) and value.phase in ["outbound", "inbound"] and _is_int(value.earned)
		if not valid_trade: return false
		if not has_delivery_station: return int(value.origin) != int(value.destination)
		if not _is_int(value.delivery_station) or int(value.delivery_station) < 0 or int(value.delivery_station) >= stations_to_validate.size(): return false
		return int(value.destination) == int(stations_to_validate[int(value.delivery_station)].system)
	if kind == "patrol":
		if value.size() != 7 or not value.has_all(["kind", "crew_id", "ship_id", "system", "progress", "encounters", "paused"]): return false
		return ship_ids.has(value.ship_id) and _is_int(value.system) and int(value.system) >= 0 and int(value.system) < SYSTEM_LIMIT and _is_int(value.encounters) and int(value.encounters) >= 0
	if kind == "station":
		if value.size() != 6 or not value.has_all(["kind", "crew_id", "station_index", "progress", "produced", "paused"]): return false
		return _is_int(value.station_index) and int(value.station_index) >= 0 and int(value.station_index) < stations_to_validate.size() and _is_int(value.produced) and int(value.produced) >= 0
	if kind == "defend":
		return value.size() == 4 and value.has_all(["kind", "crew_id", "progress", "paused"])
	return false

func _fleet_cargo_total(ship: Dictionary) -> int:
	var total: int = 0
	for quantity: Variant in ship.cargo.values(): total += int(quantity)
	return total

func _crew_role(members: Array[Dictionary], crew_id: String) -> String:
	for member: Dictionary in members:
		if str(member.id) == crew_id: return str(member.role)
	return ""

func _normalize_recovery(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	for key: String in ["next_id", "insurance_until_day", "debt"]: result[key] = int(result[key])
	for wreck: Dictionary in result.wrecks:
		for key: String in ["system", "surface", "salvage_value"]: wreck[key] = int(wreck[key])
		for good: String in wreck.cargo: wreck.cargo[good] = int(wreck.cargo[good])
		for module: Dictionary in wreck.modules:
			for key: String in ["x", "y", "z"]: module[key] = int(module[key])
	return result

func _new_crew_name() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for attempt: int in range(64):
		var candidate: String = "%s %s" % [CREW_FIRST_NAMES[rng.randi_range(0, CREW_FIRST_NAMES.size() - 1)], CREW_LAST_NAMES[rng.randi_range(0, CREW_LAST_NAMES.size() - 1)]]
		var used: bool = false
		for member: Dictionary in crew:
			if str(member.name) == candidate:
				used = true
				break
		if not used: return candidate
	return "Crew %s" % Crypto.new().generate_random_bytes(4).hex_encode()

func _valid_location(value: Variant, current_system: int) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if value.size() < 5 or value.size() > 8 or not value.has_all(["system", "surface", "address", "rotation", "flying"]): return false
	for key: Variant in value:
		if not str(key) in ["system", "surface", "address", "rotation", "flying", "ship_address", "station_index", "velocity"]: return false
	if not _is_int(value.system) or int(value.system) != current_system or not _is_int(value.surface) or int(value.surface) < -1 or int(value.surface) > 7: return false
	if not SectorPosition.from_save(value.address) is SectorPosition: return false
	if not value.rotation is Array or value.rotation.size() != 3 or not value.flying is bool: return false
	if value.has("ship_address") and (int(value.surface) < 0 or value.flying or not SectorPosition.from_save(value.ship_address) is SectorPosition): return false
	if value.has("station_index") and (not _is_int(value.station_index) or int(value.station_index) < 0 or int(value.station_index) > 255 or int(value.surface) != -1 or value.flying or value.has("ship_address")): return false
	if value.has("velocity") and (not value.flying or not value.velocity is Array or value.velocity.size() != 3): return false
	if value.has("velocity"):
		for component: Variant in value.velocity:
			if not _is_number(component) or not is_finite(float(component)) or absf(float(component)) > 100000.0: return false
	for component: Variant in value.rotation:
		if not _is_number(component) or not is_finite(float(component)) or absf(float(component)) > 100000.0: return false
	return true

func _normalize_location(value: Dictionary) -> Dictionary:
	if value.is_empty(): return {}
	var result: Dictionary = value.duplicate(true)
	result.system = int(result.system)
	result.surface = int(result.surface)
	result.address = SectorPosition.from_save(result.address).to_save()
	if result.has("ship_address"): result.ship_address = SectorPosition.from_save(result.ship_address).to_save()
	if result.has("station_index"): result.station_index = int(result.station_index)
	for index: int in range(3): result.rotation[index] = float(result.rotation[index])
	if result.has("velocity"):
		for index: int in range(3): result.velocity[index] = float(result.velocity[index])
	return result

func _save_data() -> Dictionary:
	return {"version": SAVE_VERSION, "system_index": system_index, "world_id": world_id, "location": location, "credits": credits, "cargo": cargo, "hull": hull, "shield": shield, "fuel": fuel, "drive_temperature_k": drive_temperature_k, "kills": kills, "day": day, "day_progress": day_progress, "ephemeris_seconds": ephemeris_seconds, "visited": visited, "reputation": reputation, "wanted": wanted, "ship_modules": ship_modules, "stations": stations, "shares": shares, "crew": crew, "world_flags": world_flags, "company_name": company_name, "company_balance": company_balance, "crew_paid": crew_paid, "contracts": contracts, "fleet_ships": fleet_ships, "crew_orders": crew_orders, "recovery": recovery, "ship_layout": ship_layout, "faction": faction, "market_stocks": market_stocks}

func _copy_from(other: GameState) -> void:
	for key: String in ["system_index", "world_id", "location", "credits", "cargo", "hull", "shield", "fuel", "drive_temperature_k", "kills", "day", "day_progress", "ephemeris_seconds", "visited", "reputation", "wanted", "ship_modules", "stations", "shares", "crew", "world_flags", "company_name", "company_balance", "crew_paid", "contracts", "fleet_ships", "crew_orders", "recovery", "ship_layout", "faction", "market_stocks"]:
		set(key, other.get(key).duplicate(true) if other.get(key) is Array or other.get(key) is Dictionary else other.get(key))

func _pay_crew_and_company() -> void:
	var wages: int = 0
	var passive_count: int = 0
	for member: Dictionary in crew:
		if _is_crew_assigned(str(member.id)): continue
		passive_count += 1
		wages += int(member.salary)
	crew_paid = passive_count > 0 and credits >= wages
	if crew_paid:
		credits -= wages
		hull = minf(float(ship_stats().max_hull), hull + 8.0 * _paid_crew_count("engineer"))
		credits += 20 * _paid_crew_count("trader")
	for station: Dictionary in stations: credits += int(station.level) * 150
	if company_name != "":
		company_balance += 100 + 75 * _paid_crew_count("trader")

func _module_record(kind: String, cell: Vector3i) -> Dictionary:
	return {"kind": kind, "x": cell.x, "y": cell.y, "z": cell.z}

func _module_at(cell: Vector3i) -> int:
	for i: int in range(ship_modules.size()):
		var m: Dictionary = ship_modules[i]
		if int(m.x) == cell.x and int(m.y) == cell.y and int(m.z) == cell.z: return i
	return -1

func _adjacent_to_ship(cell: Vector3i) -> bool:
	for offset: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if _module_at(cell + offset) >= 0: return true
	return false

func _connected(modules: Array[Dictionary]) -> bool:
	if modules.size() <= 1: return true
	var seen: Dictionary = {0: true}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var index: int = queue.pop_front()
		var a: Dictionary = modules[index]
		for j: int in range(modules.size()):
			if seen.has(j): continue
			var b: Dictionary = modules[j]
			var distance: int = absi(int(a.x) - int(b.x)) + absi(int(a.y) - int(b.y)) + absi(int(a.z) - int(b.z))
			if distance == 1:
				seen[j] = true
				queue.append(j)
	return seen.size() == modules.size()

func _stats_for(modules: Array[Dictionary]) -> Dictionary:
	# Power values are abstract ratings; generation serves nominal systems before boost headroom.
	var result := {"cargo_capacity": 20, "max_hull": 100.0, "max_shield": 100.0, "speed": 10.0, "damage": 10, "mass": 0, "dry_mass_kg": 0, "thrust_newtons": 0, "power_balance": 0, "power_generation": 0, "power_demand": 0, "engine_power_demand": 0, "boost_multiplier": 1.0, "crew_capacity": 2, "walkable": false}
	var habitat_count: int = 0
	for m: Dictionary in modules:
		var spec: Dictionary = MODULES.get(str(m.get("kind", "")), {})
		result.mass += int(spec.get("mass", 0))
		result.dry_mass_kg += int(spec.get("mass", 0)) * 1000
		result.thrust_newtons += int(spec.get("thrust", 0)) * 65000
		var module_power: int = int(spec.get("power", 0))
		result.power_balance += module_power
		if module_power > 0: result.power_generation += module_power
		elif module_power < 0:
			result.power_demand -= module_power
			if m.get("kind") == "engine": result.engine_power_demand -= module_power
		result.cargo_capacity += int(spec.get("cargo", 0))
		result.max_hull += float(spec.get("hull", 0))
		result.speed += float(spec.get("thrust", 0))
		if m.get("kind") == "weapon": result.damage += 15
		if m.get("kind") == "shield": result.max_shield += 50.0
		if m.get("kind") == "habitat": habitat_count += 1
	result.speed = maxf(25.0, (10.0 + maxf(0.0, float(result.speed) - 10.0) * 7.2) * 34.0 / maxf(10.0, float(result.mass)))
	result.crew_capacity = mini(12, 2 + habitat_count * 4)
	if int(result.engine_power_demand) > 0:
		result.boost_multiplier = clampf(1.0 + maxf(float(result.power_balance), 0.0) / float(result.engine_power_demand), 1.0, 2.0)
	result.walkable = habitat_count > 0 and modules.size() >= 8
	if crew_paid: result.damage += _paid_crew_count("gunner") * 5
	return result

func _has_required_modules(modules: Array[Dictionary]) -> bool:
	var kinds: Array[String] = []
	for m: Dictionary in modules: kinds.append(str(m.kind))
	return kinds.has("core") and kinds.has("cockpit") and kinds.has("reactor") and kinds.has("engine") and kinds.has("cargo")

func _module_cells_duplicate(modules: Array[Dictionary]) -> bool:
	var cells: Dictionary = {}
	for m: Dictionary in modules:
		var key: String = "%d,%d,%d" % [m.x, m.y, m.z]
		if cells.has(key): return true
		cells[key] = true
	return false

func _valid_module(value: Dictionary) -> bool:
	if value.size() != 4 or not value.has_all(["kind", "x", "y", "z"]) or not value.kind is String or not MODULES.has(value.kind): return false
	return _is_int(value.x) and _is_int(value.y) and _is_int(value.z) and absi(int(value.x)) <= SHIP_CELL_LIMIT and absi(int(value.y)) <= SHIP_CELL_LIMIT and absi(int(value.z)) <= SHIP_CELL_LIMIT

func _valid_world_key(key: String) -> bool:
	if key.is_valid_int(): return int(key) >= 0 and int(key) < SYSTEM_LIMIT
	var parts: PackedStringArray = key.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
	return int(parts[0]) >= 0 and int(parts[0]) < SYSTEM_LIMIT and int(parts[1]) >= -1 and int(parts[1]) <= 7

func _contract_index(id: String) -> int:
	for i: int in range(contracts.size()):
		if str(contracts[i].get("id", "")) == id: return i
	return -1

func _refresh_contracts() -> void:
	var retained: Array[Dictionary] = []
	for offer: Dictionary in contracts:
		if bool(offer.get("accepted", false)) or bool(offer.get("completed", false)):
			retained.append(offer)
	for offer: Dictionary in contract_board():
		var exists: bool = false
		for old: Dictionary in retained:
			if str(old.id) == str(offer.id):
				exists = true
				break
		if not exists: retained.append(offer)
	contracts = retained.slice(maxi(0, retained.size() - MAX_ITEMS))

func _count_kind(kind: String) -> int:
	var count: int = 0
	for module: Dictionary in ship_modules:
		if module.kind == kind: count += 1
	return count

func _paid_crew_count(role: String) -> int:
	if not crew_paid: return 0
	var count: int = 0
	for member: Dictionary in crew:
		if str(member.get("role", "")) == role and not _is_crew_assigned(str(member.get("id", ""))): count += 1
	return count

func _is_crew_assigned(crew_id: String) -> bool:
	return crew_orders.has(crew_id)

func _is_int(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and floorf(value) == value)

func _is_number(value: Variant) -> bool:
	return value is int or value is float

func _new_world_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode().to_lower()

func _valid_world_id(value: Variant) -> bool:
	if not value is String or value.length() != 32: return false
	for character: String in value:
		if not ((character >= "0" and character <= "9") or (character >= "a" and character <= "f")): return false
	return true
