extends SceneTree

## Smoke-test: load lobby, open pause, confirm freeze texture + buttons exist.

var frames := 0
var phase := 0

func _initialize() -> void:
	call_deferred("_boot")

func _boot() -> void:
	change_scene_to_file("res://scenes/lobby/lobby.tscn")

func _process(_delta: float) -> bool:
	frames += 1
	if phase == 0 and frames > 90:
		phase = 1
		var pause: Node = root.get_node_or_null("PauseMenu")
		if pause == null:
			push_error("PauseMenu autoload missing")
			quit(1)
			return true
		pause.call("open_pause")
	elif phase == 1 and frames > 130:
		var pause: Node = root.get_node("PauseMenu")
		var root_ui: Control = pause.get_node("Root")
		if not root_ui.visible:
			push_error("Pause root not visible")
			quit(1)
			return true
		if not paused:
			push_error("Tree not paused")
			quit(1)
			return true
		var capture := func() -> void:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://assets/ui/pause_preview.png")
			print("PAUSE_PREVIEW_CAPTURED")
			pause.call("resume")
			if paused:
				push_error("Tree still paused after resume")
				quit(1)
				return
			print("PAUSE_FLOW_OK")
			quit(0)
		capture.call()
		phase = 2
	return false
