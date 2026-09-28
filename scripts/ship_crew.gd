class_name ShipCrew
extends GroundActor

var _crew_label: Label3D
var roaming_enabled: bool = true
var _cabin: ShipInterior
var _stops: Array[Vector3] = []
var _local_path := PackedVector3Array()
var _room_wait: float = 8.0
var _next_stop: int = 0
var _stuck_time: float = 0.0


func configure_roaming(cabin: ShipInterior, stops: Array[Vector3]) -> void:
	_cabin = cabin
	_stops = stops.duplicate()
	_local_path.clear()
	_room_wait = 8.0 + float(posmod(actor_id.hash(), 7))
	_next_stop = posmod(actor_id.hash(), maxi(1, _stops.size()))
	hold_position = false


func activity() -> String:
	return "Checking rooms" if not _local_path.is_empty() and roaming_enabled else "On duty"


func _init() -> void:
	speed = 1.1
	faction = "crew"
	hostile = false
	hold_position = true
	follow_when_friendly = false


func _ready() -> void:
	super._ready()
	_crew_label = Label3D.new()
	_crew_label.name = "DutyLabel"
	_crew_label.position.y = 1.95
	_crew_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_crew_label.font_size = 32
	_crew_label.pixel_size = 0.0013
	_crew_label.outline_size = 4
	_crew_label.shaded = false
	_crew_label.modulate = Color("c7e9ed")
	add_child(_crew_label)
	update_duty("On duty")


func _physics_process(delta: float) -> void:
	if not active:
		return
	up_direction = global_basis.y.normalized()
	var vertical := velocity.dot(up_direction)
	if not is_on_floor():
		vertical -= 20.0 * delta
	else:
		vertical = -0.15
	var direction := Vector3.ZERO
	if roaming_enabled and is_instance_valid(_cabin):
		_room_wait = maxf(0.0, _room_wait - delta)
		if _local_path.is_empty() and _room_wait <= 0.0:
			# Bounded attempts: unreachable rooms do not generate a path request every frame.
			for attempt in mini(3, _stops.size()):
				var target_position := _stops[_next_stop % _stops.size()]
				_next_stop += 1
				if absf(target_position.y-position.y) > 0.5 or position.distance_to(target_position) < 1.0: continue
				_local_path = _cabin.crew_path(position, target_position)
				if not _local_path.is_empty(): break
			_room_wait = 8.0 + float(posmod(actor_id.hash(), 7))
		var was_walking := not _local_path.is_empty()
		while not _local_path.is_empty():
			var offset := _local_path[0] - position
			offset.y = 0.0
			if offset.length() > 0.18:
				direction = offset.normalized() * minf(speed, offset.length() * 2.5)
				rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), minf(1.0, delta * 5.0))
				break
			_local_path.remove_at(0)
		if was_walking and _local_path.is_empty(): _room_wait = 8.0 + float(posmod(actor_id.hash(), 7))
	else:
		_local_path.clear()
	velocity = (get_parent() as Node3D).global_basis * direction + up_direction * vertical
	var previous := position
	force_update_transform()
	move_and_slide()
	if direction.length_squared() > 0.01 and position.distance_to(previous) < delta * 0.08:
		_stuck_time += delta
		if _stuck_time > 1.5:
			_local_path.clear()
			_room_wait = 3.0
			_stuck_time = 0.0
	else: _stuck_time = 0.0
	_gait += delta * (7.0 if direction.length_squared() > 0.01 else 1.8)
	_animate()


func update_duty(text: String) -> void:
	if is_instance_valid(_crew_label):
		_crew_label.text = "%s\n%s / %s" % [display_name, role.capitalize(), text]
