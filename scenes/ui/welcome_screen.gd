extends Control
## Title menu and explicit, cancellable single-slot character selection.

@onready var _start: Button = %StartButton
@onready var _options: Button = %OptionsButton
@onready var _exit: Button = %ExitButton
var _continue: Button
var _selection: PanelContainer
var _status: Label
var _begin: Button
var _chosen := "base_suit"
var _confirm: ConfirmationDialog

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_start.text = "New Game"
	_continue = Button.new()
	_continue.name = "ContinueButton"
	_continue.text = "Continue"
	_continue.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_continue.custom_minimum_size.y = 64
	_start.get_parent().add_child(_continue)
	_start.get_parent().move_child(_continue, 0)
	_continue.disabled = not PlayerState.has_save()
	_continue.pressed.connect(_on_continue)
	_start.pressed.connect(_on_start)
	_options.pressed.connect(func() -> void: OptionsMenu.open_options(_options))
	_exit.pressed.connect(func() -> void: get_tree().quit())
	for button in [_continue, _start, _options, _exit]:
		button.focus_neighbor_top = NodePath()
		button.focus_neighbor_bottom = NodePath()
		MenuSFX.bind_button(button)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 18)
	_start.get_parent().add_child(_status)
	if PlayerState.save_exists() and _continue.disabled:
		_status.text = "Saved game unavailable. New Game can replace it."
	elif not _continue.disabled:
		_status.text = "Continue from your last saved checkpoint."
	_build_selection()
	(_start if _continue.disabled else _continue).grab_focus()

func _build_selection() -> void:
	_selection = PanelContainer.new()
	_selection.name = "StarterSelection"
	add_child(_selection)
	_selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection.anchor_left = 0.36
	_selection.anchor_right = 0.96
	_selection.anchor_top = 0.15
	_selection.anchor_bottom = 0.85
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172333")
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	_selection.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_selection.add_child(box)
	var heading := Label.new()
	heading.text = "CHOOSE YOUR STARTER"
	heading.add_theme_font_size_override("font_size", 30)
	box.add_child(heading)
	var detail := Label.new()
	detail.text = "Both start with 100 HP. Recover blueprints to unlock stronger armor."
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)
	var choices := HBoxContainer.new()
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 20)
	box.add_child(choices)
	var group := ButtonGroup.new()
	for id: String in PlayerState.STARTERS:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_child(column)
		var preview := SubViewportContainer.new()
		preview.custom_minimum_size = Vector2(0, 270)
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview.stretch = true
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(preview)
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		preview.add_child(viewport)
		var path := "res://assets/models/characters/exo_gray_idle.glb" if id == "base_suit" else "res://assets/models/gear/armor/previews/armor_starter_dustcoat.glb"
		var model: Node3D = load(path).instantiate()
		viewport.add_child(model)
		_fit_preview(model)
		_start_preview_idle(model)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.position = Vector3(0, 1.0, 3.5)
		camera.look_at(Vector3(0, 0.9, 0))
		camera.fov = 38
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-30, -25, 0)
		light.light_energy = 2.0
		viewport.add_child(light)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color(0.7, 0.8, 1.0)
		environment.environment.ambient_light_energy = 0.7
		viewport.add_child(environment)
		var button := Button.new()
		button.name = "Choice_" + id
		button.text = "%s · 100 HP" % PlayerState.armor(id).name
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = id == _chosen
		button.custom_minimum_size.y = 60
		button.pressed.connect(func() -> void: _chosen = id)
		column.add_child(button)
		MenuSFX.bind_button(button)
	_begin = Button.new()
	_begin.text = "Begin Journey"
	_begin.custom_minimum_size.y = 60
	_begin.pressed.connect(_on_begin)
	box.add_child(_begin)
	MenuSFX.bind_button(_begin)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_close_selection)
	box.add_child(back)
	MenuSFX.bind_button(back)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Replace saved game?"
	_confirm.dialog_text = "Beginning a new journey replaces your saved character and armor progress."
	_confirm.ok_button_text = "Replace and Begin"
	_confirm.confirmed.connect(_start_new)
	add_child(_confirm)
	_selection.hide()

func _start_preview_idle(model: Node3D) -> void:
	var source: Node = load("res://assets/models/characters/exo_gray_idle.glb").instantiate()
	var source_player := source.get_node("AnimationPlayer") as AnimationPlayer
	var clip := source_player.get_animation("mixamo_com").duplicate(true) as Animation
	clip.loop_mode = Animation.LOOP_LINEAR
	var library := AnimationLibrary.new()
	library.add_animation("idle", clip)
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.add_animation_library("preview", library)
	player.play("preview/idle")
	player.advance(0.0)
	source.free()

func _fit_preview(model: Node3D) -> void:
	var bounds := AABB()
	var found := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var local_box: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(local_box) if found else local_box
		found = true
	if found and bounds.size.y > 0:
		var scale_factor := 1.8 / bounds.size.y
		model.scale = Vector3.ONE * scale_factor
		model.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_factor

func _on_start() -> void:
	_selection.show()
	_selection.find_child("Choice_" + _chosen, true, false).grab_focus()

func _close_selection() -> void:
	_selection.hide()
	_start.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if _selection.visible and event.is_action_pressed("ui_cancel"):
		_close_selection()
		get_viewport().set_input_as_handled()

func _on_begin() -> void:
	if PlayerState.save_exists():
		_confirm.popup_centered(Vector2i(580, 180))
	else:
		_start_new()

func _start_new() -> void:
	if PlayerState.start_new(_chosen):
		_enter_game(PlayerState.LOBBY)
	else:
		_status.text = PlayerState.last_error

func _on_continue() -> void:
	if PlayerState.continue_game():
		_enter_game(PlayerState.data.checkpoint)
	else:
		_status.text = PlayerState.last_error
		_continue.disabled = true

func _enter_game(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_status.text = "Could not open the saved checkpoint. Please try again."
