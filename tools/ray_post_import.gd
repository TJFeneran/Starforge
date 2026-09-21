@tool
extends EditorScenePostImport
## Persist Crescent Ray loop flags and the face-aperture attack contact marker.

func _post_import(scene: Node) -> Object:
	var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	if player == null: return scene
	var looping := ["hover_idle", "fly_forward", "bank_left", "bank_right"]
	for name in player.get_animation_list():
		var animation := player.get_animation(name)
		animation.loop_mode = Animation.LOOP_LINEAR if name in looping else Animation.LOOP_NONE
		if name == "attack": animation.add_marker("fire", 6.0 / 30.0)
	return scene
