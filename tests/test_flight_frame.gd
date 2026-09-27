extends SceneTree

const FlightFrameScript = preload("res://scripts/flight_frame.gd")

class ShiftNode:
	extends Node3D
	var shifts: Array[Vector3] = []
	func apply_origin_shift(delta: Vector3) -> void:
		shifts.append(delta)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var frame = FlightFrameScript.new()
	var root_node := ShiftNode.new()
	root.add_child(root_node)
	var mesh := MeshInstance3D.new()
	root_node.add_child(mesh)
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 8
	root_node.add_child(body)
	var origin := SectorPosition.new()
	assert(frame.track(root_node, origin))
	root_node.position = Vector3(120, 25, -12)
	var near_origin := SectorPosition.new(Vector3i(0, 0, 0), Vector3(50, 0, 0))
	frame.rebase(origin, near_origin)
	assert(root_node.position.is_equal_approx(Vector3(70, 25, -12)), "nearby movement survives origin rebasing")
	assert(root_node.shifts.size() == 1 and root_node.shifts[0].is_equal_approx(Vector3(50, 0, 0)), "cached spatial references receive the rebase delta")
	var remote_origin := SectorPosition.new(Vector3i(100, 0, 0), Vector3.ZERO)
	frame.rebase(near_origin, remote_origin)
	assert(root_node.has_meta("spatial_culled") and root_node.get_meta("spatial_culled"), "distant spatial root is marked culled")
	assert(not root_node.visible and root_node.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(body.collision_layer == 0 and body.collision_mask == 0, "culled collision body is disabled")
	assert(root_node.position.is_equal_approx(Vector3(70, 25, -12)), "culled node keeps bounded prior local coordinates")
	frame.rebase(remote_origin, origin)
	assert(not root_node.get_meta("spatial_culled") and root_node.visible and root_node.process_mode == Node.PROCESS_MODE_INHERIT)
	assert(root_node.position.is_equal_approx(Vector3(120, 25, -12)), "returning to sector restores the moved object's nearby position")
	assert(body.collision_layer == 4 and body.collision_mask == 8, "return restores original collision settings")
	assert(mesh.visible and root_node.shifts.size() == 2 and root_node.shifts[1].is_equal_approx(Vector3(-50, 0, 0)))
	var generated := ShiftNode.new()
	generated.position = Vector3(15, 0, 0)
	root.add_child(generated)
	var far_address := SectorPosition.new(Vector3i(100, 0, 0), Vector3.ZERO)
	assert(frame.track(generated, origin, far_address) and generated.get_meta("spatial_culled") and frame.has_node(generated), "generated remote objects cull immediately from explicit addresses")
	assert(frame.track(generated, origin, far_address) and generated.get_meta("spatial_culled"), "retracking restores the saved state before culling again")
	frame.rebase(origin, far_address)
	assert(not generated.get_meta("spatial_culled") and generated.position == Vector3.ZERO, "generated object restores at its addressed origin")
	frame.clear()
	assert(not frame.has_node(root_node) and not frame.has_node(generated), "clear removes tracked nodes")
	print("Flight frame tests passed")
	quit()
