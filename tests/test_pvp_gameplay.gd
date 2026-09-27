extends SceneTree

var game: Node
var guest: NetworkSession
var guest_scope: Node
var failed := false
var home := Vector3(1500, 1500, 0)
var visitor := Vector3(1500, 1500, -100)
var aim := Vector3(0, -1.55, 100).normalized()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	set_multiplayer(MultiplayerAPI.create_default_interface(), game.get_path())
	await process_frame
	game.set_process(false)
	game.close_menu()
	game._clear_actors()
	game.pilot.set_flight(true)
	game.pilot.teleport(home)
	game.pilot.set_physics_process(false)
	game.session.world_id = "0123456789abcdef0123456789abcdef"
	guest_scope = Node.new()
	guest_scope.name = "Guest"
	root.add_child(guest_scope)
	set_multiplayer(MultiplayerAPI.create_default_interface(), guest_scope.get_path())
	guest = NetworkSession.new()
	guest.name = "NetworkSession"
	guest_scope.add_child(guest)
	var state := GameState.new()
	guest.ship_modules = state.ship_modules.duplicate(true)
	guest.ship_layout = state.ship_layout.duplicate(true)
	guest.world_id = game.session.world_id
	_check(game.session.host(27861).is_empty(), "host main scene")
	_check(guest.join("127.0.0.1", 27861).is_empty(), "join actual ENet")
	for i in 200:
		if guest.connected: break
		await create_timer(0.01).timeout
	_check(guest.connected, "guest handshake")
	if failed: await _finish(); return
	var id := guest.multiplayer.get_unique_id()
	game.session.set_pvp_allowed(true)
	guest.set_pvp_allowed(true)
	await _poses()
	game._sync_visitors()
	game._update_remote_positions()
	await physics_frame
	await physics_frame
	var visual: ShipVisual = game.remote_ships[id]
	var body: StaticBody3D = visual.get_meta("hit_body")
	_check(visual.position.is_equal_approx(visitor) and body.collision_layer == 2, "visitor hit hull follows received position")
	_check(body.get_child_count() == guest.ship_modules.size(), "one collision box per actual module")
	var low := Vector3(INF, INF, INF)
	var high := -low
	for module: Dictionary in guest.ship_modules:
		var cell := Vector3(module.x, module.y, module.z)
		low = low.min(cell)
		high = high.max(cell)
	var center := (low + high) * ShipVisual.CELL_SIZE * 0.5
	for i in guest.ship_modules.size():
		var module: Dictionary = guest.ship_modules[i]
		var shape: CollisionShape3D = body.get_child(i)
		_check(shape.position.is_equal_approx(Vector3(module.x, module.y, module.z) * ShipVisual.CELL_SIZE - center), "centered module collider")
		_check(shape.shape.size.is_equal_approx(Vector3.ONE * ShipVisual.CELL_SIZE), "module collision dimensions")
	var ray_start := visitor + Vector3.UP * 1.55
	var raw_query := PhysicsRayQueryParameters3D.create(ray_start, ray_start + aim * 105, 7)
	var raw_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(raw_query)
	_check(not raw_hit.is_empty() and raw_hit.collider == game.pilot, "unfiltered ray really intersects target pilot collider")
	_check(game._pvp_clear_shot(id, 1, aim, 105), "shooter and target colliders excluded")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 20, 2)
	collision.shape = box
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = home + Vector3(0, 0, -50)
	await physics_frame
	await physics_frame
	_check(not game._pvp_clear_shot(id, 1, aim, 105), "physical wall occludes remote weapon")
	game.state.shield = 5.0
	game.state.hull = 100.0
	await _poses()
	guest.request_pvp_shot(aim)
	await create_timer(0.2).timeout
	_check(game.state.shield == 5.0 and game.state.hull == 100.0, "wall blocks damage through real network request")
	wall.queue_free()
	await physics_frame
	await physics_frame
	await _poses()
	var damage: float = state.ship_stats().damage
	guest.request_pvp_shot(aim)
	await create_timer(0.2).timeout
	_check(game.state.shield == 0.0 and is_equal_approx(game.state.hull, 105.0 - damage), "accepted guest shot consumes shield then hull")
	_check(game.shield_delay == 6.0 and game.hud.flash > 0, "main damage feedback")
	var hull: float = game.state.hull
	game.session.set_pvp_allowed(false)
	await _poses()
	guest.request_pvp_shot(aim)
	await create_timer(0.2).timeout
	_check(game.state.hull == hull, "local consent revoke prevents later damage")
	guest.publish_pose(visitor, Vector3(0, PI, 0), SectorPosition.new(Vector3i(10, 0, 0)).to_save(), true)
	await create_timer(0.1).timeout
	game._update_remote_positions()
	_check(not visual.visible and body.collision_layer == 0, "distant visitor hull cannot remain as invisible obstacle")
	await _poses()
	game._update_remote_positions()
	_check(visual.visible and body.collision_layer == 2 and visual.position.is_equal_approx(visitor), "returning visitor restores collider")
	if DisplayServer.get_name() != "headless":
		game.pilot.reset_view()
		game.hud.message_time = 0
		await create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/pvp-protected.png")
		game.session.set_pvp_allowed(true)
		await _poses()
		await create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/pvp-agreed.png")
	await _finish()

func _poses() -> void:
	await create_timer(0.06).timeout
	game.session.publish_pose(home, Vector3.ZERO, {}, true)
	guest.publish_pose(visitor, Vector3(0, PI, 0), {}, true)
	await create_timer(0.06).timeout

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("PVP_GAMEPLAY_FAIL: " + message)

func _finish() -> void:
	guest.leave()
	game.session.leave()
	guest_scope.queue_free()
	game.queue_free()
	await process_frame
	if not failed: print("PVP_GAMEPLAY_OK: actual ENet guest fire, physical occlusion, modular colliders, shield/hull damage, revocation and distant collision culling")
	quit(1 if failed else 0)
