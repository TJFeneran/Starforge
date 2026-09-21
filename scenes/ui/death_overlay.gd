extends CanvasLayer
## Centered death overlay. Respawn returns to the lobby launch spawn.

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"

@onready var _root: Control = $Root
@onready var _respawn: Button = %RespawnButton

var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	_root.visible = false
	_respawn.pressed.connect(_on_respawn_pressed)
	MenuSFX.bind_button(_respawn)


func is_open() -> bool:
	return _open


func show_death() -> void:
	if _open:
		return
	PauseMenu.resume()
	var prompt := get_tree().root.get_node_or_null("InteractPrompt")
	if prompt != null and prompt.has_method("begin_modal"):
		prompt.begin_modal()
	_open = true
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_respawn.grab_focus()


func hide_death() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	var prompt := get_tree().root.get_node_or_null("InteractPrompt")
	if prompt != null and prompt.has_method("end_modal"):
		prompt.end_modal()


func _on_respawn_pressed() -> void:
	if PlayerState.is_campaign_scene(get_tree().current_scene) and not PlayerState.respawn():
		_respawn.text = "Save failed — retry respawn"
		return
	hide_death()
	get_tree().paused = false
	get_tree().change_scene_to_file(LOBBY_SCENE)
