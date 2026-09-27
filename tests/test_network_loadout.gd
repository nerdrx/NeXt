extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const ShipLayoutScript = preload("res://scripts/ship_layout.gd")
const NetworkSessionScript = preload("res://scripts/network_session.gd")
const TEST_PORT: int = 27861

var host: NetworkSession
var guest: NetworkSession
var failed: bool = false
var guest_hits: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _session(scope_name: String, modules: Array, layout: Dictionary) -> NetworkSession:
	var scope := Node.new()
	scope.name = scope_name
	root.add_child(scope)
	set_multiplayer(MultiplayerAPI.create_default_interface(), scope.get_path())
	var session: NetworkSession = NetworkSessionScript.new()
	session.name = "Session"
	session.world_id = "0123456789abcdef0123456789abcdef"
	session.ship_modules = modules.duplicate(true)
	session.ship_layout = layout.duplicate(true)
	scope.add_child(session)
	return session


func _run() -> void:
	var base_state := GameStateScript.new()
	base_state.credits = 10000
	var base_modules: Array = base_state.ship_modules.duplicate(true)
	var base_layout: Dictionary = base_state.ship_layout.duplicate(true)
	var changed_state := GameStateScript.new()
	changed_state.credits = 10000
	changed_state.ship_modules = base_modules.duplicate(true)
	changed_state.ship_layout = base_layout.duplicate(true)
	if not _check(ShipLayoutScript.set_panel(changed_state, Vector3i.ZERO, "-z", "armored").is_empty(), "create valid room/panel layout change"):
		quit(1)
		return
	var changed_layout: Dictionary = changed_state.ship_layout.duplicate(true)
	var changed_modules: Array = base_modules.duplicate(true)
	changed_modules.append({"kind": "radiator", "x": 0, "y": 1, "z": 0})

	host = _session("Host", base_modules, base_layout)
	guest = _session("Guest", base_modules, base_layout)
	guest.pvp_damage_received.connect(func(_attacker: int, _damage: float) -> void: guest_hits += 1)
	if not _check(host.host(TEST_PORT).is_empty(), "host setup") or not _check(guest.join("127.0.0.1", TEST_PORT).is_empty(), "guest setup"):
		await _cleanup(1)
		return
	if not await _wait_until(func() -> bool: return guest.connected and _guest_peer_id() > 1, 3.0):
		_check(false, "loopback guest admitted")
		await _cleanup(1)
		return
	var guest_id: int = _guest_peer_id()
	if not _check(_same_design(host.presence[1], base_modules, base_layout) and _same_design(host.presence[guest_id], base_modules, base_layout), "both profiles begin with negotiated design"):
		await _cleanup(1)
		return

	# Normal pose relay works while the design matches the join-time loadout.
	host.publish_pose(Vector3.ZERO, Vector3.ZERO, {}, true)
	guest.publish_pose(Vector3(0, 0, -100), Vector3.ZERO, {}, true)
	await create_timer(0.15).timeout
	if not _check(host.presence[guest_id].position == Vector3(0, 0, -100), "unchanged guest design pose relays"):
		await _cleanup(1)
		return
	# Module array ordering has no design meaning, so harmless serialization order changes remain valid.
	var reordered_modules: Array = base_modules.duplicate(true)
	reordered_modules.reverse()
	guest.ship_modules = reordered_modules
	guest.publish_pose(Vector3(0, 0, -110), Vector3.ZERO, {}, true)
	await create_timer(0.15).timeout
	if not _check(host.presence[guest_id].position == Vector3(0, 0, -110) and _same_design(host.presence[guest_id], base_modules, base_layout), "module ordering changes preserve the same design"):
		await _cleanup(1)
		return
	guest.ship_modules = base_modules.duplicate(true)
	guest.publish_pose(Vector3(0, 0, -100), Vector3.ZERO, {}, true)
	await create_timer(0.15).timeout
	var locked_pose: Vector3 = host.presence[guest_id].position
	var last_fresh: int = int(host._last_remote_pose_msec.get(guest_id, -1))

	# Modules-only mutations fail locally and through a forged RPC.
	guest.ship_modules = changed_modules.duplicate(true)
	guest.ship_layout = base_layout.duplicate(true)
	guest.publish_pose(Vector3(25, 0, -100), Vector3.ZERO, {}, true)
	await create_timer(0.15).timeout
	if not _check(host.presence[guest_id].position == locked_pose and _same_design(host.presence[guest_id], base_modules, base_layout), "guest module-only mutation is rejected"):
		await _cleanup(1)
		return
	if not _check(int(host._last_remote_pose_msec.get(guest_id, -1)) == last_fresh, "rejected modules do not refresh host pose"):
		await _cleanup(1)
		return
	guest.ship_modules = base_modules.duplicate(true)
	var forged_position := Vector3(60, 0, -100)
	var forged_address := SectorPosition.new(Vector3i.ZERO, forged_position).to_save()
	guest._rpc_publish_pose.rpc_id(1, forged_position, Vector3.ZERO, changed_modules, base_layout, forged_address, true, guest._pvp_epoch)
	await create_timer(0.15).timeout
	if not _check(host.presence[guest_id].position == locked_pose and _same_design(host.presence[guest_id], base_modules, base_layout), "forged module-only pose RPC is rejected"):
		await _cleanup(1)
		return
	if not _check(int(host._last_remote_pose_msec.get(guest_id, -1)) == last_fresh, "forged modules do not refresh host pose"):
		await _cleanup(1)
		return

	# Layout-only mutations fail locally and through a forged RPC.
	guest.ship_layout = changed_layout.duplicate(true)
	guest.publish_pose(Vector3(75, 0, -100), Vector3.ZERO, {}, true)
	await create_timer(0.15).timeout
	if not _check(host.presence[guest_id].position == locked_pose and _same_design(host.presence[guest_id], base_modules, base_layout), "guest layout-only mutation is rejected"):
		await _cleanup(1)
		return
	if not _check(int(host._last_remote_pose_msec.get(guest_id, -1)) == last_fresh, "rejected layout does not refresh host pose"):
		await _cleanup(1)
		return
	guest.ship_layout = base_layout.duplicate(true)
	forged_position = Vector3(90, 0, -100)
	forged_address = SectorPosition.new(Vector3i.ZERO, forged_position).to_save()
	guest._rpc_publish_pose.rpc_id(1, forged_position, Vector3.ZERO, base_modules, changed_layout, forged_address, true, guest._pvp_epoch)
	await create_timer(0.15).timeout
	if not _check(host.presence[guest_id].position == locked_pose and _same_design(host.presence[guest_id], base_modules, base_layout), "forged layout-only pose RPC is rejected"):
		await _cleanup(1)
		return
	if not _check(int(host._last_remote_pose_msec.get(guest_id, -1)) == last_fresh, "forged layout does not refresh host pose"):
		await _cleanup(1)
		return

	# A normal pose with the locked design is accepted after the attempts above.
	guest.ship_modules = base_modules.duplicate(true)
	guest.ship_layout = base_layout.duplicate(true)
	guest.publish_pose(Vector3(0, 0, -100), Vector3.ZERO, {}, true)
	await create_timer(0.15).timeout
	if not _check(host.presence[guest_id].position == Vector3(0, 0, -100) and _same_design(host.presence[guest_id], base_modules, base_layout), "unchanged design continues pose relay"):
		await _cleanup(1)
		return

	# Host-local refits are also frozen for the hosted session.
	var host_pose: Vector3 = host.presence[1].position
	host.ship_modules = changed_modules.duplicate(true)
	host.ship_layout = changed_layout.duplicate(true)
	host.publish_pose(Vector3(35, 0, 0), Vector3.ZERO, {}, true)
	await create_timer(0.1).timeout
	if not _check(host.presence[1].position == host_pose and _same_design(host.presence[1], base_modules, base_layout), "host loadout mutation is rejected"):
		await _cleanup(1)
		return
	host.ship_modules = base_modules.duplicate(true)
	host.ship_layout = base_layout.duplicate(true)

	# Frozen designs must not disable consensual combat.
	host.pvp_occlusion_check = func(_a: int, _b: int, _direction: Vector3, _range: float) -> bool: return true
	host.publish_pose(Vector3.ZERO, Vector3.ZERO, {}, true)
	guest.publish_pose(Vector3(0, 0, -100), Vector3.ZERO, {}, true)
	await create_timer(0.15).timeout
	host.set_pvp_allowed(true)
	guest.set_pvp_allowed(true)
	await create_timer(0.15).timeout
	host.request_pvp_shot(Vector3(0, -1.55, -100).normalized())
	await create_timer(0.15).timeout
	if not _check(guest_hits == 1, "bilateral PvP consent still works with locked designs"):
		await _cleanup(1)
		return

	# Reconnect negotiates the new design as a fresh session snapshot.
	guest.leave()
	if not await _wait_until(func() -> bool: return not host.presence.has(guest_id), 2.0):
		_check(false, "old guest profile removed")
		await _cleanup(1)
		return
	guest.ship_modules = changed_modules.duplicate(true)
	guest.ship_layout = changed_layout.duplicate(true)
	if not _check(guest.join("127.0.0.1", TEST_PORT).is_empty(), "guest reconnect"):
		await _cleanup(1)
		return
	if not await _wait_until(func() -> bool: return guest.connected and _guest_peer_id() > 1 and _same_design(host.presence.get(_guest_peer_id(), {}), changed_modules, changed_layout), 3.0):
		_check(false, "reconnect negotiates changed design")
		await _cleanup(1)
		return
	if not failed:
		print("NETWORK_LOADOUT_OK: session design lock, forged pose rejection, pose relay, PvP consent and reconnect renegotiation")
	await _cleanup(1 if failed else 0)


func _same_design(profile: Dictionary, modules: Array, layout: Dictionary) -> bool:
	if profile.get("ship_layout", {}) != layout: return false
	var expected := _module_map(modules)
	return expected.size() == _module_map(profile.get("ship_modules", [])).size() and expected == _module_map(profile.get("ship_modules", []))


func _module_map(modules: Array) -> Dictionary:
	var result: Dictionary = {}
	for module: Dictionary in modules:
		result[Vector3i(int(module.x), int(module.y), int(module.z))] = str(module.kind)
	return result


func _guest_peer_id() -> int:
	if guest == null or not guest.multiplayer.has_multiplayer_peer(): return -1
	var id: int = guest.multiplayer.get_unique_id()
	return id if id > 1 else -1


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < timeout_seconds:
		if condition.call(): return true
		await create_timer(0.01).timeout
		elapsed += 0.01
	return condition.call()


func _check(condition: bool, message: String) -> bool:
	if condition: return true
	failed = true
	push_error("NETWORK_LOADOUT_FAIL: " + message)
	return false


func _cleanup(exit_code: int) -> void:
	if guest != null: guest.leave()
	if host != null: host.leave()
	await create_timer(0.05).timeout
	quit(exit_code)
