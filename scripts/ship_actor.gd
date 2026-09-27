class_name ShipActor
extends CharacterBody3D

signal fired(actor: ShipActor, origin: Vector3, direction: Vector3)
signal destroyed(actor: ShipActor)
signal damaged(actor: ShipActor)

var faction: String = "pirate"
var target: Node3D
var active: bool = true
var hp: float = 100.0
var shields: float = 40.0
var speed: float = 65.0
var drive_temperature_k: float = 450.0
var radiator_area_m2: float = 40.0
var actor_id: String = ""
var hostile: bool = true
const CONTACT_SEARCH_SECONDS: float = 15.0
const DRIVE_HEAT_CAPACITY_J_K: float = 2500000.0
const DRIVE_NOMINAL_MASS_KG: float = 40000.0
var last_contact_position := Vector3.ZERO
var search_seconds_remaining: float = 0.0
var travel_active: bool = false
var travel_target := Vector3.ZERO

var _visual: ShipVisual
var _attack_cooldown: float = 0.0
var _patrol_phase: float = 0.0
var _desired_velocity: Vector3 = Vector3.ZERO
var _safe_zone_center: Vector3 = Vector3.ZERO
var _home: Vector3
var _destroyed: bool = false
var _patrol_center_set: bool = false
var _avoidance_direction := Vector3.ZERO
var _avoidance_shape := SphereShape3D.new()


func _ready() -> void:
	_avoidance_shape.radius = 2.6
	collision_layer = 4
	collision_mask = 1
	if actor_id.is_empty():
		actor_id = str(get_instance_id())
	if not _patrol_center_set:
		_home = global_position
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.3
	collision.shape = shape
	add_child(collision)
	_visual = ShipVisual.new()
	add_child(_visual)
	var side_module := "cargo" if get_meta("fleet_order_kind", "") == "trade" else "weapon"
	_visual.build([{"cell": Vector3i.ZERO, "kind": "cockpit"}, {"cell": Vector3i(0, 0, 1), "kind": "engine"}, {"cell": Vector3i(-1, 0, 1), "kind": side_module}, {"cell": Vector3i(1, 0, 1), "kind": side_module}], faction)


func _physics_process(delta: float) -> void:
	if not active or not is_finite(delta) or delta <= 0.0 or delta > 1.0:
		return
	if not hostile: search_seconds_remaining = 0.0
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_patrol_phase += delta
	var destination := _home + Vector3(sin(_patrol_phase * 0.22) * 26.0, sin(_patrol_phase * 0.31) * 8.0, cos(_patrol_phase * 0.22) * 26.0)
	if travel_active: destination = travel_target
	var attacking := hostile and _target_is_active()
	if not attacking and hostile and search_seconds_remaining > 0.0:
		search_seconds_remaining = maxf(0.0, search_seconds_remaining - delta)
		if search_seconds_remaining > 0.0:
			# Only the last observed point is available after contact is lost.
			destination = last_contact_position
			if global_position.distance_to(destination) < 80.0:
				destination += Vector3(sin(_patrol_phase) * 35.0, sin(_patrol_phase * 0.7) * 12.0, cos(_patrol_phase) * 35.0)
	if attacking:
		var range := global_position.distance_to(target.global_position)
		var away := (global_position - target.global_position).normalized()
		if hp < 30.0:
			destination = target.global_position + away * 210.0 + Vector3.UP * 30.0
		elif range > 105.0:
			destination = target.global_position + Vector3(sin(_patrol_phase) * 24.0, sin(_patrol_phase * 0.7) * 12.0, cos(_patrol_phase) * 24.0)
		else:
			destination = target.global_position + away * 92.0 + Vector3.UP * sin(_patrol_phase * 1.6) * 18.0
		if range < 720.0 and _attack_cooldown <= 0.0 and hp >= 30.0 and not _near_safe_zone():
			_attack_cooldown = 1.1
			var origin := global_position + (-global_basis.z * 4.0)
			var aim_position: Vector3 = target.global_position
			if target is CoastingHull:
				aim_position = target.aim_point()
			var fire_direction: Vector3 = aim_position - origin
			if fire_direction.length_squared() > 0.000001:
				fired.emit(self, origin, fire_direction.normalized())
	var offset := destination - global_position
	var distance := offset.length()
	var desired_speed := speed * (0.55 if attacking and hp < 30.0 else 1.0)
	var command := _avoid_obstacles(offset.normalized() * minf(desired_speed, distance * 2.0))
	var baseline_w := ThermalSignature.emitted_power_w(300.0, radiator_area_m2)
	var cooling_w := maxf(0.0, thermal_emission_w() - baseline_w)
	drive_temperature_k = maxf(300.0, drive_temperature_k - cooling_w * delta / DRIVE_HEAT_CAPACITY_J_K)
	var heat_factor := clampf((700.0 - drive_temperature_k) / 200.0, 0.0, 1.0)
	var requested_dv := command - velocity
	var dv_limit := minf(30.0 * heat_factor * delta, maxf(0.0, 700.0 - drive_temperature_k) / 20.0 * 5000000.0 / DRIVE_NOMINAL_MASS_KG)
	var actual_dv := requested_dv.limit_length(dv_limit)
	velocity += actual_dv
	var fuel_equivalent := DRIVE_NOMINAL_MASS_KG * actual_dv.length() / 5000000.0
	drive_temperature_k = minf(700.0, drive_temperature_k + fuel_equivalent * 20.0)
	_desired_velocity = velocity
	if distance > 0.5:
		var forward: Vector3 = velocity.normalized() if velocity.length_squared() > 0.25 else offset.normalized()
		var up: Vector3 = Vector3.FORWARD if absf(forward.dot(Vector3.UP)) > 0.98 else Vector3.UP
		look_at(global_position + forward, up)
	move_and_slide()
	_desired_velocity = velocity
	_visual.set_thrust(clampf(actual_dv.length() / maxf(30.0 * delta, 0.000001), 0.0, 1.0))


func _avoid_obstacles(desired_velocity: Vector3) -> Vector3:
	if not desired_velocity.is_finite() or desired_velocity.length_squared() < 0.000001: return Vector3.ZERO
	var travel_speed := desired_velocity.length()
	if not is_finite(travel_speed): return Vector3.ZERO
	var forward := desired_velocity / travel_speed
	var lookahead := maxf(16.0, travel_speed * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _avoidance_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return Vector3.ZERO
	query.motion = forward * lookahead
	if space.cast_motion(query)[0] >= 0.999:
		_avoidance_direction = Vector3.ZERO
		return desired_velocity
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var right := forward.cross(up).normalized()
	up = right.cross(forward).normalized()
	var best := Vector3.ZERO
	var best_score := -INF
	# Local steering only: a fully blocked fan brakes; global routing is separate.
	for angle: float in [PI * 0.25, PI * 5.0 / 12.0, PI * 0.5]:
		for side: Vector3 in [right, -right, up, -up]:
			var direction := (forward * cos(angle) + side * sin(angle)).normalized()
			query.motion = direction * lookahead
			if space.cast_motion(query)[0] < 0.999: continue
			var score := direction.dot(forward) * 2.0 + direction.dot(_avoidance_direction) * 0.65
			if score > best_score:
				best_score = score
				best = direction
	_avoidance_direction = best
	return best * travel_speed


func take_damage(amount: float) -> void:
	if not active or _destroyed or not is_finite(amount) or amount <= 0.0:
		return
	var absorbed := minf(shields, amount)
	shields -= absorbed
	hp = maxf(0.0, hp - (amount - absorbed))
	damaged.emit(self)
	if hp <= 0.0:
		_destroyed = true
		active = false
		destroyed.emit(self)
		queue_free()


func set_patrol_center(center: Vector3) -> void:
	if not center.is_finite():
		return
	_home = center
	_patrol_center_set = true


func set_travel_target(point: Vector3) -> void:
	if not point.is_finite(): return
	travel_target = point
	travel_active = true


func observe_target(candidate: Node3D) -> void:
	target = candidate
	if not hostile:
		search_seconds_remaining = 0.0
		return
	if _target_is_active() and target.global_position.is_finite():
		last_contact_position = target.global_position
		search_seconds_remaining = CONTACT_SEARCH_SECONDS
	else:
		target = null


func _target_is_active() -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if target is ShipActor:
		return target.active and not target._destroyed and target.hp > 0.0
	if target is Pilot:
		return target.flying
	if target is CoastingHull:
		return true
	return false


func _near_safe_zone() -> bool:
	if target.is_in_group("safe_zone") or target.has_meta("safe_zone"):
		return target.global_position.distance_to(global_position) < 240.0
	# Docking or concourse areas use a conservative exclusion bubble around origin.
	return global_position.distance_to(_safe_zone_center) < 220.0

func restore_flight_velocity(value: Vector3) -> void:
	if not value.is_finite(): return
	velocity = value
	_desired_velocity = value

func thermal_emission_w() -> float:
	return ThermalSignature.emitted_power_w(drive_temperature_k, radiator_area_m2)

func apply_origin_shift(delta: Vector3) -> void:
	_safe_zone_center -= delta
	_home -= delta
	last_contact_position -= delta
	travel_target -= delta
	reset_physics_interpolation()
