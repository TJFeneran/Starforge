extends SceneTree

var frames := 0

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	var lobby := load("res://scenes/lobby/lobby.tscn").instantiate() as Node3D
	root.add_child(lobby)
	var camera := Camera3D.new()
	lobby.add_child(camera)
	camera.global_position = Vector3(4.0, 6.5, 1.0)
	camera.look_at(Vector3(0, 8.3, -14))
	if "--workshop" in OS.get_cmdline_user_args():
		camera.global_position = Vector3(-4.0, 4.0, 7.0)
		camera.look_at(Vector3(-11.4, 0.8, 6.0))
	camera.fov = 58.0
	camera.make_current()

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 140:
		_capture.call_deferred()
	return false

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var output := "res://assets/source/blender/gate_optimization/gem_vfx_lobby.png"
	if "--workshop" in OS.get_cmdline_user_args():
		output = "res://assets/source/blender/workshop_floor_plaques.png"
	root.get_texture().get_image().save_png(output)
	print("GATE_VFX_CAPTURED")
	quit()
