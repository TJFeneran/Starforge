extends Node
## Shared UI hover one-shot for welcome / pause menu buttons.

const HOVER_PATH := "res://assets/audio/ui/707041__vilkas_sound__vs-button-click-04.mp3"

@export_range(-40.0, 6.0, 0.1) var hover_volume_db: float = -10.0

var _player: AudioStreamPlayer
var _stream: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "HoverPlayer"
	_player.bus = &"UI"
	add_child(_player)
	if ResourceLoader.exists(HOVER_PATH):
		_stream = load(HOVER_PATH) as AudioStream
		_player.stream = _stream


func play_hover() -> void:
	if _player == null or _stream == null:
		return
	_player.volume_db = hover_volume_db
	_player.pitch_scale = randf_range(0.98, 1.02)
	_player.play()


func bind_button(button: BaseButton) -> void:
	if button == null:
		return
	if not button.mouse_entered.is_connected(play_hover):
		button.mouse_entered.connect(play_hover)
	if not button.pressed.is_connected(play_hover):
		button.pressed.connect(play_hover)
