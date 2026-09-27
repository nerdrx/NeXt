extends SceneTree

var path := "user://market-inventory-%d.json" % OS.get_process_id()

func _initialize() -> void:
	var state := GameState.new()
	state.credits = 100000
	var initial := state.market_stock("ore")
	var base_price := state.price("ore")
	assert(initial > 10 and state.market_stocks.is_empty(), "reading untouched markets is deterministic and sparse")
	assert(GameState.new().market_stock("ore") == initial)
	assert(state.market_stock("ore", -2) == -1)
	var wallet := state.credits
	var quoted := state.player_trade_total("ore", 10, true)
	assert(state.trade("ore", 10, true).is_empty())
	assert(state.market_stock("ore") == initial - 10 and state.cargo.ore == 10 and state.credits == wallet - quoted)
	var sale := state.player_trade_total("ore", 10, false)
	assert(state.trade("ore", 10, false).is_empty())
	assert(state.market_stock("ore") == initial and state.cargo.ore == 0 and state.credits == wallet - quoted + sale and state.credits <= wallet, "roundtrip conserves goods and cannot mint money")
	assert(state.market_transfer("ore", 0, initial, true).is_empty())
	assert(state.market_stock("ore") == 0 and state.price("ore") > base_price)
	var before: Dictionary = state._save_data().duplicate(true)
	assert(not state.trade("ore", 1, true).is_empty() and state._save_data() == before, "empty market rejects atomically")
	assert(state.market_transfer("ore", 0, GameState.MARKET_CAPACITY, false).is_empty())
	state.cargo.ore = 1
	before = state._save_data().duplicate(true)
	assert(not state.trade("ore", 1, false).is_empty() and state._save_data() == before, "full market rejects atomically")
	assert(state.save(path).is_empty())
	var loaded := GameState.new()
	assert(loaded.load_save(path).is_empty() and loaded.market_stocks == state.market_stocks)
	var valid := loaded._save_data().duplicate(true)
	for bad: Variant in [[], {"00": {"ore": 1}}, {"-1": {"ore": 1}}, {"1000000000": {"ore": 1}}, {"0": {"bogus": 1}}, {"0": {"ore": -1}}, {"0": {"ore": 1.5}}, {"0": {"ore": GameState.MARKET_CAPACITY + 1}}]:
		var damaged := valid.duplicate(true)
		damaged.market_stocks = bad
		_write(damaged)
		assert(not loaded.load_save(path).is_empty() and loaded._save_data() == valid, "invalid stock rejected transactionally")
	var legacy := valid.duplicate(true)
	legacy.erase("market_stocks")
	_write(legacy)
	assert(loaded.load_save(path).is_empty() and loaded.market_stocks.is_empty() and loaded.market_stock("ore") == initial)
	assert(GameState.new().market_stock("ore") == initial, "world inventories remain isolated")
	var crowded := GameState.new()
	for index: int in range(GameState.MAX_MARKETS): crowded.market_stocks[str(index)] = {"ore": 0}
	crowded.system_index = GameState.MAX_MARKETS
	var crowded_wallet := crowded.credits
	assert(not crowded.trade("ore", 1, true).is_empty() and crowded.credits == crowded_wallet and crowded.cargo_total() == 0 and crowded.market_stocks.size() == GameState.MAX_MARKETS, "market capacity cannot evict shortages or charge rejected trades")
	assert(crowded.market_transfer("ore", 0, 1, false).is_empty(), "existing market can still receive deliveries at record cap")
	crowded.advance_time(GameState.DAY_SECONDS)
	assert(crowded.market_stock("ore", 0) == 1, "clock changes do not silently replenish stock")
	_test_freight()
	for file_path: String in [path, path + ".bak"]:
		if FileAccess.file_exists(file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	print("MARKET_INVENTORY_OK: stock conservation, marginal prices, scarcity, freight and transactional saves")
	quit()

func _test_freight() -> void:
	var state := GameState.new()
	state.credits = 50000
	assert(state.hire("trader").is_empty())
	var orders := CrewOrders.new(state)
	assert(orders.purchase_ship("Supply Runner").is_empty())
	var ship: Dictionary = state.fleet_ships[0]
	var crew_id: String = state.crew[0].id
	var destination_stock := state.market_stock("ore", 17)
	assert(orders.assign_trade_route(crew_id, ship.id, "ore", 17, 5).is_empty())
	# Another buyer exhausts most supply while the ship is approaching.
	assert(state.market_transfer("ore", 0, state.market_stock("ore", 0) - 2, true).is_empty())
	var origin_price := state.price_at("ore", 0)
	var reports := orders.tick(600)
	assert(reports.size() == 1 and reports[0].status == "cargo bought")
	var bought := int(ship.cargo.ore)
	assert(bought > 0 and bought <= 2 and state.market_stock("ore", 0) + bought == 2, "trader cannot buy imaginary stock")
	assert(state.price_at("ore", 0) >= origin_price)
	assert(state.market_transfer("ore", 17, GameState.MARKET_CAPACITY - destination_stock, false).is_empty())
	var escrow_before: int = state.crew_orders[crew_id].escrow
	reports = orders.tick(600)
	assert(reports.size() == 1 and reports[0].status == "waiting: destination market full")
	assert(ship.cargo.ore == bought and state.crew_orders[crew_id].phase == "inbound" and state.crew_orders[crew_id].escrow == escrow_before, "full destination cannot erase or pay for undelivered cargo")
	assert(state.market_transfer("ore", 17, GameState.MARKET_CAPACITY - destination_stock, true).is_empty())
	reports = orders.tick(600)
	assert(reports.size() == 1 and reports[0].status == "cargo sold")
	assert(int(ship.cargo.ore) == 0 and state.market_stock("ore", 17) == destination_stock + bought, "delivery moves actual cargo into destination supply")

func _write(data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
