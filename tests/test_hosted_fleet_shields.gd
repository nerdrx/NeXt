extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state = GameStateScript.new()
	state.credits = 100000
	assert(state.hire("gunner").is_empty())
	assert(state.hire("gunner").is_empty())
	var orders = CrewOrdersScript.new(state)
	assert(orders.purchase_ship("Idle Family", "pathfinder").is_empty())
	assert(orders.purchase_ship("Remote Family", "merchant").is_empty())
	assert(orders.purchase_ship("Local Family", "pathfinder").is_empty())
	assert(orders.purchase_ship("Legacy Fleet", "").is_empty())
	var idle: Dictionary = state.fleet_ships[0]
	var remote: Dictionary = state.fleet_ships[1]
	var local: Dictionary = state.fleet_ships[2]
	var legacy: Dictionary = state.fleet_ships[3]
	assert(not idle.has("defense") and not remote.has("defense") and not local.has("defense"), "family defense remains optional before first hosted tick")
	var remote_crew := str(state.crew[0].id)
	var local_crew := str(state.crew[1].id)
	assert(orders.assign_patrol(remote_crew, str(remote.id), 1).is_empty())
	assert(orders.assign_patrol(local_crew, str(local.id), state.system_index).is_empty())

	orders.tick(2.0, [str(local.id)])
	for ship: Dictionary in [idle, remote, local]:
		assert(is_equal_approx(float(ship.defense.charge), 10.0), "idle, remote, and local family ships recharge at five per second")
	assert(not legacy.has("defense"), "hosted tick leaves legacy ships without shields unchanged")

	var snapshot: Dictionary = state._save_data().duplicate(true)
	for delta: float in [0.0, -1.0, INF, NAN]:
		orders.tick(delta, [str(local.id)])
	assert(state._save_data() == snapshot, "zero, negative, and nonfinite snapshots do not advance shields or orders")

	idle.defense = {"charge": 0.0, "delay": 6.0}
	orders.tick(5.0, [str(local.id)])
	assert(float(idle.defense.charge) == 0.0 and float(idle.defense.delay) == 1.0, "hosted shields honor saved recharge delay")
	orders.tick(1.0, [str(local.id)])
	assert(float(idle.defense.charge) == 0.0, "hosted shields stay empty at delay boundary")
	orders.tick(1.0, [str(local.id)])
	assert(is_equal_approx(float(idle.defense.charge), 5.0), "hosted recharge starts after six seconds")

	var remote_model = GameStateScript.new()
	remote_model.ship_modules.assign(ShipBlueprint.family("merchant").modules)
	var remote_capacity := float(remote_model.ship_stats().max_shield)
	remote.defense = {"charge": remote_capacity - 2.0, "delay": 0.0}
	orders.tick(1.0, [str(local.id)])
	assert(is_equal_approx(float(remote.defense.charge), remote_capacity), "hosted shield recharge remains capped at ship capacity")

	local.hull = 0.0
	local.defense = {"charge": 0.0, "delay": 0.0}
	orders.tick(1.0, [str(local.id)])
	assert(float(local.defense.charge) == 0.0 and float(local.defense.delay) == 0.0, "disabled family hull does not recharge")

	var combat_state = GameStateScript.new()
	combat_state.credits = 100000
	var combat_orders = CrewOrdersScript.new(combat_state)
	assert(combat_orders.purchase_ship("Shield Patrol", "pathfinder").is_empty())
	var combat_ship: Dictionary = combat_state.fleet_ships[0]
	combat_ship.defense = {"charge": 50.0, "delay": 0.0}
	var patrol := {"crew_id": "test", "ship_id": str(combat_ship.id), "system": 1, "encounters": 0}
	var intercepted := false
	for _attempt in range(50):
		var report: Dictionary = combat_orders._patrol_leg(patrol)
		if str(report.status) == "hostile intercepted":
			intercepted = true
			assert(float(report.hull) == 100.0 and float(combat_ship.hull) == 100.0, "patrol shields absorb hostile damage before hull")
			assert(is_equal_approx(float(combat_ship.defense.charge), 50.0 - float(report.damage)), "patrol consumes shield charge by absolute damage")
			assert(float(combat_ship.defense.delay) == 6.0, "patrol damage starts six-second shield delay")
			patrol.encounters -= 1
			combat_ship.defense.charge = 0.0
			var unshielded: Dictionary = combat_orders._patrol_leg(patrol)
			var capacity := float(CrewOrdersScript.family_combat_stats("pathfinder").max_hull)
			assert(is_equal_approx(float(unshielded.hull), 100.0 - float(report.damage) * 100.0 / capacity), "remote unshielded damage uses family hull strength")
			break
	assert(intercepted, "deterministic patrol encounter loop reaches a hostile")

	print("HOSTED_FLEET_SHIELDS_OK")
	quit()
