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
var actor_id: String = ""
var hostile: bool = true

var _visual: ShipVisual
var _attack_cooldown: float = 0.0
var _patrol_phase: float = 0.0
var _desired_velocity: Vector3 = Vector3.ZERO
var _home: Vector3
var _destroyed: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	if actor_id.is_empty():
		actor_id = str(get_instance_id())
	_home = global_position
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.3
	collision.shape = shape
	add_child(collision)
	_visual = ShipVisual.new()
	add_child(_visual)
	_visual.build([{"cell": Vector3i.ZERO, "kind": "cockpit"}, {"cell": Vector3i(0, 0, 1), "kind": "engine"}, {"cell": Vector3i(-1, 0, 1), "kind": "weapon"}, {"cell": Vector3i(1, 0, 1), "kind": "weapon"}], faction)


func _physics_process(delta: float) -> void:
	if not active:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_patrol_phase += delta
	var destination := _home + Vector3(sin(_patrol_phase * 0.22) * 26.0, sin(_patrol_phase * 0.31) * 8.0, cos(_patrol_phase * 0.22) * 26.0)
	var attacking := hostile and is_instance_valid(target) and _target_is_flying()
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
			fired.emit(self, origin, (target.global_position - origin).normalized())
	var offset := destination - global_position
	var distance := offset.length()
	var desired_speed := speed * (0.55 if attacking and hp < 30.0 else 1.0)
	_desired_velocity = _desired_velocity.lerp(offset.normalized() * minf(desired_speed, distance * 2.0), minf(1.0, delta * 1.8))
	velocity = _desired_velocity
	if distance > 0.5:
		look_at(global_position + offset.normalized(), Vector3.UP)
	move_and_slide()
	_visual.set_thrust(clampf(velocity.length() / maxf(speed, 1.0), 0.0, 1.0))


func take_damage(amount: float) -> void:
	if not active or _destroyed or amount <= 0.0:
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


func _target_is_flying() -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method("get"):
		var flying_value: Variant = target.get("flying")
		return flying_value is bool and flying_value
	return false


func _near_safe_zone() -> bool:
	if target.is_in_group("safe_zone") or target.has_meta("safe_zone"):
		return target.global_position.distance_to(global_position) < 240.0
	# Docking or concourse areas use a conservative exclusion bubble around origin.
	return global_position.length() < 220.0
