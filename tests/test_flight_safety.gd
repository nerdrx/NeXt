extends SceneTree

const PilotScript = preload("res://scripts/pilot.gd")

var blocked_count := 0
var arrived_count := 0
var impacts: Array[float] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "move_up", "move_down", "boost", "roll_left", "roll_right", "fire"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	_add_wall(Vector3(0, 1, -5), Vector3(10, 2, 0.5))
	var autopilot := _pilot(Vector3.ZERO)
	autopilot.set_flight(true)
	autopilot.autopilot_blocked.connect(func(): blocked_count += 1)
	autopilot.autopilot_arrived.connect(func(): arrived_count += 1)
	autopilot.autopilot_to(Vector3(0, 0, -100))
	await create_timer(0.25).timeout
	assert(not autopilot.autopilot_active and autopilot.velocity == Vector3.ZERO, "autopilot cancels and stops before a blocking wall")
	assert(blocked_count == 1 and arrived_count == 0, "blocked autopilot emits once and never reports arrival")

	_add_wall(Vector3(100, 1, 0), Vector3(0.5, 2, 10))
	var slow := _pilot(Vector3.ZERO)
	slow.position = Vector3(98.5, 0, 0)
	slow.set_flight(true)
	slow._flight_velocity = Vector3(10, 0, 0)
	slow.flight_impact.connect(func(value: float): impacts.append(value))
	await create_timer(0.15).timeout
	assert(impacts.is_empty(), "slow flight bump does not produce damage impact")

	_add_wall(Vector3(200, 1, 0), Vector3(0.5, 2, 10))
	var fast := _pilot(Vector3.ZERO)
	fast.position = Vector3(198.5, 0, 0)
	fast.set_flight(true)
	fast._flight_velocity = Vector3(100, 0, 0)
	fast.flight_impact.connect(func(value: float): impacts.append(value))
	await create_timer(0.15).timeout
	assert(impacts.size() == 1 and impacts[0] > 25.0, "high-speed flight collision emits incoming normal speed")
	fast.teleport(Vector3(198.5, 0, 0))
	fast._flight_velocity = Vector3(100, 0, 0)
	await create_timer(0.15).timeout
	assert(impacts.size() == 1, "rapid repeat contact respects impact cooldown")

	_add_wall(Vector3(300, 1, 0), Vector3(0.5, 2, 10))
	var tangent := _pilot(Vector3.ZERO)
	tangent.position = Vector3(298.5, 0, 0)
	tangent.set_flight(true)
	tangent._flight_velocity = Vector3(20, 0, -140)
	tangent.flight_impact.connect(func(value: float): impacts.append(value))
	await create_timer(0.15).timeout
	assert(impacts.size() == 1, "fast tangential sliding is not reported as a high-speed impact")

	var walker := _pilot(Vector3(400, 0, 0))
	walker.flight_impact.connect(func(value: float): impacts.append(value))
	_add_wall(Vector3(400, 1, -2), Vector3(10, 2, 0.5))
	Input.action_press("move_forward")
	await create_timer(0.5).timeout
	Input.action_release("move_forward")
	assert(impacts.size() == 1, "walking collision never emits flight damage")
	print("FLIGHT_SAFETY_OK: autopilot sweep, impact threshold and normal-speed filtering")
	quit()


func _pilot(at: Vector3) -> Pilot:
	var pilot: Pilot = PilotScript.new()
	root.add_child(pilot)
	pilot.position = at
	return pilot


func _add_wall(at: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
