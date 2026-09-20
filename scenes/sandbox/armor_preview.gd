extends Node3D

const MODEL_HEIGHT := 1.8
const TALL_HELMET_HEIGHT := 2.16
const TALL_HELMET_MODELS := ["SignalMantle", "HorizonAegis"]
const MODEL_SPACING := 2.3
const LOOK_AT_HEIGHT := 1.02
const ARMOR_ORDER := [
	"Dustcoat", "OutpostPlate", "TrailWarden", "SignalMantle", "QuarryShell",
	"Riftward", "Nightwell", "HorizonAegis", "SolarHeart",
]
const CLIP_NAMES := ["walk", "run", "strafe", "jump", "aim", "idle"]
const CLIP_SOURCES := [
	preload("res://assets/models/characters/exo_gray_walk.glb"),
	preload("res://assets/models/characters/exo_gray_run.glb"),
	preload("res://assets/models/characters/exo_gray_pistol_strafe.glb"),
	preload("res://assets/models/characters/exo_gray_jump.glb"),
	preload("res://assets/models/characters/exo_gray_pistol_aim.glb"),
	preload("res://assets/models/characters/exo_gray_idle.glb"),
]
const CLIP_DURATIONS := [2.7, 2.6, 2.4, 1.05, 2.4, 1.15]

@onready var _camera: Camera3D = $Camera3D
var _yaw := 0.0
var _pitch := 0.03
var _distance := 4.8
var _dragging := false
var _players: Array[AnimationPlayer] = []
var _clip_index := 0
var _clip_time := 0.0
var _target := Vector3(0.0, LOOK_AT_HEIGHT, 0.0)
var _initial_target := Vector3(0.0, LOOK_AT_HEIGHT, 0.0)
var _move_left := false
var _move_right := false
var _move_forward := false
var _move_back := false
var _speed_boost := false


func _ready() -> void:
	var models: Array[Node3D] = []
	for name in ARMOR_ORDER:
		var model: Node3D = get_node_or_null(name)
		if model != null:
			models.append(model)
	var library := _build_animation_library()
	for index in models.size():
		var model := models[index]
		var x_position := (index - (models.size() - 1) * 0.5) * MODEL_SPACING
		_fit_model(model, x_position)
		var label: Label3D = get_node_or_null("%sLabel" % model.name)
		if label != null:
			label.position.x = x_position
			if model.name in TALL_HELMET_MODELS:
				label.position.y = 2.5
		_players.append(_create_animation_player(model, library))
	if models.size() > 3:
		_initial_target.x = -((models.size() - 1) * 0.5 - 1.0) * MODEL_SPACING
	_target = _initial_target
	_play_clip(0)
	_update_camera()


func _process(delta: float) -> void:
	_clip_time += delta
	if _clip_time >= CLIP_DURATIONS[_clip_index]:
		_play_clip((_clip_index + 1) % CLIP_NAMES.size())
	var rightward := float(_move_right) - float(_move_left)
	var forwardward := float(_move_forward) - float(_move_back)
	if rightward != 0.0 or forwardward != 0.0:
		var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
		var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		var direction := (right * rightward + forward * forwardward).normalized()
		var speed := 7.0 if _speed_boost else 3.5
		_target += direction * speed * delta
		_update_camera()


func _build_animation_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for index in CLIP_NAMES.size():
		var source: Node = CLIP_SOURCES[index].instantiate()
		var source_player: AnimationPlayer = source.get_node("AnimationPlayer")
		var animation: Animation = source_player.get_animation("mixamo_com").duplicate(true)
		animation.loop_mode = Animation.LOOP_NONE if CLIP_NAMES[index] == "jump" else Animation.LOOP_LINEAR
		library.add_animation(CLIP_NAMES[index], animation)
		source.free()
	return library


func _create_animation_player(model: Node3D, library: AnimationLibrary) -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "PreviewAnimations"
	model.add_child(player)
	player.add_animation_library("", library)
	return player


func _play_clip(index: int) -> void:
	_clip_index = index
	_clip_time = 0.0
	for player in _players:
		player.play(CLIP_NAMES[_clip_index], 0.22)
	$CanvasLayer/Animation.text = "ANIMATION: %s" % CLIP_NAMES[_clip_index].to_upper()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(2.6, _distance - 0.4)
			_update_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(18.0, _distance + 0.4)
			_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.007
		_pitch = clampf(_pitch + event.relative.y * 0.007, -0.6, 0.6)
		_update_camera()
	elif event is InputEventKey:
		match event.keycode:
			KEY_A:
				_move_left = event.pressed
			KEY_D:
				_move_right = event.pressed
			KEY_W:
				_move_forward = event.pressed
			KEY_S:
				_move_back = event.pressed
			KEY_SHIFT:
				_speed_boost = event.pressed
			KEY_R:
				if event.pressed and not event.echo:
					_yaw = 0.0
					_pitch = 0.03
					_distance = 4.8
					_target = _initial_target
					_update_camera()
			KEY_SPACE:
				if event.pressed and not event.echo:
					_play_clip((_clip_index + 1) % CLIP_NAMES.size())


func _update_camera() -> void:
	_camera.position = _target + Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	) * _distance
	_camera.look_at(_target)


func _fit_model(model: Node3D, x_position: float) -> void:
	var bounds := _mesh_bounds(model)
	if bounds.is_empty():
		push_warning("No visible mesh found for %s" % model.name)
		return
	var minimum: Vector3 = bounds[0]
	var maximum: Vector3 = bounds[1]
	var height := maximum.y - minimum.y
	if height <= 0.0:
		return
	# Tall helmet pieces extend above the shared character height so the bodies
	# remain comparable in size to the other armors.
	var target_height := TALL_HELMET_HEIGHT if model.name in TALL_HELMET_MODELS else MODEL_HEIGHT
	var factor := target_height / height
	model.scale = Vector3.ONE * factor
	model.position = Vector3(
		x_position - (minimum.x + maximum.x) * 0.5 * factor,
		-minimum.y * factor,
		-(minimum.z + maximum.z) * 0.5 * factor
	)


func _mesh_bounds(model: Node3D) -> Array[Vector3]:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	if meshes.is_empty():
		return []
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for mesh_instance in meshes:
		var box := mesh_instance.get_aabb()
		for x in [box.position.x, box.end.x]:
			for y in [box.position.y, box.end.y]:
				for z in [box.position.z, box.end.z]:
					var point := model.to_local(mesh_instance.to_global(Vector3(x, y, z)))
					minimum = minimum.min(point)
					maximum = maximum.max(point)
	return [minimum, maximum]


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node)
	for child in node.get_children():
		_collect_meshes(child, output)
