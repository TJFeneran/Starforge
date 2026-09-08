extends CharacterBody3D

## Third-person locomotion for the frontier guardian.
## Camera-relative move, mouse look, walk/run from Meshy clips.

const WALK_SPEED := 2.6
const RUN_SPEED := 5.4
const ACCEL := 14.0
const DECEL := 16.0
const TURN_SPEED := 10.0
const JUMP_VELOCITY := 4.6
const MOUSE_SENS := 0.0024
const PITCH_MIN := -0.62
const PITCH_MAX := 0.28
const RUN_THRESHOLD := 3.6
const LAND_RECOVER := 0.18
const JUMP_TAKEOFF_TIME := 0.10
const JUMP_LAND_TIME := 0.22
const JUMP_VISUAL_LIFT := 0.12
const JUMP_VISUAL_TUCK := 0.22
const ATTACK_DAMAGE := 34.0
const ATTACK_RANGE := 14.0
const ATTACK_COOLDOWN := 0.28

const HAND_BONE := "RightHand"

@export var walk_scene: PackedScene
@export var run_scene: PackedScene
@export var idle_scene: PackedScene
@export var pulse_bolt_scene: PackedScene

@onready var _yaw: Node3D = $CameraYaw
@onready var _spring: SpringArm3D = $CameraYaw/SpringArm3D
@onready var _camera: Camera3D = $CameraYaw/SpringArm3D/Camera3D
@onready var _visual: Node3D = $Visual
@onready var _model_root: Node3D = $Visual/Model
@onready var _health: Health = $Health
@onready var _weapon: Node3D = $Visual/WeaponAnchor/ForgeSidearm

var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _hand_bone_idx := -1
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_clip := ""
var _was_on_floor := true
var _land_timer := 0.0
var _jump_timer := 0.0
var _jump_visual_offset := Vector3.ZERO
var _base_visual_position := Vector3.ZERO
var _base_model_position := Vector3.ZERO
var _base_model_rotation := Vector3.ZERO
var _base_fov := 55.0
var _spring_base_length := 5.0
var _attack_timer := 0.0


func _ready() -> void:
	add_to_group("player")
	_camera.current = true
	_base_fov = _camera.fov
	_spring_base_length = _spring.spring_length
	_install_locomotion_animations()
	_base_visual_position = _visual.position
	_base_model_position = _model_root.position
	_base_model_rotation = _model_root.rotation
	_setup_weapon_follow()
	_play_clip("loco/idle", 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_health.died.connect(_on_player_died)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw.rotate_y(-event.relative.x * MOUSE_SENS)
		_spring.rotation.x = clampf(
			_spring.rotation.x - event.relative.y * MOUSE_SENS,
			PITCH_MIN,
			PITCH_MAX
		)
		return

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("attack"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_try_attack()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if _health.is_dead:
		velocity = Vector3.ZERO
		return

	# Backup path if _input missed the press (focus quirks).
	if Input.is_action_just_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_try_attack()

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_land_timer = LAND_RECOVER
	_was_on_floor = on_floor

	if not on_floor:
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		_jump_timer = JUMP_TAKEOFF_TIME
		_play_clip("loco/idle", 0.05)

	var input_dir := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var cam_basis := _yaw.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var wish := (right * input_dir.x + forward * input_dir.y)
	var want_run := Input.is_action_pressed("sprint") and wish.length_squared() > 0.01
	var target_speed := RUN_SPEED if want_run else WALK_SPEED
	if _land_timer > 0.0:
		_land_timer = maxf(0.0, _land_timer - delta)
		target_speed *= 0.55

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if wish.length_squared() > 0.0001:
		wish = wish.normalized()
		horizontal = horizontal.move_toward(wish * target_speed, ACCEL * delta)
		var face := atan2(-wish.x, -wish.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, face, TURN_SPEED * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, DECEL * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	# Evaluate floor contact after movement so landing animation starts on the
	# actual impact frame rather than one physics frame late.
	on_floor = is_on_floor()
	if on_floor and not _was_on_floor:
		_land_timer = JUMP_LAND_TIME
		_jump_timer = 0.0
	_was_on_floor = on_floor
	_update_jump_visual(delta, on_floor, horizontal.length())
	_update_animation(horizontal.length(), on_floor)
	# Follow the animated hand after AnimationPlayer updates the skeleton.
	call_deferred("_update_weapon_follow")
	_update_camera_feel(delta, horizontal.length(), on_floor)


func _update_jump_visual(delta: float, on_floor: bool, horizontal_speed: float) -> void:
	# Animate the whole imported model as a safe fallback when no jump clip is
	# available. The stronger silhouette changes make takeoff, hang-time, and
	# impact readable without rewriting individual skeleton bones.
	if _jump_timer > 0.0:
		_jump_timer = maxf(0.0, _jump_timer - delta)

	var target_offset := _base_visual_position
	var target_model_offset := _base_model_position
	var target_tilt := _base_model_rotation.x
	if not on_floor:
		var vertical_phase := clampf(velocity.y / JUMP_VELOCITY, -1.0, 1.0)
		var hang_phase := 1.0 - absf(vertical_phase)
		target_offset.y += JUMP_VISUAL_LIFT + hang_phase * JUMP_VISUAL_TUCK
		# Lean into the jump on ascent and settle back while falling.
		target_tilt += lerpf(-0.20, 0.10, clampf((vertical_phase + 1.0) * 0.5, 0.0, 1.0))
		# A small vertical model compression gives the takeoff/air silhouette
		# more life without touching the imported bone hierarchy.
		target_model_offset.y += sin(hang_phase * PI) * 0.06
	elif _land_timer > 0.0:
		var land_t := clampf(_land_timer / JUMP_LAND_TIME, 0.0, 1.0)
		var impact := sin(land_t * PI)
		target_offset.y -= impact * 0.08
		target_tilt += impact * 0.12
		target_model_offset.y -= impact * 0.04
	else:
		# Grounded idle is always restored to the authored standing transform.
		target_offset = _base_visual_position
		target_model_offset = _base_model_position
		target_tilt = _base_model_rotation.x

	var blend := 1.0 - exp(-18.0 * delta)
	_jump_visual_offset = _jump_visual_offset.lerp(target_offset, blend)
	_visual.position = _visual.position.lerp(_jump_visual_offset, blend)
	_model_root.position = _model_root.position.lerp(target_model_offset, blend)
	_model_root.rotation.x = lerpf(_model_root.rotation.x, target_tilt, 1.0 - exp(-14.0 * delta))


func _setup_weapon_follow() -> void:
	_skeleton = _find_skeleton(_model_root)
	if _skeleton == null or _weapon == null:
		push_warning("Could not set up weapon hand follow")
		return

	_hand_bone_idx = _skeleton.find_bone(HAND_BONE)
	if _hand_bone_idx < 0:
		push_warning("Missing RightHand bone for weapon follow")
		return

	# The imported weapon mesh is authored along +X. Rotate it once so the
	# sidearm barrel points along the weapon root's local -Z axis. The root
	# itself is placed at the hand, so the handle—not the muzzle—is the pivot.
	var model := _weapon.get_node_or_null("Model") as Node3D
	if model:
		model.transform = Transform3D.IDENTITY
		model.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		model.position = Vector3(0.0, -0.08, 0.13)

	var muzzle := _weapon.get_node_or_null("Muzzle") as Marker3D
	if muzzle:
		muzzle.position = Vector3(0.0, 0.03, -0.2)


func _update_weapon_follow() -> void:
	if _skeleton == null or _weapon == null or _hand_bone_idx < 0:
		return

	# Read the animation's actual hand pose. No bone overrides are used: this
	# prevents the imported skeleton from being stretched or folded by the gun.
	var hand_pose: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose_no_override(_hand_bone_idx)
	var aim := -_camera.global_transform.basis.z.normalized()
	var up := _visual.global_transform.basis.y.normalized()
	if absf(aim.dot(up)) > 0.92:
		up = Vector3.UP

	# Keep the handle at the hand while aiming the barrel with the camera.
	_weapon.global_transform = Transform3D(Basis.looking_at(aim, up), hand_pose.origin)


func _try_attack() -> void:
	if _health.is_dead or _attack_timer > 0.0:
		return
	_attack_timer = ATTACK_COOLDOWN

	var aim_dir := -_camera.global_transform.basis.z.normalized()
	var origin := _camera.global_position
	if _weapon and _weapon.has_method("get_muzzle_global"):
		origin = _weapon.get_muzzle_global()

	if pulse_bolt_scene == null:
		push_warning("pulse_bolt_scene is not assigned")
		return

	var bolt := pulse_bolt_scene.instantiate()
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(bolt)
	if bolt.has_method("launch"):
		bolt.launch(origin, aim_dir, ATTACK_DAMAGE)


func _on_player_died() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _install_locomotion_animations() -> void:
	_anim = _find_animation_player(_model_root)
	if _anim == null:
		push_warning("Player model has no AnimationPlayer")
		return

	var lib := AnimationLibrary.new()
	_add_clip_from_scene(lib, "idle", idle_scene if idle_scene else null, true)
	_add_clip_from_scene(lib, "walk", walk_scene)
	_add_clip_from_scene(lib, "run", run_scene)
	if not lib.has_animation("idle"):
		_add_clip_from_scene(lib, "idle", walk_scene, true)
	if _anim.has_animation_library("loco"):
		_anim.remove_animation_library("loco")
	_anim.add_animation_library("loco", lib)
	_current_clip = ""


func _add_clip_from_scene(
	lib: AnimationLibrary,
	clip_name: String,
	scene: PackedScene,
	as_pose := false
) -> void:
	if scene == null:
		return
	var instance := scene.instantiate()
	var source_player := _find_animation_player(instance)
	if source_player == null or source_player.get_animation_list().is_empty():
		instance.queue_free()
		return
	var source_name: String = source_player.get_animation_list()[0]
	var anim: Animation = source_player.get_animation(source_name).duplicate(true)
	if as_pose:
		anim.loop_mode = Animation.LOOP_NONE
		if anim.length > 0.05:
			anim.length = 0.05
	else:
		anim.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation(clip_name, anim)
	instance.queue_free()


func _update_animation(speed: float, on_floor: bool) -> void:
	if _anim == null:
		return
	if not on_floor:
		if _current_clip != "loco/idle":
			_play_clip("loco/idle", 0.1)
		return
	if speed < 0.15:
		_play_clip("loco/idle", 0.2)
		return

	var want := "loco/run" if speed >= RUN_THRESHOLD else "loco/walk"
	_play_clip(want, 0.15)


func _play_clip(clip_name: String, blend: float) -> void:
	if _anim == null or not _anim.has_animation(clip_name):
		return
	if clip_name == _current_clip and _anim.is_playing():
		return
	_anim.play(clip_name, blend)
	_current_clip = clip_name
	if clip_name == "loco/idle":
		_anim.seek(0.0, true)
		_anim.speed_scale = 0.0
	else:
		_anim.speed_scale = 1.0


func _update_camera_feel(delta: float, speed: float, on_floor: bool) -> void:
	var speed_t := clampf(speed / RUN_SPEED, 0.0, 1.0)
	var target_fov := lerpf(_base_fov, _base_fov + 4.0, speed_t)
	if not on_floor:
		target_fov += 1.5
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-6.0 * delta))
	var target_len := lerpf(_spring_base_length, _spring_base_length + 0.55, speed_t)
	_spring.spring_length = lerpf(_spring.spring_length, target_len, 1.0 - exp(-5.0 * delta))


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
