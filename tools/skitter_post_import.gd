@tool
extends EditorScenePostImport
## Preserve loop policy and melee contact marker after every GLB import.

func _post_import(scene: Node) -> Object:
	var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	if player == null: return scene
	for name in player.get_animation_list():
		var animation := player.get_animation(name)
		animation.loop_mode = Animation.LOOP_LINEAR if name in ["idle", "walk", "run"] else Animation.LOOP_NONE
		if name == "attack": animation.add_marker("contact", 8.0 / 30.0)
	return scene
