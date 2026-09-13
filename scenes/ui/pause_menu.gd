extends CanvasLayer
## Monument-frame pause overlay. Freezes + blurs the current frame, then shows
## Resume / Options / Exit. Options opens the shared OptionsMenu overlay.

@onready var _root: Control = $Root
@onready var _freeze: TextureRect = %FreezeFrame
@onready var _resume: Button = %ResumeButton
@onready var _options: Button = %OptionsButton
@onready var _exit: Button = %ExitButton

var _open := false
var _busy := false
var _was_mouse_captured := false
var _freeze_material: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_root.visible = false
	_freeze_material = _freeze.material as ShaderMaterial
	_resume.pressed.connect(resume)
	_options.pressed.connect(_on_options)
	_exit.pressed.connect(_on_exit)
	MenuSFX.bind_button(_resume)
	MenuSFX.bind_button(_options)
	MenuSFX.bind_button(_exit)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_welcome() or _busy or DeathOverlay.is_open() or OptionsMenu.is_open():
		return
	# Focused overlays (hologram map, future bench UIs) own Esc first.
	var prompt := _prompt()
	if not _open and prompt != null and prompt.is_modal_blocking():
		return
	if _open:
		resume()
	else:
		open_pause()
	get_viewport().set_input_as_handled()

func open_pause() -> void:
	if _open or _busy or _is_welcome() or DeathOverlay.is_open():
		return
	var prompt := _prompt()
	if prompt != null and prompt.is_modal_blocking():
		return
	_busy = true
	_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if prompt:
		prompt.begin_modal()
	await _capture_freeze_frame()
	_open = true
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resume.grab_focus()
	_busy = false

func resume() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false
	var prompt := _prompt()
	if prompt:
		prompt.end_modal()
	if _was_mouse_captured and not _is_welcome():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_options() -> void:
	OptionsMenu.open_options(_options)

func _on_exit() -> void:
	get_tree().paused = false
	get_tree().quit()

func _is_welcome() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return true
	var path := scene.scene_file_path
	if path.ends_with("welcome_screen.tscn") or path.ends_with("main.tscn"):
		return true
	return scene.get_node_or_null("WelcomeScreen") != null

func _prompt() -> Node:
	return get_tree().root.get_node_or_null("InteractPrompt")

func _capture_freeze_frame() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	# Keep enough resolution for a smooth Gaussian; mip lod does the heavy blur.
	var max_edge := 1920
	if maxi(image.get_width(), image.get_height()) > max_edge:
		var scale := float(max_edge) / float(maxi(image.get_width(), image.get_height()))
		image.resize(
			maxi(2, int(image.get_width() * scale)),
			maxi(2, int(image.get_height() * scale)),
			Image.INTERPOLATE_LANCZOS
		)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	if _freeze_material:
		_freeze_material.set_shader_parameter("freeze_tex", texture)
	_freeze.texture = texture
