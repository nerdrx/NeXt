extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var state := GameState.new()
	state.credits = 10000
	assert(state.hire("engineer").is_empty())
	var identity: String = state.crew[0].id
	var expected := CrewAppearance.palette(identity, "crew", false)
	var path := "user://crew-appearance-%d.json" % OS.get_process_id()
	assert(state.save(path).is_empty())
	var restored := GameState.new()
	assert(restored.load_save(path).is_empty())
	assert(CrewAppearance.palette(restored.crew[0].id, "crew", false) == expected)
	var colors := {}
	for index in 32:
		colors[CrewAppearance.palette("crew-appearance-%d" % index, "crew", false).suit] = true
	assert(colors.size() >= 4, "different crew identities produce visible finish variation")
	for member_id: String in [identity, str(restored.crew[0].id)]:
		var member := ShipCrew.new()
		member.actor_id = member_id
		root.add_child(member)
		member.set_physics_process(false)
		var torso := member._visual.get_child(0) as MeshInstance3D
		assert((torso.material_override as StandardMaterial3D).albedo_color == expected.suit,
			"live crew rig uses its persistent identity palette")
		var capsule := member.get_child(0) as CollisionShape3D
		assert(is_equal_approx((capsule.shape as CapsuleShape3D).radius, 0.42))
		assert(is_equal_approx((capsule.shape as CapsuleShape3D).height, 1.75))
		member.queue_free()
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("CREW_APPEARANCE_OK: identity palette, saved crew continuity, live rig and unchanged capsule")
	quit()
