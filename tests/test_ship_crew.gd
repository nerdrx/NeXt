extends SceneTree

var destroyed_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _track_destroyed(_actor: GroundActor) -> void:
	destroyed_count += 1


func _run() -> void:
	var ship := Node3D.new()
	root.add_child(ship)
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 0.2, 8)
	floor_shape.shape = box
	floor_shape.position.y = -0.1
	floor.add_child(floor_shape)
	ship.add_child(floor)
	var crew := ShipCrew.new()
	crew.actor_id = "crew-test-17"
	crew.display_name = "Mira Vale"
	crew.role = "engineer"
	ship.add_child(crew)
	await create_timer(0.3).timeout
	assert(crew.actor_id == "crew-test-17" and crew.display_name == "Mira Vale" and crew.role == "engineer", "configured crew identity survives tree entry")
	assert(crew.faction == "crew" and not crew.hostile and crew.hold_position, "ship crew is stationary and friendly")
	assert(crew.is_on_floor(), "crew stands on the ship deck")
	assert(crew.up_direction.is_equal_approx(ship.global_basis.y.normalized()), "crew gravity follows deck up")
	crew.update_duty("repairing engines")
	assert(crew.get_node("DutyLabel").text == "Mira Vale\nEngineer / repairing engines", "duty updates the name and role label")
	var local_position := crew.position
	crew.velocity = Vector3(5, 0, 0)
	ship.position = Vector3(14, -3, 7)
	ship.rotation = Vector3(0.35, 0.8, PI * 0.5)
	ship.force_update_transform()
	floor.force_update_transform()
	await create_timer(0.35).timeout
	assert(crew.position.distance_to(local_position) < 0.03, "crew holds its local deck position as the ship translates and turns")
	assert(crew.is_on_floor(), "crew remains supported on a rotated deck")
	assert(crew.up_direction.is_equal_approx(ship.global_basis.y.normalized()), "crew gravity updates after the ship turns")
	assert(crew.velocity.cross(crew.up_direction).length() < 0.01, "crew velocity stays constrained to deck up")
	crew.destroyed.connect(_track_destroyed)
	crew.take_damage(1000.0)
	assert(destroyed_count == 1 and crew.hp == 0.0 and not crew.active, "crew casualty uses inherited damage handling")
	print("SHIP_CREW_OK: identity, duty label, rotated-deck support and casualty")
	quit()
