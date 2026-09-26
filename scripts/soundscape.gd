class_name Soundscape
extends Node

var engine: AudioStreamPlayer
var shot: AudioStreamWAV
var alert: AudioStreamWAV
var jump: AudioStreamWAV
var muted: bool = false

func _ready() -> void:
	if muted or DisplayServer.get_name() == "headless": return
	shot = _tone(0.15, 920, 95, 0.3)
	alert = _tone(0.18, 540, 480, 0.06)
	jump = _tone(1.2, 70, 1300, 0.2)
	engine = AudioStreamPlayer.new()
	var drone := _tone(2, 52, 52, 0.12, true)
	engine.stream = drone
	engine.volume_db = -38
	add_child(engine)
	engine.play()

func _tone(seconds: float, start: float, finish: float, noise: float, loop: bool = false) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(seconds * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase: float = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 415
	for i in count:
		var t: float = float(i) / count
		phase += TAU * lerpf(start, finish, t) / rate
		var envelope: float = 0.3 if loop else sin(minf(t * 12, 1) * PI * 0.5) * pow(1 - t, 2)
		var sample: float = (sin(phase) * 0.5 + sin(phase * 0.5) * 0.25 + rng.randf_range(-noise, noise)) * envelope
		bytes.encode_s16(i * 2, int(clampf(sample, -1, 1) * 24000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream

func play_sound(kind: String) -> void:
	if muted or shot == null: return
	var player := AudioStreamPlayer.new()
	player.stream = shot if kind == "shot" else (jump if kind == "jump" else alert)
	player.volume_db = -19 if kind == "shot" else -24
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func flight(speed_ratio: float, active: bool) -> void:
	if engine == null: return
	engine.volume_db = -80 if muted else (-31 + minf(speed_ratio, 3) * 3 if active else -45)
	engine.pitch_scale = 0.8 + minf(speed_ratio, 3) * 0.16

func _exit_tree() -> void:
	if is_instance_valid(engine):
		engine.stop()
		engine.stream = null

func shutdown() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
			child.queue_free()
	engine = null
