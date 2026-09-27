extends SceneTree

const PilotScript = preload("res://scripts/pilot.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "move_up", "boost", "fire"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.position = Vector3(-0.5, 0, 0)
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 100, 100)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var pilot := PilotScript.new()
	root.add_child(pilot)
	pilot.position = Vector3(0.9, 0, 0)
	await process_frame
	pilot.set_walk_up(Vector3.RIGHT)
	await create_timer(0.35).timeout
	assert(pilot.is_on_floor(), "wall plane supports pilot with rightward gravity")
	assert(pilot.up_direction.is_equal_approx(Vector3.RIGHT), "walk up is normalized into character up direction")
	assert(pilot.global_basis.y.is_equal_approx(Vector3.RIGHT), "body local up aligns to wall normal")
	var start := pilot.global_position
	Input.action_press("move_forward")
	await create_timer(0.4).timeout
	Input.action_release("move_forward")
	var moved := pilot.global_position - start
	assert(absf(moved.x) < 0.15 and moved.length() > 0.5, "forward walking remains tangent to the wall")
	var jump_start := pilot.global_position
	Input.action_press("move_up")
	await physics_frame
	Input.action_release("move_up")
	await create_timer(0.15).timeout
	assert(pilot.global_position.x > jump_start.x + 0.3, "jump impulse follows walk up")
	var prior_up := pilot.up_direction
	pilot.set_walk_up(Vector3.ZERO)
	pilot.set_walk_up(Vector3(INF, 0, 0))
	assert(pilot.up_direction == prior_up, "zero and nonfinite walk-up vectors are ignored")
	pilot.set_flight(true)
	assert(pilot.up_direction == Vector3.UP and pilot.global_basis.y.is_equal_approx(Vector3.UP), "flight restores global up while retaining heading")
	print("PILOT_GRAVITY_OK: tangent wall walking, up-axis jump, invalid-up rejection, flight reset")
	quit()
