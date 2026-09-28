extends SceneTree

class PathProbe extends Node3D:
	var requested := Vector3.INF
	func navigation_path(_from: Vector3, destination: Vector3) -> PackedVector3Array:
		requested = destination
		return PackedVector3Array()

var shots: int = 0

func _initialize() -> void: _run.call_deferred()

func _body(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	return body

func _run() -> void:
	var floor_body := _body(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	var target := _body(Vector3(20, 0, 0), Vector3(1, 3, 1))
	var probe := PathProbe.new()
	root.add_child(probe)
	var guard := GroundActor.new()
	guard.speed = 0
	guard.patrol_radius = 0
	guard.target = target
	guard.navigation_source = probe
	root.add_child(guard)
	guard.set_physics_process(false)
	guard.fired.connect(func(_actor, _origin, _direction): shots += 1)
	await physics_frame
	await physics_frame
	guard._physics_process(0.1)
	assert(shots == 1 and guard.contact_remaining == GroundActor.SEARCH_SECONDS)
	assert(guard.last_seen_position == Vector3(20, 0, 0) and probe.requested == guard.last_seen_position)
	var wall := _body(Vector3(10, 4, 0), Vector3(1, 8, 80))
	target.position = Vector3(20, 0, 15)
	await physics_frame
	await physics_frame
	guard._navigation_timer = 0
	guard._physics_process(0.1)
	assert(shots == 1 and guard.contact_remaining < GroundActor.SEARCH_SECONDS)
	assert(guard.last_seen_position == Vector3(20, 0, 0) and probe.requested == guard.last_seen_position, "hidden movement cannot update pursuit destination")
	for step in range(61): guard._physics_process(0.1)
	assert(guard.contact_remaining == 0 and shots == 1, "cover breaks contact and stops fire")
	guard._navigation_timer = 0
	guard._physics_process(0.1)
	assert(probe.requested.is_zero_approx(), "expired search returns to patrol home")
	wall.queue_free()
	await physics_frame
	await physics_frame
	guard._physics_process(0.1)
	assert(guard.contact_remaining == GroundActor.SEARCH_SECONDS and guard.last_seen_position == target.position and shots == 2, "clear sight reacquires the actual target")
	var other := _body(Vector3(90, 0, 0), Vector3(1, 3, 1))
	guard.target = other
	guard._physics_process(0.1)
	assert(guard.contact_remaining == 0 and shots == 2, "switching target cannot inherit old contact; distant target remains unseen")
	guard.target = target
	guard._physics_process(0.1)
	assert(guard.contact_remaining > 0)
	guard.hostile = false
	guard.follow_when_friendly = false
	guard._physics_process(0.1)
	assert(guard.contact_remaining == 0, "peaceful actor clears combat tracking")
	guard.queue_free()
	probe.queue_free()
	target.queue_free()
	other.queue_free()
	floor_body.queue_free()
	await process_frame
	print("GROUND_CONTACT_OK: visible acquisition, last-seen pursuit, cover, expiry, reacquisition, target isolation and peace")
	quit()
