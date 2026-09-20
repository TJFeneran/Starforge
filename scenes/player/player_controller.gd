extends CharacterBody3D

## Third-person locomotion for Mixamo Exo Gray.
## Camera-relative move, mouse look, walk/run from Mixamo clips.

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
const ZOOM_STEP := 0.65
const MIN_THIRD_PERSON_DISTANCE := 1.25
const FIRST_PERSON_DISTANCE := 0.05
const BODY_HIDE_DISTANCE := 1.0

const HAND_BONE_CANDIDATES := [
	"mixamorig_RightHand",
	"mixamorig:RightHand",
	"RightHand",
]
const HIP_BONE_CANDIDATES := [
	"mixamorig_RightUpLeg",
	"mixamorig:RightUpLeg",
	"mixamorig_Hips",
	"mixamorig:Hips",
	"Hips",
]
## Holster offset in the character visual's local space (right hip).
## Positive Z sits toward the back of the thigh for this mesh facing.
const HOLSTER_OFFSET := Vector3(0.07, 0.02, 0.14)
const PRIMARY_STOW_OFFSET := Vector3(-0.16, 0.90, 0.39)

@export var walk_scene: PackedScene
@export var run_scene: PackedScene
@export var idle_scene: PackedScene
@export var jump_scene: PackedScene
@export var pistol_aim_scene: PackedScene ## Stationary ADS: Mixamo Pistol Idle (not Pistol Aim).
@export var pistol_run_scene: PackedScene
@export var pistol_jump_scene: PackedScene
@export var pistol_strafe_scene: PackedScene ## Mixamo Pistol Strafe; opposite side is mirrored at install.
@export var run_stream: AudioStream
@export var stairs_run_stream: AudioStream
@export var land_stream: AudioStream
@export_range(-40.0, 6.0, 0.1) var footstep_volume_db: float = -8.0
@export_range(-40.0, 6.0, 0.1) var land_volume_db: float = -6.0

@onready var _yaw: Node3D = $CameraYaw
@onready var _spring: SpringArm3D = $CameraYaw/SpringArm3D
@onready var _camera: Camera3D = $CameraYaw/SpringArm3D/Camera3D
@onready var _visual: Node3D = $Visual
@onready var _model_root: Node3D = $Visual/Model
@onready var _health: Health = $Health
@onready var _weapon: GunMount = $Visual/WeaponAnchor/GunMount
@onready var _footsteps: AudioStreamPlayer3D = $Footsteps
@onready var _land_sfx: AudioStreamPlayer3D = $LandImpact

var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _hand_bone_idx := -1
var _hip_bone_idx := -1
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
var _zoom_distance := 5.0
var _first_person := false
var _suppress_attack_until_release := false
var _aim_move_input := Vector2.ZERO
var _run_loop_stream: AudioStream
var _stairs_loop_stream: AudioStream
var _on_stairs_audio := false


func _ready() -> void:
	add_to_group("player")
	_camera.current = true
	_base_fov = _camera.fov
	_spring_base_length = _spring.spring_length
	_zoom_distance = _spring_base_length
	_install_locomotion_animations()
	_base_visual_position = _visual.position
	_base_model_position = _model_root.position
	_base_model_rotation = _model_root.rotation
	_weapon.set_shooter(self)
	_weapon.recoil.connect(_on_gun_recoil)
	_setup_weapon_follow()
	_play_clip("loco/idle", 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_health.died.connect(_on_player_died)
	_setup_run_loop()


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
		# Esc is owned by the pause menu autoload during gameplay.
		return

	if event.is_action_pressed("attack"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_suppress_attack_until_release = true
		get_viewport().set_input_as_handled()
	elif event.is_action_released("attack"):
		_suppress_attack_until_release = false


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _health.is_dead:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if not _first_person:
			if _zoom_distance <= MIN_THIRD_PERSON_DISTANCE + 0.001:
				_first_person = true
			else:
				_zoom_distance = maxf(MIN_THIRD_PERSON_DISTANCE, _zoom_distance - ZOOM_STEP)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if _first_person:
			_first_person = false
			_zoom_distance = MIN_THIRD_PERSON_DISTANCE
		else:
			_zoom_distance = minf(_spring_base_length, _zoom_distance + ZOOM_STEP)
	else:
		return
	get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _health.is_dead:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		_weapon.equip(event.keycode - KEY_1)
	elif event.keycode == KEY_R:
		_weapon.reload()
	else:
		return
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _health.is_dead:
		_weapon.process_trigger(delta, false, false, _camera.global_position, -_camera.global_transform.basis.z)
		velocity = Vector3.ZERO
		_stop_run_loop()
		return

	if not Input.is_action_pressed("attack"):
		_suppress_attack_until_release = false

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_land_timer = LAND_RECOVER
	_was_on_floor = on_floor

	if not on_floor:
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		_jump_timer = JUMP_TAKEOFF_TIME
		_play_clip(_jump_clip_name(), 0.05)

	var input_dir := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	_aim_move_input = input_dir
	var cam_basis := _yaw.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var wish := (right * input_dir.x + forward * input_dir.y)
	var aiming := _is_aiming()
	var want_run := Input.is_action_pressed("sprint") and wish.length_squared() > 0.01 and not aiming
	var target_speed := RUN_SPEED if want_run else WALK_SPEED
	if aiming:
		# Aim locomotion uses pistol-run clip; keep a controlled move speed.
		target_speed = WALK_SPEED * 1.15
	if _land_timer > 0.0:
		_land_timer = maxf(0.0, _land_timer - delta)
		target_speed *= 0.55

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if wish.length_squared() > 0.0001:
		wish = wish.normalized()
		horizontal = horizontal.move_toward(wish * target_speed, ACCEL * delta)
		var face_dir := wish
		if aiming:
			# Face camera yaw while ADS so the pistol aim pose points downrange.
			face_dir = forward
		var face := atan2(-face_dir.x, -face_dir.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, face, TURN_SPEED * delta)
	elif aiming:
		var face := atan2(-forward.x, -forward.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, face, TURN_SPEED * delta)
		horizontal = horizontal.move_toward(Vector3.ZERO, DECEL * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, DECEL * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_step_up(wish)
	move_and_slide()
	# Evaluate floor contact after movement so landing animation starts on the
	# actual impact frame rather than one physics frame late.
	on_floor = is_on_floor()
	if on_floor and not _was_on_floor:
		_land_timer = JUMP_LAND_TIME
		_jump_timer = 0.0
		_play_land_impact()
	_was_on_floor = on_floor
	_update_jump_visual(delta, on_floor, horizontal.length())
	_update_animation(horizontal, on_floor)
	_update_run_footsteps(delta, horizontal.length(), on_floor)
	# Follow the animated hand after AnimationPlayer updates the skeleton.
	call_deferred("_update_weapon_follow")
	var fire_allowed := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (_is_aiming() or _first_person)
	_weapon.process_trigger(
		delta, fire_allowed and not _suppress_attack_until_release and Input.is_action_pressed("attack"),
		_is_aiming(), _camera.global_position, -_camera.global_transform.basis.z
	)
	_update_camera_feel(delta, horizontal.length(), on_floor)


func _setup_run_loop() -> void:
	if _footsteps == null:
		return
	_run_loop_stream = _prepare_loop_stream(run_stream)
	_stairs_loop_stream = _prepare_loop_stream(stairs_run_stream)
	var initial := _run_loop_stream if _run_loop_stream != null else _stairs_loop_stream
	if initial == null:
		return
	_footsteps.stream = initial
	_footsteps.volume_db = footstep_volume_db
	_footsteps.bus = &"SFX"
	_on_stairs_audio = false


func _prepare_loop_stream(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	var wav := stream as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		var bytes_per_frame := 2 if not wav.stereo else 4
		if wav.format == AudioStreamWAV.FORMAT_8_BITS:
			bytes_per_frame = 1 if not wav.stereo else 2
		if bytes_per_frame > 0 and wav.data.size() > 0:
			wav.loop_begin = 0
			wav.loop_end = maxi(int(wav.data.size() / float(bytes_per_frame)) - 1, 1)
		return wav
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
		return ogg
	return stream


func _update_run_footsteps(_delta: float, speed: float, on_floor: bool) -> void:
	if _footsteps == null:
		return
	var running := on_floor and speed >= RUN_THRESHOLD
	if not running:
		_stop_run_loop()
		_on_stairs_audio = false
		return
	var want_stairs := _is_on_stairs() and _stairs_loop_stream != null
	var want_stream: AudioStream = _stairs_loop_stream if want_stairs else _run_loop_stream
	if want_stream == null:
		_stop_run_loop()
		return
	if _footsteps.stream != want_stream or want_stairs != _on_stairs_audio:
		_footsteps.stream = want_stream
		_footsteps.volume_db = footstep_volume_db
		_on_stairs_audio = want_stairs
		_footsteps.play()
	elif not _footsteps.playing:
		_footsteps.play()


## Stair ramps / monument approach: tilted floor or stair-named colliders.
func _is_on_stairs() -> bool:
	if not is_on_floor():
		return false
	if get_floor_normal().y < 0.985:
		return true
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var node := col.get_collider() as Node
		if _node_looks_like_stairs(node):
			return true
	return false


func _node_looks_like_stairs(node: Node) -> bool:
	var cur := node
	while cur != null:
		var n := String(cur.name)
		if n.contains("Stair") or n.contains("stair") or n == "Approach" or n.ends_with("Ramp"):
			return true
		cur = cur.get_parent()
	return false


func _stop_run_loop() -> void:
	if _footsteps != null and _footsteps.playing:
		_footsteps.stop()


func _play_land_impact() -> void:
	if _land_sfx == null or land_stream == null:
		return
	_land_sfx.stream = land_stream
	_land_sfx.volume_db = land_volume_db + randf_range(-1.0, 1.0)
	_land_sfx.pitch_scale = randf_range(0.96, 1.04)
	_land_sfx.play()


func _step_up(wish: Vector3) -> void:
	if not is_on_floor() or wish.length_squared() < 0.0001:
		return
	var space := get_world_3d().direct_space_state
	var heading := Vector3(wish.x, 0.0, wish.z).normalized()
	var probe := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, 0.12, 0.0),
		global_position + heading * 0.55 + Vector3(0.0, 0.12, 0.0),
		1
	)
	probe.exclude = [get_rid()]
	var blocked: Dictionary = space.intersect_ray(probe)
	if blocked.is_empty():
		return
	var up := PhysicsRayQueryParameters3D.create(
		global_position + heading * 0.42 + Vector3(0.0, 0.55, 0.0),
		global_position + heading * 0.42 + Vector3(0.0, 0.02, 0.0),
		1
	)
	up.exclude = [get_rid()]
	var tread: Dictionary = space.intersect_ray(up)
	if tread.is_empty():
		return
	var rise: float = tread.position.y - global_position.y
	if rise <= 0.02 or rise > 0.48:
		return
	var ceiling := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, 1.7, 0.0),
		global_position + Vector3(0.0, 1.7 + rise, 0.0),
		1
	)
	ceiling.exclude = [get_rid()]
	if not space.intersect_ray(ceiling).is_empty():
		return
	global_position.y += rise + 0.02


func _update_jump_visual(delta: float, on_floor: bool, horizontal_speed: float) -> void:
	# Procedural squash is only a fallback when no Mixamo jump clip is installed.
	if _jump_timer > 0.0:
		_jump_timer = maxf(0.0, _jump_timer - delta)

	if _has_clip("loco/jump") or _has_clip("loco/pistol_jump"):
		var blend_reset := 1.0 - exp(-18.0 * delta)
		_visual.position = _visual.position.lerp(_base_visual_position, blend_reset)
		_model_root.position = _model_root.position.lerp(_base_model_position, blend_reset)
		_model_root.rotation.x = lerpf(_model_root.rotation.x, _base_model_rotation.x, blend_reset)
		_jump_visual_offset = _visual.position
		return

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

	_hand_bone_idx = _find_named_bone(_skeleton, HAND_BONE_CANDIDATES, "RightHand")
	_hip_bone_idx = _find_named_bone(_skeleton, HIP_BONE_CANDIDATES, "UpLeg")
	if _hand_bone_idx < 0:
		push_warning("Missing RightHand bone for weapon follow")
	if _hip_bone_idx < 0:
		push_warning("Missing hip bone for weapon holster")

	_update_weapon_follow()


func _update_weapon_follow() -> void:
	if _skeleton == null or _weapon == null:
		return

	if _first_person:
		# Each gun keeps a separate first-person offset; large rifles and the
		# Monument chamber need more room than the compact starter pistol.
		var offset := _weapon.definition.first_person_ads_offset if _is_aiming() else _weapon.definition.first_person_offset
		_weapon.global_transform = _camera.global_transform * Transform3D(Basis.IDENTITY, offset)
		return

	var aiming := _is_aiming()
	if aiming:
		if _hand_bone_idx < 0:
			return
		var hand_pose: Transform3D = (
			_skeleton.global_transform * _skeleton.get_bone_global_pose_no_override(_hand_bone_idx)
		)
		var aim := -_camera.global_transform.basis.z.normalized()
		var up := _visual.global_transform.basis.y.normalized()
		if absf(aim.dot(up)) > 0.92:
			up = Vector3.UP
		# Keep the handle at the hand while aiming the barrel with the camera.
		_weapon.global_transform = Transform3D(Basis.looking_at(aim, up), hand_pose.origin)
		return

	if _weapon.definition.slot == "primary":
		# Long guns rest diagonally across the back instead of crossing the leg.
		var visual_basis := _visual.global_transform.basis
		var stow_origin := _visual.global_position + visual_basis * PRIMARY_STOW_OFFSET
		var barrel_direction := (visual_basis.y + visual_basis.x * 0.35).normalized()
		_weapon.global_transform = Transform3D(
			Basis.looking_at(barrel_direction, -visual_basis.z), stow_origin
		)
		return

	if _hip_bone_idx < 0:
		return
	var hip_pose: Transform3D = (
		_skeleton.global_transform * _skeleton.get_bone_global_pose_no_override(_hip_bone_idx)
	)
	var visual_basis := _visual.global_transform.basis
	var holster_origin: Vector3 = hip_pose.origin + visual_basis * HOLSTER_OFFSET
	# Aim the authored -Z barrel down the leg while holstered.
	var up := visual_basis.y.normalized()
	var forward := -visual_basis.z.normalized()
	_weapon.global_transform = Transform3D(Basis.looking_at(-up, forward), holster_origin)


func _is_aiming() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("aim")


func _on_gun_recoil(amount_degrees: float) -> void:
	_spring.rotation.x = clampf(
		_spring.rotation.x - deg_to_rad(amount_degrees) * 0.35,
		PITCH_MIN, PITCH_MAX
	)


func _on_player_died() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DeathOverlay.show_death()


func _install_locomotion_animations() -> void:
	_anim = _find_animation_player(_model_root)
	if _anim == null:
		push_warning("Player model has no AnimationPlayer")
		return

	var lib := AnimationLibrary.new()
	_add_clip_from_scene(lib, "idle", idle_scene if idle_scene else null, false)
	_add_clip_from_scene(lib, "walk", walk_scene)
	_add_clip_from_scene(lib, "run", run_scene)
	_add_clip_from_scene(lib, "jump", jump_scene, false, false)
	_add_clip_from_scene(lib, "pistol_aim", pistol_aim_scene)
	_add_clip_from_scene(lib, "pistol_run", pistol_run_scene)
	_add_clip_from_scene(lib, "pistol_jump", pistol_jump_scene, false, false)
	_add_strafe_clips(lib)
	if not lib.has_animation("idle"):
		_add_clip_from_scene(lib, "idle", walk_scene, false)
	if _anim.has_animation_library("loco"):
		_anim.remove_animation_library("loco")
	_anim.add_animation_library("loco", lib)
	_current_clip = ""


func _add_strafe_clips(lib: AnimationLibrary) -> void:
	if pistol_strafe_scene == null:
		return
	var instance := pistol_strafe_scene.instantiate()
	var source_player := _find_animation_player(instance)
	if source_player == null or source_player.get_animation_list().is_empty():
		instance.queue_free()
		return
	var source_name: String = source_player.get_animation_list()[0]
	var left: Animation = source_player.get_animation(source_name).duplicate(true)
	_strip_hips_root_motion(left)
	left.loop_mode = Animation.LOOP_LINEAR
	# Mixamo "Pistol Strafe" moves toward the character's left; mirror for right.
	var right := _mirror_mixamo_clip(left)
	lib.add_animation("pistol_strafe_left", left)
	lib.add_animation("pistol_strafe_right", right)
	instance.queue_free()


func _mirror_mixamo_clip(anim: Animation) -> Animation:
	var out := anim.duplicate(true) as Animation
	# Two-pass path swap avoids Left/Right collisions while renaming.
	for track_idx in out.get_track_count():
		var path := str(out.track_get_path(track_idx))
		out.track_set_path(
			track_idx,
			NodePath(path.replace("Left", "__L__").replace("Right", "__R__"))
		)
	for track_idx in out.get_track_count():
		var path := str(out.track_get_path(track_idx))
		out.track_set_path(
			track_idx,
			NodePath(path.replace("__L__", "Right").replace("__R__", "Left"))
		)
		match out.track_get_type(track_idx):
			Animation.TYPE_POSITION_3D:
				for key_idx in out.track_get_key_count(track_idx):
					var value: Vector3 = out.track_get_key_value(track_idx, key_idx)
					out.track_set_key_value(track_idx, key_idx, Vector3(-value.x, value.y, value.z))
			Animation.TYPE_ROTATION_3D:
				for key_idx in out.track_get_key_count(track_idx):
					var q: Quaternion = out.track_get_key_value(track_idx, key_idx)
					# Reflect across YZ: (x, y, z, w) -> (x, -y, -z, w)
					out.track_set_key_value(track_idx, key_idx, Quaternion(q.x, -q.y, -q.z, q.w))
	return out


func _add_clip_from_scene(
	lib: AnimationLibrary,
	clip_name: String,
	scene: PackedScene,
	as_pose := false,
	loop := true
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
	_strip_hips_root_motion(anim)
	if as_pose:
		anim.loop_mode = Animation.LOOP_NONE
		if anim.length > 0.05:
			anim.length = 0.05
	elif loop:
		anim.loop_mode = Animation.LOOP_LINEAR
	else:
		anim.loop_mode = Animation.LOOP_NONE
	lib.add_animation(clip_name, anim)
	instance.queue_free()


func _strip_hips_root_motion(anim: Animation) -> void:
	## Safety net if a Mixamo clip still has locomotion translation on hips.
	## Locks only axes that travel more than a few centimeters; keeps bob.
	for track_idx in anim.get_track_count():
		if anim.track_get_type(track_idx) != Animation.TYPE_POSITION_3D:
			continue
		var path := str(anim.track_get_path(track_idx))
		if not ("Hips" in path or "hips" in path):
			continue
		var key_count := anim.track_get_key_count(track_idx)
		if key_count <= 1:
			continue
		var first: Vector3 = anim.track_get_key_value(track_idx, 0)
		var min_v := first
		var max_v := first
		for key_idx in key_count:
			var value: Vector3 = anim.track_get_key_value(track_idx, key_idx)
			min_v = min_v.min(value)
			max_v = max_v.max(value)
		var delta := max_v - min_v
		var lock_x := delta.x > 0.05
		var lock_y := delta.y > 0.05
		var lock_z := delta.z > 0.05
		if not (lock_x or lock_y or lock_z):
			continue
		for key_idx in key_count:
			var value: Vector3 = anim.track_get_key_value(track_idx, key_idx)
			anim.track_set_key_value(
				track_idx,
				key_idx,
				Vector3(
					first.x if lock_x else value.x,
					first.y if lock_y else value.y,
					first.z if lock_z else value.z
				)
			)


func _has_clip(clip_name: String) -> bool:
	return _anim != null and _anim.has_animation(clip_name)


func _jump_clip_name() -> String:
	if _is_aiming() and _has_clip("loco/pistol_jump"):
		return "loco/pistol_jump"
	if _has_clip("loco/jump"):
		return "loco/jump"
	return "loco/idle"


func _update_animation(horizontal: Vector3, on_floor: bool) -> void:
	if _anim == null:
		return
	var speed := horizontal.length()
	var aiming := _is_aiming()
	if not on_floor:
		var jump_clip := _jump_clip_name()
		if jump_clip != "loco/idle":
			if _current_clip != jump_clip:
				_play_clip(jump_clip, 0.1)
			elif not _anim.is_playing():
				# Hold the last jump pose if airtime outlasts the clip.
				_anim.play(jump_clip)
				_anim.seek(_anim.current_animation_length, true)
				_anim.speed_scale = 0.0
		elif _current_clip != "loco/idle":
			_play_clip("loco/idle", 0.1)
		return

	if aiming:
		if speed < 0.15:
			_play_clip("loco/pistol_aim" if _has_clip("loco/pistol_aim") else "loco/idle", 0.15)
		else:
			_play_clip(_aim_move_clip(horizontal), 0.15)
		return

	if speed < 0.15:
		_play_clip("loco/idle", 0.2)
		return

	var want := "loco/run" if speed >= RUN_THRESHOLD else "loco/walk"
	_play_clip(want, 0.15)


func _aim_move_clip(_horizontal: Vector3 = Vector3.ZERO) -> String:
	# Use raw ADS stick/keys so velocity lag and facing lerp can't keep pistol_run.
	# With this project's get_vector order, x = strafe (right+), y = forward+.
	var lateral := _aim_move_input.x
	var forward := _aim_move_input.y
	if absf(lateral) >= absf(forward) and absf(lateral) > 0.2:
		if lateral < 0.0 and _has_clip("loco/pistol_strafe_left"):
			return "loco/pistol_strafe_left"
		if lateral > 0.0 and _has_clip("loco/pistol_strafe_right"):
			return "loco/pistol_strafe_right"
	if _has_clip("loco/pistol_run"):
		return "loco/pistol_run"
	return "loco/run"


func _play_clip(clip_name: String, blend: float) -> void:
	if _anim == null or not _anim.has_animation(clip_name):
		return
	if clip_name == _current_clip and _anim.is_playing():
		return
	_anim.play(clip_name, blend)
	_current_clip = clip_name
	_anim.speed_scale = 1.0


func _find_named_bone(skeleton: Skeleton3D, candidates: Array, fallback_suffix: String) -> int:
	for bone_name in candidates:
		var idx := skeleton.find_bone(bone_name)
		if idx >= 0:
			return idx
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		if name.ends_with(fallback_suffix) or name.ends_with(fallback_suffix.to_lower()):
			return i
	return -1


func _update_camera_feel(delta: float, speed: float, on_floor: bool) -> void:
	var speed_t := clampf(speed / RUN_SPEED, 0.0, 1.0)
	var aim_t := 1.0 if _is_aiming() else 0.0
	var target_fov := lerpf(_base_fov, _base_fov - 6.0, aim_t)
	target_fov = lerpf(target_fov, target_fov + 4.0, speed_t * (1.0 - aim_t))
	if not on_floor:
		target_fov += 1.5 * (1.0 - aim_t)
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-8.0 * delta))
	var target_len := FIRST_PERSON_DISTANCE if _first_person else _zoom_distance - 0.85 * aim_t
	if not _first_person:
		target_len += 0.55 * speed_t * (1.0 - aim_t)
		target_len = clampf(target_len, MIN_THIRD_PERSON_DISTANCE, _spring_base_length)
	_spring.spring_length = lerpf(_spring.spring_length, target_len, 1.0 - exp(-7.0 * delta))
	# The camera can also be pushed inward by a wall. Hide the local body before
	# it enters the near plane, while leaving the hand-held weapon visible.
	_model_root.visible = _camera.global_position.distance_to(_yaw.global_position) > BODY_HIDE_DISTANCE


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
