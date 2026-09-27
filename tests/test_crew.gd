extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CrewOrdersScript = preload("res://scripts/crew_orders.gd")
const ShipLayoutScript = preload("res://scripts/ship_layout.gd")

func _initialize() -> void:
	var state = GameStateScript.new()
	state.credits = 20000
	assert(state.add_module("habitat", Vector3i(0, 0, 3)) == "")
	assert(state.hire("trader") == "")
	assert(state.hire("gunner") == "")
	assert(state.hire("engineer") == "")
	var names: Dictionary = {}
	for member: Dictionary in state.crew:
		assert(member.name.split(" ").size() == 2 and not names.has(member.name), "crew have unique generated human names")
		names[member.name] = true
	state.cargo.alloys = 20
	assert(state.build_station("Pelican Yard") == "")
	assert(state.jump(7919) == "" and state.crew_paid)
	var orders = CrewOrdersScript.new(state)
	assert(orders.purchase_ship("Mule") == "")
	assert(orders.purchase_ship("mule") != "", "fleet names are unique")
	var trader: String = state.crew[0].id
	var gunner: String = state.crew[1].id
	var engineer: String = state.crew[2].id
	# Stable identity gives a quiet first patrol, then a hostile remote encounter.
	state.fleet_ships[0].id = "crew-test-ship"
	var ship_id: String = state.fleet_ships[0].id
	var credit_before_order: int = state.credits
	var quote: Dictionary = orders.route_quote("ore", 9001, 5, ship_id)
	assert(quote.ok and quote.buy_unit == state.price_at("ore", int(state.fleet_ships[0].system)) and quote.sale_unit == state.market_total("ore", 9001, 1, false, 0.85), "route planner and market share exact prices")
	assert(orders.assign_trade_route(trader, ship_id, "ore", 9001, 5) == "")
	assert(state.credits < credit_before_order, "route escrow is reserved")
	assert(state._paid_crew_count("trader") == 0 and state._paid_crew_count("gunner") == 1, "assigned crew stop contributing passive role bonuses")
	var credits_after_escrow: int = state.credits
	assert(orders.assign_patrol(gunner, ship_id, 7919) != "", "one ship cannot receive two orders")
	assert(orders.tick(0).is_empty() and orders.tick(-500).is_empty(), "non-positive time cannot accrue work")
	assert(orders.tick(599).is_empty(), "trade cannot settle before the complete round trip")
	var bought: Array[Dictionary] = orders.tick(1)
	assert(bought.size() == 1 and bought[0].status == "cargo bought")
	assert(state.credits == credits_after_escrow - int(state.crew[0].salary), "completed operation cycle charges its named crew wage once")
	assert(int(state.fleet_ships[0].cargo.get("ore", 0)) == 5, "trade buys physical fleet cargo")
	var progress_before_offline: float = float(state.crew_orders[trader].progress)
	assert(orders.tick(1200).size() == 2, "hosted travel buys and sells at both ends")
	assert(int(state.fleet_ships[0].cargo.get("ore", 0)) > 0, "sale proceeds refill bounded trade escrow for the next trip")
	assert(state.crew_orders[trader].has("earned"), "trade proceeds accumulate on persistent order")
	assert(state.crew_orders[trader].progress >= progress_before_offline)
	var cargo_before_cancel: int = int(state.fleet_ships[0].cargo.get("ore", 0))
	assert(orders.cancel(trader) == "" and not state.crew_orders.has(trader), "cancel releases route")
	assert(int(state.fleet_ships[0].cargo.get("ore", 0)) == cargo_before_cancel, "cancellation keeps physical cargo aboard")
	var paid_before_cancel: int = state.credits
	assert(paid_before_cancel > 0)
	assert(orders.assign_patrol(gunner, ship_id, 7919) == "")
	var patrol: Dictionary = state.crew_orders[gunner]
	var patrol_ship: Dictionary = state.fleet_ships[0]
	patrol_ship.system = state.system_index
	var local_hull: float = float(patrol_ship.hull)
	var local_credits: int = state.credits
	var gunner_wage: int = int(state.crew[1].salary)
	var local_report: Array[Dictionary] = orders.tick(300, [ship_id])
	assert(local_report.size() == 1 and local_report[0].status == "local patrol wages paid" and local_report[0].wages == gunner_wage, "local patrol advances with an explicit wage report")
	assert(int(patrol.encounters) == 0 and float(patrol_ship.hull) == local_hull and state.credits == local_credits - gunner_wage, "local patrol has no duplicate synthetic combat, damage, or bounty")
	state.credits = 0
	var unpaid_local: Array[Dictionary] = orders.tick(300, [ship_id])
	assert(unpaid_local.size() == 1 and unpaid_local[0].status == "paused: wages unpaid" and patrol.paused, "local patrol pauses when wages cannot be paid")
	assert(int(patrol.encounters) == 0 and float(patrol_ship.hull) == local_hull and state.credits == 0)
	state.credits = gunner_wage
	local_report = orders.tick(1, [ship_id])
	assert(local_report.size() == 1 and local_report[0].status == "local patrol wages paid" and not patrol.paused and state.credits == 0, "local patrol resumes once wages are funded")
	# A listed local ID is not enough during transit: only matching current-system ships are suppressed.
	patrol_ship.system = 7918
	state.credits = 10000
	var report: Array[Dictionary] = orders.tick(300, [ship_id])
	assert(report.size() == 1 and report[0].status == "quiet patrol" and report[0].has("hull"), "transiting patrol simulates its arrival even when listed as local")
	assert(int(patrol.encounters) == 1 and int(patrol_ship.system) == state.system_index and float(patrol_ship.hull) == local_hull)
	report = orders.tick(300, [ship_id])
	assert(report.size() == 1 and report[0].status == "local patrol wages paid" and int(patrol.encounters) == 1, "arrived patrol uses local combat on subsequent ticks")
	# Without a locally simulated actor, strategic encounters must still cause damage.
	report = orders.tick(300)
	assert(report.size() == 1 and report[0].status == "hostile intercepted" and int(patrol.encounters) == 2, "remote patrol simulates hostile encounters")
	assert(float(patrol_ship.hull) < local_hull and float(report[0].damage) > 0 and int(report[0].reward) > 0, "remote encounter applies hull risk and bounty")
	state.fleet_ships[0].hull = 0.0
	var credits_before_disabled: int = state.credits
	var disabled_report: Array[Dictionary] = orders.tick(300)
	assert(disabled_report.size() == 1 and disabled_report[0].status == "paused: ship disabled" and state.credits == credits_before_disabled, "disabled fleet ship cannot incur wages or earn rewards")
	assert(orders.repair_fleet_ship(ship_id) == "" and float(state.fleet_ships[0].hull) == 100.0)
	assert(orders.cancel(gunner) == "")
	assert(orders.assign_station_manager(engineer, 0) == "")
	var produced_good: String = ["ore", "alloys", "food", "fuel", "medicine", "electronics", "luxuries"][int(state.stations[0].system) % 7]
	var stock_before: int = int(state.stations[0].get("stock", {}).get(produced_good, 0))
	var produced: Array[Dictionary] = orders.tick(900)
	assert(produced.size() == 1 and produced[0].status == "production complete")
	assert(int(state.stations[0].stock[produced_good]) > stock_before, "manager produces real station stock")
	state.system_index = int(state.stations[0].system)
	var stock_before_withdrawal: int = int(state.stations[0].stock[produced_good])
	assert(orders.withdraw_station_stock(0, produced_good, 1) == "")
	assert(int(state.cargo[produced_good]) == 1 and int(state.stations[0].stock[produced_good]) == stock_before_withdrawal - 1, "station stock can be moved into personal hold")
	assert(state.remove_module(Vector3i(0, 0, 3)) != "", "cannot remove capacity needed by named crew")
	var reassign_error: String = orders.assign_trade_route(trader, ship_id, "ore", 9002, 5)
	assert(reassign_error == "", reassign_error)
	var path: String = "user://crew-test-%d.json" % OS.get_process_id()
	assert(state.save(path) == "")
	var loaded = GameStateScript.new()
	var load_error: String = loaded.load_save(path)
	assert(load_error == "", load_error)
	assert(loaded._save_data() == state._save_data(), "fleet, production and crew order round-trip")
	var v2_path: String = path + ".v2"
	var v2: Dictionary = state._save_data().duplicate(true)
	v2.version = 2
	for added_field: String in ["fleet_ships", "crew_orders", "recovery", "ship_layout"]: v2.erase(added_field)
	var v2_file := FileAccess.open(v2_path, FileAccess.WRITE)
	v2_file.store_string(JSON.stringify(v2))
	v2_file.close()
	var migrated = GameStateScript.new()
	assert(migrated.load_save(v2_path) == "")
	assert(migrated.credits == state.credits and migrated.crew == state.crew and migrated.world_id == state.world_id, "v2 migration preserves commander economy and named identities")
	assert(migrated.fleet_ships.is_empty() and migrated.crew_orders.is_empty() and migrated.ship_layout == ShipLayoutScript.empty_data(), "v2 migration initializes new persistent systems")
	var resumed = CrewOrdersScript.new(loaded)
	var manager_id: String = loaded.crew[2].id
	assert(resumed.tick(599).is_empty(), "restored orders keep saved progress")
	var reopened: Array[Dictionary] = resumed.tick(1)
	assert(reopened.size() == 1 and reopened[0].status == "cargo bought", "trade resumes only after remaining hosted time")
	assert(resumed.tick(299).is_empty())
	reopened = resumed.tick(1)
	assert(reopened.size() == 1 and reopened[0].status == "production complete", "station production uses only hosted elapsed time")
	assert(int(loaded.stations[0].stock[produced_good]) == int(state.stations[0].stock[produced_good]) + 1)
	loaded.credits = 0
	var pause_report: Array[Dictionary] = resumed.tick(900)
	var wages_paused: bool = false
	for entry: Dictionary in pause_report:
		if entry.status == "paused: wages unpaid": wages_paused = true
	assert(wages_paused, "unpaid orders report wage status")
	assert(resumed.tick(900).is_empty(), "unpaid status reports once")
	assert(loaded.crew_orders[manager_id].paused)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(v2_path))
	print("Crew order tests passed")
	quit()
