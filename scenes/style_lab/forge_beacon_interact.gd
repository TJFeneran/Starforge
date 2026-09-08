extends Node3D

## Press interact nearby to attune the forge beacon (tiny loop beat).

signal attuned

@export var interact_range := 2.4
@export var prompt_text := "E  Attune Beacon"
@export var attuned_text := "Beacon Attuned"

@onready var _area: Area3D = $Area3D
@onready var _prompt: Label3D = $Prompt
@onready var _light: OmniLight3D = $"../BeaconLight"

var _player_inside := false
var _is_attuned := false
var _pulse_time := 0.0


func _ready() -> void:
	_prompt.text = prompt_text
	_prompt.visible = false
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or _is_attuned:
		return
	if event.is_action_pressed("interact"):
		_attune()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _is_attuned or _light == null:
		return
	_pulse_time += delta
	_light.light_energy = 4.5 + sin(_pulse_time * 4.0) * 2.5


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_inside = true
		if not _is_attuned:
			_prompt.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_inside = false
		_prompt.visible = false


func _attune() -> void:
	_is_attuned = true
	_prompt.text = attuned_text
	_prompt.visible = true
	_pulse_time = 0.0
	if _light:
		_light.light_color = Color(1.0, 0.72, 0.28)
		_light.omni_range = 12.0
	attuned.emit()
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(_prompt) and not _player_inside:
		_prompt.visible = false
