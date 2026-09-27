extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const StationLayout = preload("res://scripts/station_layout.gd")

func _initialize() -> void:
	var legacy: Dictionary = {"name": "Old Station", "system": 0, "level": 1}
	assert(StationLayout.rooms_for(legacy) == ["market", "company", "shipyard"])
	legacy.level = 18
	assert(StationLayout.rooms_for(legacy).size() == 4)
	legacy.level = 100
	assert(StationLayout.rooms_for(legacy).size() == 8)
	assert(not StationLayout.validate_data([]) and not StationLayout.validate_data(["bad"]))
	assert(not StationLayout.validate_data(["market", "company", "shipyard", "contracts", "factions", "stations", "market", "company", "shipyard", "contracts", "factions", "stations", "market", "company", "shipyard", "contracts", "factions"]))

	var state = GameStateScript.new()
	legacy.level = 1
	state.stations.append(legacy)
	state.credits = 5000
	state.cargo.alloys = 20
	var before_credits: int = state.credits
	var before_alloys: int = state.cargo.alloys
	assert(state.add_station_room(0, "bad") != "")
	assert(state.add_station_room(5, "market") != "")
	assert(state.credits == before_credits and state.cargo.alloys == before_alloys and not state.stations[0].has("rooms"))
	assert(state.add_station_room(0, "market") == "")
	assert(state.stations[0].rooms.size() == 4 and state.credits == before_credits - 1000 and state.cargo.alloys == before_alloys - 5)
	var edited: Array[String] = StationLayout.rooms_for(state.stations[0])
	assert(state.set_station_room(0, 0, edited[0]) == "" and state.credits == before_credits - 1000)
	assert(state.set_station_room(0, 0, "bad") != "" and state.set_station_room(0, 99, "market") != "")
	assert(state.set_station_room(0, 0, "stations") == "" and state.credits == before_credits - 1250)
	assert(state.remove_station_room(0) == "" and state.credits == before_credits - 750 and state.stations[0].rooms.size() == 3)
	for _i: int in range(2): assert(state.remove_station_room(0) == "")
	var min_credits: int = state.credits
	var one_room: Array[String] = StationLayout.rooms_for(state.stations[0])
	assert(one_room.size() == 1 and state.remove_station_room(0) != "" and state.credits == min_credits)

	state.stations[0].rooms = ["market"]
	state.credits = 50000
	state.cargo.alloys = 5
	for _i: int in range(15):
		assert(state.add_station_room(0, "market") == "")
		state.cargo.alloys = 5
	state.cargo.alloys = 0
	var full_credits: int = state.credits
	var full_alloys: int = state.cargo.alloys
	assert(state.stations[0].rooms.size() == 16 and state.add_station_room(0, "company") != "")
	assert(state.credits == full_credits and state.cargo.alloys == full_alloys)
	state.cargo.alloys = 10
	assert(state.upgrade_station(0) == "" and state.stations[0].rooms.size() == 16)

	var path := "user://station-layout-%d.json" % OS.get_process_id()
	assert(state.save(path) == "")
	var loaded = GameStateScript.new()
	assert(loaded.load_save(path) == "")
	assert(loaded._save_data() == state._save_data(), "explicit station layout survives a real save roundtrip")
	var prior: Dictionary = loaded._save_data().duplicate(true)
	var corrupt: Dictionary = state._save_data().duplicate(true)
	corrupt.stations[0].rooms = ["market", "unknown"]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(corrupt))
	file.close()
	assert(loaded.load_save(path) != "" and loaded._save_data() == prior, "corrupt station rooms are rejected without mutation")
	var old: Dictionary = state._save_data().duplicate(true)
	old.stations[0].erase("rooms")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	assert(loaded.load_save(path) == "" and not loaded.stations[0].has("rooms"), "legacy station saves retain implicit room layouts")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Station layout tests passed")
	quit()
