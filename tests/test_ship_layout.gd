extends SceneTree

const Layout = preload("res://scripts/ship_layout.gd")


class State:
	extends RefCounted
	var credits: int = 10000
	var ship_modules: Array[Dictionary] = []
	var ship_layout: Dictionary = {}


func _initialize() -> void:
	var modules: Array[Dictionary] = [
		{"kind": "cockpit", "x": 0, "y": 0, "z": 0},
		{"kind": "habitat", "x": 1, "y": 0, "z": 0},
		{"kind": "cargo", "x": 2, "y": 0, "z": 0},
		{"kind": "reactor", "x": 1, "y": 1, "z": 0},
	]
	var empty := Layout.empty_data()
	assert(Layout.validate_data(empty, modules))
	var serialized: Variant = JSON.parse_string(JSON.stringify(empty))
	assert(Layout.validate_data(serialized, modules), "JSON integer version must round-trip")

	var valid := {
		"version": 1,
		"rooms": {"1,0,0": "lounge", "2,0,0": "workshop"},
		"panels": {"1,0,0": {"-y": "window", "+z": "armored"}},
	}
	assert(Layout.validate_data(valid, modules))
	assert(not Layout.validate_data({"version": 1, "rooms": {"1,0,0": "bridge"}, "panels": {}}, modules))
	assert(not Layout.validate_data({"version": 1, "rooms": {"9,0,0": "engineering"}, "panels": {}}, modules))
	assert(not Layout.validate_data({"version": 1, "rooms": {}, "panels": {"1,0,0": {"+x": "window"}}}, modules), "internal faces cannot be panel overrides")
	assert(not Layout.validate_data({"version": 1, "rooms": {}, "panels": {"1,0,0": {"north": "window"}}}, modules))
	assert(not Layout.validate_data({"version": 1, "rooms": {}, "panels": {"1,0,0": {"+y": "door"}}}, modules))
	assert(not Layout.validate_data({"version": 1.5, "rooms": {}, "panels": {}}, modules))
	assert(not Layout.validate_data({"version": 1, "rooms": {}, "panels": {}, "extra": true}, modules))

	var state := State.new()
	state.ship_modules = modules
	state.ship_layout = Layout.empty_data()
	var starting_credits: int = state.credits
	assert(Layout.configure_room(state, Vector3i(1, 0, 0), "lounge") == "")
	assert(state.credits == starting_credits - Layout.ROOM_REFIT_COST)
	assert(state.ship_layout.rooms["1,0,0"] == "lounge")
	assert(Layout.configure_room(state, Vector3i(1, 0, 0), "lounge") == "" and state.credits == starting_credits - Layout.ROOM_REFIT_COST)
	assert(Layout.configure_room(state, Vector3i(1, 0, 0), "bridge") != "" and state.credits == starting_credits - Layout.ROOM_REFIT_COST)
	assert(Layout.configure_room(state, Vector3i(99, 0, 0), "engineering") != "")
	assert(Layout.set_panel(state, Vector3i(1, 0, 0), "+x", "window") != "", "neighboring cell face cannot be changed")
	assert(Layout.set_panel(state, Vector3i(1, 0, 0), "up", "window") != "")
	var after_room_cost: int = state.credits
	assert(Layout.set_panel(state, Vector3i(1, 0, 0), "-y", "window") == "")
	assert(state.credits == after_room_cost - int(Layout.PANEL_COSTS.window))
	assert(Layout.validate_data(JSON.parse_string(JSON.stringify(state.ship_layout)), modules))
	assert(Layout.set_panel(state, Vector3i(1, 0, 0), "-y", "window") == "" and state.credits == after_room_cost - int(Layout.PANEL_COSTS.window))
	assert(Layout.set_panel(state, Vector3i(1, 0, 0), "-y", "standard") == "")
	assert(not state.ship_layout.panels.has("1,0,0"))
	assert(state.credits == after_room_cost - int(Layout.PANEL_COSTS.window) - int(Layout.PANEL_COSTS.standard))
	state.credits = 0
	assert(Layout.configure_room(state, Vector3i(1, 0, 0), "medical") == "Insufficient credits.")
	assert(Layout.set_panel(state, Vector3i(1, 0, 0), "-y", "armored") == "Insufficient credits.")

	var stale := {"version": 1, "rooms": {"2,0,0": "workshop"}, "panels": {"1,0,0": {"+x": "armored", "+y": "window", "+z": "window"}}}
	var after_remove: Array[Dictionary] = [modules[0], modules[1], modules[3]]
	Layout.prune(stale, after_remove)
	assert(stale.rooms.is_empty(), "removed module room override is pruned")
	assert(stale.panels["1,0,0"] == {"+x": "armored", "+z": "window"}, "newly internal face override is pruned")
	assert(Layout.validate_data(stale, after_remove))

	print("ShipLayout tests passed")
	quit()
