extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

var save_path := "user://trade-cost-basis-%d.json" % OS.get_process_id()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := _new_trade_state()
	var orders := CrewOrdersScript.new(state)
	var crew_id: String = state.crew[0].id
	var ship_id: String = state.fleet_ships[0].id
	var origin: int = int(state.fleet_ships[0].system)
	var destination: int = origin + 100
	assert(orders.assign_trade_route(crew_id, ship_id, "ore", destination, 5).is_empty())
	var order: Dictionary = state.crew_orders[crew_id]
	assert(order.purchase_cost == 0, "empty cargo begins with known zero cost")
	var buy_cost: int = state.market_total("ore", origin, 5, true)
	assert(orders.tick(CrewOrdersScript.TRIP_SECONDS * 2.0).size() == 1, "outbound leg buys cargo")
	assert(int(order.purchase_cost) == buy_cost, "actual marginal buy total becomes cost basis")
	assert(int(state.fleet_ships[0].cargo.ore) == 5)
	assert(state.save(save_path).is_empty())
	var loaded := GameStateScript.new()
	var load_error: String = loaded.load_save(save_path)
	assert(load_error.is_empty(), load_error)
	orders = CrewOrdersScript.new(loaded)
	var loaded_order: Dictionary = loaded.crew_orders[crew_id]
	assert(int(loaded_order.purchase_cost) == buy_cost, "inbound cost basis survives save/load")
	assert(loaded.market_transfer("ore", origin, loaded.market_stock("ore", origin), true).is_empty(), "drain origin market after purchase")
	loaded.day += 5
	assert(loaded.price_at("ore", origin) * 5 != buy_cost, "fixture makes live origin price diverge from recorded purchase cost")
	var destination_stock: int = loaded.market_stock("ore", destination)
	assert(loaded.market_transfer("ore", destination, GameStateScript.MARKET_CAPACITY - destination_stock, false).is_empty(), "fill destination market")
	var cargo_before_wait: int = int(loaded.fleet_ships[0].cargo.ore)
	var cost_before_wait: int = int(loaded_order.purchase_cost)
	var full_report: Array[Dictionary] = orders.tick(CrewOrdersScript.TRIP_SECONDS * 2.0)
	assert(full_report.size() == 1 and full_report[0].status == "waiting: destination market full")
	assert(int(loaded.fleet_ships[0].cargo.ore) == cargo_before_wait and int(loaded_order.purchase_cost) == cost_before_wait, "full market preserves cargo and cost basis")
	assert(loaded.market_transfer("ore", destination, 5, true).is_empty(), "free capacity for the sale")
	var expected_revenue: int = loaded.market_total("ore", destination, 5, false, 0.85)
	var sale_report: Array[Dictionary] = orders.tick(CrewOrdersScript.TRIP_SECONDS * 2.0)
	assert(sale_report.size() == 1 and sale_report[0].status == "cargo sold")
	assert(sale_report[0].purchase_cost == buy_cost and sale_report[0].revenue == expected_revenue)
	assert(sale_report[0].profit == expected_revenue - buy_cost, "day and destination price changes cannot rewrite actual cost basis")
	assert(int(loaded_order.earned) == expected_revenue - buy_cost and int(loaded_order.purchase_cost) == 0)

	# Old 13-field order saves migrate: empty outbound cargo can establish a known cost,
	# while pre-existing inbound cargo remains unknown instead of inventing a basis.
	var legacy_outbound := _new_trade_state()
	var legacy_orders := CrewOrdersScript.new(legacy_outbound)
	var legacy_crew: String = legacy_outbound.crew[0].id
	var legacy_ship: String = legacy_outbound.fleet_ships[0].id
	assert(legacy_orders.assign_trade_route(legacy_crew, legacy_ship, "ore", int(legacy_outbound.fleet_ships[0].system) + 1, 2).is_empty())
	var legacy_data: Dictionary = legacy_outbound._save_data().duplicate(true)
	legacy_data.crew_orders[legacy_crew].erase("purchase_cost")
	_write_save(legacy_data)
	var legacy_loaded := GameStateScript.new()
	assert(legacy_loaded.load_save(save_path).is_empty())
	var migrated_order: Dictionary = legacy_loaded.crew_orders[legacy_crew]
	assert(int(migrated_order.get("purchase_cost", 0)) == 0, "old empty outbound order remains ready to establish basis")
	var legacy_buy_cost: int = legacy_loaded.market_total("ore", int(legacy_loaded.fleet_ships[0].system), 2, true)
	var migrated_orders := CrewOrdersScript.new(legacy_loaded)
	assert(migrated_orders.tick(CrewOrdersScript.TRIP_SECONDS * 2.0).size() == 1)
	assert(int(migrated_order.purchase_cost) == legacy_buy_cost, "old outbound order establishes basis from its first actual buy")

	var old_inbound := _new_trade_state()
	var inbound_orders := CrewOrdersScript.new(old_inbound)
	var inbound_crew: String = old_inbound.crew[0].id
	var inbound_ship: Dictionary = old_inbound.fleet_ships[0]
	var inbound_origin: int = int(inbound_ship.system)
	assert(inbound_orders.assign_trade_route(inbound_crew, str(inbound_ship.id), "ore", inbound_origin + 2, 2).is_empty())
	old_inbound.crew_orders[inbound_crew].phase = "inbound"
	old_inbound.crew_orders[inbound_crew].earned = 77
	inbound_ship.system = int(old_inbound.crew_orders[inbound_crew].destination)
	inbound_ship.cargo.ore = 2
	var old_inbound_data: Dictionary = old_inbound._save_data().duplicate(true)
	old_inbound_data.crew_orders[inbound_crew].erase("purchase_cost")
	_write_save(old_inbound_data)
	var unknown_loaded := GameStateScript.new()
	assert(unknown_loaded.load_save(save_path).is_empty())
	var unknown_orders := CrewOrdersScript.new(unknown_loaded)
	var unknown_order: Dictionary = unknown_loaded.crew_orders[inbound_crew]
	assert(int(unknown_order.get("purchase_cost", -1)) == -1, "legacy inbound cargo has unknown cost basis")
	var unknown_sale: Array[Dictionary] = unknown_orders.tick(CrewOrdersScript.TRIP_SECONDS * 2.0)
	assert(unknown_sale.size() == 1 and unknown_sale[0].status == "cargo sold")
	assert(unknown_sale[0].purchase_cost == null and unknown_sale[0].profit == null, "unknown basis is reported as null")
	assert(int(unknown_order.earned) == 77 and int(unknown_order.purchase_cost) == 0, "unknown profit is not fabricated and basis resets after sale")

	var preloaded := _new_trade_state()
	preloaded.fleet_ships[0].cargo.ore = 1
	var preloaded_orders := CrewOrdersScript.new(preloaded)
	var preloaded_crew: String = preloaded.crew[0].id
	assert(preloaded_orders.assign_trade_route(preloaded_crew, str(preloaded.fleet_ships[0].id), "ore", int(preloaded.fleet_ships[0].system) + 3, 5).is_empty())
	assert(int(preloaded.crew_orders[preloaded_crew].purchase_cost) == -1, "pre-existing cargo starts with unknown basis")
	preloaded.fleet_ships[0].system = int(preloaded.crew_orders[preloaded_crew].destination)
	preloaded.fleet_ships[0].cargo.ore = 2
	preloaded.crew_orders[preloaded_crew].phase = "inbound"
	assert(preloaded_orders.cancel(preloaded_crew).is_empty())
	assert(preloaded_orders.assign_trade_route(preloaded_crew, str(preloaded.fleet_ships[0].id), "ore", int(preloaded.fleet_ships[0].system) + 4, 5).is_empty())
	assert(int(preloaded.crew_orders[preloaded_crew].purchase_cost) == -1, "cancel and reassign keeps leftover cargo basis unknown")

	var atomic := _new_trade_state()
	var atomic_orders := CrewOrdersScript.new(atomic)
	var atomic_crew: String = atomic.crew[0].id
	assert(atomic_orders.assign_trade_route(atomic_crew, str(atomic.fleet_ships[0].id), "ore", int(atomic.fleet_ships[0].system) + 5, 1).is_empty())
	var unchanged := GameStateScript.new()
	unchanged.credits = 12345
	var prior: Dictionary = unchanged._save_data()
	var max_basis: int = 100 * ceili(float(GameStateScript.GOODS.ore) * 1.45 * GameStateScript.MAX_SCARCITY_MULTIPLIER)
	for malformed_basis: Variant in [-2, 1.5, "1", max_basis + 1]:
		var malformed: Dictionary = atomic._save_data().duplicate(true)
		malformed.crew_orders[atomic_crew].purchase_cost = malformed_basis
		_write_save(malformed)
		assert(not unchanged.load_save(save_path).is_empty() and unchanged._save_data() == prior, "malformed optional basis %s is rejected transactionally" % str(malformed_basis))

	for file_path: String in [save_path, save_path + ".tmp", save_path + ".bak"]:
		if FileAccess.file_exists(file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	print("TRADE_COST_BASIS_OK: actual cost, save migration, unknown cargo and atomic validation")
	quit()

func _new_trade_state() -> GameState:
	var state := GameStateScript.new()
	state.credits = 50000
	assert(state.hire("trader").is_empty())
	var orders := CrewOrdersScript.new(state)
	assert(orders.purchase_ship("Cost Basis Courier").is_empty())
	return state

func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
