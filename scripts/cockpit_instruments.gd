class_name CockpitInstruments
extends Node

# Small, physical displays share the cockpit's transform; the HUD remains readable
# independently of camera field of view and future authored cockpit replacements.
var game: Node3D
var readouts: Array[Label3D] = []
var bars: Array[MeshInstance3D] = []
var speed_label: Label3D
var mode_label: Label3D
var _clock := 0.0

func _ready() -> void:
	var cockpit: Node3D = game.pilot._cockpit
	var left: Node3D = cockpit.get_node("LeftDisplay")
	var right: Node3D = cockpit.get_node("RightDisplay")
	for index in 3:
		var y := 0.052 - index * 0.045
		readouts.append(_label(left, Vector3(-0.14, y, 0.004), "", 18))
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.28, 0.002, 0.001)
		bar.mesh = box
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("73bcb5") if index != 2 else Color("b9a078")
		bar.material_override = material
		left.add_child(bar)
		bar.position = Vector3(0, y - 0.019, 0.004)
		bars.append(bar)
	_label(right, Vector3(-0.14, 0.052, 0.004), "FLIGHT TELEMETRY", 15)
	speed_label = _label(right, Vector3(-0.14, 0.012, 0.004), "", 25)
	mode_label = _label(right, Vector3(-0.14, -0.038, 0.004), "", 16)
	refresh()

func _process(delta: float) -> void:
	_clock += delta
	if _clock < 0.1 or not game.pilot.flying: return
	_clock = 0.0
	refresh()

func refresh() -> void:
	var stats: Dictionary = game.state.ship_stats()
	var values := [game.state.hull / maxf(1, stats.max_hull), game.state.shield / maxf(1, stats.max_shield), game.state.fuel / 100.0]
	var names := ["HULL", "SHIELD", "FUEL"]
	for index in 3:
		var ratio := clampf(values[index], 0, 1)
		readouts[index].text = "%s   %03d%%" % [names[index], roundi(ratio * 100)]
		bars[index].scale.x = maxf(0.001, ratio)
		bars[index].position.x = -0.14 * (1.0 - ratio)
		readouts[index].modulate = Color("eb9f7c") if ratio < 0.2 else Color("b5cfce")
	speed_label.text = "%03d  m/s" % roundi(game.pilot.velocity.length())
	mode_label.text = "CRUISE ENGAGED" if game.pilot.autopilot_active else "FLIGHT ASSIST"

func _label(parent: Node3D, point: Vector3, text: String, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.00065
	label.outline_size = 0
	label.modulate = Color("b5cfce")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(label)
	label.position = point
	return label
