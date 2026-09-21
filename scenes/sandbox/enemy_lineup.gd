extends Control
## Four independent Godot viewports, with every authored enemy clip shown in one sequence.

const ACTORS := [
	{"title": "SHIELDBACK SKITTER", "model": preload("res://assets/models/enemies/rift_skitter/skitter.glb"), "height": 0.64, "distance": 3.25, "hover": 0.0},
	{"title": "NEEDLECREST MARKSMAN", "model": preload("res://assets/models/enemies/rift_marksman/marksman.glb"), "height": 0.98, "distance": 3.6, "hover": 0.0},
	{"title": "CRESCENT RIFT RAY", "model": preload("res://assets/models/enemies/rift_ray/ray.glb"), "height": 1.35, "distance": 3.15, "hover": 1.35},
	{"title": "SPLIT CROWN BULWARK", "model": preload("res://assets/models/enemies/forge_bulwark/bulwark.glb"), "height": 1.48, "distance": 6.0, "hover": 0.0},
]

# Slots run in parallel. The extra locomotion/aim slots cover the unique moves.
const SEQUENCE := [
	{"title": "IDLE / HOVER", "clips": ["idle", "idle", "hover_idle", "idle"], "seconds": 3.4},
	{"title": "WALK / FLIGHT", "clips": ["walk", "walk", "fly_forward", "walk"], "seconds": 3.5},
	{"title": "RUN / LEFT BANK", "clips": ["run", "run", "bank_left", "walk"], "seconds": 3.0},
	{"title": "LEFT STRAFE / RIGHT BANK", "clips": ["idle", "strafe_left", "bank_right", "idle"], "seconds": 2.4},
	{"title": "RIGHT STRAFE", "clips": ["idle", "strafe_right", "hover_idle", "idle"], "seconds": 2.4},
	{"title": "AIM", "clips": ["idle", "aim", "hover_idle", "idle"], "seconds": 2.3},
	{"title": "ATTACK ANTICIPATION", "clips": ["attack_anticipation", "attack_anticipation", "attack_anticipation", "attack_anticipation"], "seconds": 2.3},
	{"title": "ATTACK / CONTACT", "clips": ["attack", "attack", "attack", "attack"], "seconds": 2.3},
	{"title": "ATTACK RECOVERY", "clips": ["attack_recovery", "attack_recovery", "attack_recovery", "attack_recovery"], "seconds": 2.1},
	{"title": "HIT REACTION", "clips": ["hit", "hit", "hit", "hit"], "seconds": 1.7},
	{"title": "DEATH", "clips": ["death", "death", "death", "death"], "seconds": 3.8},
	{"title": "TURNTABLE", "clips": ["idle", "idle", "hover_idle", "idle"], "seconds": 4.5},
]

const LOOPING := ["idle", "hover_idle", "walk", "run", "fly_forward", "bank_left", "bank_right", "strafe_left", "strafe_right", "aim"]

var actors: Array[Dictionary] = []
var phase_label: Label
var slot := 0
var elapsed := 0.0
var demo := false
var paused := false
var one_shot_elapsed: Array[float] = []


func _ready() -> void:
	DisplayServer.window_set_title("Starforge — enemy animation lineup")
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--demo": demo = true
	for i in ACTORS.size():
		_make_panel(i)
	_make_overlay()
	_play_slot(0)
	print("ENEMY_LINEUP_READY: four models, 12 synchronized animation phases")


func _make_panel(index: int) -> void:
	var spec: Dictionary = ACTORS[index]
	var panel := Panel.new()
	panel.anchor_left = 0.5 * (index % 2)
	panel.anchor_right = panel.anchor_left + 0.5
	panel.anchor_top = 0.5 * (index / 2)
	panel.anchor_bottom = panel.anchor_top + 0.5
	var border := StyleBoxFlat.new()
	border.bg_color = Color("101923")
	border.border_color = Color("314451")
	border.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", border)
	add_child(panel)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var image := TextureRect.new()
	image.anchor_right = 1.0
	image.anchor_bottom = 1.0
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.texture = viewport.get_texture()
	panel.add_child(image)

	var stage := Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("121d29")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9cddd")
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -30, 0)
	key.light_energy = 1.15
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, 145, 0)
	fill.light_color = Color("8cbed0")
	fill.light_energy = 0.4
	stage.add_child(fill)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor.mesh = plane
	floor.position.y = -0.02
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("263643")
	floor_material.roughness = 0.85
	floor.material_override = floor_material
	stage.add_child(floor)
	var model: Node3D = (spec["model"] as PackedScene).instantiate() as Node3D
	model.position.y = spec["hover"]
	stage.add_child(model)
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(player != null, spec["title"] + " has no AnimationPlayer")
	var names: Dictionary = {}
	for name: String in player.get_animation_list():
		var short_name := name.get_slice("/", name.get_slice_count("/") - 1)
		names[short_name] = name
		player.get_animation(name).loop_mode = Animation.LOOP_LINEAR if short_name in LOOPING else Animation.LOOP_NONE
	for phase: Dictionary in SEQUENCE:
		assert(names.has(phase["clips"][index]), spec["title"] + " missing " + phase["clips"][index])
	var camera := Camera3D.new()
	camera.fov = 43.0
	stage.add_child(camera)
	camera.make_current()
	actors.append({"player": player, "names": names, "camera": camera, "label": _panel_label(panel, spec["title"]), "spec": spec})
	one_shot_elapsed.append(0.0)
	_update_camera(index, 0.28)


func _panel_label(panel: Panel, title: String) -> Label:
	var label := Label.new()
	label.position = Vector2(22, 20)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("e2f0ef"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.text = title
	panel.add_child(label)
	return label


func _make_overlay() -> void:
	phase_label = Label.new()
	phase_label.anchor_left = 0.26
	phase_label.anchor_right = 0.74
	phase_label.anchor_top = 0.5
	phase_label.anchor_bottom = 0.5
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.offset_top = -39
	phase_label.offset_bottom = -2
	phase_label.add_theme_font_size_override("font_size", 23)
	phase_label.add_theme_color_override("font_color", Color("8ce6d4"))
	phase_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	phase_label.add_theme_constant_override("shadow_offset_x", 2)
	phase_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(phase_label)
	var controls := Label.new()
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_top = -32
	controls.offset_left = 18
	controls.text = "← / → phases     Space pause     R replay     All four models shown together"
	controls.add_theme_font_size_override("font_size", 17)
	controls.add_theme_color_override("font_color", Color("b8d0d7"))
	controls.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	add_child(controls)


func _play_slot(index: int) -> void:
	slot = posmod(index, SEQUENCE.size())
	elapsed = 0.0
	var phase: Dictionary = SEQUENCE[slot]
	phase_label.text = "%02d / %02d    %s" % [slot + 1, SEQUENCE.size(), phase["title"]]
	for i in actors.size():
		var actor: Dictionary = actors[i]
		var clip: String = phase["clips"][i]
		var player: AnimationPlayer = actor["player"]
		player.play(actor["names"][clip], 0.0)
		actor["label"].text = "%s\n%s" % [actor["spec"]["title"], clip.to_upper().replace("_", " ")]
		one_shot_elapsed[i] = 0.0
		_update_camera(i, 0.28)
		if paused: player.pause()


func _update_camera(index: int, yaw: float) -> void:
	var actor: Dictionary = actors[index]
	var camera: Camera3D = actor["camera"]
	var spec: Dictionary = actor["spec"]
	var target := Vector3(0, spec["height"], 0)
	var distance: float = spec["distance"]
	camera.position = target + Vector3(sin(yaw) * distance, distance * 0.09, cos(yaw) * distance)
	camera.look_at(target)


func _process(delta: float) -> void:
	if paused: return
	elapsed += delta
	if slot == SEQUENCE.size() - 1:
		for i in actors.size():
			_update_camera(i, 0.28 + elapsed / float(SEQUENCE[slot]["seconds"]) * TAU)
	else:
		for i in actors.size():
			var actor: Dictionary = actors[i]
			var clip: String = SEQUENCE[slot]["clips"][i]
			if clip in LOOPING or clip == "death": continue
			one_shot_elapsed[i] += delta
			var player: AnimationPlayer = actor["player"]
			var length := player.get_animation(actor["names"][clip]).length
			if one_shot_elapsed[i] >= length + 0.28:
				player.play(actor["names"][clip], 0.0)
				one_shot_elapsed[i] = 0.0
	if demo:
		RenderingServer.force_draw(false, delta)
		if elapsed >= float(SEQUENCE[slot]["seconds"]):
			if slot == SEQUENCE.size() - 1:
				get_tree().quit()
			else: _play_slot(slot + 1)
	elif elapsed >= float(SEQUENCE[slot]["seconds"]):
		_play_slot(slot + 1)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_LEFT:
			_play_slot(slot - 1)
		KEY_RIGHT:
			_play_slot(slot + 1)
		KEY_R:
			_play_slot(slot)
		KEY_SPACE:
			paused = not paused
			for actor: Dictionary in actors:
				var player: AnimationPlayer = actor["player"]
				if paused: player.pause()
				else: player.play()
