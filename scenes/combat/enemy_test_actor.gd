extends CharacterBody3D
## Lightweight field combat harness for newly authored enemy animation sets.
## Visual/model and timing are supplied per spawn; this does not own campaign state.

const ENEMY_PROJECTILE := preload("res://scenes/combat/enemy_projectile.gd")
const ENERGY_SHOT_SOUND := preload("res://assets/audio/weapons/348164__djfroyd__laser-one-shot-1.wav")
const IMPACT_SOUND := preload("res://assets/audio/player/669714__vestibule-door__single-big-impact-large-creature-jumping-down.wav")

@export var model_scene: PackedScene
@export var display_name := "Enemy"
@export var height_m := 1.8
@export var radius_m := 0.45
@export var move_speed := 3.0
@export var attack_damage := 10.0
@export var attack_range := 1.5
@export var aggro_range := 18.0
@export var attack_cooldown := 1.0
@export var attack_lunge_speed := 0.0
@export_enum("melee", "marksman", "ray", "slam") var attack_style := "melee"
@export var projectile_speed := 30.0
@export var slam_radius := 3.2
@export var contact_fraction := 0.3
@export var flying := false
@export var attack_clip := "attack"
@export var idle_clip := "idle"
@export var move_clip := "walk"
@export var forward_offset := 0.0

@onready var _health: Health = $Health
@onready var _visual: Node3D = $Visual

var _player: Node3D
var _animations: AnimationPlayer
var _clip_names: Dictionary = {}
var _current_clip := ""
var _attack_elapsed := -1.0
var _attack_stage := ""
var _stage_length := 0.8
var _did_damage := false
var _cooldown := 0.0
var _hit_elapsed := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _warning: Node3D
var _locked_target := Vector3.ZERO
var _strafe_sign := 1.0
var _attack_sound: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 3 # field and player
	_make_collision()
	if model_scene:
		var instance := model_scene.instantiate() as Node3D
		_visual.add_child(instance)
		_animations = instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _animations:
			for name: String in _animations.get_animation_list():
				_clip_names[name.get_slice("/", name.get_slice_count("/") - 1)] = name
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_play(idle_clip)
	_make_label()
	_make_attack_sound()


func _make_attack_sound() -> void:
	_attack_sound = AudioStreamPlayer3D.new()
	_attack_sound.stream = IMPACT_SOUND if attack_style in ["melee", "slam"] else ENERGY_SHOT_SOUND
	_attack_sound.pitch_scale = 0.72 if attack_style == "slam" else (1.35 if attack_style == "marksman" else 1.0)
	_attack_sound.volume_db = -5.0 if attack_style == "slam" else -12.0
	_attack_sound.max_distance = 32.0
	_attack_sound.unit_size = 3.0
	_attack_sound.bus = "SFX"
	add_child(_attack_sound)


func _make_collision() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius_m
	capsule.height = maxf(height_m, radius_m * 2.0)
	collision.shape = capsule
	collision.position.y = 0.0 if flying else height_m * 0.5
	add_child(collision)


func _make_label() -> void:
	var label := Label3D.new()
	label.text = display_name.to_upper()
	label.position.y = height_m + (0.5 if flying else 0.25)
	label.font_size = 36
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _physics_process(delta: float) -> void:
	if _health.is_dead:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	_cooldown = maxf(0.0, _cooldown - delta)
	if not flying and not is_on_floor():
		velocity.y -= _gravity * delta
	var toward := _player.global_position - global_position
	toward.y = 0.0
	var distance_to_player := toward.length()
	if distance_to_player > 0.01:
		var direction := toward / distance_to_player
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(direction.x, direction.z) + forward_offset, minf(1.0, delta * 7.0))
	if _attack_elapsed >= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		_attack_elapsed += delta
		if _attack_stage == "anticipation":
			_locked_target = _target_point()
		_update_warning()
		if _attack_stage == "attack" and attack_lunge_speed > 0.0:
			var strike_phase := _attack_elapsed / _stage_length
			if strike_phase >= 0.14 and strike_phase <= 0.42 and distance_to_player > radius_m + 0.65:
				var strike_direction := toward.normalized()
				velocity.x = strike_direction.x * attack_lunge_speed
				velocity.z = strike_direction.z * attack_lunge_speed
		if _attack_stage == "attack" and not _did_damage and _attack_elapsed >= _stage_length * contact_fraction:
			_did_damage = true
			_apply_attack_contact(distance_to_player)
			_clear_warning()
		if _attack_elapsed >= _stage_length:
			_advance_attack()
	elif _hit_elapsed > 0.0:
		_hit_elapsed -= delta
		velocity.x = 0.0
		velocity.z = 0.0
	elif distance_to_player <= attack_range and _cooldown <= 0.0 and _has_line_of_sight():
		_start_attack()
	else:
		_move_while_waiting(toward, distance_to_player)
	if attack_style == "ray":
		var dip := 0.55 if _attack_stage == "attack" else 0.0
		_visual.position.y = lerpf(_visual.position.y, -dip, minf(1.0, delta * 6.0))
	move_and_slide()


func _move_while_waiting(toward: Vector3, distance: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if distance > aggro_range or distance <= 0.01:
		_play(idle_clip)
		return
	var direction := toward / distance
	if attack_style == "marksman" or attack_style == "ray":
		var retreat_distance := 7.0 if attack_style == "marksman" else 5.0
		if distance > attack_range * 0.9:
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			_play(move_clip)
		elif distance < retreat_distance:
			velocity.x = -direction.x * move_speed * 0.8
			velocity.z = -direction.z * move_speed * 0.8
			_play(move_clip)
		else:
			var side := Vector3(-direction.z, 0.0, direction.x) * _strafe_sign
			velocity.x = side.x * move_speed * 0.72
			velocity.z = side.z * move_speed * 0.72
			if attack_style == "marksman":
				_play("strafe_right" if _strafe_sign > 0.0 else "strafe_left")
			else:
				_play("bank_right" if _strafe_sign > 0.0 else "bank_left")
	elif distance > attack_range * 0.8:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		_play(move_clip)
	else:
		_play(idle_clip)


func _target_point() -> Vector3:
	return _player.global_position + Vector3.UP * 0.9


func _muzzle_position() -> Vector3:
	var height := 0.1 if flying else height_m * 0.7
	return global_position + Vector3.UP * height + _visual.global_transform.basis.z * 0.55


func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	return material


func _make_warning() -> void:
	_clear_warning()
	if attack_style == "marksman" or attack_style == "ray":
		var warning_color := Color("63e8dc") if attack_style == "marksman" else Color("c778ff")
		_warning = WeaponEffect.beam(self, _muzzle_position(), _locked_target, warning_color, 0.032 if attack_style == "marksman" else 0.070)
		_warning.set("pulse_strength", 0.10 if attack_style == "marksman" else 0.22)
		_warning.set("pulse_frequency", 16.0 if attack_style == "marksman" else 11.0)
	elif attack_style == "slam":
		_warning = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = slam_radius - 0.11
		ring.outer_radius = slam_radius
		(_warning as MeshInstance3D).mesh = ring
		(_warning as MeshInstance3D).material_override = _glow(Color("ff704f"), 0.9)
		_warning.position.y = 0.07
		add_child(_warning)
		var fill := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = slam_radius
		disc.bottom_radius = slam_radius
		disc.height = 0.012
		fill.mesh = disc
		fill.material_override = _glow(Color("ff573d"), 0.13)
		_warning.add_child(fill)
	_update_warning()


func _update_warning() -> void:
	if _warning == null or attack_style not in ["marksman", "ray"]:
		return
	WeaponEffect.place_beam(_warning, _muzzle_position(), _locked_target)


func _clear_warning() -> void:
	if is_instance_valid(_warning):
		if attack_style in ["marksman", "ray"]:
			WeaponEffect.close_beam(_warning)
		else:
			_warning.queue_free()
	_warning = null


func _apply_attack_contact(distance_to_player: float) -> void:
	_attack_sound.play()
	if attack_style == "marksman" or attack_style == "ray":
		var color := Color("69eaff") if attack_style == "marksman" else Color("bd7bff")
		var count := 1 if attack_style == "marksman" else 3
		var from := _muzzle_position()
		var straight := (_locked_target - from).normalized()
		WeaponEffect.muzzle(self, from, straight, color, 0.25 if count == 1 else 0.34, attack_style)
		for index in count:
			var spread := float(index - (count - 1) * 0.5) * 0.17
			var direction := straight.rotated(Vector3.UP, spread)
			var shot := ENEMY_PROJECTILE.new() as EnemyProjectile
			get_parent().add_child(shot)
			shot.launch(from, direction, self, attack_damage, projectile_speed, color, 0.085 if count == 1 else 0.15)
	elif attack_style == "slam":
		var ground_separation := absf(_player.global_position.y - global_position.y)
		if distance_to_player <= slam_radius and ground_separation <= 0.9 and _has_line_of_sight():
			_damage_player(attack_damage)
		_spawn_slam_wave()
	elif distance_to_player <= attack_range + 0.8 and _has_line_of_sight():
		_damage_player(attack_damage)


func _damage_player(amount: float) -> void:
	var target_health := _player.get_node_or_null("Health") as Health
	if target_health != null:
		target_health.apply_damage(amount)


func _spawn_slam_wave() -> void:
	var wave := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = slam_radius - 0.2
	ring.outer_radius = slam_radius
	wave.mesh = ring
	wave.material_override = _glow(Color("ffa269"), 0.85)
	wave.position.y = 0.1
	add_child(wave)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "scale", Vector3.ONE * 1.35, 0.35)
	tween.tween_property(wave, "transparency", 1.0, 0.35)
	tween.chain().tween_callback(wave.queue_free)


func _has_line_of_sight() -> bool:
	if attack_range <= 4.0 and attack_style != "slam":
		return true
	var from := global_position + Vector3.UP * (0.25 if flying else height_m * 0.65)
	var to := _player.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == _player


func _start_attack() -> void:
	_did_damage = false
	_locked_target = _target_point()
	_make_warning()
	if _clip_names.has("attack_anticipation"):
		_enter_attack_stage("anticipation")
	else:
		_enter_attack_stage("attack")


func _enter_attack_stage(stage: String) -> void:
	_attack_stage = stage
	_attack_elapsed = 0.0
	var clip := attack_clip if stage == "attack" else "attack_" + stage
	_stage_length = _length(clip, 0.8 if stage == "attack" else 0.35)
	_play(clip)


func _advance_attack() -> void:
	if _attack_stage == "anticipation":
		_enter_attack_stage("attack")
	elif _attack_stage == "attack" and _clip_names.has("attack_recovery"):
		_enter_attack_stage("recovery")
	else:
		_attack_elapsed = -1.0
		_attack_stage = ""
		_cooldown = attack_cooldown
		_strafe_sign *= -1.0
		_clear_warning()


func _length(clip: String, fallback: float) -> float:
	if _animations and _clip_names.has(clip):
		return _animations.get_animation(_clip_names[clip]).length
	return fallback


func _play(clip: String) -> void:
	if _animations == null or _current_clip == clip:
		return
	var name: String = _clip_names.get(clip, "")
	if name.is_empty():
		return
	_animations.play(name, 0.12)
	_current_clip = clip


func apply_hit(amount: float) -> void:
	_health.apply_damage(amount)


func is_weak_point(world_point: Vector3) -> bool:
	return world_point.y >= global_position.y + height_m * (0.3 if flying else 0.72)


func _on_damaged(_amount: float, _remaining: float) -> void:
	if _health.is_dead or _attack_elapsed >= 0.0:
		return
	_hit_elapsed = _length("hit", 0.35)
	_play("hit")


func _on_died() -> void:
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_attack_elapsed = -1.0
	_clear_warning()
	_play("death")
	await get_tree().create_timer(maxf(2.5, _length("death", 2.0) + 0.3)).timeout
	queue_free()
