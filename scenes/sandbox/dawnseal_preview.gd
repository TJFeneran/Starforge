extends Node3D
## Isolated GLB inspection; never changes the playable weapon or lobby.
## Drag: orbit. Wheel: zoom. 1/2/3/4: hero/side/front/top. Space: turntable.

const MODEL = preload("res://assets/models/gear/guns/dawnseal/dawnseal.glb")
var pivot := Node3D.new()
var camera := Camera3D.new()
var yaw := -1.12
var pitch := 0.28
var distance := 0.60
var spinning := false
var dragging := false
var capture_path := ""
var frames := 0

func _ready() -> void:
	add_child(MODEL.instantiate())
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("172031")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("aec4e5")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 0.85
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("748fae")
	sky_material.sky_horizon_color = Color("d8d4c2")
	sky_material.ground_bottom_color = Color("202735")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.glow_enabled = true
	settings.glow_intensity = 0.35
	settings.glow_bloom = 0.0
	environment.environment = settings
	add_child(environment)
	_add_light(Vector3(-0.5, 0.7, -0.5), Color("ffe6bc"), 1.0)
	_add_light(Vector3(0.4, 0.4, 0.2), Color("91baff"), 0.75)
	_add_light(Vector3(-0.3, 0.15, 0.5), Color("e6eeff"), 0.4)
	pivot.position = Vector3(0, 0.007, -0.125)
	add_child(pivot)
	pivot.add_child(camera)
	camera.near = 0.005
	camera.far = 10
	camera.fov = 39
	camera.current = true
	_update_camera()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var label := Label.new()
	label.text = "DAWNSEAL  /  BLENDER → GLB → GODOT\nDrag to orbit · Wheel to zoom · 1 Hero · 2 Side · 3 Front · 4 Top · Space turntable"
	label.position = Vector2(26, 22)
	label.add_theme_font_size_override("font_size", 20)
	canvas.add_child(label)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")

func _add_light(position_: Vector3, color_: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = color_
	light.light_energy = energy
	light.shadow_enabled = true
	add_child(light)
	light.position = position_
	light.look_at(Vector3(0, 0, -0.12))

func _update_camera() -> void:
	camera.position = Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)) * distance
	camera.look_at(pivot.global_position, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance * 0.9, 0.25, 1.5)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * 1.1, 0.25, 1.5)
		_update_camera()
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.008, -1.5, 1.5)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: spinning = not spinning
			KEY_1:
				yaw = -1.12
				pitch = 0.28
			KEY_2:
				yaw = -PI / 2
				pitch = 0.0
			KEY_3:
				yaw = 0.0
				pitch = 0.0
			KEY_4:
				yaw = -PI / 2
				pitch = 1.5
		_update_camera()

func _process(delta: float) -> void:
	if spinning:
		yaw += delta * 0.35
		_update_camera()
	if not capture_path.is_empty():
		frames += 1
		if frames == 40:
			await RenderingServer.frame_post_draw
			var error := get_viewport().get_texture().get_image().save_png(capture_path)
			print("DAWNSEAL_CAPTURE ", error)
			get_tree().quit(error)
