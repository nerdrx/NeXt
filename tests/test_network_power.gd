extends SceneTree

var host: NetworkSession
var guest: NetworkSession
var host_hits := 0
var guest_hits := 0

func _initialize() -> void: _run.call_deferred()

func _session(scope_name: String) -> NetworkSession:
	var scope := Node.new()
	scope.name = scope_name
	root.add_child(scope)
	set_multiplayer(MultiplayerAPI.create_default_interface(), scope.get_path())
	var session := NetworkSession.new()
	session.name = "Session"
	scope.add_child(session)
	session.world_id = "0123456789abcdef0123456789abcdef"
	session.ship_modules = [{"kind": "core", "x": 0, "y": 0, "z": 0}, {"kind": "weapon", "x": 1, "y": 0, "z": 0}]
	return session

func _poses() -> void:
	for _step in 4:
		host.publish_pose(Vector3.ZERO, Vector3.ZERO, {}, true)
		guest.publish_pose(Vector3(0, 0, -100), Vector3.ZERO, {}, true)
		await create_timer(0.06).timeout

func _run() -> void:
	host = _session("PowerHost")
	guest = _session("PowerGuest")
	host.pvp_damage_received.connect(func(_id: int, _damage: float): host_hits += 1)
	guest.pvp_damage_received.connect(func(_id: int, _damage: float): guest_hits += 1)
	host.pvp_occlusion_check = func(_a: int, _b: int, _d: Vector3, _r: float) -> bool: return true
	assert(host.host(27870).is_empty())
	assert(guest.join("127.0.0.1", 27870).is_empty())
	for _step in 200:
		if guest.connected: break
		await create_timer(0.01).timeout
	assert(guest.connected)
	var guest_id := guest.multiplayer.get_unique_id()
	host.set_pvp_allowed(true)
	guest.set_pvp_allowed(true)
	await _poses()
	guest.set_systems_online(false)
	await _poses()
	assert(not host.presence[guest_id].systems_online and not guest.presence[guest_id].systems_online,
		"reliable power choice reaches host and guest")
	guest.request_pvp_shot(Vector3(0, -1.55, 100).normalized())
	# Bypass the local convenience guard: host must still reject an offline attacker.
	guest._rpc_pvp_shot.rpc_id(1, Vector3(0, -1.55, 100).normalized(), host._pvp_epoch)
	await create_timer(0.1).timeout
	assert(host_hits == 0, "offline attacker cannot damage through raw shot RPC")
	host.request_pvp_shot(Vector3(0, -1.55, -100).normalized())
	await create_timer(0.1).timeout
	assert(guest_hits == 1, "offline consenting target remains vulnerable")
	var stale: Dictionary = host.presence[guest_id].duplicate(true)
	stale.systems_online = true
	host._rpc_presence.rpc_id(guest_id, guest_id, stale, host._pvp_epoch)
	await create_timer(0.1).timeout
	assert(not guest.presence[guest_id].systems_online, "stale unreliable pose cannot overwrite reliable power")
	# A delayed reliable echo must not replace the owner's newer local setting.
	host._rpc_systems_online.rpc_id(guest_id, guest_id, true, host._pvp_epoch)
	await create_timer(0.1).timeout
	assert(not guest._local_systems_online and not guest.presence[guest_id].systems_online)
	var changes := [0]
	var count_change := func(): changes[0] += 1
	guest.peers_changed.connect(count_change)
	guest.set_systems_online(false)
	assert(changes[0] == 0, "unchanged physics-tick updates are silent")
	guest.peers_changed.disconnect(count_change)
	# A client cannot change another player's power, or apply an old epoch.
	guest._rpc_systems_online.rpc_id(1, 1, false, host._pvp_epoch)
	guest._rpc_systems_online.rpc_id(1, guest_id, true, host._pvp_epoch - 1)
	await create_timer(0.1).timeout
	assert(host.presence[1].systems_online and not host.presence[guest_id].systems_online)
	# Reliable power can precede the first unreliable pose of a new peer.
	var arriving_id := 12345
	host._rpc_systems_online.rpc_id(guest_id, arriving_id, false, host._pvp_epoch)
	await create_timer(0.1).timeout
	assert(guest._pending_systems_online.has(arriving_id))
	host._rpc_presence.rpc_id(guest_id, arriving_id, stale, host._pvp_epoch)
	await create_timer(0.1).timeout
	assert(not guest.presence[arriving_id].systems_online)
	assert(not guest._pending_systems_online.has(arriving_id))
	host._rpc_peer_left.rpc_id(guest_id, arriving_id)
	await create_timer(0.1).timeout
	assert(not guest.presence.has(arriving_id))
	guest.set_systems_online(true)
	await _poses()
	guest.request_pvp_shot(Vector3(0, -1.55, 100).normalized())
	await create_timer(0.1).timeout
	assert(host_hits == 1, "restart permits a valid consensual shot")
	var legacy: Dictionary = host.presence[guest_id].duplicate(true)
	legacy.erase("systems_online")
	assert(host._normalize_presence(legacy).ok and host._normalize_presence(legacy).profile.systems_online)
	legacy.systems_online = "false"
	assert(not host._normalize_presence(legacy).ok, "power presence field requires boolean")
	# Travel advances the host epoch before it receives the simultaneous toggle.
	assert(host.travel(18).is_empty())
	guest.set_systems_online(false)
	await create_timer(0.1).timeout
	assert(not host.presence[guest_id].systems_online and not guest.presence[guest_id].systems_online,
		"system transition retains power mode while clearing consent")
	assert(not host.presence[guest_id].pvp)
	guest.leave()
	await create_timer(0.1).timeout
	assert(guest.join("127.0.0.1", 27870).is_empty())
	for _step in 200:
		if guest.connected: break
		await create_timer(0.01).timeout
	assert(guest.connected)
	await _poses()
	guest_id = guest.multiplayer.get_unique_id()
	assert(not host.presence[guest_id].systems_online, "offline power choice survives reconnect")
	guest.leave()
	host.leave()
	print("NETWORK_POWER_OK: reliable state, offline shot rejection, vulnerable target, restart, stale pose and reconnect")
	quit()
