extends CanvasLayer
## Globe destination overlay. Selecting an available world arms the monument gate.

signal opened
signal closed
signal destination_selected(destination: MapDestination)

@onready var _root: Control = $Root
@onready var _list: VBoxContainer = %DestinationList
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_blurb: Label = %DetailBlurb
@onready var _select_button: Button = %SelectButton
@onready var _status_label: Label = %StatusLabel
@onready var _close_key: Label = %CloseKey

var _open := false
var _was_mouse_captured := false
var _destinations: Array[MapDestination] = []
var _selected: MapDestination
var _buttons: Dictionary = {}  # id -> Button


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_select_button.pressed.connect(_on_select_pressed)
	var prompt := _prompt()
	var close_label := "Esc"
	if prompt:
		close_label = str(prompt.key_label_for(&"ui_cancel")).replace("Escape", "Esc")
	_close_key.text = "%s  Close" % close_label
	_seed_stub_destinations()
	_rebuild_list()
	_clear_selection()


func is_open() -> bool:
	return _open


func open_map() -> void:
	if _open:
		return
	_open = true
	_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var prompt := _prompt()
	if prompt:
		prompt.begin_modal()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_status_label.text = "Select a destination"
	if not _buttons.is_empty():
		var first: Button = _buttons.values()[0]
		first.grab_focus()
	opened.emit()


func close_map() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false
	var prompt := _prompt()
	if prompt:
		prompt.end_modal()
	if _was_mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func set_destinations(destinations: Array[MapDestination]) -> void:
	_destinations = destinations.duplicate()
	_rebuild_list()
	_clear_selection()


func get_selected() -> MapDestination:
	return _selected


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		close_map()
		get_viewport().set_input_as_handled()


func _seed_stub_destinations() -> void:
	_destinations.clear()
	_destinations.append(_make_dest(
		"frontier_outpost",
		"Frontier Outpost",
		"Secure the beacon and push the rift back from the outer wall.",
		true,
		"res://scenes/playable/outpost_slice.tscn"
	))
	_destinations.append(_make_dest(
		"rift_scar",
		"Rift Scar",
		"Unstable corridor. Charting incomplete.",
		false,
		""
	))
	_destinations.append(_make_dest(
		"ash_orbit",
		"Ash Orbit",
		"Derelict ring yard. Locked pending forge clearance.",
		false,
		""
	))


func _make_dest(
	id: String,
	title: String,
	blurb: String,
	available: bool,
	scene_path: String
) -> MapDestination:
	var dest := MapDestination.new()
	dest.id = id
	dest.title = title
	dest.blurb = blurb
	dest.available = available
	dest.scene_path = scene_path
	return dest


func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	_buttons.clear()
	for dest in _destinations:
		var button := Button.new()
		button.text = dest.title if dest.available else "%s  — locked" % dest.title
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not dest.available
		button.custom_minimum_size = Vector2(0, 56)
		button.focus_mode = Control.FOCUS_ALL
		var dest_id := dest.id
		button.pressed.connect(func() -> void: _select_destination(dest_id))
		_list.add_child(button)
		_buttons[dest.id] = button


func _select_destination(dest_id: String) -> void:
	_selected = null
	for dest in _destinations:
		if dest.id == dest_id:
			_selected = dest
			break
	if _selected == null:
		_clear_selection()
		return
	_detail_title.text = _selected.title
	_detail_blurb.text = _selected.blurb
	_select_button.disabled = not _selected.available
	_status_label.text = "Ready to mark for deployment" if _selected.available else "Destination locked"


func _clear_selection() -> void:
	_selected = null
	_detail_title.text = "No destination marked"
	_detail_blurb.text = "Approach options appear as the forge charts new worlds."
	_select_button.disabled = true
	_status_label.text = "Select a destination"


func _on_select_pressed() -> void:
	if _selected == null or not _selected.available:
		return
	destination_selected.emit(_selected)
	_status_label.text = "Gate armed: %s" % _selected.title
	close_map()


func _prompt() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("InteractPrompt")
