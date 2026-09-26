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
	var suit_color := Color("51433c") if faction == "pirate" else (Color("344958") if faction == "police" else Color("46504e"))
	var patch_color := Color("bd8052") if faction == "pirate" else (Color("7796a0") if faction == "police" else Color("a28c65"))
	match role.to_lower():
		"medic": patch_color = Color("a65d58")
		"engineer": patch_color = Color("c49a58")
		"trader": patch_color = Color("738e78")
	var fabric := _mat(suit_color, 0.86, 0.0, 0.02)
	var ceramic := _mat(Color("a5aaa4") if not hostile else Color("626b6b"), 0.42, 0.0, 0.16)
	var dark_ceramic := _mat(Color("293438"), 0.48, 0.0, 0.2)
	var patch := _mat(patch_color, 0.68, 0.0, 0.05)
	var visor := _mat(Color("26383a"), 0.16, 0.0, 0.58)
	var rubber := _mat(Color("202626"), 0.88, 0.0, 0.0)

	# Soft pressure suit silhouette, with armor concentrated at exposed joints.
	var torso := CylinderMesh.new()
	torso.top_radius = 0.235
	torso.bottom_radius = 0.31
	torso.height = 0.56
	torso.radial_segments = 20
	_add_mesh(torso, Vector3(0, 1.18, 0), fabric)
	var vest := SphereMesh.new()
	vest.radius = 0.31
	vest.height = 0.55
	_add_mesh(vest, Vector3(0, 1.2, -0.075), ceramic, Vector3(0.88, 0.92, 0.38))
	var pelvis := CapsuleMesh.new()
	pelvis.radius = 0.23
	pelvis.height = 0.38
	_add_mesh(pelvis, Vector3(0, 0.87, 0), fabric, Vector3(1.0, 0.64, 0.92))
	var belt := CylinderMesh.new()
	belt.top_radius = 0.25
	belt.bottom_radius = 0.27
	belt.height = 0.095
	belt.radial_segments = 20
	_add_mesh(belt, Vector3(0, 0.94, 0), dark_ceramic)

	# Rounded helmet shell, recessed curved visor, and sealed neck ring.
	_add_sphere(Vector3(0, 1.61, 0), 0.235, ceramic)
	var visor_mesh := SphereMesh.new()
	visor_mesh.radius = 0.19
	visor_mesh.height = 0.20
	_add_mesh(visor_mesh, Vector3(0, 1.635, -0.205), visor, Vector3(1.35, 0.72, 0.34))
	var neck_ring := CylinderMesh.new()
	neck_ring.top_radius = 0.155
	neck_ring.bottom_radius = 0.17
	neck_ring.height = 0.075
	neck_ring.radial_segments = 20
	_add_mesh(neck_ring, Vector3(0, 1.445, 0), dark_ceramic)

	# Chest hardware and restrained role patch provide scale and visual read.
	_add_box(Vector3(0, 1.28, -0.205), Vector3(0.14, 0.07, 0.035), dark_ceramic)
	_add_box(Vector3(0.01, 1.28, -0.228), Vector3(0.075, 0.043, 0.016), patch)
	_add_box(Vector3(-0.19, 1.25, -0.205), Vector3(0.07, 0.045, 0.025), dark_ceramic)
	var pack := BoxMesh.new()
	pack.size = Vector3(0.42, 0.38, 0.17)
	_add_mesh(pack, Vector3(0, 1.18, 0.23), dark_ceramic)

	_left_arm = _arm(Vector3(-0.34, 1.34, 0), fabric, ceramic, dark_ceramic, rubber)
	_right_arm = _arm(Vector3(0.34, 1.34, 0), fabric, ceramic, dark_ceramic, rubber)
	_left_leg = _leg(Vector3(-0.145, 0.92, 0), fabric, ceramic, dark_ceramic, rubber)
	_right_leg = _leg(Vector3(0.145, 0.92, 0), fabric, ceramic, dark_ceramic, rubber)

	# Small shoulder tabs break the suit color without adding glowing trim.
	_add_box(Vector3(-0.35, 1.38, -0.025), Vector3(0.17, 0.08, 0.19), ceramic)
	_add_box(Vector3(0.35, 1.38, -0.025), Vector3(0.17, 0.08, 0.19), ceramic)
	_add_box(Vector3(-0.35, 1.385, -0.13), Vector3(0.09, 0.025, 0.02), patch)
	_add_box(Vector3(0.35, 1.385, -0.13), Vector3(0.09, 0.025, 0.02), patch)
	if hostile:
		# Compact sidearm stays close to the hip and reads as equipment, not a block.
		_add_box(Vector3(0.43, 0.94, -0.18), Vector3(0.12, 0.2, 0.16), dark_ceramic)
		_add_box(Vector3(0.43, 0.99, -0.31), Vector3(0.07, 0.07, 0.2), ceramic)
		_add_box(Vector3(0.43, 0.99, -0.425), Vector3(0.045, 0.045, 0.035), patch)


func _arm(pivot_position: Vector3, fabric: Material, ceramic: Material, dark: Material, rubber: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_position
	_visual.add_child(pivot)
	_add_child_capsule(pivot, Vector3(0, -0.2, 0), 0.115, 0.43, fabric)
	_add_child_sphere(pivot, Vector3(0, -0.42, 0), 0.105, ceramic, Vector3(0.9, 0.9, 0.9))
	var forearm := CylinderMesh.new()
	forearm.top_radius = 0.075
	forearm.bottom_radius = 0.105
	forearm.height = 0.34
	forearm.radial_segments = 16
	_add_child_mesh(pivot, forearm, Vector3(0, -0.59, -0.005), fabric)
	_add_child_sphere(pivot, Vector3(0, -0.59, -0.005), 0.105, ceramic, Vector3(0.88, 1.55, 0.9))
	_add_child_capsule(pivot, Vector3(0, -0.81, -0.015), 0.078, 0.19, rubber)
	var cuff := CylinderMesh.new()
	cuff.top_radius = 0.09
	cuff.bottom_radius = 0.09
	cuff.height = 0.055
	cuff.radial_segments = 16
	_add_child_mesh(pivot, cuff, Vector3(0, -0.47, 0), dark)
	return pivot


func _leg(pivot_position: Vector3, fabric: Material, ceramic: Material, dark: Material, rubber: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_position
	_visual.add_child(pivot)
	_add_child_capsule(pivot, Vector3(0, -0.22, 0), 0.145, 0.48, fabric)
	_add_child_sphere(pivot, Vector3(0, -0.46, 0), 0.13, dark, Vector3(0.95, 0.9, 0.95))
	_add_child_capsule(pivot, Vector3(0, -0.68, 0.015), 0.115, 0.48, fabric)
	_add_child_sphere(pivot, Vector3(0, -0.65, -0.095), 0.11, ceramic, Vector3(0.72, 1.2, 0.27))
	var boot := CapsuleMesh.new()
	boot.radius = 0.12
	boot.height = 0.36
	var boot_mesh := _add_child_mesh(pivot, boot, Vector3(0, -0.9, -0.08), rubber)
	boot_mesh.rotation.x = PI / 2.0
	return pivot


func _add_mesh(mesh: Mesh, pos: Vector3, material: Material, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	return _add_child_mesh(_visual, mesh, pos, material, scale)


func _add_child_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.scale = scale
	parent.add_child(instance)
	return instance


func _add_child_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	_add_child_mesh(parent, box, pos, material)


func _add_child_sphere(parent: Node3D, pos: Vector3, radius: float, material: Material, scale: Vector3 = Vector3.ONE) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	_add_child_mesh(parent, sphere, pos, material, scale)


func _add_child_capsule(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	_add_child_mesh(parent, capsule, pos, material)


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


func _mat(color: Color, roughness: float, glow: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material
