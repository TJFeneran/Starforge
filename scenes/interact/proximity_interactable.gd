extends Area3D
class_name ProximityInteractable
## Reusable proximity + hold-to-interact trigger. Drives InteractPrompt HUD.
## Prompt hovers at prompt_anchor (or this node + prompt_offset) and faces the camera.

signal interacted
signal hold_started
signal hold_cancelled
signal player_entered
signal player_exited

@export var action_text := "Interact"
@export var input_action: StringName = &"interact"
## Seconds the interact action must be held before firing.
@export_range(0.1, 3.0, 0.05) var hold_duration := 0.5
## Local offset from this Area3D used when prompt_anchor is unset.
@export var prompt_offset := Vector3(0.0, 1.55, 0.0)
## Optional Marker3D / Node3D the prompt should hover on (prompt_offset is local to it).
@export var prompt_anchor: NodePath
@export var enabled := true:
	set(value):
		var was_enabled := enabled
		enabled = value
		monitoring = value
		if not value:
			_clear_player()
		elif was_enabled != value and is_inside_tree():
			# Arming while the player already stands in the volume should still prompt.
			call_deferred("_refresh_overlap")

var _player_inside := false
var _hold_time := 0.0
var _hold_completed := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	monitoring = enabled
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(true)


func _exit_tree() -> void:
	_clear_player()


func _process(delta: float) -> void:
	if not enabled or not _player_inside:
		return
	var prompt := _prompt()
	if prompt != null and prompt.is_modal_blocking():
		_reset_hold(prompt)
		return
	if not Input.is_action_pressed(input_action):
		_reset_hold(prompt)
		return
	if _hold_completed:
		return
	var starting := _hold_time <= 0.0
	_hold_time = minf(_hold_time + delta, hold_duration)
	if starting:
		hold_started.emit()
	var progress := 0.0 if hold_duration <= 0.0 else _hold_time / hold_duration
	if prompt and prompt.has_method("set_hold_progress"):
		prompt.set_hold_progress(progress)
	if _hold_time >= hold_duration:
		_hold_completed = true
		interacted.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Consume the press so other systems do not treat interact as an instant tap.
	if not enabled or not _player_inside:
		return
	var prompt := _prompt()
	if prompt != null and prompt.is_modal_blocking():
		return
	if event.is_action_pressed(input_action) or event.is_action_released(input_action):
		get_viewport().set_input_as_handled()


func is_player_inside() -> bool:
	return _player_inside


func _refresh_overlap() -> void:
	if not enabled or not monitoring:
		return
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	_player_inside = true
	_reset_hold(_prompt())
	_show_prompt()
	player_entered.emit()


func _on_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	_player_inside = false
	_reset_hold(_prompt())
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
	prompt.request(self, action_text, prompt.key_label_for(input_action), source, offset)


func _reset_hold(prompt: Node) -> void:
	var was_holding := _hold_time > 0.0 and not _hold_completed
	_hold_time = 0.0
	_hold_completed = false
	if prompt and prompt.has_method("set_hold_progress"):
		prompt.set_hold_progress(0.0)
	if was_holding:
		hold_cancelled.emit()


func _clear_player() -> void:
	_player_inside = false
	_hold_time = 0.0
	_hold_completed = false
	if not is_inside_tree():
		return
	var prompt := _prompt()
	if prompt:
		if prompt.has_method("set_hold_progress"):
			prompt.set_hold_progress(0.0)
		prompt.release(self)


func _prompt() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("InteractPrompt")
