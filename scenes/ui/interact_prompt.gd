extends CanvasLayer
## World-anchored interact prompt. Requesters push/release; top of stack wins.
## Prompt hovers at a 3D point near the interactable and faces the camera
## (screen-space projection of that world point each frame).
## Call begin_modal()/end_modal() while focused UIs own input (map, benches, etc.).

@onready var _root: Control = $Root
@onready var _prompt_row: Control = $Root/PromptRow
@onready var _key_label: Label = %KeyLabel
@onready var _action_label: Label = %ActionLabel

var _stack: Array[Dictionary] = []
var _modal_depth := 0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	set_process(true)


func request(
	requester: Object,
	action_text: String,
	key_label: String = "",
	world_source: Node3D = null,
	world_offset: Vector3 = Vector3.ZERO,
) -> void:
	if requester == null or not is_instance_valid(requester):
		return
	release(requester)
	var key := key_label if not key_label.is_empty() else key_label_for(&"interact")
	var source := world_source
	if source == null and requester is Node3D:
		source = requester as Node3D
	_stack.append({
		"requester": requester,
		"action": action_text,
		"key": key,
		"world_source": source,
		"world_offset": world_offset,
	})
	_refresh()


func release(requester: Object) -> void:
	if requester == null:
		return
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i]["requester"] == requester:
			_stack.remove_at(i)
			break
	_refresh()


func clear() -> void:
	_stack.clear()
	_refresh()


func begin_modal() -> void:
	_modal_depth += 1
	_refresh()


func end_modal() -> void:
	_modal_depth = maxi(0, _modal_depth - 1)
	_refresh()


func is_modal_blocking() -> bool:
	return _modal_depth > 0


func key_label_for(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var code: Key = key_event.physical_keycode
			if code == KEY_NONE:
				code = key_event.keycode
			var label := OS.get_keycode_string(code)
			if not label.is_empty():
				return label.to_upper()
	return "E"


func _process(_delta: float) -> void:
	if not _root.visible or _stack.is_empty():
		return
	_update_anchor_position()


func _refresh() -> void:
	# Drop freed requesters / dead anchors.
	for i in range(_stack.size() - 1, -1, -1):
		var req: Variant = _stack[i]["requester"]
		if req == null or not is_instance_valid(req):
			_stack.remove_at(i)
			continue
		var source: Variant = _stack[i].get("world_source")
		if source != null and not is_instance_valid(source):
			_stack[i]["world_source"] = null

	if _modal_depth > 0 or _stack.is_empty():
		_root.visible = false
		return

	var top: Dictionary = _stack[_stack.size() - 1]
	_key_label.text = str(top["key"])
	_action_label.text = str(top["action"])
	_root.visible = true
	_update_anchor_position()


func _update_anchor_position() -> void:
	if _stack.is_empty():
		return
	var top: Dictionary = _stack[_stack.size() - 1]
	var source: Node3D = top.get("world_source") as Node3D
	if source == null or not is_instance_valid(source):
		# Fallback: bottom-center if no world anchor.
		_place_fallback()
		return

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_place_fallback()
		return

	var offset: Vector3 = top.get("world_offset", Vector3.ZERO)
	var world_pos: Vector3 = source.global_transform * offset
	if cam.is_position_behind(world_pos):
		_prompt_row.visible = false
		return

	var screen: Vector2 = cam.unproject_position(world_pos)
	_prompt_row.visible = true
	# Center the row on the projected world point (billboard / camera-facing).
	var size := _prompt_row.get_combined_minimum_size()
	_prompt_row.size = size
	_prompt_row.position = screen - size * 0.5


func _place_fallback() -> void:
	_prompt_row.visible = true
	var viewport_size := _root.size
	if viewport_size.x < 1.0:
		viewport_size = get_viewport().get_visible_rect().size
	var size := _prompt_row.get_combined_minimum_size()
	_prompt_row.size = size
	_prompt_row.position = Vector2(
		(viewport_size.x - size.x) * 0.5,
		viewport_size.y - size.y - 48.0,
	)
