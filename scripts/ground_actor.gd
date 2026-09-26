class_name GroundActor
extends CharacterBody3D

signal fired(actor: GroundActor, origin: Vector3, direction: Vector3)
signal destroyed(actor: GroundActor)

var faction: String = "pirate"
var hostile: bool = true
var active: bool = true
var target: Node3D
var hp: float = 100.0
var speed: float = 3.4
var actor_id: String = ""
var role: String = "guard"
var display_name: String = ""

var _home: Vector3
var _waypoint: Vector3
var _patrol_timer: float = 0.0
var _fire_cooldown: float = 0.0
var _gait: float = 0.0
var _visual: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _destroyed: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	if actor_id.is_empty():
		actor_id = str(get_instance_id())
	_home = global_position
	_waypoint = _home
	if display_name.is_empty():
		display_name = "Station %s" % role.capitalize() if not hostile else "%s %s" % [faction.capitalize(), role.capitalize()]
	set_meta("role", role)
	set_meta("display_name", display_name)
	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.42
	capsule_shape.height = 1.75
	capsule.shape = capsule_shape
	capsule.position.y = 0.88
	add_child(capsule)
	_build_humanoid()


func _physics_process(delta: float) -> void:
	if not active:
		return
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_patrol_timer -= delta
	_gait += delta * (7.0 if velocity.length() > 0.2 else 1.8)
	var move_to := _waypoint
	var chasing := hostile and is_instance_valid(target)
	if chasing:
		var distance := global_position.distance_to(target.global_position)
		if distance < 38.0 and _fire_cooldown <= 0.0 and _has_line_of_sight():
			_fire_cooldown = 1.25
			var origin := global_position + Vector3.UP * 1.28 + (-global_basis.z * 0.48)
			fired.emit(self, origin, (target.global_position + Vector3.UP * 0.9 - origin).normalized())
		if distance > 9.0:
			move_to = target.global_position
		elif distance > 4.0:
			move_to = global_position
		else:
			move_to = global_position - (target.global_position - global_position).normalized() * 5.0
	elif not hostile and is_instance_valid(target):
		var distance := global_position.distance_to(target.global_position)
		move_to = target.global_position if distance > 6.0 else global_position
	elif _patrol_timer <= 0.0 or global_position.distance_to(_waypoint) < 0.8:
		_patrol_timer = randf_range(2.5, 5.0)
		_waypoint = _home + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
		move_to = _waypoint
	var offset := move_to - global_position
	offset.y = 0.0
	var direction := offset.normalized() if offset.length_squared() > 0.01 else Vector3.ZERO
	if direction != Vector3.ZERO and _path_blocked(direction):
		direction = direction.rotated(Vector3.UP, PI * 0.5)
	var wanted := direction * speed * (1.2 if chasing else 1.0)
	velocity.x = move_toward(velocity.x, wanted.x, delta * 8.0)
	velocity.z = move_toward(velocity.z, wanted.z, delta * 8.0)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.15
	if direction.length_squared() > 0.001:
		rotation.y = atan2(-direction.x, -direction.z)
	move_and_slide()
	_animate()


func take_damage(amount: float) -> void:
	if not active or _destroyed or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		_destroyed = true
		active = false
		destroyed.emit(self)
		queue_free()


func _has_line_of_sight() -> bool:
	if not is_instance_valid(target):
		return false
	var from := global_position + Vector3.UP * 1.28
	var to := target.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == target


func _path_blocked(direction: Vector3) -> bool:
	var from := global_position + Vector3.UP * 0.8
	var to := from + direction * 1.6
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _build_humanoid() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var suit_color := Color("743e3d") if faction == "pirate" else (Color("315b83") if faction == "police" else Color("536778"))
	var trim_color := Color("ff735c") if faction == "pirate" else (Color("8bd9ff") if faction == "police" else Color("66e4d9"))
	var suit := _mat(suit_color, 0.72, 0.0)
	var armor := _mat(Color("9babb9") if not hostile else Color("303f50"), 0.52, 0.0)
	var trim := _mat(trim_color, 0.3, 1.25)
	var visor := _mat(Color(0.04, 0.68, 0.82, 0.88), 0.16, 1.2)
	_add_sphere(Vector3(0, 1.49, 0), 0.25, armor)
	_add_box(Vector3(0, 0.99, 0), Vector3(0.62, 0.7, 0.38), suit)
	_add_box(Vector3(0, 0.77, 0), Vector3(0.52, 0.22, 0.4), armor)
	_add_box(Vector3(0, 1.49, -0.19), Vector3(0.33, 0.12, 0.075), visor)
	_add_box(Vector3(0, 1.28, -0.035), Vector3(0.46, 0.08, 0.44), trim)
	_left_arm = _limb(Vector3(-0.39, 1.27, 0), suit, 0.15, 0.63)
	_right_arm = _limb(Vector3(0.39, 1.27, 0), suit, 0.15, 0.63)
	_left_leg = _limb(Vector3(-0.17, 0.68, 0), armor, 0.18, 0.72)
	_right_leg = _limb(Vector3(0.17, 0.68, 0), armor, 0.18, 0.72)
	_add_box(Vector3(-0.39, 1.02, -0.01), Vector3(0.19, 0.17, 0.2), trim)
	_add_box(Vector3(0.39, 1.02, -0.01), Vector3(0.19, 0.17, 0.2), trim)
	# Compact sidearm and emitter make the hostile role readable at a glance.
	_add_box(Vector3(0.5, 0.99, -0.33), Vector3(0.09, 0.09, 0.3), armor)
	_add_box(Vector3(0.5, 0.99, -0.5), Vector3(0.05, 0.05, 0.06), trim)


func _limb(pivot_position: Vector3, material: Material, radius: float, length: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_position
	_visual.add_child(pivot)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.8
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 10
	mesh.mesh = cylinder
	mesh.material_override = material
	pivot.add_child(mesh)
	mesh.position.y = -length * 0.5
	var joint := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 1.15
	sphere.height = radius * 2.3
	joint.mesh = sphere
	joint.material_override = material
	pivot.add_child(joint)
	return pivot


func _animate() -> void:
	var amount := clampf(Vector2(velocity.x, velocity.z).length() / maxf(speed, 0.1), 0.0, 1.0)
	var swing := sin(_gait) * 0.62 * amount
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation.x = -swing * 0.72
	_right_arm.rotation.x = swing * 0.72 - (0.38 if hostile else 0.0)


func _add_box(pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	_visual.add_child(mesh)
	mesh.position = pos


func _add_sphere(pos: Vector3, radius: float, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.material_override = material
	_visual.add_child(mesh)
	mesh.position = pos


func _mat(color: Color, roughness: float, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.3
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material
