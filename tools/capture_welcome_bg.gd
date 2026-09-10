extends SceneTree

## Capture a cinematic lobby still for the welcome-screen backdrop.

var frames := 0

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	var lobby := load("res://scenes/lobby/lobby.tscn").instantiate() as Node3D
	root.add_child(lobby)
	var camera := Camera3D.new()
	lobby.add_child(camera)
	# Center hall looking toward the forge monument / gate.
	camera.global_position = Vector3(0.0, 3.2, 8.0)
	camera.look_at(Vector3(0.0, 5.5, -14.0))
	camera.fov = 55.0
	camera.make_current()

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 160:
		_capture.call_deferred()
	return false

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://assets/ui/welcome_lobby_source.png")
	print("WELCOME_BG_CAPTURED")
	quit()
