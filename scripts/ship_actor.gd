class_name ShipActor
extends CharacterBody3D

signal fired(actor: ShipActor, origin: Vector3, direction: Vector3)
signal destroyed(actor: ShipActor)
signal damaged(actor: ShipActor)

var faction: String = "pirate"
var target: Node3D
var active: bool = true
var hp: float = 100.0 # Hull condition percentage, also used by fleet saves.
var max_hull: float = 100.0
var weapon_damage: float = 9.0
var shields: float = 40.0
var max_shields: float = 0.0
var shield_delay: float = 0.0
var speed: float = 65.0
var drive_temperature_k: float = 450.0
var radiator_area_m2: float = 40.0
# Generic NPC tuning; family hulls replace this with their blueprint value.
var systems_heat_w: float = 6000.0
var actor_id: String = ""
var hostile: bool = true
const CONTACT_SEARCH_SECONDS: float = 15.0
var dry_mass_kg: float = 40000.0
var cargo_mass_kg: float = 0.0
var thrust_newtons: float = 1200000.0
var acceleration_limit_mps2: float = 30.0
var last_contact_position := Vector3.ZERO
var search_seconds_remaining: float = 0.0
var travel_active: bool = false
var travel_target := Vector3.ZERO
var propulsion_limiter: Callable
var atmospheric_density_source: Callable
var aerodynamic_g: float = 0.0
var stellar_heat_source: Callable
var stellar_heat_w: float = 0.0
var thermal_retreat: bool = false
var _thermal_escape_direction := Vector3.ZERO
var _thermal_probe_cooldown: float = 0.0
var _thermal_dimensions := Vector3.ONE

var hull_family: String = ""
var hull_layout: Dictionary = {}
var hull_modules: Array = []
var _visual: Node3D
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
	add_child(collision)
	var blueprint := ShipBlueprint.family(hull_family)
	if hull_family == "custom":
		blueprint = ShipBlueprint.for_vessel({"hull_family": hull_family, "modules": hull_modules, "layout": hull_layout})
	elif not hull_modules.is_empty() and ShipBlueprint.valid_equipment(hull_family,hull_modules):
		blueprint.modules = hull_modules
	if blueprint.is_empty():
		var fleet_visual := FleetShipVisual.new()
		_visual = fleet_visual
		add_child(_visual)
		fleet_visual.build(str(get_meta("fleet_order_kind", "patrol")), faction)
	else:
		var model := GameState.new()
		model.ship_modules.assign(blueprint.modules)
		model.ship_layout = hull_layout if ShipLayout.validate_data(hull_layout,blueprint.modules) else blueprint.layout
		var stats := model.ship_stats()
		max_shields = float(stats.max_shield)
		max_hull = float(stats.max_hull)
		weapon_damage = float(stats.damage)
		dry_mass_kg = float(stats.dry_mass_kg)
		thrust_newtons = float(stats.thrust_newtons)
		acceleration_limit_mps2 = 3.0 * FlightDynamics.STANDARD_GRAVITY
		speed = float(stats.speed)
		radiator_area_m2 = float(stats.radiator_area_m2)
		systems_heat_w = float(stats.systems_heat_w)
		var family_visual := ShipVisual.new()
		_visual = family_visual
		add_child(_visual)
		family_visual.build(blueprint.modules, faction, model.ship_layout)
	# Convex exterior proxy follows the model; cavities remain an approximation.
	var hull_points := PackedVector3Array()
	var radius := 0.0
	var thermal_low := Vector3(INF, INF, INF)
	var thermal_high := -thermal_low
	for mesh: MeshInstance3D in _visual.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		var relative := global_transform.affine_inverse() * mesh.global_transform
		for vertex: Vector3 in mesh.mesh.get_faces():
			var point := relative * vertex
			thermal_low = thermal_low.min(point)
			thermal_high = thermal_high.max(point)
			hull_points.append(point)
			radius = maxf(radius, point.length())
	if not hull_points.is_empty(): _thermal_dimensions = thermal_high - thermal_low
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull_points
	collision.shape = shape
	_avoidance_shape.radius = radius + 0.3



func _physics_process(delta: float) -> void:
	if not active or not is_finite(delta) or delta <= 0.0 or delta > 1.0:
		return
	# Fleet shield time is owned by hosted crew simulation, including remote vessels.
	if not has_meta("fleet_ship_id"): _tick_shields(delta)
	if not hostile: search_seconds_remaining = 0.0
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_patrol_phase += delta
	stellar_heat_w = stellar_heat_source.call(global_position, global_basis, _thermal_dimensions) if stellar_heat_source.is_valid() else 0.0
	var total_heat := (systems_heat_w if hp > 0.0 else 0.0) + stellar_heat_w
	var heat_damage := ThermalSignature.overflow_damage(drive_temperature_k, radiator_area_m2, total_heat, delta)
	drive_temperature_k = ThermalSignature.step_temperature(drive_temperature_k, radiator_area_m2, total_heat, delta)
	if heat_damage > 0.0:
		take_damage(heat_damage, true)
		if _destroyed: return
	_update_thermal_escape(delta)
	var destination := _home + Vector3(sin(_patrol_phase * 0.22) * 26.0, sin(_patrol_phase * 0.31) * 8.0, cos(_patrol_phase * 0.22) * 26.0)
	if travel_active: destination = travel_target
	var attacking := hostile and not thermal_retreat and _target_is_active()
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
	if thermal_retreat:
		destination = global_position + _thermal_escape_direction * 1000.0
	var offset := destination - global_position
	var distance := offset.length()
	var desired_speed := speed * (0.55 if attacking and hp < 30.0 else 1.0)
	var heat_factor := clampf((700.0 - drive_temperature_k) / 200.0, 0.0, 1.0)
	var mass := maxf(1.0, dry_mass_kg + cargo_mass_kg)
	var acceleration := minf(acceleration_limit_mps2, thrust_newtons * heat_factor / mass)
	var command := _avoid_obstacles(offset.normalized() * FlightDynamics.approach_speed(distance, desired_speed, acceleration), acceleration)
	var requested_dv := command - velocity
	var dv_limit := minf(acceleration * delta, maxf(0.0, 700.0 - drive_temperature_k) / 20.0 * 5000000.0 / mass)
	var actual_dv := requested_dv.limit_length(dv_limit)
	if propulsion_limiter.is_valid():
		actual_dv = propulsion_limiter.call(velocity, velocity + actual_dv) - velocity
	velocity += actual_dv
	var fuel_equivalent := mass * actual_dv.length() / 5000000.0
	drive_temperature_k = minf(700.0, drive_temperature_k + fuel_equivalent * 20.0)
	_desired_velocity = velocity
	if distance > 0.5:
		var forward: Vector3 = velocity.normalized() if velocity.length_squared() > 0.25 else offset.normalized()
		var up: Vector3 = Vector3.FORWARD if absf(forward.dot(Vector3.UP)) > 0.98 else Vector3.UP
		look_at(global_position + forward, up)
	var before_drag := velocity
	var density: float = atmospheric_density_source.call(global_position) if atmospheric_density_source.is_valid() else 0.0
	velocity = AtmosphericFlight.drag_velocity(velocity, density, _thermal_dimensions, global_basis, mass, delta)
	aerodynamic_g = FlightDynamics.thrust_load(before_drag, velocity, delta)
	move_and_slide()
	_desired_velocity = velocity
	_visual.set_thrust(clampf(actual_dv.length() / maxf(acceleration * delta, 0.000001), 0.0, 1.0))


func _avoid_obstacles(desired_velocity: Vector3, acceleration: float = 30.0) -> Vector3:
	if not desired_velocity.is_finite() or desired_velocity.length_squared() < 0.000001: return Vector3.ZERO
	var travel_speed := desired_velocity.length()
	if not is_finite(travel_speed): return Vector3.ZERO
	var forward := desired_velocity / travel_speed
	var lookahead := maxf(maxf(16.0, travel_speed * 2.0), FlightDynamics.braking_distance(travel_speed, acceleration) + travel_speed * 0.25)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _avoidance_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return Vector3.ZERO
	# Turning the desired direction cannot instantly redirect inertial momentum.
	# Brake first if our actual trajectory consumes the remaining stopping room.
	var current_speed := velocity.length()
	if current_speed > 0.01:
		var stopping_room := FlightDynamics.braking_distance(current_speed, acceleration) + current_speed * 0.25
		query.motion = velocity / current_speed * stopping_room
		if space.cast_motion(query)[0] < 0.999: return Vector3.ZERO
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


func _tick_shields(delta: float) -> void:
	if not active or hp <= 0.0 or max_shields <= 0.0 or not is_finite(delta) or delta <= 0.0: return
	var recharge_time := maxf(0.0, delta - shield_delay)
	shield_delay = maxf(0.0, shield_delay - delta)
	shields = minf(max_shields, shields + recharge_time * 5.0)


func take_damage(amount: float, bypass_shields: bool = false) -> void:
	if not active or _destroyed or not is_finite(amount) or amount <= 0.0:
		return
	if max_shields > 0.0 and not bypass_shields: shield_delay = 6.0
	var absorbed := 0.0 if bypass_shields else minf(shields, amount)
	shields -= absorbed
	hp = maxf(0.0, hp - (amount - absorbed) * 100.0 / maxf(1.0, max_hull))
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

func patrol_center() -> Vector3:
	return _home

func patrol_clock() -> float:
	return _patrol_phase

func restore_patrol_state(center: Vector3, clock: float) -> bool:
	if not center.is_finite() or not is_finite(clock) or clock < 0.0:
		return false
	_home = center
	_patrol_center_set = true
	_patrol_phase = clock
	return true


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


func _update_thermal_escape(delta: float) -> void:
	if not stellar_heat_source.is_valid() or drive_temperature_k <= 500.0 or stellar_heat_w <= 0.0 or not is_finite(stellar_heat_w):
		thermal_retreat = false
		_thermal_escape_direction = Vector3.ZERO
		_thermal_probe_cooldown = 0.0
		return
	var cooling := ThermalSignature.emitted_power_w(drive_temperature_k, radiator_area_m2) - ThermalSignature.emitted_power_w(300.0, radiator_area_m2)
	if not thermal_retreat and (drive_temperature_k < 550.0 or stellar_heat_w + systems_heat_w <= cooling): return
	_thermal_probe_cooldown = maxf(0.0, _thermal_probe_cooldown - delta)
	if _thermal_probe_cooldown > 0.0: return
	_thermal_probe_cooldown = 1.0
	var best_heat := stellar_heat_w * 0.99
	var direction := Vector3.ZERO
	# Bounded local search; normal obstacle avoidance still handles the chosen course.
	for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var sample: float = stellar_heat_source.call(global_position + axis * 500.0, global_basis, _thermal_dimensions)
		if is_finite(sample) and sample >= 0.0 and sample < best_heat:
			best_heat = sample
			direction = axis
	_thermal_escape_direction = direction
	thermal_retreat = direction != Vector3.ZERO
