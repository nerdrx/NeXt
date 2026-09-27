class_name FlightFrame
extends RefCounted

const CULL_DISTANCE: float = 60000.0

var _tracked: Dictionary = {}


func track(node: Node3D, origin: SectorPosition, absolute: SectorPosition = null) -> bool:
	if not is_instance_valid(node) or origin == null:
		return false
	var address := SectorPosition.new(absolute.sector, absolute.local) if absolute != null else SectorPosition.new(origin.sector, origin.local)
	if absolute == null and not address.move_delta(node.position): return false
	var id: int = node.get_instance_id()
	var prior: Dictionary = _tracked.get(id, {})
	if not prior.is_empty() and bool(prior.get("culled", false)):
		_restore(node, prior.get("restore", {}))
	var entry := {"node": node, "address": address, "culled": false}
	_tracked[id] = entry
	_place(node, entry, origin)
	return true


func has_node(node: Node3D) -> bool:
	return is_instance_valid(node) and _tracked.has(node.get_instance_id())


func rebase(old_origin: SectorPosition, new_origin: SectorPosition) -> void:
	if old_origin == null or new_origin == null:
		return
	for id: int in _tracked.keys():
		var entry: Dictionary = _tracked[id]
		var node: Variant = entry.get("node")
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			_tracked.erase(id)
			continue
		if not bool(entry.get("culled", false)):
			var address: SectorPosition = entry.address
			address = SectorPosition.new(old_origin.sector, old_origin.local)
			if not address.move_delta(node.position):
				continue
			entry.address = address
		var relative: Variant = (entry.address as SectorPosition).relative_to(new_origin, CULL_DISTANCE)
		if relative == null:
			if not bool(entry.get("culled", false)):
				entry["restore"] = _capture(node)
				entry.culled = true
				_hide(node)
			else:
				continue
		else:
			var old_position: Vector3 = node.position
			node.position = relative
			if bool(entry.get("culled", false)):
				_restore(node, entry.get("restore", {}))
				entry.erase("restore")
				entry.culled = false
			_apply_origin_shift(node, old_position - relative)
		_tracked[id] = entry


func _place(node: Node3D, entry: Dictionary, origin: SectorPosition) -> void:
	var relative: Variant = (entry.address as SectorPosition).relative_to(origin, CULL_DISTANCE)
	if relative == null:
		entry["restore"] = _capture(node)
		entry.culled = true
		_hide(node)
		return
	var old_position: Vector3 = node.position
	node.position = relative
	var shift: Vector3 = old_position - relative
	if not shift.is_zero_approx(): _apply_origin_shift(node, shift)


func clear() -> void:
	for entry: Dictionary in _tracked.values():
		var node: Variant = entry.get("node")
		if is_instance_valid(node) and bool(entry.get("culled", false)):
			_restore(node, entry.get("restore", {}))
	_tracked.clear()


func _capture(root: Node3D) -> Dictionary:
	var visibility: Array[Dictionary] = []
	var collisions: Array[Dictionary] = []
	for node: Node in _tree_nodes(root):
		if node is VisualInstance3D:
			visibility.append({"node": node, "visible": node.visible})
		elif node is CanvasItem:
			visibility.append({"node": node, "visible": node.visible})
		if node is CollisionObject3D:
			collisions.append({"node": node, "layer": node.collision_layer, "mask": node.collision_mask})
	return {"visible": root.visible, "process_mode": root.process_mode, "visibility": visibility, "collisions": collisions}


func _hide(root: Node3D) -> void:
	root.visible = false
	root.process_mode = Node.PROCESS_MODE_DISABLED
	root.set_meta("spatial_culled", true)
	for node: Node in _tree_nodes(root):
		if node is VisualInstance3D or node is CanvasItem:
			node.set("visible", false)
		if node is CollisionObject3D:
			node.collision_layer = 0
			node.collision_mask = 0


func _restore(root: Node3D, state: Dictionary) -> void:
	if state.is_empty():
		return
	root.visible = bool(state.get("visible", true))
	root.process_mode = int(state.get("process_mode", Node.PROCESS_MODE_INHERIT))
	for item: Dictionary in state.get("visibility", []):
		var node: Variant = item.get("node")
		if is_instance_valid(node):
			node.set("visible", bool(item.get("visible", true)))
	for item: Dictionary in state.get("collisions", []):
		var node: Variant = item.get("node")
		if is_instance_valid(node):
			node.collision_layer = int(item.get("layer", 0))
			node.collision_mask = int(item.get("mask", 0))
	root.set_meta("spatial_culled", false)


func _tree_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child: Node in root.get_children():
		result.append_array(_tree_nodes(child))
	return result


func _apply_origin_shift(node: Node3D, delta: Vector3) -> void:
	node.reset_physics_interpolation()
	if node.has_method("apply_origin_shift"):
		node.call("apply_origin_shift", delta)
