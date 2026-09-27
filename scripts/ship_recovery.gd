class_name ShipRecovery
extends RefCounted

const MAX_WRECKS: int = 1000
const MAX_SYSTEM: int = 1_000_000_000
const MAX_COORD: float = 30000.0
const MAX_CARGO: int = 1000000
const WRECK_INTEGRITY: float = 0.25


static func empty_data() -> Dictionary:
	return {"next_id": 1, "insurance_until_day": -1, "debt": 0, "wrecks": []}


static func insurance_cost(state: GameState) -> int:
	return maxi(250, ceili(float(_ship_value(state.ship_modules)) * 0.08))


static func buy_insurance(state: GameState, duration_days: int = 30) -> String:
	if duration_days < 1 or duration_days > 365:
		return "Coverage must last 1 to 365 simulation days."
	if not validate_data(state.recovery):
		return "Recovery record is invalid."
	if int(state.recovery.debt) > 0:
		return "Pay recovery debt before buying insurance."
	var cost: int = insurance_cost(state)
	if state.credits < cost:
		return "Insurance costs %d credits." % cost
	state.credits -= cost
	state.recovery.insurance_until_day = state.day + duration_days
	return ""


static func repay_debt(state: GameState, amount: int) -> String:
	if amount <= 0:
		return "Repayment must be positive."
	if not validate_data(state.recovery):
		return "Recovery record is invalid."
	var payment: int = mini(mini(amount, state.credits), int(state.recovery.debt))
	if payment <= 0:
		return "No credits available for recovery debt."
	state.credits -= payment
	state.recovery.debt -= payment
	return ""


static func destroy_ship(state: GameState, position: Vector3, surface: int, origin_data: Dictionary = {}) -> Dictionary:
	if state.hull > 0.0:
		return _report(false, "Ship is not destroyed.")
	if not _valid_location(state.system_index, surface, position) or (not origin_data.is_empty() and SectorPosition.from_save(origin_data) == null) or not validate_data(state.recovery):
		return _report(false, "Recovery location or record is invalid.")
	var wreck_address: SectorPosition
	if not origin_data.is_empty():
		wreck_address = SectorPosition.from_save(origin_data)
		if not wreck_address.move_delta(position): return _report(false, "Recovery address is out of range.")
	if state.recovery.wrecks.size() >= MAX_WRECKS:
		var recyclable: int = -1
		for index: int in range(state.recovery.wrecks.size()):
			var old_wreck: Dictionary = state.recovery.wrecks[index]
			if old_wreck.cargo_recovered and old_wreck.salvaged:
				recyclable = index
				break
		if recyclable < 0:
			return _report(false, "Wreck registry is full; recover cargo and salvage an existing wreck first.")
		state.recovery.wrecks.remove_at(recyclable)
	var blueprint: Array[Dictionary] = state.ship_modules.duplicate(true)
	if not _valid_blueprint(state, blueprint):
		return _report(false, "Ship blueprint is invalid.")
	var wreck_id: String = "wreck-%06d" % int(state.recovery.next_id)
	var cargo: Dictionary = {}
	for good: String in GameState.GOODS:
		cargo[good] = int(state.cargo.get(good, 0))
		state.cargo[good] = 0
	var insured: bool = int(state.recovery.insurance_until_day) >= state.day
	var value: int = _ship_value(blueprint)
	var fee: int = maxi(250, ceili(float(value) * (0.10 if insured else 0.55)))
	var paid: int = mini(state.credits, fee)
	state.credits -= paid
	state.recovery.debt += fee - paid
	var wreck: Dictionary = {
		"id": wreck_id,
		"system": state.system_index,
		"surface": surface,
		"position": [position.x, position.y, position.z],
		"cargo": cargo,
		"modules": blueprint,
		"integrity": WRECK_INTEGRITY,
		"salvage_value": maxi(100, ceili(float(value) * WRECK_INTEGRITY * (0.08 if insured else 1.0))),
		"cargo_recovered": false,
		"salvaged": false,
	}
	if wreck_address != null: wreck.address = wreck_address.to_save()
	state.recovery.wrecks.append(wreck)
	state.recovery.next_id += 1
	state.hull = maxf(1.0, float(state.ship_stats().max_hull) * (0.60 if insured else 0.35))
	state.shield = maxf(0.0, float(state.ship_stats().max_shield) * 0.25)
	state.fuel = 25.0
	return _report(true, "Ship recovered with %s coverage; %d credits charged, %d added to recovery debt." % ["insurance" if insured else "uninsured replacement", paid, fee - paid], {"wreck_id": wreck_id, "insured": insured, "fee": fee, "paid": paid, "debt_added": fee - paid})


static func recover_cargo(state: GameState, wreck_id: String, surface: int, position: Vector3, max_distance: float = 80.0, origin_data: Dictionary = {}) -> String:
	var result: Dictionary = _find_wreck(state, wreck_id, surface, position, max_distance, origin_data)
	if not result.ok:
		return result.message
	var wreck: Dictionary = result.wreck
	if wreck.cargo_recovered:
		return "Wreck cargo was already recovered."
	var free_capacity: int = maxi(0, int(state.ship_stats().cargo_capacity) - state.cargo_total())
	if free_capacity == 0:
		return "Cargo hold is full."
	var recovered: Dictionary = {}
	for good: String in GameState.GOODS:
		var amount: int = mini(free_capacity, int(wreck.cargo.get(good, 0)))
		if amount > 0:
			state.cargo[good] = int(state.cargo.get(good, 0)) + amount
			wreck.cargo[good] = int(wreck.cargo[good]) - amount
			free_capacity -= amount
			recovered[good] = amount
	wreck.cargo_recovered = _sum(wreck.cargo) == 0
	return ""


static func salvage_wreck(state: GameState, wreck_id: String, surface: int, position: Vector3, max_distance: float = 80.0, origin_data: Dictionary = {}) -> String:
	var result: Dictionary = _find_wreck(state, wreck_id, surface, position, max_distance, origin_data)
	if not result.ok:
		return result.message
	var wreck: Dictionary = result.wreck
	if wreck.salvaged:
		return "Wreck structure was already salvaged."
	var value: int = int(wreck.salvage_value)
	wreck.salvaged = true
	var payment: int = mini(value, int(state.recovery.debt))
	state.recovery.debt -= payment
	state.credits += value - payment
	return ""


static func validate_data(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4 or not value.has_all(["next_id", "insurance_until_day", "debt", "wrecks"]):
		return false
	if not _is_int(value.next_id) or int(value.next_id) < 1 or int(value.next_id) > 2147483647:
		return false
	if not _is_int(value.insurance_until_day) or int(value.insurance_until_day) < -1 or int(value.insurance_until_day) > 2147483647:
		return false
	if not _is_int(value.debt) or int(value.debt) < 0 or int(value.debt) > 2147483647:
		return false
	if not value.wrecks is Array or value.wrecks.size() > MAX_WRECKS:
		return false
	var ids: Dictionary = {}
	var highest_id: int = 0
	var verifier: GameState = GameState.new()
	for wreck: Variant in value.wrecks:
		if not wreck is Dictionary or wreck.size() < 10 or wreck.size() > 11 or not wreck.has_all(["id", "system", "surface", "position", "cargo", "modules", "integrity", "salvage_value", "cargo_recovered", "salvaged"]):
			return false
		if wreck.has("address") and SectorPosition.from_save(wreck.address) == null:
			return false
		if not wreck.id is String or wreck.id.length() > 32 or not wreck.id.begins_with("wreck-") or ids.has(wreck.id):
			return false
		var numeric_id: String = wreck.id.trim_prefix("wreck-")
		if not numeric_id.is_valid_int() or int(numeric_id) < 1:
			return false
		highest_id = maxi(highest_id, int(numeric_id))
		ids[wreck.id] = true
		if not _is_int(wreck.system) or not _is_int(wreck.surface) or not _valid_location(int(wreck.system), int(wreck.surface), _decode_position(wreck.position)):
			return false
		if not _is_number(wreck.integrity) or not is_finite(float(wreck.integrity)) or float(wreck.integrity) <= 0.0 or float(wreck.integrity) >= 1.0:
			return false
		if not _is_int(wreck.salvage_value) or int(wreck.salvage_value) < 0 or int(wreck.salvage_value) > 1000000000:
			return false
		if not wreck.cargo_recovered is bool or not wreck.salvaged is bool or not wreck.cargo is Dictionary:
			return false
		if wreck.cargo.size() != GameState.GOODS.size():
			return false
		var total: int = 0
		for good: Variant in wreck.cargo:
			if not good is String or not GameState.GOODS.has(good) or not _is_int(wreck.cargo[good]) or int(wreck.cargo[good]) < 0 or int(wreck.cargo[good]) > MAX_CARGO:
				return false
			total += int(wreck.cargo[good])
			if total > MAX_CARGO:
				return false
		if wreck.cargo_recovered and total > 0:
			return false
		if not wreck.modules is Array or not _valid_blueprint(verifier, wreck.modules):
			return false
	if int(value.next_id) <= highest_id:
		return false
	return true


static func wreck_relative(wreck: Dictionary, origin_data: Dictionary, radius: float = 30000.0) -> Variant:
	if not is_finite(radius) or radius < 0.0 or radius > SectorPosition.MAX_RELATIVE_DISTANCE:
		return null
	if wreck.has("address"):
		if origin_data.is_empty(): return null
		var wreck_address: Variant = SectorPosition.from_save(wreck.address)
		var origin: Variant = SectorPosition.from_save(origin_data)
		if wreck_address == null or origin == null: return null
		return wreck_address.relative_to(origin, radius)
	var legacy_position: Vector3 = _decode_position(wreck.get("position", null))
	if not legacy_position.is_finite(): return null
	if origin_data.is_empty():
		return legacy_position if legacy_position.length() <= radius else null
	var legacy_origin: Variant = SectorPosition.from_save(origin_data)
	if legacy_origin == null: return null
	return SectorPosition.new(Vector3i.ZERO, legacy_position).relative_to(legacy_origin, radius)


static func _find_wreck(state: GameState, wreck_id: String, surface: int, position: Vector3, max_distance: float, origin_data: Dictionary = {}) -> Dictionary:
	if not validate_data(state.recovery):
		return _report(false, "Recovery record is invalid.")
	if not position.is_finite() or not is_finite(max_distance) or max_distance < 0.0 or (not origin_data.is_empty() and SectorPosition.from_save(origin_data) == null):
		return _report(false, "Recovery position is invalid.")
	for wreck: Dictionary in state.recovery.wrecks:
		if str(wreck.id) != wreck_id:
			continue
		if int(wreck.system) != state.system_index or int(wreck.surface) != surface:
			return _report(false, "Wreck is at another location.")
		var relative: Variant = wreck_relative(wreck, origin_data, SectorPosition.MAX_RELATIVE_DISTANCE)
		if relative == null or position.distance_to(relative) > max_distance:
			return _report(false, "Move closer to the wreck to recover it.")
		return {"ok": true, "message": "", "wreck": wreck}
	return _report(false, "Wreck does not exist.")


static func _valid_blueprint(state: Variant, blueprint: Variant) -> bool:
	if not blueprint is Array or blueprint.is_empty() or blueprint.size() > 100:
		return false
	var normalized: Array[Dictionary] = []
	var cells: Dictionary = {}
	var kinds: Dictionary = {}
	for module: Variant in blueprint:
		if not module is Dictionary or module.size() != 4 or not module.has_all(["kind", "x", "y", "z"]):
			return false
		if not module.kind is String or not GameState.MODULES.has(module.kind):
			return false
		for key: String in ["x", "y", "z"]:
			if not _is_int(module[key]) or absi(int(module[key])) > 16:
				return false
		var cell: String = "%d,%d,%d" % [int(module.x), int(module.y), int(module.z)]
		if cells.has(cell):
			return false
		cells[cell] = true
		kinds[module.kind] = true
		normalized.append({"kind": module.kind, "x": int(module.x), "y": int(module.y), "z": int(module.z)})
	if not kinds.has_all(["core", "cockpit", "reactor", "engine", "cargo"]):
		return false
	var verifier: GameState = state if state != null else GameState.new()
	if not verifier._connected(normalized) or int(verifier._stats_for(normalized).power_balance) < 0:
		return false
	return true


static func _ship_value(modules: Array) -> int:
	var value: int = 0
	for module: Dictionary in modules:
		var cost: int = int(GameState.MODULES.get(str(module.get("kind", "")), {}).get("cost", 0))
		value += maxi(250, cost)
	return value


static func _decode_position(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if (value is Array or value is PackedFloat32Array or value is PackedFloat64Array) and value.size() == 3 and _is_number(value[0]) and _is_number(value[1]) and _is_number(value[2]):
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary and value.size() == 3 and value.has_all(["x", "y", "z"]) and _is_number(value.x) and _is_number(value.y) and _is_number(value.z):
		return Vector3(float(value.x), float(value.y), float(value.z))
	return Vector3(INF, INF, INF)


static func _valid_location(system: int, surface: int, position: Vector3) -> bool:
	return system >= 0 and system < MAX_SYSTEM and surface >= -1 and surface <= 7 and position.is_finite() and absf(position.x) <= MAX_COORD and absf(position.y) <= MAX_COORD and absf(position.z) <= MAX_COORD


static func _sum(values: Dictionary) -> int:
	var total: int = 0
	for amount: Variant in values.values():
		total += int(amount)
	return total


static func _is_int(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and floorf(value) == value)


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _report(ok: bool, message: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": ok, "message": message}
	result.merge(extra, true)
	return result
