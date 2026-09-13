extends CanvasLayer
## Options overlay with General / Video / Audio tabs. Autoloaded as `OptionsMenu`.
## The welcome screen and pause menu call open_options(); Esc or Back closes and
## returns focus to the caller. Only Video is populated so far (display mode and
## resolution, applied immediately through GameSettings).

signal opened
signal closed

@onready var _root: Control = $Root
@onready var _general_tab: Button = %GeneralTab
@onready var _video_tab: Button = %VideoTab
@onready var _audio_tab: Button = %AudioTab
@onready var _general_page: Control = %GeneralPage
@onready var _video_page: Control = %VideoPage
@onready var _audio_page: Control = %AudioPage
@onready var _display_mode: OptionButton = %DisplayModeOption
@onready var _resolution: OptionButton = %ResolutionOption
@onready var _resolution_hint: Label = %ResolutionHint
@onready var _status: Label = %StatusLabel
@onready var _back: Button = %BackButton
@onready var _close_key: Label = %CloseKey

var _open := false
var _return_focus: Control
var _syncing := false
var _resolutions: Array[Vector2i] = []


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_general_tab.toggled.connect(_on_tab_toggled.bind(_general_page))
	_video_tab.toggled.connect(_on_tab_toggled.bind(_video_page))
	_audio_tab.toggled.connect(_on_tab_toggled.bind(_audio_page))
	_back.pressed.connect(close_options)
	_display_mode.item_selected.connect(_on_display_mode_selected)
	_resolution.item_selected.connect(_on_resolution_selected)
	GameSettings.video_changed.connect(_sync_from_settings)
	var prompt := get_tree().root.get_node_or_null("InteractPrompt")
	var close_label := "Esc"
	if prompt and prompt.has_method("key_label_for"):
		close_label = str(prompt.key_label_for(&"ui_cancel")).replacen("Escape", "Esc")
	_close_key.text = "%s  Back" % close_label
	_populate_display_modes()
	_show_page(_video_page)


func is_open() -> bool:
	return _open


## Show the overlay. `return_focus` regains focus when the menu closes.
func open_options(return_focus: Control = null) -> void:
	if _open:
		return
	_open = true
	_return_focus = return_focus
	_sync_from_settings()
	_status.text = "Changes apply immediately"
	_root.visible = true
	# Video is the only populated tab for now, so always land there.
	_video_tab.button_pressed = true
	_show_page(_video_page)
	_video_tab.grab_focus()
	opened.emit()


func close_options() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	if _return_focus and is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		close_options()
		get_viewport().set_input_as_handled()


func _on_tab_toggled(pressed: bool, page: Control) -> void:
	if pressed:
		_show_page(page)


func _show_page(page: Control) -> void:
	for candidate in [_general_page, _video_page, _audio_page]:
		candidate.visible = candidate == page


func _populate_display_modes() -> void:
	_display_mode.clear()
	for mode: int in GameSettings.DisplayMode.values():
		_display_mode.add_item(GameSettings.display_mode_label(mode), mode)


func _sync_from_settings() -> void:
	_syncing = true
	_display_mode.select(_display_mode.get_item_index(GameSettings.display_mode))

	_resolutions = GameSettings.get_resolution_options()
	var native := GameSettings.get_screen_size()
	_resolution.clear()
	for i in _resolutions.size():
		var res := _resolutions[i]
		var label := "%d × %d" % [res.x, res.y]
		if res == native:
			label += "   native"
		_resolution.add_item(label, i)
		if res == GameSettings.resolution:
			_resolution.select(i)

	var windowed := GameSettings.display_mode == GameSettings.DisplayMode.WINDOWED
	_resolution.disabled = not windowed
	_resolution.focus_mode = Control.FOCUS_ALL if windowed else Control.FOCUS_NONE
	if windowed:
		_resolution_hint.text = "Window size. The window recenters on the current display."
	else:
		_resolution_hint.text = "Fullscreen uses the display's native resolution."
	_syncing = false


func _on_display_mode_selected(index: int) -> void:
	if _syncing:
		return
	var mode := _display_mode.get_item_id(index) as GameSettings.DisplayMode
	GameSettings.set_display_mode(mode)
	_status.text = "Applied: %s" % GameSettings.describe_video()


func _on_resolution_selected(index: int) -> void:
	if _syncing or index < 0 or index >= _resolutions.size():
		return
	GameSettings.set_resolution(_resolutions[index])
	_status.text = "Applied: %s" % GameSettings.describe_video()
