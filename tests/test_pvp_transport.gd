extends SceneTree

var host: NetworkSession
var guest: NetworkSession
var host_hits: int = 0
var guest_hits: int = 0
var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

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

func _run() -> void:
	if "pvp-adversarial" in OS.get_cmdline_user_args():
		await _adversarial_rpc()
		return
	# Capture expected engine security errors separately; never hide unrelated failures.
	var captured: Array = []
	var child_exit := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/test_pvp_transport.gd", "--", "pvp-adversarial"], captured, true)
	var output := "\n".join(captured)
	_check(child_exit == 0 and "PVP_AUTHORITY_REJECTION_OK" in output, "adversarial child completed")
	_check(output.count("is not allowed on node") == 2, "engine rejected both forged damage RPCs")
	_check(output.count("ERROR:") == 2 and not "SCRIPT ERROR" in output, "only expected authority errors captured")
	if failed:
		printerr(output)
		quit(1)
		return
	host = _session("Host")
	guest = _session("Guest")
	host.pvp_damage_received.connect(func(_id: int, _damage: float): host_hits += 1)
	guest.pvp_damage_received.connect(func(_id: int, _damage: float): guest_hits += 1)
	_check(host.host(27859).is_empty(), "host setup")
	_check(guest.join("127.0.0.1", 27859).is_empty(), "guest setup")
	for i in 200:
		if guest.connected: break
		await create_timer(0.01).timeout
	_check(guest.connected, "loopback join")
	if failed: quit(1); return
	var guest_id := guest.multiplayer.get_unique_id()
	var legacy: Dictionary = host.presence[1].duplicate(true)
	legacy.erase("pvp"); legacy.erase("flying")
	_check(host._normalize_presence(legacy).ok, "legacy presence defaults")
	legacy.pvp = 1
	_check(not host._normalize_presence(legacy).ok, "typed consent")
	await _poses()
	host.request_pvp_shot(Vector3(0, -1.55, -100).normalized())
	await create_timer(0.05).timeout
	_check(guest_hits == 0, "default safe")
	host.set_pvp_allowed(true)
	await _poses()
	host.request_pvp_shot(Vector3(0, -1.55, -100).normalized())
	await create_timer(0.2).timeout
	_check(guest_hits == 0, "bilateral consent required")
	guest.set_pvp_allowed(true)
	await _poses()
	host.request_pvp_shot(Vector3(0, -1.55, -100).normalized())
	await create_timer(0.2).timeout
	_check(guest_hits == 0, "missing occlusion callback fails closed")
	host.pvp_occlusion_check = func(_a: int, _b: int, _d: Vector3, _r: float) -> bool: return true
	await _poses()
	host.pvp_occlusion_check = func(_a: int, _b: int, _d: Vector3, _r: float) -> bool: return false
	host.request_pvp_shot(Vector3(0, -1.55, -100).normalized())
	await create_timer(0.2).timeout
	_check(guest_hits == 0, "physical occlusion blocks hit")
	host.pvp_occlusion_check = func(_a: int, _b: int, _d: Vector3, _r: float) -> bool: return true
	await _poses()
	host.request_pvp_shot(Vector3(0, -1.55, -100).normalized())
	host.request_pvp_shot(Vector3(0, -1.55, -100).normalized())
	await create_timer(0.1).timeout
	_check(guest_hits == 1 and host_hits == 0, "target-only delivery and cooldown")
	await create_timer(0.12).timeout
	await _poses()
	host.request_pvp_shot(Vector3.RIGHT)
	await create_timer(0.2).timeout
	_check(guest_hits == 1, "off-axis miss")
	await _poses(false)
	host.request_pvp_shot(Vector3(0, -1.55, -100).normalized())
	await create_timer(0.2).timeout
	_check(guest_hits == 1, "grounded target safe")
	await _poses()
	await create_timer(1.1).timeout
	host.request_pvp_shot(Vector3(0, -1.55, -100).normalized())
	await create_timer(0.05).timeout
	_check(guest_hits == 1, "stale poses safe")
	await _poses()
	guest.set_pvp_allowed(false)
	# A delayed host-authorized hit must not override immediate local opt-out.
	host._rpc_pvp_damage.rpc_id(guest_id, 1, 25.0, host._pvp_epoch)
	await create_timer(0.1).timeout
	_check(guest_hits == 1 and not host.presence[guest_id].pvp, "reliable revoke and stale hit safe")
	guest.set_pvp_allowed(true)
	await _poses()
	guest.request_pvp_shot(Vector3(0, -1.55, 100).normalized())
	await create_timer(0.1).timeout
	_check(host_hits == 1, "client shot sender identified by host")
	for invalid_direction: Vector3 in [Vector3.ZERO, Vector3(NAN, 0, 0)]:
		await create_timer(0.2).timeout
		await _poses()
		guest.request_pvp_shot(invalid_direction)
		await create_timer(0.1).timeout
		_check(host_hits == 1, "invalid direction cannot damage")
	var old_epoch := host._pvp_epoch
	_check(host.travel(100).is_empty(), "travel")
	await create_timer(0.1).timeout
	_check(not host.presence[1].pvp and not guest.presence[guest_id].pvp, "travel clears consent")
	guest._rpc_pvp_consent.rpc_id(1, true, old_epoch)
	await create_timer(0.1).timeout
	_check(not host.presence[guest_id].pvp, "old epoch consent rejected")
	host.set_pvp_allowed(true)
	guest.set_pvp_allowed(true)
	await _poses()
	guest._rpc_pvp_shot.rpc_id(1, Vector3(0, -1.55, 100).normalized(), old_epoch)
	await create_timer(0.1).timeout
	_check(host_hits == 1, "stale epoch shot rejected even after renewed consent")
	guest.leave()
	host.leave()
	_check(not guest.is_pvp_allowed() and not host.is_pvp_allowed(), "leave clears local consent")
	if not failed: print("PVP_TRANSPORT_OK: loopback consent, target-only damage, cooldown, freshness, grounded safety, revocation, travel epoch, invalid rays and forged RPC authority")
	quit(1 if failed else 0)

func _poses(guest_flying: bool = true) -> void:
	await create_timer(0.06).timeout
	host.publish_pose(Vector3.ZERO, Vector3.ZERO, {}, true)
	guest.publish_pose(Vector3(0, 0, -100), Vector3(0, PI, 0), {}, guest_flying)
	await create_timer(0.06).timeout

func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("PVP_TRANSPORT_FAIL: " + label)


func _adversarial_rpc() -> void:
	host = _session("Host")
	guest = _session("Guest")
	var observer := _session("Observer")
	host.pvp_damage_received.connect(func(_id: int, _damage: float): host_hits += 1)
	observer.pvp_damage_received.connect(func(_id: int, _damage: float): guest_hits += 1)
	_check(host.host(27858).is_empty(), "adversarial host")
	_check(guest.join("127.0.0.1", 27858).is_empty(), "adversarial attacker")
	_check(observer.join("127.0.0.1", 27858).is_empty(), "adversarial observer")
	for i in 300:
		if guest.connected and observer.connected and observer.presence.size() == 3: break
		await create_timer(0.01).timeout
	_check(guest.connected and observer.connected and observer.presence.size() == 3, "three peers admitted")
	for session: NetworkSession in [host, guest, observer]: session.set_pvp_allowed(true)
	await create_timer(0.1).timeout
	for session: NetworkSession in [host, guest, observer]: session.publish_pose(Vector3.ZERO, Vector3.ZERO, {}, true)
	await create_timer(0.1).timeout
	var attacker := guest.multiplayer.get_unique_id()
	var observer_id := observer.multiplayer.get_unique_id()
	# All gameplay receipt guards are satisfied; only RPC authority must reject these.
	guest._rpc_pvp_damage.rpc_id(1, attacker, 25.0, guest._pvp_epoch)
	guest._rpc_pvp_damage.rpc_id(observer_id, attacker, 25.0, guest._pvp_epoch)
	await create_timer(0.2).timeout
	_check(host_hits == 0 and guest_hits == 0, "forged damage rejected at both recipients")
	# Positive control proves that the observer could otherwise receive damage.
	host._rpc_pvp_damage.rpc_id(observer_id, attacker, 25.0, host._pvp_epoch)
	await create_timer(0.1).timeout
	_check(guest_hits == 1, "authorized damage positive control")
	observer.leave()
	guest.leave()
	host.leave()
	if not failed: print("PVP_AUTHORITY_REJECTION_OK")
	quit(1 if failed else 0)
