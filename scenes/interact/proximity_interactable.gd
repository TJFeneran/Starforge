extends Area3D
class_name ProximityInteractable
## Reusable proximity + interact-action trigger. Drives InteractPrompt HUD.
## Prompt hovers at prompt_anchor (or this node + prompt_offset) and faces the camera.

signal interacted
signal player_entered
signal player_exited

@export var action_text := "Interact"
@export var input_action: StringName = &"interact"
## Local offset from this Area3D used when prompt_anchor is unset.
@export var prompt_offset := Vector3(0.0, 1.55, 0.0)
## Optional Marker3D / Node3D the prompt should hover on (offset ignored).
@export var prompt_anchor: NodePath
@export var enabled := true:
	set(value):
		enabled = value
		monitoring = value
		if not value:
			_clear_player()

var _player_inside := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	monitoring = enabled
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	_clear_player()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not _player_inside:
		return
	var prompt := _prompt()
	if prompt != null and prompt.is_modal_blocking():
		return
	if event.is_action_pressed(input_action):
		interacted.emit()
		get_viewport().set_input_as_handled()


func is_player_inside() -> bool:
	return _player_inside


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	_player_inside = true
	_show_prompt()
	player_entered.emit()


func _on_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	_player_inside = false
	var prompt := _prompt()
	if prompt:
		prompt.release(self)
	player_exited.emit()


func _show_prompt() -> void:
	if not enabled or not _player_inside:
		return
	var prompt := _prompt()
	if prompt == null:
		return
	var source: Node3D = self
	var offset := prompt_offset
	if not prompt_anchor.is_empty():
		var anchor := get_node_or_null(prompt_anchor)
		if anchor is Node3D:
			source = anchor as Node3D
			offset = Vector3.ZERO
	prompt.request(self, action_text, prompt.key_label_for(input_action), source, offset)


func _clear_player() -> void:
	_player_inside = false
	var prompt := _prompt()
	if prompt:
		prompt.release(self)


func _prompt() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("InteractPrompt")
