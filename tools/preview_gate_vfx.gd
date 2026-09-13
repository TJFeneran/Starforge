extends SceneTree

var frames := 0
var _lobby: Node3D
var _armed_preview := false

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	var lobby := load("res://scenes/lobby/lobby.tscn").instantiate() as Node3D
	root.add_child(lobby)
	_lobby = lobby
	_armed_preview = "--armed" in OS.get_cmdline_user_args()
	var camera := Camera3D.new()
	lobby.add_child(camera)
	camera.global_position = Vector3(4.0, 6.5, 1.0)
	camera.look_at(Vector3(0, 8.3, -14))
	if "--workshop" in OS.get_cmdline_user_args():
		camera.global_position = Vector3(-4.0, 4.0, 7.0)
		camera.look_at(Vector3(-11.4, 0.8, 6.0))
	if _armed_preview:
		camera.global_position = Vector3(3.0, 4.5, 0.5)
		camera.look_at(Vector3(0, 4.4, -12))
	if _armed_preview and "--closeup" in OS.get_cmdline_user_args():
		camera.global_position = Vector3(0.6, 3.3, -6.3)
		camera.look_at(Vector3(0, 3.65, -11.95))
	camera.fov = 58.0
	camera.make_current()

func _process(_delta: float) -> bool:
	frames += 1
	if _armed_preview and frames == 30:
		var destination := MapDestination.new()
		destination.title = "Frontier Outpost"
		destination.available = true
		destination.scene_path = "res://scenes/field/forge_field.tscn"
		_lobby.get_node("HologramMap").destination_selected.emit(destination)
	if frames == (240 if _armed_preview else 140):
		_capture.call_deferred()
	return false

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var output := "res://assets/source/blender/gate_optimization/gem_vfx_lobby.png"
	if _armed_preview:
		output = "/tmp/starforge_gate_closeup.png" if "--closeup" in OS.get_cmdline_user_args() else "/tmp/starforge_gate_armed.png"
	if "--workshop" in OS.get_cmdline_user_args():
		output = "res://assets/source/blender/workshop_floor_plaques.png"
	root.get_texture().get_image().save_png(output)
	print("GATE_VFX_CAPTURED")
	quit()
