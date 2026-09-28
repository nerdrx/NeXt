extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")
const ShipBlueprintScript = preload("res://scripts/ship_blueprint.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var state := GameStateScript.new()
	state.hull = 100.0
	state.shield = 30.0
	state.shield_delay = 2.5
	state.recharge_shields(3.0)
	assert(is_equal_approx(state.shield, 32.5) and state.shield_delay == 0.0, "only the half second beyond the delay recharges shields")

	var whole := GameStateScript.new()
	var split := GameStateScript.new()
	whole.shield = 10.0
	split.shield = 10.0
	whole.shield_delay = 2.5
	split.shield_delay = 2.5
	whole.recharge_shields(4.0)
	for step: float in [1.0, 1.0, 2.0]: split.recharge_shields(step)
	assert(is_equal_approx(whole.shield, 17.5) and is_equal_approx(split.shield, whole.shield), "split time steps match a single elapsed interval")
	assert(is_equal_approx(split.shield_delay, whole.shield_delay), "split time steps consume the same recovery delay")

	var capped := GameStateScript.new()
	capped.shield = float(capped.ship_stats().max_shield) - 2.0
	capped.recharge_shields(5.0)
	assert(capped.shield == float(capped.ship_stats().max_shield), "recharge clamps to the design shield limit")
	var wrecked := GameStateScript.new()
	wrecked.hull = 0.0
	wrecked.shield = 12.0
	wrecked.shield_delay = 1.0
	wrecked.recharge_shields(3.0)
	assert(wrecked.shield == 12.0, "destroyed hull does not recharge shields")
	for invalid_delta: float in [-1.0, 0.0, NAN, INF, -INF]:
		var shield_before: float = state.shield
		var delay_before: float = state.shield_delay
		state.recharge_shields(invalid_delta)
		assert(state.shield == shield_before and state.shield_delay == delay_before, "invalid recharge delta leaves shield state unchanged")

	var path := "user://player-shields-%d.json" % OS.get_process_id()
	var exchange := GameStateScript.new()
	exchange.credits = 50000
	exchange.shield = 24.0
	exchange.shield_delay = 3.5
	var orders := CrewOrdersScript.new(exchange)
	assert(orders.purchase_ship("Shield Pathfinder", "pathfinder").is_empty(), "commission shield exchange vessel")
	var vessel: Dictionary = exchange.fleet_ships.back()
	var blueprint: Dictionary = ShipBlueprintScript.family("pathfinder")
	var model := GameStateScript.new()
	model.ship_modules.assign(blueprint.modules)
	vessel.defense = {"charge": float(model.ship_stats().max_shield) * 0.4, "delay": 2.25}
	var incoming_delay: float = float(vessel.defense.delay)
	assert(orders.exchange_helm(str(vessel.id)).is_empty(), "helm exchange uses the state's shield delay when no override is supplied")
	assert(is_equal_approx(exchange.shield_delay, incoming_delay), "incoming helm restores its saved shield delay")
	assert(is_equal_approx(exchange.fleet_ships[0].defense.delay, 3.5), "outgoing helm stores its active shield delay")
	assert(exchange.save(path).is_empty(), "delayed shield state saves")
	var loaded := GameStateScript.new()
	assert(loaded.load_save(path).is_empty() and is_equal_approx(loaded.shield_delay, incoming_delay), "active shield delay survives save and reload")
	assert(is_equal_approx(loaded.fleet_ships[0].defense.delay, 3.5), "outgoing fleet shield delay also survives save and reload")

	var stable: Dictionary = loaded._save_data().duplicate(true)
	for invalid_value: Variant in [true, "bad", -0.01, 6.01]:
		var malformed: Dictionary = stable.duplicate(true)
		malformed.shield_delay = invalid_value
		_write_save(path, malformed)
		assert(not loaded.load_save(path).is_empty() and loaded._save_data() == stable, "invalid shield delay rejects save transactionally: %s" % str(invalid_value))
	var nonfinite: Dictionary = stable.duplicate(true)
	nonfinite.shield_delay = NAN
	assert(not GameStateScript.new()._load_v2(nonfinite).is_empty(), "non-finite shield delay is rejected")

	var legacy: Dictionary = stable.duplicate(true)
	legacy.erase("shield_delay")
	_write_save(path, legacy)
	assert(loaded.load_save(path).is_empty() and loaded.shield_delay == 0.0, "older save without shield delay defaults to zero")
	_cleanup(path)
	print("PLAYER_SHIELDS_OK: delay timing, recharge bounds, helm transfer, save validation and migration")
	quit()


func _write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "test save can be written")
	file.store_string(JSON.stringify(data))
	file.close()


func _cleanup(path: String) -> void:
	for candidate: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate): DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
