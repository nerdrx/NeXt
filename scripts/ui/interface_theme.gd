class_name InterfaceTheme
extends RefCounted

const INK := Color("090f1c")
const PANEL := Color(0.027, 0.05, 0.085, 0.95)
const CYAN := Color("63e9dd")
const GOLD := Color("ecbb74")
const WHITE := Color("e5edf6")
const MUTED := Color("899caf")

static func box(color: Color, border: Color = Color.TRANSPARENT, radius: int = 8, margin: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", WHITE)
	theme.set_color("font_color", "Button", WHITE)
	theme.set_color("font_hover_color", "Button", CYAN)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color("526477"))
	theme.set_stylebox("normal", "Button", box(Color("122234"), Color("26394a"), 5, 12))
	theme.set_stylebox("hover", "Button", box(Color("1b3544"), CYAN, 5, 12))
	theme.set_stylebox("pressed", "Button", box(CYAN, CYAN, 5, 12))
	theme.set_stylebox("focus", "Button", box(Color.TRANSPARENT, GOLD, 5, 12))
	theme.set_stylebox("disabled", "Button", box(Color("101824"), Color("1b2938"), 5, 12))
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, Color("243a4b")))
	theme.set_stylebox("normal", "LineEdit", box(Color("101d2c"), Color("31485c"), 5, 12))
	theme.set_stylebox("focus", "LineEdit", box(Color("142938"), CYAN, 5, 12))
	theme.set_color("font_color", "LineEdit", WHITE)
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	return theme

static func label(text: String, size: int = 18, color: Color = WHITE) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	return item

static func button(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 44
	item.pressed.connect(action)
	return item
