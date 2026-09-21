@tool
extends EditorScenePostImport
## Persist clip loop flags and the recoil event when the GLB is reimported.

func _post_import(scene: Node) -> Object:
	var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	if player == null: return scene
	var looping := ["idle", "walk", "run", "strafe_left", "strafe_right", "aim"]
	for name in player.get_animation_list():
		var animation := player.get_animation(name)
		animation.loop_mode = Animation.LOOP_LINEAR if name in looping else Animation.LOOP_NONE
		if name == "attack": animation.add_marker("fire", 4.0 / 30.0)
	return scene
