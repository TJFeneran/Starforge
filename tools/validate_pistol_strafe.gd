extends SceneTree
## Smoke test: pistol strafe clips install and aim locomotion picks L/R.
## godot --headless --path . --script tools/validate_pistol_strafe.gd


func _init() -> void:
	call_deferred("_run")


func _find_anim(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_anim(child)
		if found:
			return found
	return null


func _run() -> void:
	var failures := 0
	var player_ps := load("res://scenes/player/player.tscn") as PackedScene
	if player_ps == null:
		push_error("player.tscn failed to load")
		quit(1)
		return
	var player := player_ps.instantiate()
	root.add_child(player)
	await process_frame
	await process_frame

	var anim := _find_anim(player.get_node("Visual/Model"))
	if anim == null:
		push_error("AnimationPlayer missing")
		failures += 1
	else:
		for clip in ["loco/pistol_strafe_left", "loco/pistol_strafe_right", "loco/pistol_run", "loco/pistol_aim"]:
			if not anim.has_animation(clip):
				push_error("Missing clip %s" % clip)
				failures += 1
		player.set("_aim_move_input", Vector2(-1, 0))
		var left: String = player.call("_aim_move_clip")
		player.set("_aim_move_input", Vector2(1, 0))
		var right: String = player.call("_aim_move_clip")
		player.set("_aim_move_input", Vector2(0, 1))
		var forward: String = player.call("_aim_move_clip")
		if left != "loco/pistol_strafe_left":
			push_error("Expected left strafe, got %s" % left)
			failures += 1
		if right != "loco/pistol_strafe_right":
			push_error("Expected right strafe, got %s" % right)
			failures += 1
		if forward != "loco/pistol_run":
			push_error("Expected forward pistol run, got %s" % forward)
			failures += 1

	player.queue_free()
	await process_frame
	print("PISTOL STRAFE VALIDATION: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
