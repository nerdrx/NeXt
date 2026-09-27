extends SceneTree

var fired_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _on_fired(_actor: GroundActor, _origin: Vector3, _direction: Vector3) -> void:
	fired_count += 1


func _target_at(parent: Node3D, position: Vector3) -> StaticBody3D:
	var target := StaticBody3D.new()
	target.position = position
	target.collision_layer = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	shape.position.y = 0.9
	target.add_child(shape)
	parent.add_child(target)
	return target


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var leash_guard := GroundActor.new()
	leash_guard.pursuit_radius = 35.0
	leash_guard.patrol_radius = 0.0
	leash_guard.target = _target_at(world, Vector3(36, 0, 0))
	leash_guard.fired.connect(_on_fired)
	world.add_child(leash_guard)
	await process_frame
	leash_guard.set_physics_process(false)
	leash_guard.position = Vector3(20, 0, 0)
	var guard_home := Vector3.ZERO
	leash_guard.set_physics_process(true)
	await create_timer(0.3).timeout
	var guard_position := Vector2(leash_guard.global_position.x, leash_guard.global_position.z)
	assert(guard_position.distance_to(Vector2(guard_home.x, guard_home.z)) < 20.0, "out-of-leash guard returns toward home")
	assert(fired_count == 0, "out-of-leash guard does not fire")

	var post_guard := GroundActor.new()
	post_guard.position = Vector3(80, 0, 0)
	post_guard.hold_position = true
	post_guard.target = _target_at(world, Vector3(85, 0, 0))
	post_guard.fired.connect(_on_fired)
	world.add_child(post_guard)
	var post_home := post_guard.global_position
	await create_timer(0.3).timeout
	assert(Vector2(post_guard.global_position.x, post_guard.global_position.z).distance_to(Vector2(post_home.x, post_home.z)) < 0.01, "hold-position actor stays at post")
	assert(post_guard.global_position.y < post_home.y, "hold-position actor still applies gravity")
	assert(fired_count == 1, "hold-position hostile can fire from post")
	post_guard.take_damage(10.0)
	assert(post_guard.hp == 90.0, "hold-position actor still takes damage")

	var clerk := GroundActor.new()
	clerk.hostile = false
	clerk.follow_when_friendly = false
	clerk.patrol_radius = 0.0
	clerk.target = _target_at(world, Vector3(120, 0, 0))
	world.add_child(clerk)
	var clerk_home := clerk.global_position
	await create_timer(0.3).timeout
	assert(Vector2(clerk.global_position.x, clerk.global_position.z).distance_to(Vector2(clerk_home.x, clerk_home.z)) < 0.01, "friendly actor without follow stays within zero patrol radius")
	print("GROUND_ACTOR_BEHAVIOR_TEST_OK: hold, follow, patrol radius and pursuit leash")
	quit()
