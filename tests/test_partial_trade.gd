extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")

var save_path := "user://partial-trade-%d.json" % OS.get_process_id()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := _new_trade_state()
	var orders := CrewOrdersScript.new(state)
	var crew_id: String = str(state.crew[0].id)
	var ship: Dictionary = state.fleet_ships[0]
	var ship_id: String = str(ship.id)
	var origin: int = int(ship.system)
	var destination := origin + 100
	assert(orders.assign_trade_route(crew_id, ship_id, "ore", destination, 5).is_empty())
	var order: Dictionary = state.crew_orders[crew_id]
	var original_cost: int = state.market_total("ore", origin, 5, true)
	assert(orders.tick(CrewOrdersScript.TRIP_SECONDS * 2.0).size() == 1)
	assert(int(ship.cargo.ore) == 5 and int(order.purchase_cost) == original_cost)
	ship.fuel = 0.0
	ship.fuel_allowance = 0

	# Make room for exactly two units, then verify an unavailable local trader waits atomically.
	var destination_stock: int = state.market_stock("ore", destination)
	var room := 2
	assert(state.market_transfer("ore", destination, GameStateScript.MARKET_CAPACITY - destination_stock - room, false).is_empty())
	var full_stock := state.market_stock("ore", destination)
	var credits_before_wait: int = state.credits
	var cargo_before_wait: int = int(ship.cargo.ore)
	var basis_before_wait: int = int(order.purchase_cost)
	var escrow_before_wait: int = int(order.escrow)
	var fuel_before_wait: float = float(ship.fuel)
	var wait_report: Array[Dictionary] = orders.tick(CrewOrdersScript.TRIP_SECONDS * 2.0, [], {ship_id: false})
	assert(wait_report.is_empty() and int(ship.cargo.ore) == cargo_before_wait and int(order.purchase_cost) == basis_before_wait)
	assert(state.market_stock("ore", destination) == full_stock and int(order.escrow) == escrow_before_wait)
	assert(state.credits == credits_before_wait and float(ship.fuel) == fuel_before_wait and order.phase == "inbound")

	var sold_first := 2
	var first_revenue: int = state.market_total("ore", destination, sold_first, false, 0.85)
	var first_basis := int(float(original_cost) * float(sold_first) / 5.0)
	var credits_before_sale: int = state.credits
	var escrow_before_sale: int = int(order.escrow)
	var fuel_at_berth: float = float(ship.fuel)
	var sale_one: Array[Dictionary] = orders.tick(1.0, [], {ship_id: true})
	assert(sale_one.size() == 1 and sale_one[0].status == "cargo partially sold")
	assert(int(sale_one[0].quantity) == sold_first and int(sale_one[0].remaining) == 3)
	assert(int(sale_one[0].purchase_cost) == first_basis and int(sale_one[0].revenue) == first_revenue)
	assert(int(sale_one[0].profit) == first_revenue - first_basis)
	assert(int(ship.cargo.ore) == 3 and int(order.purchase_cost) == original_cost - first_basis)
	assert(order.phase == "inbound" and int(ship.system) == destination and float(ship.fuel) == fuel_at_berth,
		"partial sale stays at destination without spending jump fuel")
	assert(state.market_stock("ore", destination) == full_stock + sold_first)
	var wage: int = int(state.crew[0].salary)
	assert(state.credits + int(order.escrow) == credits_before_sale + escrow_before_sale + first_revenue - wage,
		"sale revenue is conserved between credits and replenished escrow after the tick wage")
	assert(int(order.escrow) - escrow_before_sale == mini(first_revenue, int(order.escrow_limit) - escrow_before_sale),
		"each sale replenishes escrow from its revenue")
	assert(int(order.earned) == first_revenue - first_basis)
	var credits_before_full_wait: int = state.credits
	var cargo_before_full_wait: int = int(ship.cargo.ore)
	var basis_before_full_wait: int = int(order.purchase_cost)
	var escrow_before_full_wait: int = int(order.escrow)
	var fuel_before_full_wait: float = float(ship.fuel)
	var full_wait: Array[Dictionary] = orders.tick(CrewOrdersScript.TRIP_SECONDS * 2.0, [], {ship_id: true})
	assert(full_wait.size() == 1 and full_wait[0].status == "waiting: destination market full")
	assert(int(ship.cargo.ore) == cargo_before_full_wait and int(order.purchase_cost) == basis_before_full_wait)
	assert(int(order.escrow) == escrow_before_full_wait and state.market_stock("ore", destination) == GameStateScript.MARKET_CAPACITY)
	assert(state.credits == credits_before_full_wait - wage and float(ship.fuel) == fuel_before_full_wait)
	assert(order.phase == "inbound" and int(order.earned) == first_revenue - first_basis,
		"full market wait preserves trade state and only charges the tick wage")
	assert(state.save(save_path).is_empty())

	var loaded := GameStateScript.new()
	assert(loaded.load_save(save_path).is_empty())
	state = loaded
	orders = CrewOrdersScript.new(state)
	order = state.crew_orders[crew_id]
	ship = state.fleet_ships[0]
	assert(int(ship.cargo.ore) == 3 and int(order.purchase_cost) == original_cost - first_basis)
	assert(order.phase == "inbound" and int(ship.system) == destination)
	assert(state.market_transfer("ore", destination, 3, true).is_empty(), "make room for the remaining cargo")
	ship.fuel = 100.0 # The completed round trip still needs its return jump.
	var final_revenue: int = state.market_total("ore", destination, 3, false, 0.85)
	var final_basis: int = int(order.purchase_cost)
	var final_report: Array[Dictionary] = orders.tick(CrewOrdersScript.TRIP_SECONDS * 2.0)
	assert(final_report.size() == 1 and final_report[0].status == "cargo sold")
	assert(int(final_report[0].quantity) == 3 and int(final_report[0].purchase_cost) == final_basis)
	assert(int(order.earned) == first_revenue + final_revenue - original_cost,
		"sum of sale profits equals total revenue minus original actual cost")
	assert(int(order.purchase_cost) == 0 and int(ship.cargo.ore) == 0 and order.phase == "outbound")
	assert(int(ship.system) == origin, "final sale resumes the round trip")
	
	_test_unknown_legacy_basis()
	for path: String in [save_path, save_path + ".tmp", save_path + ".bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PARTIAL_TRADE_OK: partial settlement, escrow, persistence, final profit, legacy basis")
	quit()

func _test_unknown_legacy_basis() -> void:
	var state := _new_trade_state()
	var orders := CrewOrdersScript.new(state)
	var crew_id: String = str(state.crew[0].id)
	var ship: Dictionary = state.fleet_ships[0]
	var origin: int = int(ship.system)
	var destination := origin + 101
	assert(orders.assign_trade_route(crew_id, str(ship.id), "ore", destination, 2).is_empty())
	ship.system = destination
	ship.cargo.ore = 2
	state.crew_orders[crew_id].phase = "inbound"
	state.crew_orders[crew_id].earned = 77
	var old_data: Dictionary = state._save_data().duplicate(true)
	old_data.crew_orders[crew_id].erase("purchase_cost")
	_write_save(old_data)
	var loaded := GameStateScript.new()
	assert(loaded.load_save(save_path).is_empty())
	orders = CrewOrdersScript.new(loaded)
	var order: Dictionary = loaded.crew_orders[crew_id]
	var loaded_ship: Dictionary = loaded.fleet_ships[0]
	assert(int(order.get("purchase_cost", -1)) == -1, "legacy inbound cargo basis remains unknown")
	var stock: int = loaded.market_stock("ore", destination)
	assert(loaded.market_transfer("ore", destination, GameStateScript.MARKET_CAPACITY - stock - 1, false).is_empty())
	var report: Array[Dictionary] = orders.tick(CrewOrdersScript.TRIP_SECONDS * 2.0, [], {str(loaded_ship.id): true})
	assert(report.size() == 1 and report[0].status == "cargo partially sold")
	assert(int(report[0].remaining) == 1 and report[0].purchase_cost == null and report[0].profit == null)
	assert(int(order.purchase_cost) == -1 and int(order.earned) == 77 and int(loaded_ship.cargo.ore) == 1,
		"partial legacy sale preserves unknown basis and does not fabricate profit")
	assert(order.phase == "inbound" and int(loaded_ship.system) == destination)

func _new_trade_state() -> GameState:
	var state := GameStateScript.new()
	state.credits = 50000
	assert(state.hire("trader").is_empty())
	var orders := CrewOrdersScript.new(state)
	assert(orders.purchase_ship("Partial Sale Courier").is_empty())
	return state

func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
