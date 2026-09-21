extends CharacterBody3D
## Lightweight field combat harness for newly authored enemy animation sets.
## Visual/model and timing are supplied per spawn; this does not own campaign state.

@export var model_scene: PackedScene
@export var display_name := "Enemy"
@export var height_m := 1.8
@export var radius_m := 0.45
@export var move_speed := 3.0
@export var attack_damage := 10.0
@export var attack_range := 1.5
@export var aggro_range := 18.0
@export var attack_cooldown := 1.0
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
		if _attack_stage == "attack" and not _did_damage and _attack_elapsed >= _stage_length * contact_fraction:
			_did_damage = true
			if distance_to_player <= attack_range + 0.8 and _has_line_of_sight():
				var target_health := _player.get_node_or_null("Health") as Health
				if target_health:
					target_health.apply_damage(attack_damage)
		if _attack_elapsed >= _stage_length:
			_advance_attack()
	elif _hit_elapsed > 0.0:
		_hit_elapsed -= delta
		velocity.x = 0.0
		velocity.z = 0.0
	elif distance_to_player <= attack_range and _cooldown <= 0.0 and _has_line_of_sight():
		_start_attack()
	elif distance_to_player <= aggro_range and distance_to_player > attack_range * 0.8:
		var direction := toward.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		_play(move_clip)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play(idle_clip)
	move_and_slide()


func _has_line_of_sight() -> bool:
	if attack_range <= 4.0:
		return true
	var from := global_position + Vector3.UP * (0.25 if flying else height_m * 0.65)
	var to := _player.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == _player


func _start_attack() -> void:
	_did_damage = false
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
	_play("death")
	await get_tree().create_timer(maxf(2.5, _length("death", 2.0) + 0.3)).timeout
	queue_free()
