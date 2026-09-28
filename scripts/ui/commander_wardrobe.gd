class_name CommanderWardrobe
extends VBoxContainer

signal applied(suit: int, armor: int)

var selection: Dictionary = {"suit": 0, "armor": 0}
var suit_choice: OptionButton
var armor_choice: OptionButton
var preview: GroundActor
var viewport: SubViewport
var _stage: Node3D
var _angle := 0.0

func _ready() -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(320, 360)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 360)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	_stage = Node3D.new()
	viewport.add_child(_stage)
	var environment := WorldEnvironment.new()
	environment.environment = ShipVisual.preview_environment()
	_stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 145, 0)
	key.light_energy = 1.3
	_stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -20, 0)
	fill.light_energy = 0.3
	_stage.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.4
	camera.position = Vector3(0, 1, -5)
	_stage.add_child(camera)
	camera.look_at(Vector3(0, 1, 0))
	camera.make_current()
	var options := HBoxContainer.new()
	add_child(options)
	options.add_child(InterfaceTheme.label("FABRIC", 13, InterfaceTheme.CYAN))
	suit_choice = OptionButton.new()
	suit_choice.name = "SuitChoice"
	for label: String in CrewAppearance.SUIT_NAMES: suit_choice.add_item(label)
	suit_choice.select(int(selection.suit))
	options.add_child(suit_choice)
	options.add_child(InterfaceTheme.label("ARMOR", 13, InterfaceTheme.CYAN))
	armor_choice = OptionButton.new()
	armor_choice.name = "ArmorChoice"
	for label: String in CrewAppearance.ARMOR_NAMES: armor_choice.add_item(label)
	armor_choice.select(int(selection.armor))
	options.add_child(armor_choice)
	suit_choice.item_selected.connect(func(index: int): selection.suit = index; _rebuild())
	armor_choice.item_selected.connect(func(index: int): selection.armor = index; _rebuild())
	var actions := HBoxContainer.new()
	add_child(actions)
	actions.add_child(InterfaceTheme.button("TURN LEFT", _turn.bind(-PI / 4)))
	actions.add_child(InterfaceTheme.button("TURN RIGHT", _turn.bind(PI / 4)))
	var apply := InterfaceTheme.button("APPLY FINISH", func(): applied.emit(int(selection.suit), int(selection.armor)))
	apply.name = "ApplyFinish"
	actions.add_child(apply)
	_rebuild()
	visibility_changed.connect(_update_visibility)
	_update_visibility()

func _rebuild() -> void:
	if is_instance_valid(preview):
		_stage.remove_child(preview)
		preview.queue_free()
	preview = GroundActor.new()
	preview.actor_id = "commander-preview"
	preview.faction = "crew"
	preview.hostile = false
	preview.active = false
	preview.suit_index = int(selection.suit)
	preview.armor_index = int(selection.armor)
	preview.rotation.y = _angle
	_stage.add_child(preview)
	preview.set_physics_process(false)

func _turn(amount: float) -> void:
	_angle = wrapf(_angle + amount, -PI, PI)
	preview.rotation.y = _angle

func _update_visibility() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
