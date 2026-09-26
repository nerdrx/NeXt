class_name PlayerFaction
extends RefCounted

const UniverseScript = preload("res://scripts/universe.gd")
const FOUNDING_COST: int = 10000
const STATION_CLAIM_COST: int = 1000
const DIPLOMACY_COST: int = 500
const MAX_TREASURY: int = 1000000000000
const MAX_CREDITS: int = 9223372036854775807
const FRIENDLY_BUY_MULTIPLIER: float = 0.95
const FRIENDLY_SELL_MULTIPLIER: float = 1.05
const HOSTILE_BUY_MULTIPLIER: float = 1.15
const HOSTILE_SELL_MULTIPLIER: float = 0.85
const STANCES: Array[String] = ["neutral", "friendly", "hostile"]


static func empty_data() -> Dictionary:
	return {"name": "", "treasury": 0, "claimed_stations": [], "diplomacy": {}}


static func validate_data(value: Variant, station_count: int) -> bool:
	if not value is Dictionary or value.size() != 4 or not value.has_all(["name", "treasury", "claimed_stations", "diplomacy"]):
		return false
	if not value.name is String or not _is_int(value.treasury) or int(value.treasury) < 0 or int(value.treasury) > MAX_TREASURY:
		return false
	if not value.claimed_stations is Array or value.claimed_stations.size() > 1000 or not value.diplomacy is Dictionary or value.diplomacy.size() > UniverseScript.FACTIONS.size():
		return false
	var founded: bool = not value.name.is_empty()
	if founded and not _valid_name(value.name):
		return false
	if not founded and (value.treasury != 0 or not value.claimed_stations.is_empty() or not value.diplomacy.is_empty()):
		return false
	var claims: Dictionary = {}
	for index: Variant in value.claimed_stations:
		if not _is_int(index) or int(index) < 0 or int(index) >= station_count or claims.has(int(index)):
			return false
		claims[int(index)] = true
	for key: Variant in value.diplomacy:
		if not key is String or not UniverseScript.FACTIONS.has(key) or not value.diplomacy[key] is String or not STANCES.has(value.diplomacy[key]):
			return false
	return true


static func found(state: Object, raw_name: String) -> String:
	var name := raw_name.strip_edges()
	var current: Variant = state.get("faction")
	if not current is Dictionary:
		return "Faction data is invalid."
	if not str(current.get("name", "")).is_empty():
		return "You already command a faction."
	if not _valid_name(name):
		return "Faction name must be 2 to 32 letters, numbers, spaces, apostrophes, periods or hyphens."
	var credits := int(state.get("credits"))
	if credits < FOUNDING_COST:
		return "Founding requires %d credits." % FOUNDING_COST
	state.set("credits", credits - FOUNDING_COST)
	state.set("faction", {"name": name, "treasury": 0, "claimed_stations": [], "diplomacy": {}})
	return ""


static func deposit(state: Object, amount: int) -> String:
	var data: Dictionary = state.get("faction")
	if str(data.get("name", "")).is_empty():
		return "Found a faction before using its treasury."
	if amount <= 0:
		return "Deposit must be positive."
	var credits := int(state.get("credits"))
	var treasury := int(data.get("treasury", 0))
	if amount > credits:
		return "Insufficient personal credits."
	if amount > MAX_TREASURY - treasury:
		return "Faction treasury limit reached."
	state.set("credits", credits - amount)
	data.treasury = treasury + amount
	state.set("faction", data)
	return ""


static func withdraw(state: Object, amount: int) -> String:
	var data: Dictionary = state.get("faction")
	if str(data.get("name", "")).is_empty():
		return "Found a faction before using its treasury."
	if amount <= 0:
		return "Withdrawal must be positive."
	if amount > int(data.get("treasury", 0)):
		return "Insufficient faction funds."
	if amount > MAX_CREDITS - int(state.get("credits")):
		return "Personal credit limit reached."
	data.treasury = int(data.treasury) - amount
	state.set("faction", data)
	state.set("credits", int(state.get("credits")) + amount)
	return ""


static func claim_station(state: Object, station_index: int) -> String:
	var data: Dictionary = state.get("faction")
	var stations: Array = state.get("stations")
	if str(data.get("name", "")).is_empty():
		return "Found a faction before claiming stations."
	if station_index < 0 or station_index >= stations.size():
		return "Station does not exist."
	if data.claimed_stations.has(station_index):
		return "That station is already claimed."
	if int(data.treasury) < STATION_CLAIM_COST:
		return "A station claim costs %d faction credits." % STATION_CLAIM_COST
	data.treasury = int(data.treasury) - STATION_CLAIM_COST
	data.claimed_stations.append(station_index)
	state.set("faction", data)
	return ""


static func set_stance(state: Object, faction_name: String, new_stance: String) -> String:
	var data: Dictionary = state.get("faction")
	if str(data.get("name", "")).is_empty():
		return "Found a faction before setting diplomacy."
	if not UniverseScript.FACTIONS.has(faction_name) or not STANCES.has(new_stance):
		return "Choose a known faction and a valid diplomatic stance."
	var current := stance(data, faction_name)
	if current == new_stance:
		return ""
	if int(data.treasury) < DIPLOMACY_COST:
		return "A diplomatic change costs %d faction credits." % DIPLOMACY_COST
	data.treasury = int(data.treasury) - DIPLOMACY_COST
	data.diplomacy[faction_name] = new_stance
	state.set("faction", data)
	return ""


static func stance(data: Dictionary, faction_name: String) -> String:
	return str(data.get("diplomacy", {}).get(faction_name, "neutral"))


static func trade_multiplier(data: Dictionary, faction_name: String, buy: bool) -> float:
	match [stance(data, faction_name), buy]:
		["friendly", true]: return FRIENDLY_BUY_MULTIPLIER
		["friendly", false]: return FRIENDLY_SELL_MULTIPLIER
		["hostile", true]: return HOSTILE_BUY_MULTIPLIER
		["hostile", false]: return HOSTILE_SELL_MULTIPLIER
		_: return 1.0


static func police_hostile(data: Dictionary, faction_name: String, wanted_level: int) -> bool:
	return wanted_level > 0 or stance(data, faction_name) == "hostile"


static func station_affiliation(data: Dictionary, station_index: int) -> String:
	return str(data.get("name", "")) if data.get("claimed_stations", []).has(station_index) else "Independent operator"


static func _valid_name(value: String) -> bool:
	if value.length() < 2 or value.length() > 32 or value != value.strip_edges():
		return false
	for character: String in value:
		var code := character.unicode_at(0)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or character in [" ", "'", ".", "-"]):
			return false
	return true


static func _is_int(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and floorf(value) == value)
