extends Node3D
## Isolated inspection scene for the optimized, animated Split Crown Bulwark.

const MODEL_PATH := "res://assets/models/enemies/forge_bulwark/bulwark.glb"
const SOURCE_PATH := "res://assets/source/meshy/forge_bulwark/bulwark_a.glb"
const CLIPS := ["idle", "walk", "attack_anticipation", "attack", "attack_recovery", "hit", "death"]
const LOOPING := ["idle", "walk"]
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var camera: Camera3D
var info: Label
var caption: Label
var reference: Node3D
var clip_index := 0
var yaw := 0.45
var pitch := 0.12
var distance := 6.4
var dragging := false
var paused := false
var autoplay := true
var comparing := false
var elapsed := 0.0
var capture_path := ""
var capture_time := 0.0
var capture_delay := 0.0
var clip_names: Dictionary = {}
var demo := false
var demo_index := -1
var demo_elapsed := 0.0
const DEMO := [["comparison", 5.0], ["idle", 4.0], ["walk", 4.8], ["attack_anticipation", 1.5], ["attack", 1.7], ["attack_recovery", 2.2], ["hit", 1.5], ["death", 4.0], ["turntable", 5.0]]

func _ready() -> void:
	DisplayServer.window_set_title("Starforge — Bulwark animation review")
	var model_resource: PackedScene = load(MODEL_PATH)
	if model_resource == null:
		push_error("Bulwark runtime GLB is not available yet: " + MODEL_PATH)
		get_tree().quit()
		return
	model = model_resource.instantiate()
	add_child(model)
	player = model.find_child("AnimationPlayer", true, false)
	skeleton = model.find_child("*Skeleton*", true, false)
	if skeleton == null:
		for node in model.find_children("*", "Skeleton3D", true, false):
			skeleton = node
	for name in player.get_animation_list():
		var short_name: String = name.get_slice("/", name.get_slice_count("/") - 1)
		if short_name in CLIPS:
			clip_names[short_name] = name
			var animation := player.get_animation(name)
			animation.loop_mode = Animation.LOOP_LINEAR if short_name in LOOPING else Animation.LOOP_NONE
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
	_play(clip_index)
	_update_camera()
	if demo: _next_demo()
	if not capture_path.is_empty():
		player.seek(capture_time, true)
		player.pause()
		paused = true
	print("BULWARK_REVIEW_READY: ", clip_names.size(), " clips")

func _material(color: Color, roughness := 0.65) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = pos
	add_child(node)
	return node

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
	# The scale reference is intentionally simple and separate from the asset.
	_box(Vector3(.022, 2.8, .022), Vector3(-1.6, 1.4, 0), Color("567880"))
	for h in range(15):
		_box(Vector3(.08, .009, .022), Vector3(-1.6, h*.2, 0), Color("8da8ad"))
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
	title.text = "SPLIT CROWN BULWARK  /  ANIMATION REVIEW"
	title.add_theme_font_size_override("font_size", 19)
	title.modulate = Color("dfe8e8")
	stack.add_child(title)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 16)
	info.modulate = Color("71cfbe")
	stack.add_child(info)
	var stats := Label.new()
	stats.text = "2.80 m including crown · 94,019 triangles · %d bones · original textures\nMechanical armor rig · two-arm ground slam" % skeleton.get_bone_count()
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
	clip_index = posmod(index, CLIPS.size())
	elapsed = 0
	if comparing:
		_toggle_comparison()
	player.play(clip_names[CLIPS[clip_index]], 0.12)
	if paused:
		player.advance(0)
		player.pause()
	info.text = "%02d / %02d   %s" % [clip_index + 1, CLIPS.size(), CLIPS[clip_index].to_upper().replace("_", " ")]

func _process(delta: float) -> void:
	caption.position.y = get_viewport().get_visible_rect().size.y - 58
	if demo:
		demo_elapsed += delta
		var shot: String = DEMO[demo_index][0]
		if shot == "turntable":
			yaw = 0.45 + demo_elapsed / float(DEMO[demo_index][1]) * TAU
			_update_camera()
		if demo_elapsed >= float(DEMO[demo_index][1]): _next_demo()
		# Desktop compositors may suppress draws for an occluded window. Movie
		# capture explicitly renders every frame so it cannot repeat a stale frame.
		RenderingServer.force_draw(false, delta)
	if not capture_path.is_empty():
		RenderingServer.force_draw(false, delta)
		capture_delay += delta
		if capture_delay > 1.5:
			var path := capture_path
			capture_path = ""
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			print("BULWARK_CAPTURE ", path)
			get_tree().quit()
	if autoplay and not paused and not comparing:
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
	yaw = 0.45
	pitch = 0.12
	if shot == "comparison":
		_toggle_comparison()
		yaw = 0.0
		pitch = 0.04
		distance = 9.2
		caption.text = "Original source (left)  /  optimized rig (right)\n18% fewer body triangles · p99 sampled surface change 0.26 mm"
	else:
		if comparing: _toggle_comparison()
		_play(CLIPS.find("idle" if shot == "turntable" else shot))
		caption.text = "Authored in-place animation · captured in Godot\n" + ("Full model turntable" if shot == "turntable" else "Mechanical rig · original Meshy textures · torso-mounted crown")
		if shot == "death":
			pitch = 0.38
			distance = 7.4
		else: distance = 6.4
	_update_camera()

func _toggle_comparison() -> void:
	comparing = not comparing
	if comparing:
		if reference == null:
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			if document.append_from_file(SOURCE_PATH, state) != OK:
				comparing = false
				return
			reference = document.generate_scene(state)
			add_child(reference)
			var meshes := reference.find_children("*", "MeshInstance3D", true, false)
			var bounds := AABB()
			var first := true
			for mesh: MeshInstance3D in meshes:
				var box: AABB = reference.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
				bounds = box if first else bounds.merge(box)
				first = false
			var scale_factor := 2.8 / bounds.size.y
			reference.scale = Vector3.ONE * scale_factor
			reference.position = Vector3(-1.6 - bounds.get_center().x * scale_factor, -bounds.position.y * scale_factor, -bounds.get_center().z * scale_factor)
		reference.visible = true
		model.position.x = 1.6
		player.stop()
		skeleton.reset_bone_poses()
		distance = 9.2
		info.text = "SOURCE: 114,658 triangles     |     OPTIMIZED: 94,019"
	else:
		if reference != null: reference.visible = false
		model.position.x = 0
		distance = 6.4
		_play(clip_index)
	_update_camera()

func _update_camera() -> void:
	var target := Vector3(0, 1.45, 0)
	camera.position = target + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*distance
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(3.8, distance-.3)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(13, distance+.3)
		_update_camera()
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x*.006
		pitch = clampf(pitch+event.relative.y*.005, -.3, .85)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				autoplay = false
				_play(clip_index + (-1 if event.shift_pressed else 1))
			KEY_SPACE:
				paused = not paused
				if paused: player.pause()
				else: player.play()
			KEY_R: _play(clip_index)
			KEY_A: autoplay = not autoplay
			KEY_C: _toggle_comparison()
