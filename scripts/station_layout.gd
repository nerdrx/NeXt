class_name StationLayout
extends RefCounted

const ROOM_KINDS: Array[String] = ["market", "company", "shipyard", "contracts", "factions", "stations"]
const MAX_ROOMS: int = 16

static func rooms_for(station: Dictionary) -> Array[String]:
	if station.get("rooms") is Array:
		var explicit_rooms: Array[String] = []
		for room: Variant in station.rooms:
			if room is String: explicit_rooms.append(room)
		return explicit_rooms
	var rooms: Array[String] = []
	var count: int = clampi(3 + int(station.get("level", 1)) / 18, 3, 8)
	for index: int in count:
		rooms.append(ROOM_KINDS[index % ROOM_KINDS.size()])
	return rooms

static func validate_data(value: Variant) -> bool:
	if not value is Array or value.is_empty() or value.size() > MAX_ROOMS: return false
	for room: Variant in value:
		if not room is String or not ROOM_KINDS.has(room): return false
	return true
