extends SceneTree

func _initialize() -> void:
	root.add_child.call_deferred(load("res://tests/crew_gameplay_runner.gd").new())
