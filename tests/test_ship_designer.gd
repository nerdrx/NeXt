extends SceneTree

var request_count: int = 0
var last_kind: String = ""
var last_cell := Vector3i.ZERO
var last_remove: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _requested(kind: String, cell: Vector3i, remove: bool) -> void:
	request_count += 1
	last_kind = kind
	last_cell = cell
	last_remove = remove


func _run() -> void:
	var designer := ShipDesigner.new()
	root.add_child(designer)
	await process_frame
	designer.requested.connect(_requested)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(8 * 30 + 15, 8 * 30 + 15)
	designer.grid._gui_input(click)
	assert(designer.selected_cell == Vector3i(4, 0, 4), "grid input picks the coordinate under the pointer")

	designer.x_control.value = 16
	designer.z_control.value = 16
	designer.deck_control.value = 16
	assert(designer.selected_cell == Vector3i(16, 16, 16), "coordinate controls select high X, Z and deck values")
	assert(designer.grid.center == Vector2i(16, 16), "coordinate selection recenters the visible grid")

	click.position = Vector2(8 * 30 + 15, 8 * 30 + 15)
	designer.grid._gui_input(click)
	assert(designer.selected_cell == Vector3i(16, 16, 16), "clicking outside the build bounds leaves selection unchanged")
	designer.pan_buttons[3].pressed.emit()
	assert(designer.selected_cell == Vector3i(16, 16, 16), "panning clamps at the build edge")
	designer.pan_buttons[1].pressed.emit()
	assert(designer.selected_cell == Vector3i(15, 16, 16), "panning updates the visible highlighted selection")

	designer.select_cell(Vector3i(16, 16, 16))
	designer.install_button.pressed.emit()
	assert(request_count == 1 and last_kind == "cargo" and last_cell == Vector3i(16, 16, 16) and not last_remove, "install signal uses selected kind and high coordinate")

	var chosen := designer.selected_cell
	designer.refresh([{"kind": "core", "x": 0, "y": 0, "z": 0}, {"kind": "engine", "x": 16, "y": 16, "z": 16}])
	assert(designer.selected_cell == chosen and designer.grid.cell == chosen, "refresh preserves selected coordinate and highlight")
	assert(designer.preview_camera.size > 9.5 and designer.preview_camera.position.length() > 100.0 and designer.preview_camera.far > 90.0, "preview camera adapts to large ship designs")
	designer.queue_free()
	await process_frame
	quit()
