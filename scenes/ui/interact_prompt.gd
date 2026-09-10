extends CanvasLayer
## World-anchored interact prompt. Requesters push/release; top of stack wins.
## Prompt hovers at a 3D point near the interactable and faces the camera.
## Call begin_modal()/end_modal() while focused UIs own input (map, benches, etc.).
## set_hold_progress() drives the amber wrap around the key badge (0 = idle, 1 = full).

@onready var _root: Control = $Root
@onready var _prompt_row: Control = $Root/PromptRow
@onready var _key_label: Label = %KeyLabel
@onready var _action_label: Label = %ActionLabel
@onready var _hold_ring: Control = %HoldRing

var _stack: Array[Dictionary] = []
var _modal_depth := 0
var _hold_progress := 0.0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	set_process(true)
	if _hold_ring and not _hold_ring.draw.is_connected(_on_hold_ring_draw):
		_hold_ring.draw.connect(_on_hold_ring_draw)


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
	var was_top: bool = not _stack.is_empty() and _stack[_stack.size() - 1]["requester"] == requester
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i]["requester"] == requester:
			_stack.remove_at(i)
			break
	if was_top:
		set_hold_progress(0.0)
	_refresh()


func clear() -> void:
	_stack.clear()
	set_hold_progress(0.0)
	_refresh()


func begin_modal() -> void:
	_modal_depth += 1
	set_hold_progress(0.0)
	_refresh()


func end_modal() -> void:
	_modal_depth = maxi(0, _modal_depth - 1)
	_refresh()


func is_modal_blocking() -> bool:
	return _modal_depth > 0


func set_hold_progress(progress: float) -> void:
	_hold_progress = clampf(progress, 0.0, 1.0)
	if _hold_ring:
		_hold_ring.queue_redraw()


func get_hold_progress() -> float:
	return _hold_progress


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
	if _hold_ring:
		_hold_ring.queue_redraw()


func _update_anchor_position() -> void:
	if _stack.is_empty():
		return
	var top: Dictionary = _stack[_stack.size() - 1]
	var source: Node3D = top.get("world_source") as Node3D
	if source == null or not is_instance_valid(source):
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


func _on_hold_ring_draw() -> void:
	if _hold_ring == null:
		return
	# Stroke sits on the outer edge of the grey-blue key badge.
	var inset := 1.5
	var rect := Rect2(Vector2(inset, inset), _hold_ring.size - Vector2(inset * 2.0, inset * 2.0))
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	# Quiet idle frame so the badge reads as a key even before holding.
	_hold_ring.draw_rect(rect, Color(1.0, 0.698, 0.22, 0.28), false, 2.0)
	if _hold_progress <= 0.001:
		return
	var perimeter := rect.size.x * 2.0 + rect.size.y * 2.0
	var remaining := perimeter * _hold_progress
	var color := Color(1.0, 0.78, 0.28, 1.0)
	var width := 3.0
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	]
	var edge_lengths := [rect.size.x, rect.size.y, rect.size.x, rect.size.y]
	for edge in range(4):
		if remaining <= 0.0:
			break
		var span: float = minf(remaining, edge_lengths[edge])
		var start: Vector2 = corners[edge]
		var end: Vector2 = corners[(edge + 1) % 4]
		var direction := (end - start).normalized()
		_hold_ring.draw_line(start, start + direction * span, color, width, true)
		remaining -= span
