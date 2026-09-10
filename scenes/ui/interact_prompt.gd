extends CanvasLayer
## Screen-space interact prompt. Requesters push/release; top of stack wins.
## Call begin_modal()/end_modal() while focused UIs own input (map, benches, etc.).

@onready var _root: Control = $Root
@onready var _key_label: Label = %KeyLabel
@onready var _action_label: Label = %ActionLabel

var _stack: Array[Dictionary] = []
var _modal_depth := 0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false


func request(requester: Object, action_text: String, key_label: String = "") -> void:
	if requester == null or not is_instance_valid(requester):
		return
	release(requester)
	var key := key_label if not key_label.is_empty() else key_label_for(&"interact")
	_stack.append({
		"requester": requester,
		"action": action_text,
		"key": key,
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


func _refresh() -> void:
	# Drop freed requesters.
	for i in range(_stack.size() - 1, -1, -1):
		var req: Variant = _stack[i]["requester"]
		if req == null or not is_instance_valid(req):
			_stack.remove_at(i)

	if _modal_depth > 0 or _stack.is_empty():
		_root.visible = false
		return

	var top: Dictionary = _stack[_stack.size() - 1]
	_key_label.text = str(top["key"])
	_action_label.text = str(top["action"])
	_root.visible = true
