class_name ShipDesigner
extends HBoxContainer

signal requested(kind: String, cell: Vector3i, remove: bool)

var read_only := false
var modules: Array = []
var layout: Dictionary = {}
var selected_cell := Vector3i.ZERO
var selected_kind: String = "cargo"
var preview: ShipVisual
var orbit: Node3D
var grid: BuildGrid
var selection: Label
var install_button: Button
var pan_buttons: Array[Button] = []
var x_control: SpinBox
var z_control: SpinBox
var deck_control: SpinBox
var viewport: SubViewport
var preview_camera: Camera3D

class BuildGrid:
	extends Control
	signal picked(cell: Vector3i)
	var modules: Array = []
	var cell := Vector3i.ZERO
	var center := Vector2i.ZERO
	var layer: int = 0
	const CELL: float = 30.0
	const GRID_CELLS: int = 9
	const HALF_GRID: int = 4

	func _ready() -> void:
		custom_minimum_size = Vector2(GRID_CELLS, GRID_CELLS) * CELL
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.position.x < 0 or event.position.y < 0 or event.position.x >= GRID_CELLS * CELL or event.position.y >= GRID_CELLS * CELL:
				return
			var xz := center + Vector2i(int(event.position.x / CELL) - HALF_GRID, int(event.position.y / CELL) - HALF_GRID)
			if absi(xz.x) > GameState.SHIP_CELL_LIMIT or absi(xz.y) > GameState.SHIP_CELL_LIMIT:
				return
			cell = Vector3i(xz.x, layer, xz.y)
			picked.emit(cell)
			queue_redraw()

	func _draw() -> void:
		for x in range(GRID_CELLS):
			for z in range(GRID_CELLS):
				var key := Vector3i(center.x + x - HALF_GRID, layer, center.y + z - HALF_GRID)
				var valid: bool = absi(key.x) <= GameState.SHIP_CELL_LIMIT and absi(key.z) <= GameState.SHIP_CELL_LIMIT
				var color := Color("0b1724") if valid else Color("070d14")
				var title := ""
				for item: Dictionary in modules:
					if int(item.x) == key.x and int(item.y) == key.y and int(item.z) == key.z:
						color = Color("27606b")
						title = str(item.kind).left(1).to_upper()
				var rect := Rect2(Vector2(x, z) * CELL + Vector2.ONE, Vector2.ONE * (CELL - 2))
				draw_rect(rect, color)
				if key == cell and valid:
					draw_rect(rect, InterfaceTheme.GOLD, false, 2)
				if title != "":
					draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, 20), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, InterfaceTheme.CYAN)

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
	preview_camera = Camera3D.new()
	scene.add_child(preview_camera)
	preview_camera.position = Vector3(19, 15, 24)
	preview_camera.look_at(Vector3.ZERO)
	preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	preview_camera.size = 10
	preview_camera.near = 0.05
	preview_camera.far = 2000.0
	preview_camera.current = true
	left.add_child(InterfaceTheme.label("HULL LAYOUT PREVIEW" if read_only else "LIVE ASSEMBLY  /  All modules affect your ship", 14, InterfaceTheme.MUTED))
	var kind := OptionButton.new()
	for name: String in GameState.MODULES:
		if name == "core":
			continue
		kind.add_item("%s  /  %s CR" % [name.capitalize(), GameState.MODULES[name].cost])
		kind.set_item_metadata(kind.item_count - 1, name)
		if name == "cargo":
			kind.selected = kind.item_count - 1
	kind.item_selected.connect(func(index: int): selected_kind = str(kind.get_item_metadata(index)))
	left.add_child(kind)
	kind.visible = not read_only
	var actions := HBoxContainer.new()
	install_button = InterfaceTheme.button("INSTALL MODULE", func(): requested.emit(selected_kind, selected_cell, false))
	actions.add_child(install_button)
	actions.add_child(InterfaceTheme.button("REMOVE / REFUND", func(): requested.emit("", selected_cell, true)))
	left.add_child(actions)
	actions.visible = not read_only
	var right := VBoxContainer.new()
	add_child(right)
	right.add_child(InterfaceTheme.label("DECK PLAN" if read_only else "CONSTRUCTION GRID", 15, InterfaceTheme.CYAN))
	var coordinates := HBoxContainer.new()
	coordinates.add_child(InterfaceTheme.label("X", 14, InterfaceTheme.MUTED))
	x_control = _coordinate_spin()
	coordinates.add_child(x_control)
	coordinates.add_child(InterfaceTheme.label("Z", 14, InterfaceTheme.MUTED))
	z_control = _coordinate_spin()
	coordinates.add_child(z_control)
	right.add_child(coordinates)
	coordinates.visible = not read_only
	var deck_row := HBoxContainer.new()
	deck_row.add_child(InterfaceTheme.label("DECK", 14, InterfaceTheme.MUTED))
	deck_control = SpinBox.new()
	deck_control.min_value = -GameState.SHIP_CELL_LIMIT
	deck_control.max_value = GameState.SHIP_CELL_LIMIT
	deck_control.step = 1
	deck_control.rounded = true
	deck_row.add_child(deck_control)
	right.add_child(deck_row)
	deck_row.visible = not read_only
	var pan_row := HBoxContainer.new()
	var up := InterfaceTheme.button("▲", func(): pan_grid(Vector2i(0, -1)))
	var left_button := InterfaceTheme.button("◀", func(): pan_grid(Vector2i(-1, 0)))
	var down := InterfaceTheme.button("▼", func(): pan_grid(Vector2i(0, 1)))
	var right_button := InterfaceTheme.button("▶", func(): pan_grid(Vector2i(1, 0)))
	pan_buttons = [up, left_button, down, right_button]
	for button: Button in pan_buttons:
		button.custom_minimum_size = Vector2(36, 30)
		pan_row.add_child(button)
	right.add_child(pan_row)
	pan_row.visible = not read_only
	grid = BuildGrid.new()
	right.add_child(grid)
	grid.picked.connect(select_cell)
	x_control.value_changed.connect(func(value: float): select_cell(Vector3i(int(value), selected_cell.y, selected_cell.z)))
	z_control.value_changed.connect(func(value: float): select_cell(Vector3i(selected_cell.x, selected_cell.y, int(value))))
	deck_control.value_changed.connect(func(value: float): select_cell(Vector3i(selected_cell.x, int(value), selected_cell.z)))
	selection = InterfaceTheme.label("", 14, InterfaceTheme.MUTED)
	right.add_child(selection)
	_update_selection()
	refresh(modules)

func _coordinate_spin() -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = -GameState.SHIP_CELL_LIMIT
	spin.max_value = GameState.SHIP_CELL_LIMIT
	spin.step = 1
	spin.rounded = true
	spin.custom_minimum_size.x = 100
	return spin

func select_cell(cell: Vector3i) -> void:
	var limit: int = GameState.SHIP_CELL_LIMIT
	selected_cell = Vector3i(clampi(cell.x, -limit, limit), clampi(cell.y, -limit, limit), clampi(cell.z, -limit, limit))
	if grid != null:
		grid.center = Vector2i(selected_cell.x, selected_cell.z)
		grid.layer = selected_cell.y
		grid.cell = selected_cell
		grid.queue_redraw()
	if x_control != null:
		x_control.set_value_no_signal(selected_cell.x)
		z_control.set_value_no_signal(selected_cell.z)
		deck_control.set_value_no_signal(selected_cell.y)
	_update_selection()

func pan_grid(delta: Vector2i) -> void:
	if grid == null:
		return
	var limit: int = GameState.SHIP_CELL_LIMIT
	var center := grid.center + delta
	center.x = clampi(center.x, -limit, limit)
	center.y = clampi(center.y, -limit, limit)
	select_cell(Vector3i(center.x, selected_cell.y, center.y))

func _update_selection() -> void:
	if selection != null:
		selection.text = "X %d  /  Deck %d  /  Z %d\nBounds ±%d  /  Modules %d/%d" % [selected_cell.x, selected_cell.y, selected_cell.z, GameState.SHIP_CELL_LIMIT, modules.size(), GameState.MAX_SHIP_MODULES]
		if read_only:
			selection.text = "Select a room on the plan."
			for module: Dictionary in modules:
				if Vector3i(module.x,module.y,module.z) == selected_cell:
					var room: String = layout.get("rooms",{}).get(ShipLayout.cell_key(selected_cell),ShipLayout.default_room(module.kind))
					selection.text = room.capitalize() + " / " + str(module.kind).capitalize()


func refresh(values: Array) -> void:
	modules = values.duplicate(true)
	if preview != null:
		preview.build(modules, "player", layout)
		var low := Vector3.ZERO
		var high := Vector3.ZERO
		for item: Dictionary in modules:
			var cell := Vector3(item.x, item.y, item.z)
			low = low.min(cell)
			high = high.max(cell)
		var extent := (high - low) * ShipVisual.CELL_SIZE + ShipBlueprint.PRESSURE_SIZE
		preview_camera.size = maxf(9.5, extent.length() * 1.2)
		preview_camera.position = Vector3(19, 15, 24).normalized() * maxf(40.0, extent.length() * 1.7)
		preview_camera.look_at(Vector3.ZERO)
		grid.modules = modules
		grid.queue_redraw()
		_update_selection()

func _process(delta: float) -> void:
	if orbit != null:
		orbit.rotation.y += delta * 0.15
