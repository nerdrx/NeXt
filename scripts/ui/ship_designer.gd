class_name ShipDesigner
extends HBoxContainer

signal requested(kind: String, cell: Vector3i, remove: bool)
var modules: Array = []
var selected_cell := Vector3i(0, 0, 0)
var selected_kind: String = "cargo"
var preview: ShipVisual
var orbit: Node3D
var grid: BuildGrid
var selection: Label
var viewport: SubViewport
var preview_camera: Camera3D

class BuildGrid:
	extends Control
	signal picked(cell: Vector3i)
	var modules: Array = []
	var cell := Vector3i.ZERO
	var layer: int = 0
	const CELL: float = 30.0
	func _ready() -> void:
		custom_minimum_size = Vector2(270, 270)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			cell = Vector3i(clampi(int(event.position.x / CELL) - 4, -4, 4), layer, clampi(int(event.position.y / CELL) - 4, -4, 4))
			picked.emit(cell)
			queue_redraw()
	func _draw() -> void:
		for x in range(9):
			for z in range(9):
				var key := Vector3i(x - 4, layer, z - 4)
				var color := Color("0b1724")
				var title: String = ""
				for item: Dictionary in modules:
					if int(item.x) == key.x and int(item.y) == key.y and int(item.z) == key.z:
						color = Color("27606b")
						title = str(item.kind).left(1).to_upper()
				var rect := Rect2(Vector2(x, z) * CELL + Vector2.ONE, Vector2.ONE * (CELL - 2))
				draw_rect(rect, color)
				if key == cell: draw_rect(rect, InterfaceTheme.GOLD, false, 2)
				if title != "": draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, 20), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, InterfaceTheme.CYAN)

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(450, 350)
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(560, 350)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("091321")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("91a9c1")
	environment.environment.ambient_light_energy = 0.35
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 2.2
	scene.add_child(light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(35, 130, 0)
	rim.light_color = Color("b9c9df")
	rim.light_energy = 1.5
	scene.add_child(rim)
	orbit = Node3D.new()
	scene.add_child(orbit)
	preview = ShipVisual.new()
	orbit.add_child(preview)
	var camera := Camera3D.new()
	preview_camera = camera
	scene.add_child(camera)
	camera.position = Vector3(19, 15, 24)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16
	camera.current = true
	left.add_child(InterfaceTheme.label("LIVE ASSEMBLY  /  All modules affect your ship", 14, InterfaceTheme.MUTED))
	var right := VBoxContainer.new()
	add_child(right)
	right.add_child(InterfaceTheme.label("CONSTRUCTION GRID", 15, InterfaceTheme.CYAN))
	var layer_control := SpinBox.new()
	layer_control.min_value = -2
	layer_control.max_value = 2
	layer_control.prefix = "Deck "
	right.add_child(layer_control)
	grid = BuildGrid.new()
	right.add_child(grid)
	grid.picked.connect(func(cell: Vector3i):
		selected_cell = cell
		_update_selection())
	layer_control.value_changed.connect(func(value: float):
		grid.layer = int(value)
		selected_cell.y = int(value)
		grid.cell = selected_cell
		grid.queue_redraw()
		_update_selection())
	selection = InterfaceTheme.label("", 14, InterfaceTheme.MUTED)
	right.add_child(selection)
	var kind := OptionButton.new()
	for name: String in GameState.MODULES:
		kind.add_item("%s  /  %s CR" % [name.capitalize(), GameState.MODULES[name].cost])
		kind.set_item_metadata(kind.item_count - 1, name)
		if name == "cargo": kind.selected = kind.item_count - 1
	kind.item_selected.connect(func(index: int): selected_kind = str(kind.get_item_metadata(index)))
	right.add_child(kind)
	right.add_child(InterfaceTheme.button("INSTALL MODULE", func(): requested.emit(selected_kind, selected_cell, false)))
	right.add_child(InterfaceTheme.button("REMOVE / REFUND", func(): requested.emit("", selected_cell, true)))
	_update_selection()
	refresh(modules)

func _update_selection() -> void:
	selection.text = "CELL  %d : %d : %d   /   Bow faces ↑" % [selected_cell.x, selected_cell.y, selected_cell.z]

func refresh(values: Array) -> void:
	modules = values.duplicate(true)
	if preview != null:
		preview.build(modules, "player")
		var low := Vector3.ZERO
		var high := Vector3.ZERO
		for item: Dictionary in modules:
			var cell := Vector3(item.x, item.y, item.z)
			low = low.min(cell)
			high = high.max(cell)
		preview_camera.size = maxf(16.0, (high - low + Vector3.ONE).length() * ShipVisual.CELL_SIZE * 1.25)
		grid.modules = modules
		grid.queue_redraw()

func _process(delta: float) -> void:
	if orbit != null: orbit.rotation.y += delta * 0.15
