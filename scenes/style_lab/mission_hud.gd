extends CanvasLayer

@onready var _objective: Label = $Margin/VBox/Objective
@onready var _hint: Label = $Margin/VBox/Hint
@onready var _banner: Label = $Banner
@onready var _hp: Label = $HpMargin/Hp


func set_objective(text: String, hint: String = "") -> void:
	_objective.text = text
	_hint.text = hint
	_hint.visible = not hint.is_empty()


func set_player_hp(current: float, maximum: float) -> void:
	_hp.text = "HP  %d / %d" % [int(round(current)), int(round(maximum))]


func show_banner(text: String, seconds: float = 3.0) -> void:
	_banner.text = text
	_banner.visible = true
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(_banner):
		_banner.visible = false
