extends Control
## Starforge welcome / title baseline.
## Left rail is a solid Void Navy panel; Start enters the lobby, Exit quits.

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"

@onready var _start: Button = %StartButton
@onready var _options: Button = %OptionsButton
@onready var _exit: Button = %ExitButton
@onready var _options_note: Label = %OptionsNote

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_start.pressed.connect(_on_start)
	_options.pressed.connect(_on_options)
	_exit.pressed.connect(_on_exit)
	_options_note.visible = false
	MenuSFX.bind_button(_start)
	MenuSFX.bind_button(_options)
	MenuSFX.bind_button(_exit)
	_start.grab_focus()

func _on_start() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_options() -> void:
	_options_note.visible = true
	_options_note.text = "Options — coming soon"

func _on_exit() -> void:
	get_tree().quit()
