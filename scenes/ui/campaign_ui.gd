extends CanvasLayer
## Campaign health/objective HUD and Armor workshop. No sandbox state changes.
var _hud: Label
var _panel: PanelContainer
var _list: VBoxContainer
var _detail: Label
var _apply: Button
var _selected := ""
var _open := false
var _error := ""

func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = load("res://assets/ui/starforge_ui_theme.tres")
	add_child(root)
	_hud = Label.new()
	_hud.position = Vector2(32, 22)
	_hud.add_theme_font_size_override("font_size", 20)
	_hud.add_theme_constant_override("outline_size", 6)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud)
	_panel = PanelContainer.new()
	root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -470
	_panel.offset_right = 470
	_panel.offset_top = -445
	_panel.offset_bottom = 445
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172333")
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "ARMOR / LOADOUT"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Recover a field blueprint and return to the forge to unlock the next armor."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	box.add_child(_list)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.y = 70
	box.add_child(_detail)
	_apply = Button.new()
	_apply.text = "Apply Armor"
	_apply.custom_minimum_size.y = 52
	_apply.pressed.connect(_on_apply)
	box.add_child(_apply)
	MenuSFX.bind_button(_apply)
	var cancel := Button.new()
	cancel.text = "Cancel / Close"
	cancel.pressed.connect(close_workshop)
	box.add_child(cancel)
	MenuSFX.bind_button(cancel)
	_panel.hide()
	PlayerState.save_failed.connect(func(message: String) -> void: _error = message)
	PlayerState.changed.connect(func() -> void: _error = "")

func _process(_delta: float) -> void:
	var campaign := PlayerState.is_campaign_scene(get_tree().current_scene)
	_hud.visible = campaign and not _open
	if not campaign:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var health := player.get_node("Health") as Health
	var item := PlayerState.armor(PlayerState.data.equipped)
	var objective := "Armor workshop: inspect and equip unlocked armor."
	if get_tree().current_scene.scene_file_path == PlayerState.FIELD:
		if not PlayerState.data.pending_blueprint.is_empty():
			objective = "Blueprint recovered — return to the forge monument to unlock armor."
		elif not PlayerState.next_armor_id().is_empty():
			objective = "Recover the marked armor blueprint, then return to the forge monument."
		else:
			objective = "All armor unlocked. Return to the forge when ready."
	_hud.text = "%s  |  HP %d / %d\n%s" % [item.name, ceili(health.hp), int(health.max_hp), objective]
	if not _error.is_empty():
		_hud.text += "\n" + _error

func open_workshop() -> void:
	if _open or not PlayerState.is_campaign_scene(get_tree().current_scene):
		return
	_open = true
	_selected = PlayerState.data.equipped
	_rebuild()
	_panel.show()
	InteractPrompt.begin_modal()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_list.get_child(0).grab_focus()

func close_workshop() -> void:
	if not _open:
		return
	_open = false
	_panel.hide()
	get_tree().paused = false
	InteractPrompt.end_modal()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		close_workshop()
		get_viewport().set_input_as_handled()

func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for item: Dictionary in PlayerState.catalog:
		if item.id in PlayerState.STARTERS and item.id != PlayerState.data.starter:
			continue
		var status := "Owned" if item.id in PlayerState.data.unlocked else "Locked"
		if item.id == PlayerState.data.equipped:
			status = "Equipped"
		var button := Button.new()
		button.theme_type_variation = &"TabButton"
		button.text = "%s  ·  %s  ·  %d HP  ·  %s" % [item.name, item.tier, item.max_hp, status]
		button.custom_minimum_size.y = 46
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void:
			_selected = item.id
			_refresh_detail()
		)
		_list.add_child(button)
		MenuSFX.bind_button(button)
	_refresh_detail()

func _refresh_detail() -> void:
	var item := PlayerState.armor(_selected)
	var current := PlayerState.armor(PlayerState.data.equipped)
	var owned: bool = _selected in PlayerState.data.unlocked
	_detail.text = "%s: %d → %d max HP (%+d).\n%s" % [item.name, current.max_hp, item.max_hp,
		int(item.max_hp) - int(current.max_hp), "Apply to equip. Current health percentage is preserved." if owned else "Locked — recover blueprints in order on field expeditions."]
	_apply.disabled = not owned or _selected == PlayerState.data.equipped

func _on_apply() -> void:
	if PlayerState.equip(_selected):
		_rebuild()
		_list.get_child(0).grab_focus()
	else:
		_detail.text = PlayerState.last_error
