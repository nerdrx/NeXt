extends SceneTree

var destroyed_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _track_destroyed(_actor: Node) -> void:
	destroyed_count += 1


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
	print("ACTOR_TEST_OK: ship and ground actor instantiate and destroy once")
	quit()
