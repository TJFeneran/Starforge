extends Node3D
## Isolated review scene for the Crescent ray. The body origin is its neutral hover center.

const MODEL_PATH := "res://assets/models/enemies/rift_ray/ray.glb"
const SOURCE_PATH := "res://assets/source/meshy/rift_ray/ray_a.glb"
const CLIPS := ["hover_idle", "fly_forward", "bank_left", "bank_right", "attack_anticipation", "attack", "attack_recovery", "hit", "death"]
const LOOPING := ["hover_idle", "fly_forward", "bank_left", "bank_right"]
const DEMO := [["comparison", 4.0], ["hover_idle", 3.5], ["fly_forward", 3.5], ["bank_left", 3.0], ["bank_right", 3.0], ["attack_anticipation", 2.0], ["attack", 2.0], ["attack_recovery", 2.0], ["hit", 2.0], ["death", 3.5], ["turntable", 4.5]]
const HOVER_HEIGHT := 1.35
const WINGSPAN := 1.6

var model: Node3D
var source: Node3D
var player: AnimationPlayer
var camera: Camera3D
var info: Label
var caption: Label
var clip_index := 0
var clip_names: Dictionary = {}
var yaw := 0.4
var pitch := 0.18
var distance := 3.8
var dragging := false
var paused := false
var autoplay := true
var comparing := false
var elapsed := 0.0
var demo := false
var demo_index := -1
var demo_elapsed := 0.0
var capture_path := ""
var capture_time := 0.0
var capture_delay := 0.0

func _ready() -> void:
	DisplayServer.window_set_title("Starforge — Rift Ray animation review")
	_make_stage()
	_make_ui()
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo":
			demo = true
			autoplay = false
		if arg.begins_with("--clip="):
			clip_index = maxi(0, CLIPS.find(arg.trim_prefix("--clip=")))
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
			autoplay = false
		if arg.begins_with("--time="):
			capture_time = arg.trim_prefix("--time=").to_float()
	if ResourceLoader.exists(MODEL_PATH):
		model = load(MODEL_PATH).instantiate()
		add_child(model)
		model.position.y = HOVER_HEIGHT
		player = model.find_child("AnimationPlayer", true, false)
		if player != null:
			for name in player.get_animation_list():
				var short_name: String = name.get_slice("/", name.get_slice_count("/") - 1)
				if short_name in CLIPS:
					clip_names[short_name] = name
					player.get_animation(name).loop_mode = Animation.LOOP_LINEAR if short_name in LOOPING else Animation.LOOP_NONE
		if clip_names.has(CLIPS[clip_index]):
			_play(clip_index)
		if demo: _next_demo()
		if not capture_path.is_empty() and player != null:
			player.seek(capture_time, true)
			player.pause()
			paused = true
		print("RIFT_RAY_REVIEW_READY: ", clip_names.size(), " clips")
	else:
		info.text = "Awaiting generated Ray GLB"
	_update_camera()

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat

func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = pos
	add_child(node)

func _make_stage() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101923")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c1d3e0")
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -32, 0)
	key.light_energy = 0.95
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color("9ebbd6")
	fill.light_energy = 0.35
	add_child(fill)
	_box(Vector3(20, 0.08, 20), Vector3(0, -0.045, 0), Color("18232e"))
	for i in range(-8, 9):
		_box(Vector3(0.008, 0.003, 8), Vector3(i * 0.5, 0, 0), Color("253643"))
		_box(Vector3(8, 0.003, 0.008), Vector3(0, 0, i * 0.5), Color("253643"))
	_box(Vector3(.022, WINGSPAN, .022), Vector3(-1.3, WINGSPAN/2.0, 0), Color("567880"))
	for h in range(9):
		_box(Vector3(.08, .009, .022), Vector3(-1.3, h*.2, 0), Color("8da8ad"))
	camera = Camera3D.new()
	camera.fov = 39
	add_child(camera)
	camera.make_current()

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.1, .90)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var title := Label.new()
	title.text = "CRESCENT RAY  /  ANIMATION REVIEW"
	title.add_theme_font_size_override("font_size", 19)
	title.modulate = Color("dfe8e8")
	stack.add_child(title)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 16)
	info.modulate = Color("71cfbe")
	stack.add_child(info)
	var stats := Label.new()
	stats.text = "1.6 m wingspan · body-centered origin · in-place flight\nProjectile is a separate runtime effect"
	stats.add_theme_font_size_override("font_size", 13)
	stats.modulate = Color("9db0ba")
	stack.add_child(stats)
	caption = Label.new()
	caption.text = "Tab / Shift+Tab: clip     Space: pause     R: restart     A: auto cycle\nDrag: orbit     Wheel: zoom     C: source comparison"
	caption.position = Vector2(22, 710)
	caption.add_theme_font_size_override("font_size", 14)
	caption.modulate = Color("bdd0d6")
	layer.add_child(caption)

func _play(index: int) -> void:
	if player == null: return
	clip_index = posmod(index, CLIPS.size())
	if not clip_names.has(CLIPS[clip_index]):
		info.text = "Missing clip: " + CLIPS[clip_index]
		return
	elapsed = 0
	if comparing: _toggle_comparison()
	player.play(clip_names[CLIPS[clip_index]], 0.12)
	if paused:
		player.advance(0)
		player.pause()
	info.text = "%02d / %02d   %s" % [clip_index + 1, CLIPS.size(), CLIPS[clip_index].to_upper().replace("_", " ")]

func _process(delta: float) -> void:
	caption.position.y = get_viewport().get_visible_rect().size.y - 58
	if demo:
		demo_elapsed += delta
		if demo_index >= 0:
			var shot: String = DEMO[demo_index][0]
			if shot == "turntable":
				yaw = 0.4 + demo_elapsed / float(DEMO[demo_index][1]) * TAU
				_update_camera()
			if demo_elapsed >= float(DEMO[demo_index][1]): _next_demo()
		# The movie writer must draw each frame even if the desktop is occluded.
		RenderingServer.force_draw(false, delta)
	if not capture_path.is_empty():
		RenderingServer.force_draw(false, delta)
		capture_delay += delta
		if capture_delay > 1.5:
			var path := capture_path
			capture_path = ""
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			print("RIFT_RAY_CAPTURE ", path)
			get_tree().quit()
	if autoplay and not paused and not comparing and player != null and clip_names.has(CLIPS[clip_index]):
		elapsed += delta
		var length := player.get_animation(clip_names[CLIPS[clip_index]]).length
		if elapsed > maxf(length * 2, 3.0) + (1.0 if CLIPS[clip_index] == "death" else 0.0):
			_play(clip_index + 1)

func _next_demo() -> void:
	demo_index += 1
	demo_elapsed = 0
	if demo_index >= DEMO.size():
		get_tree().quit()
		return
	var shot: String = DEMO[demo_index][0]
	yaw = 0.4
	pitch = 0.18
	if shot == "comparison":
		_toggle_comparison()
		yaw = 0
		pitch = 0.12
		distance = 6.4
		caption.text = "Original source (left)  /  optimized rig (right)\nBoth shown at the same 1.6 m wingspan"
	else:
		if comparing: _toggle_comparison()
		_play(CLIPS.find("hover_idle" if shot == "turntable" else shot))
		caption.text = "Authored in-place flight · captured in Godot\n" + ("Full model turntable" if shot == "turntable" else "Two fin chains · tail chain · original Meshy textures")
		distance = 4.1 if shot == "death" else 3.8
	_update_camera()

func _toggle_comparison() -> void:
	if model == null: return
	comparing = not comparing
	if comparing:
		if source == null:
			if not FileAccess.file_exists(SOURCE_PATH):
				comparing = false
				return
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			if document.append_from_file(SOURCE_PATH, state) != OK:
				comparing = false
				return
			source = document.generate_scene(state)
			add_child(source)
			var bounds := AABB()
			var first := true
			for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
				var box: AABB = source.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
				bounds = box if first else bounds.merge(box)
				first = false
			if first:
				comparing = false
				return
			var width := maxf(bounds.size.x, bounds.size.z)
			var factor := WINGSPAN / width
			source.scale = Vector3.ONE * factor
			source.position = Vector3(-1.2 - bounds.get_center().x * factor, HOVER_HEIGHT - bounds.get_center().y * factor, -bounds.get_center().z * factor)
		source.visible = true
		model.position.x = 1.2
		player.stop()
		var skeleton: Skeleton3D = model.find_child("*Skeleton*", true, false)
		if skeleton != null: skeleton.reset_bone_poses()
		distance = 6.4
		info.text = "SOURCE   |   OPTIMIZED RIG"
	else:
		if source != null: source.visible = false
		model.position.x = 0
		distance = 3.8
		_play(clip_index)
	_update_camera()

func _update_camera() -> void:
	if camera == null: return
	var target := Vector3(0, HOVER_HEIGHT, 0)
	camera.position = target + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*distance
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(2.0, distance-.3)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(10, distance+.3)
		_update_camera()
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x*.006
		pitch = clampf(pitch+event.relative.y*.005, -.5, 1.2)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				autoplay = false
				_play(clip_index + (-1 if event.shift_pressed else 1))
			KEY_SPACE:
				paused = not paused
				if player != null:
					if paused: player.pause()
					else: player.play()
			KEY_R: _play(clip_index)
			KEY_A: autoplay = not autoplay
			KEY_C: _toggle_comparison()
