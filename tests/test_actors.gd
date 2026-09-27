extends SceneTree

var destroyed_count: int = 0
var fired_count: int = 0
var last_fire_origin: Vector3 = Vector3.ZERO
var last_fire_direction: Vector3 = Vector3.ZERO
var damaged_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _track_destroyed(_actor: Node) -> void:
	destroyed_count += 1


func _track_fired(_actor: ShipActor, origin: Vector3, direction: Vector3) -> void:
	fired_count += 1
	last_fire_origin = origin
	last_fire_direction = direction


func _track_damaged(_actor: ShipActor) -> void:
	damaged_count += 1


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var visual := ShipVisual.new()
	world.add_child(visual)
	visual.build([{"kind": "cockpit", "x": 0, "y": 0, "z": 0}, {"kind": "engine", "x": 0, "y": 0, "z": 1}])
	assert(visual.get_child_count() > 0, "designer module records must build ship geometry")
	var ship := ShipActor.new()
	world.add_child(ship)
	ship.destroyed.connect(_track_destroyed)
	var person := GroundActor.new()
	person.faction = "pirate"
	world.add_child(person)
	person.destroyed.connect(_track_destroyed)
	await process_frame
	assert(ship.get_child_count() > 1 and person.get_child_count() > 1)
	ship.take_damage(1000.0)
	ship.take_damage(1000.0)
	person.take_damage(1000.0)
	person.take_damage(1000.0)
	assert(destroyed_count == 2, "each actor must emit destroyed exactly once")
	var target_ship := ShipActor.new()
	target_ship.position = Vector3(0, 330, 0)
	world.add_child(target_ship)
	var attacker := ShipActor.new()
	attacker.position = Vector3(0, 420, 0)
	attacker.target = target_ship
	attacker.fired.connect(_track_fired)
	world.add_child(attacker)
	await create_timer(0.1).timeout
	assert(fired_count == 1, "hostile ship can fire on an active ship target outside origin safe zone")
	assert(last_fire_direction.dot((target_ship.global_position - last_fire_origin).normalized()) > 0.999, "ship fire aims toward target")
	attacker._attack_cooldown = 0.0
	target_ship.active = false
	await create_timer(0.1).timeout
	assert(fired_count == 1, "inactive target is not attacked")
	target_ship.active = true
	target_ship.destroyed.connect(_track_destroyed)
	target_ship.take_damage(1000.0)
	attacker._attack_cooldown = 0.0
	await create_timer(0.1).timeout
	assert(destroyed_count == 3 and fired_count == 1, "destroyed target is not attacked")
	var hull_target := CoastingHull.new()
	hull_target.position = Vector3(1000, 330, 0)
	world.add_child(hull_target)
	hull_target.configure([Vector3i(-2, 0, 0), Vector3i(2, 0, 0)])
	var hull_attacker := ShipActor.new()
	hull_attacker.position = Vector3(1000, 420, 0)
	hull_attacker.target = hull_target
	hull_attacker.fired.connect(_track_fired)
	world.add_child(hull_attacker)
	await create_timer(0.1).timeout
	assert(fired_count == 2, "hostile ship fires on an active CoastingHull target")
	assert(last_fire_direction.dot((hull_target.aim_point() - last_fire_origin).normalized()) > 0.9999, "enemy aims at occupied module rather than empty hull center")
	assert(hull_target.aim_point().distance_to(hull_target.global_position) > 5.0)
	hull_target.queue_free()
	hull_attacker._attack_cooldown = 0.0
	await create_timer(0.1).timeout
	assert(fired_count == 2, "queued-for-deletion CoastingHull target is not attacked")
	var pilot_target := Pilot.new()
	pilot_target.position = Vector3(500, 300, 0)
	world.add_child(pilot_target)
	pilot_target.set_physics_process(false)
	pilot_target.flying = true
	var pilot_attacker := ShipActor.new()
	pilot_attacker.position = Vector3(500, 390, 0)
	pilot_attacker.target = pilot_target
	pilot_attacker.fired.connect(_track_fired)
	world.add_child(pilot_attacker)
	await create_timer(0.1).timeout
	assert(fired_count == 3, "flying Pilot target behavior remains active")
	var damage_probe := ShipActor.new()
	damage_probe.hp = 50.0
	damage_probe.shields = 20.0
	damage_probe.damaged.connect(_track_damaged)
	world.add_child(damage_probe)
	await process_frame
	damage_probe.take_damage(NAN)
	damage_probe.take_damage(INF)
	damage_probe.take_damage(-1.0)
	assert(damage_probe.hp == 50.0 and damage_probe.shields == 20.0 and damaged_count == 0, "non-finite and non-positive damage is ignored")
	damage_probe.set_patrol_center(Vector3(800, 400, -200))
	assert(damage_probe._home == Vector3(800, 400, -200), "patrol center can be configured")
	print("ACTOR_TEST_OK: ship targeting, safe aim, finite damage and one-shot destruction")
	quit()
