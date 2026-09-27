class_name ShipCrew
extends GroundActor

var _crew_label: Label3D


func _init() -> void:
	faction = "crew"
	hostile = false
	hold_position = true
	follow_when_friendly = false


func _ready() -> void:
	super._ready()
	_crew_label = Label3D.new()
	_crew_label.name = "DutyLabel"
	_crew_label.position.y = 2.1
	_crew_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_crew_label.font_size = 32
	_crew_label.pixel_size = 0.004
	_crew_label.modulate = Color("c7e9ed")
	add_child(_crew_label)
	update_duty("On duty")


func _physics_process(delta: float) -> void:
	if not active:
		return
	up_direction = global_basis.y.normalized()
	velocity = up_direction * velocity.dot(up_direction)
	if not is_on_floor():
		velocity -= up_direction * 20.0 * delta
	else:
		velocity = -up_direction * 0.15
	force_update_transform()
	move_and_slide()
	_gait += delta * 1.8
	_animate()


func update_duty(text: String) -> void:
	if is_instance_valid(_crew_label):
		_crew_label.text = "%s\n%s / %s" % [display_name, role.capitalize(), text]
