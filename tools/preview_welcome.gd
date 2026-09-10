extends SceneTree

var frames := 0

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	var welcome: Control = load("res://scenes/ui/welcome_screen.tscn").instantiate() as Control
	root.add_child(welcome)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 40:
		_capture.call_deferred()
	return false

func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://assets/ui/welcome_preview.png")
	print("WELCOME_PREVIEW_CAPTURED")
	quit()
