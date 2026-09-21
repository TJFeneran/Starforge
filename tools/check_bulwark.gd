extends SceneTree
## Verify the exported GLB, clip seams, in-place root and review controls.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://scenes/sandbox/bulwark_preview.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.autoplay = false
	assert(scene.clip_names.size() == 7, "Missing exported Bulwark animation clips")
	var skeleton: Skeleton3D = scene.skeleton
	assert(skeleton.get_bone_count() >= 20, "Incomplete mechanical skeleton")
	var player: AnimationPlayer = scene.player
	var root_bone := skeleton.find_bone("root")
	var max_loop_position_error := 0.0
	var max_loop_rotation_error := 0.0
	for clip: String in scene.CLIPS:
		var name: String = scene.clip_names[clip]
		var animation := player.get_animation(name)
		assert(animation.length > .4, "Empty or truncated clip: " + clip)
		# Godot removes constant rest tracks during import; moving clips still need the limbs.
		assert(animation.get_track_count() >= 10, "Missing motion tracks: " + clip)
		player.play(name)
		player.seek(0, true)
		var starts: Array[Transform3D] = []
		for i in skeleton.get_bone_count(): starts.append(skeleton.get_bone_pose(i))
		var foot_bone := skeleton.find_bone("foot.L")
		var foot_start := skeleton.get_bone_global_pose(foot_bone).origin
		var max_foot_movement := 0.0
		for step in range(9):
			player.seek(animation.length * step / 8.0, true)
			for i in skeleton.get_bone_count():
				assert(skeleton.get_bone_pose(i).is_finite(), "Invalid pose: " + clip)
			max_foot_movement = maxf(max_foot_movement, foot_start.distance_to(skeleton.get_bone_global_pose(foot_bone).origin))
			if clip != "death":
				assert(skeleton.get_bone_pose_position(root_bone).length() < .001, "Locomotion root drifts")
		if clip == "walk":
			assert(max_foot_movement > .15, "Exported locomotion is static: " + clip)
		# Temporarily disable looping so seeking the endpoint cannot wrap to zero.
		if clip in scene.LOOPING:
			animation.loop_mode = Animation.LOOP_NONE
			player.seek(animation.length, true)
			for i in skeleton.get_bone_count():
				var end := skeleton.get_bone_pose(i)
				max_loop_position_error = maxf(max_loop_position_error, starts[i].origin.distance_to(end.origin))
				max_loop_rotation_error = maxf(max_loop_rotation_error, starts[i].basis.get_rotation_quaternion().angle_to(end.basis.get_rotation_quaternion()))
			animation.loop_mode = Animation.LOOP_LINEAR
		print("BULWARK_CLIP ", clip, " ", animation.length, " seconds / ", animation.get_track_count(), " tracks")
	assert(max_loop_position_error < .001, "Loop position seam")
	assert(max_loop_rotation_error < .002, "Loop rotation seam")
	scene._toggle_comparison()
	assert(scene.comparing and scene.reference != null, "Source comparison failed")
	scene._toggle_comparison()
	scene._play(2)
	assert(scene.CLIPS[scene.clip_index] == "attack_anticipation", "Clip selection failed")
	print("BULWARK_PASS: 7 clips, ", skeleton.get_bone_count(), " bones, source comparison, loop position error=", max_loop_position_error, ", rotation error=", max_loop_rotation_error)
	scene.queue_free()
	await process_frame
	quit()
