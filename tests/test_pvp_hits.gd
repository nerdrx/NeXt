extends SceneTree

const Hits = preload("res://scripts/pvp_hits.gd")

func _initialize() -> void:
	var attacker := _profile(Vector3.ZERO)
	attacker.ship_modules.append({"kind": "weapon", "x": 1, "y": 0, "z": 0})
	var near := _profile(Vector3(0, 1.55, -100))
	var far := _profile(Vector3(0, 1.55, -200))
	var hit := Hits.trace(attacker, {2: far, 3: near}, Vector3.FORWARD)
	assert(hit.target == 3 and is_equal_approx(hit.distance, 98.6) and hit.damage == 25.0)
	assert(Hits.trace(attacker, {1: attacker, 3: near}, Vector3.FORWARD, 1).target == 3)
	assert(Hits.trace(attacker, {3: near}, Vector3.BACK).is_empty())
	assert(Hits.trace(attacker, {3: near}, Vector3.RIGHT).is_empty())
	for direction in [Vector3.ZERO, Vector3(INF, 0, 0), Vector3(NAN, 0, 0), Vector3(1e30, 0, 0)]:
		assert(Hits.trace(attacker, {3: near}, direction).is_empty())
	near.pvp = false
	assert(Hits.trace(attacker, {2: far, 3: near}, Vector3.FORWARD).is_empty())
	var overlapping := near.duplicate(true)
	overlapping.pvp = true
	assert(Hits.trace(attacker, {2: overlapping, 3: near}, Vector3.FORWARD).is_empty())
	near.pvp = true
	near.flying = false
	assert(Hits.trace(attacker, {2: far, 3: near}, Vector3.FORWARD).is_empty())
	near.flying = true
	attacker.pvp = false
	assert(Hits.trace(attacker, {3: near}, Vector3.FORWARD).is_empty())
	attacker.pvp = true
	attacker.flying = false
	assert(Hits.trace(attacker, {3: near}, Vector3.FORWARD).is_empty())
	attacker.flying = true
	# Bounds centering matches ShipVisual for asymmetric multi-module hulls.
	near.ship_modules = [{"kind": "core", "x": 0, "y": 0, "z": 0}, {"kind": "hull", "x": 1, "y": 0, "z": 0}]
	near.rotation = Vector3(0, PI / 2.0, 0)
	hit = Hits.trace(attacker, {3: near}, Vector3.FORWARD)
	assert(is_equal_approx(hit.distance, 97.2))
	# A gap between disconnected test cells is not a solid aggregate bounding box.
	near.rotation = Vector3.ZERO
	near.ship_modules = [{"kind": "core", "cell": Vector3i(-2, 0, 0)}, {"kind": "hull", "cell": Vector3i(2, 0, 0)}]
	assert(Hits.trace(attacker, {3: near}, Vector3.FORWARD).is_empty())
	var distant := _profile(Vector3(0, 1.55, -2300))
	assert(Hits.trace(attacker, {3: distant}, Vector3.FORWARD).is_empty())
	# Sector-edge crossing and enormous shared addresses retain local precision.
	var sector := Vector3i(1000000000, -1000000000, 1000000000)
	attacker.address = SectorPosition.new(sector, Vector3(0, 0, -4090)).to_save()
	far.address = SectorPosition.new(sector + Vector3i(0, 0, -1), Vector3(0, 1.55, 4002)).to_save()
	hit = Hits.trace(attacker, {2: far}, Vector3.FORWARD)
	assert(hit.target == 2 and is_equal_approx(hit.distance, 98.6))
	far.address = SectorPosition.new(Vector3i.ZERO, Vector3.ZERO).to_save()
	assert(Hits.trace(attacker, {2: far}, Vector3.FORWARD).is_empty())
	print("PvPHits tests passed: hull geometry, nearest occlusion, consent, docking, range, sector precision, damage and invalid rays")
	quit()

func _profile(position: Vector3) -> Dictionary:
	return {"address": SectorPosition.new(Vector3i.ZERO, position).to_save(), "rotation": Vector3.ZERO, "ship_modules": [{"kind": "core", "x": 0, "y": 0, "z": 0}], "pvp": true, "flying": true}
