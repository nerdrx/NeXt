class_name GalaxyChart
extends Control

signal selected(address: int)
var current: int = 0
var destination: int = 7919
var points: Array[Dictionary] = []
var zoom: float = 1.0
var pan := Vector2.ZERO
var dragging: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(650, 370)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	tooltip_text = "Click a star to inspect. Wheel to zoom. Right-drag to pan."
	_rebuild()

func configure(address: int) -> void:
	current = address
	destination = address
	_rebuild()

func _rebuild() -> void:
	points.clear()
	points.append({"address": current, "point": Vector2.ZERO})
	for i in range(1, 25):
		var angle: float = i * 2.39996
		var radius: float = sqrt(float(i)) * 30.0
		points.append({"address": (current + i * 7919) % Universe.SYSTEM_LIMIT, "point": Vector2(cos(angle), sin(angle)) * radius})
	queue_redraw()

func _point(point: Vector2) -> Vector2:
	return size * 0.5 + point * zoom + pan

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = minf(zoom * 1.12, 3.0)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = maxf(zoom / 1.12, 0.65)
		if event.button_index == MOUSE_BUTTON_RIGHT: dragging = event.pressed
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			for star: Dictionary in points:
				if _point(star.point).distance_to(event.position) < 16:
					destination = int(star.address)
					selected.emit(destination)
					break
		queue_redraw()
	elif event is InputEventMouseMotion and dragging:
		pan += event.relative
		queue_redraw()

func _draw() -> void:
	draw_style_box(InterfaceTheme.box(Color("080f1c"), Color("243a4b")), Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	for x in range(20, int(size.x), 40):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.22, 0.35, 0.48, 0.12))
	for y in range(20, int(size.y), 40):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.22, 0.35, 0.48, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3391
	for i in range(130):
		var pos := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		draw_circle(pos, rng.randf_range(0.5, 1.2), Color(0.6, 0.75, 0.9, 0.3))
	for star: Dictionary in points:
		var pos: Vector2 = _point(star.point)
		if not Rect2(Vector2(18, 18), size - Vector2(36, 36)).has_point(pos): continue
		var data: Dictionary = Universe.system_data(int(star.address))
		var active: bool = int(star.address) == destination
		if active:
			draw_line(_point(Vector2.ZERO), pos, Color(0.39, 0.9, 0.87, 0.4), 1.0, true)
			draw_arc(pos, 13, 0, TAU, 40, InterfaceTheme.CYAN, 1.5, true)
		draw_circle(pos, 8, Color(data.star_color, 0.08))
		draw_circle(pos, 3.5 if active else 2.5, data.star_color)
		if active or star.address == current:
			draw_string(font, pos + Vector2(17, 5), data.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, InterfaceTheme.WHITE)
	draw_string(font, Vector2(18, 25), "STELLAR CARTOGRAPHY    /    1,000,000,000 ADDRESSES", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, InterfaceTheme.MUTED)
	draw_string(font, Vector2(18, size.y - 16), "TOPOLOGICAL ROUTE VIEW    •    SCROLL TO ZOOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, InterfaceTheme.MUTED)
