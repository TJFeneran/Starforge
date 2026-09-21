extends SceneTree
## Verify Shieldback's imported rig, clips, movement, and source comparison.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://scenes/sandbox/rift_skitter_preview.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.autoplay = false
	assert(scene.clip_names.size() == 8, "Missing Shieldback clips")
	var skeleton: Skeleton3D = scene.skeleton
	assert(skeleton.get_bone_count() == 20, "Unexpected Shieldback skeleton")
	var player: AnimationPlayer = scene.player
	var root_bone := skeleton.find_bone("root")
	var largest_seam := 0.0
	for clip: String in scene.CLIPS:
		var animation := player.get_animation(scene.clip_names[clip])
		assert(animation.length > .5, "Empty or truncated clip: " + clip)
		assert(animation.get_track_count() >= 10, "Missing bone tracks: " + clip)
		player.play(scene.clip_names[clip])
		player.seek(0, true)
		var starts: Array[Transform3D] = []
		for i in skeleton.get_bone_count(): starts.append(skeleton.get_bone_pose(i))
		var foot_index := skeleton.find_bone("foot.front.L")
		var start := skeleton.get_bone_global_pose(foot_index).origin
		var movement := 0.0
		for step in range(9):
			player.seek(animation.length * step / 8.0, true)
			for i in skeleton.get_bone_count(): assert(skeleton.get_bone_pose(i).is_finite(), "Invalid pose: " + clip)
			movement = maxf(movement, start.distance_to(skeleton.get_bone_global_pose(foot_index).origin))
			if clip != "death": assert(skeleton.get_bone_pose_position(root_bone).length() < .001, "Root drifts: " + clip)
		if clip in ["walk", "run"]: assert(movement > .05, "Locomotion is static: " + clip)
		if clip in scene.LOOPING:
			animation.loop_mode = Animation.LOOP_NONE
			player.seek(animation.length, true)
			for i in skeleton.get_bone_count(): largest_seam = maxf(largest_seam, starts[i].origin.distance_to(skeleton.get_bone_pose(i).origin))
			animation.loop_mode = Animation.LOOP_LINEAR
		print("SKITTER_CLIP ", clip, " ", animation.length, " seconds / ", animation.get_track_count(), " tracks")
	assert(largest_seam < .002, "Loop seam")
	scene._toggle_comparison()
	assert(scene.comparing and scene.reference != null, "Source comparison failed")
	scene._toggle_comparison()
	print("SKITTER_PASS: 8 clips, 20 bones, source comparison, loop seam=", largest_seam)
	scene.queue_free()
	await process_frame
	quit()
