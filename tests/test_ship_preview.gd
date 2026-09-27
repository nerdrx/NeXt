extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var parent := Control.new()
	root.add_child(parent)
	var designer := _new_designer()
	parent.add_child(designer)
	await process_frame
	await process_frame
	designer._process(0.1)
	assert(designer.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "visible preview renders")
	var visible_angle := designer.orbit.rotation.y
	designer._process(0.1)
	assert(designer.orbit.rotation.y > visible_angle, "visible preview rotates")

	parent.hide()
	await process_frame
	await process_frame
	designer._process(0.1)
	assert(designer.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden preview stops rendering")
	var hidden_angle := designer.orbit.rotation.y
	await process_frame
	await process_frame
	designer._process(0.1)
	assert(is_equal_approx(designer.orbit.rotation.y, hidden_angle), "hidden preview stops rotating")

	parent.show()
	await process_frame
	await process_frame
	designer._process(0.1)
	assert(designer.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "shown preview resumes rendering")
	var resumed_angle := designer.orbit.rotation.y
	designer._process(0.1)
	assert(designer.orbit.rotation.y > resumed_angle, "shown preview resumes rotating")

	parent.queue_free()
	await process_frame
	await process_frame
	for _index in range(3):
		var repeated_parent := Control.new()
		root.add_child(repeated_parent)
		var repeated_designer := _new_designer()
		repeated_parent.add_child(repeated_designer)
		await process_frame
		await process_frame
		repeated_parent.queue_free()
		await process_frame
		await process_frame
	print("SHIP_PREVIEW_OK: hidden rendering disabled, rotation paused, visible resume and repeated teardown")
	quit()


func _new_designer() -> ShipDesigner:
	var designer := ShipDesigner.new()
	designer.read_only = true
	var blueprint: Dictionary = ShipBlueprint.family("merchant")
	designer.modules = blueprint.modules.duplicate(true)
	designer.layout = blueprint.layout.duplicate(true)
	return designer
