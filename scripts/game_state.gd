class_name GameState
extends RefCounted

const SAVE_VERSION: int = 2
const SYSTEM_LIMIT: int = 1_000_000_000
const MAX_ITEMS: int = 1000
const MAX_WORLD_FLAGS: int = 10000
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

var system_index: int = 0
var world_id: String = ""
var credits: int = 18000
var cargo: Dictionary = {}
var hull: float = 100.0
var shield: float = 100.0
var fuel: float = 100.0
var kills: int = 0
var day: int = 0
var visited: Array[int] = [0]
var reputation: Dictionary = {}
var wanted: int = 0
var ship_modules: Array[Dictionary] = []
var stations: Array[Dictionary] = []
var shares: Dictionary = {}
var crew: Array[Dictionary] = []
var world_flags: Dictionary = {}
var company_name: String = ""
var company_balance: int = 0
var crew_paid: bool = false
var contracts: Array[Dictionary] = []

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

func cargo_total() -> int:
	var total: int = 0
	for quantity: Variant in cargo.values():
		if quantity is int: total += quantity
	return total

func ship_stats() -> Dictionary:
	return _stats_for(ship_modules)

func price(good: String) -> int:
	var key: String = good.to_lower()
	if not GOODS.has(key): return 0
	var salt: int = 0
	for byte: int in key.to_ascii_buffer(): salt = (salt * 31 + byte) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = ((system_index * 1103515245 + salt * 12345 + day * 7919) & 0x7fffffff)
	return maxi(1, roundi(float(GOODS[key]) * rng.randf_range(0.65, 1.45)))

func trade(good: String, quantity: int, buy: bool) -> String:
	var key: String = good.to_lower()
	if not GOODS.has(key): return "Unknown good."
	if quantity <= 0 or quantity > 100000: return "Quantity must be between 1 and 100000."
	var discount: int = mini(15, _paid_crew_count("trader") * 2)
	var unit: int = maxi(1, int(floor(float(price(key)) * (100 - discount) / 100.0)))
	if buy:
		if quantity > int(ship_stats().cargo_capacity) - cargo_total(): return "Insufficient cargo capacity."
		if quantity > credits / unit: return "Insufficient credits."
		credits -= unit * quantity
		cargo[key] = int(cargo.get(key, 0)) + quantity
	else:
		if int(cargo.get(key, 0)) < quantity: return "Insufficient cargo."
		cargo[key] = int(cargo.get(key, 0)) - quantity
		credits += int(floor(float(unit * quantity) * 0.85))
	return ""

func add_module(kind: String, cell: Vector3i) -> String:
	if not MODULES.has(kind) or kind == "core": return "Unknown or unavailable module."
	if ship_modules.size() >= 100: return "Ship module limit reached."
	if absi(cell.x) > 4 or absi(cell.z) > 4 or absi(cell.y) > 2: return "Cell is outside the construction grid."
	if _module_at(cell) >= 0: return "That ship cell is occupied."
	if ship_modules.is_empty() or not _adjacent_to_ship(cell): return "Module must attach to the ship."
	var spec: Dictionary = MODULES[kind]
	if credits < int(spec.cost): return "Insufficient credits."
	var trial := ship_modules.duplicate(true)
	trial.append(_module_record(kind, cell))
	if _stats_for(trial).power_balance < 0: return "Ship has insufficient reactor power."
	credits -= int(spec.cost)
	ship_modules.append(_module_record(kind, cell))
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
	if cargo_total() > int(stats.cargo_capacity): return "Cargo exceeds the resulting hold capacity."
	if int(stats.power_balance) < 0: return "Ship would have insufficient power."
	ship_modules = trial
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
	day += 1
	if not visited.has(destination):
		visited.append(destination)
		if visited.size() > MAX_ITEMS: visited.pop_front()
	_pay_crew_and_company()
	_refresh_contracts()
	return ""

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
	crew.append({"role": key, "name": spec.name, "salary": int(spec.salary), "id": "crew-%s" % Crypto.new().generate_random_bytes(12).hex_encode()})
	crew_paid = false
	return ""

func dismiss_crew(index: int) -> String:
	if index < 0 or index >= crew.size(): return "Crew member does not exist."
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
		if version != SAVE_VERSION: return "Unsupported save version."
		var error: String = candidate._load_v2(data)
		if error != "": return error
	_copy_from(candidate)
	return ""

func _load_v1(data: Dictionary) -> String:
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
	var expected: Array[String] = ["version", "system_index", "world_id", "credits", "cargo", "hull", "shield", "fuel", "kills", "day", "visited", "reputation", "wanted", "ship_modules", "stations", "shares", "crew", "world_flags", "company_name", "company_balance", "crew_paid", "contracts"]
	var missing_world_id: bool = not data.has("world_id")
	if data.size() != expected.size() - (1 if missing_world_id else 0): return "Save fields do not match schema."
	for key: String in expected:
		if key == "world_id" and missing_world_id: continue
		if not data.has(key): return "Save is missing %s." % key
	if not missing_world_id and not _valid_world_id(data.world_id): return "Invalid world identity."
	for key: String in ["system_index", "credits", "kills", "day", "wanted", "company_balance"]:
		if not _is_int(data[key]): return "Invalid integer field: %s." % key
	for key: String in ["hull", "shield", "fuel"]:
		if not _is_number(data[key]) or not is_finite(float(data[key])): return "Invalid numeric field: %s." % key
	if not data.crew_paid is bool: return "Invalid crew payroll status."
	if int(data.system_index) < 0 or int(data.system_index) >= SYSTEM_LIMIT or int(data.credits) < 0 or int(data.kills) < 0 or int(data.day) < 0 or int(data.wanted) < 0 or int(data.company_balance) < 0: return "Save values are out of range."
	if float(data.hull) < 0 or float(data.hull) > 10000 or float(data.shield) < 0 or float(data.shield) > 10000 or float(data.fuel) < 0 or float(data.fuel) > 100: return "Save vitals are out of range."
	if not data.cargo is Dictionary or not data.reputation is Dictionary or not data.shares is Dictionary or not data.world_flags is Dictionary or not data.visited is Array: return "Invalid collection field."
	if not data.ship_modules is Array or not data.stations is Array or not data.crew is Array or not data.contracts is Array: return "Invalid collection field."
	if data.cargo.size() > GOODS.size() or data.reputation.size() > 100 or data.shares.size() > COMPANIES.size() or data.world_flags.size() > MAX_WORLD_FLAGS or data.visited.size() > MAX_ITEMS or data.ship_modules.size() > 100 or data.stations.size() > MAX_ITEMS or data.crew.size() > 12 or data.contracts.size() > MAX_ITEMS: return "Save collection exceeds limits."
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
		if not value is Dictionary or value.size() != 3 or not value.has_all(["name", "system", "level"]) or not value.name is String or value.name.length() < 2 or value.name.length() > 40 or not _is_int(value.system) or not _is_int(value.level) or int(value.system) < 0 or int(value.system) >= SYSTEM_LIMIT or int(value.level) < 1 or int(value.level) > 100: return "Invalid station record."
		loaded_stations.append({"name": value.name, "system": int(value.system), "level": int(value.level)})
	var loaded_crew: Array[Dictionary] = []
	for value: Variant in data.crew:
		if not value is Dictionary or value.size() != 4 or not value.has_all(["id", "role", "name", "salary"]) or not value.id is String or value.id.length() > 64 or not CREW_ROLES.has(value.role) or not value.name is String or value.name != str(CREW_ROLES[value.role].name) or not _is_int(value.salary) or int(value.salary) != int(CREW_ROLES[value.role].salary): return "Invalid crew record."
		loaded_crew.append({"id": value.id, "role": value.role, "name": value.name, "salary": int(value.salary)})
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
	world_id = _new_world_id() if missing_world_id else data.world_id
	credits = int(data.credits)
	cargo = loaded_cargo
	hull = float(data.hull)
	shield = float(data.shield)
	fuel = float(data.fuel)
	kills = int(data.kills)
	day = int(data.day)
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
	return ""

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

func _save_data() -> Dictionary:
	return {"version": SAVE_VERSION, "system_index": system_index, "world_id": world_id, "credits": credits, "cargo": cargo, "hull": hull, "shield": shield, "fuel": fuel, "kills": kills, "day": day, "visited": visited, "reputation": reputation, "wanted": wanted, "ship_modules": ship_modules, "stations": stations, "shares": shares, "crew": crew, "world_flags": world_flags, "company_name": company_name, "company_balance": company_balance, "crew_paid": crew_paid, "contracts": contracts}

func _copy_from(other: GameState) -> void:
	for key: String in ["system_index", "world_id", "credits", "cargo", "hull", "shield", "fuel", "kills", "day", "visited", "reputation", "wanted", "ship_modules", "stations", "shares", "crew", "world_flags", "company_name", "company_balance", "crew_paid", "contracts"]:
		set(key, other.get(key).duplicate(true) if other.get(key) is Array or other.get(key) is Dictionary else other.get(key))

func _pay_crew_and_company() -> void:
	var wages: int = 0
	for member: Dictionary in crew: wages += int(member.salary)
	crew_paid = not crew.is_empty() and credits >= wages
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
	var result := {"cargo_capacity": 20, "max_hull": 100.0, "max_shield": 100.0, "speed": 10.0, "damage": 10, "mass": 0, "power_balance": 0, "crew_capacity": 2, "walkable": false}
	var habitat_count: int = 0
	for m: Dictionary in modules:
		var spec: Dictionary = MODULES.get(str(m.get("kind", "")), {})
		result.mass += int(spec.get("mass", 0))
		result.power_balance += int(spec.get("power", 0))
		result.cargo_capacity += int(spec.get("cargo", 0))
		result.max_hull += float(spec.get("hull", 0))
		result.speed += float(spec.get("thrust", 0))
		if m.get("kind") == "weapon": result.damage += 15
		if m.get("kind") == "shield": result.max_shield += 50.0
		if m.get("kind") == "habitat": habitat_count += 1
	result.speed = maxf(25.0, (10.0 + maxf(0.0, float(result.speed) - 10.0) * 7.2) * 34.0 / maxf(10.0, float(result.mass)))
	result.crew_capacity = mini(12, 2 + habitat_count * 4)
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
	return _is_int(value.x) and _is_int(value.y) and _is_int(value.z) and absi(int(value.x)) <= 16 and absi(int(value.y)) <= 16 and absi(int(value.z)) <= 16

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
		if str(member.get("role", "")) == role: count += 1
	return count

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
