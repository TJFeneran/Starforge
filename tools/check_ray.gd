extends SceneTree
## Focused import check for the Crescent ray, run after ray.glb is built.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://scenes/sandbox/rift_ray_preview.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.autoplay = false
	assert(scene.clip_names.size() == 9, "Missing exported Ray animation clips")
	var skeleton: Skeleton3D = scene.model.find_child("*Skeleton*", true, false)
	assert(skeleton != null and skeleton.get_bone_count() >= 8, "Missing fin/tail rig")
	var fin_left := skeleton.find_bone("fin_tip.L")
	var fin_right := skeleton.find_bone("fin_tip.R")
	var tail := skeleton.find_bone("tail_tip")
	var root_bone := skeleton.find_bone("root")
	assert(fin_left >= 0 and fin_right >= 0 and tail >= 0 and root_bone >= 0, "Missing named fin/tail/root bones")
	var max_loop_position_error := 0.0
	var max_loop_rotation_error := 0.0
	for clip: String in scene.CLIPS:
		var name: String = scene.clip_names[clip]
		var animation: Animation = scene.player.get_animation(name)
		assert(animation.length >= .5 and animation.get_track_count() >= 4, "Empty Ray clip: " + clip)
		scene.player.play(name)
		scene.player.seek(0, true)
		var starts: Array[Transform3D] = []
		for i in skeleton.get_bone_count(): starts.append(skeleton.get_bone_pose(i))
		var left_start := skeleton.get_bone_global_pose(fin_left).origin
		var right_start := skeleton.get_bone_global_pose(fin_right).origin
		var root_start := skeleton.get_bone_pose_position(root_bone)
		var max_fin_movement := 0.0
		for step in range(9):
			scene.player.seek(animation.length * step / 8.0, true)
			for i in skeleton.get_bone_count():
				assert(skeleton.get_bone_pose(i).is_finite(), "Invalid Ray pose: " + clip)
			max_fin_movement = maxf(max_fin_movement, maxf(left_start.distance_to(skeleton.get_bone_global_pose(fin_left).origin), right_start.distance_to(skeleton.get_bone_global_pose(fin_right).origin)))
			if clip != "death":
				var root_offset := skeleton.get_bone_pose_position(root_bone) - root_start
				assert(Vector2(root_offset.x, root_offset.y).length() < .001, "Ray root drifts horizontally: " + clip)
		if clip in ["hover_idle", "fly_forward", "bank_left", "bank_right", "death"]:
			assert(max_fin_movement > .015, "Ray fins are static: " + clip)
		if clip in scene.LOOPING:
			animation.loop_mode = Animation.LOOP_NONE
			scene.player.seek(animation.length, true)
			for i in skeleton.get_bone_count():
				var end := skeleton.get_bone_pose(i)
				max_loop_position_error = maxf(max_loop_position_error, starts[i].origin.distance_to(end.origin))
				max_loop_rotation_error = maxf(max_loop_rotation_error, starts[i].basis.get_rotation_quaternion().angle_to(end.basis.get_rotation_quaternion()))
			animation.loop_mode = Animation.LOOP_LINEAR
		print("RAY_CLIP ", clip, " ", animation.length, " seconds / ", animation.get_track_count(), " tracks")
	assert(max_loop_position_error < .001, "Ray loop position seam")
	assert(max_loop_rotation_error < .002, "Ray loop rotation seam")
	scene._toggle_comparison()
	assert(scene.comparing and scene.source != null, "Ray source comparison failed")
	scene._toggle_comparison()
	scene._play(2)
	assert(scene.CLIPS[scene.clip_index] == "bank_left", "Ray clip selection failed")
	print("RAY_PASS: 9 clips, source comparison, loop position error=", max_loop_position_error, ", rotation error=", max_loop_rotation_error)
	scene.queue_free()
	await process_frame
	quit()
