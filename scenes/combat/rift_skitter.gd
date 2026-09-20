extends CharacterBody3D

## Simple chase / contact-damage scout for the combat stub.

const MOVE_SPEED := 3.2
const ATTACK_RANGE := 1.35
const ATTACK_DAMAGE := 12.0
const ATTACK_COOLDOWN := 0.9
const AGGRO_RANGE := 18.0

@export var player_path: NodePath

@onready var _health: Health = $Health
@onready var _visual: Node3D = $Visual

var _player: Node3D
var _attack_timer := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	_health.died.connect(_on_died)
	if player_path != NodePath():
		_player = get_node_or_null(player_path)


func _physics_process(delta: float) -> void:
	if _health.is_dead:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	_attack_timer = maxf(0.0, _attack_timer - delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > AGGRO_RANGE:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if dist > 0.05:
		var dir := to_player.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	if dist <= ATTACK_RANGE and _attack_timer <= 0.0:
		_attack_timer = ATTACK_COOLDOWN
		var target_health := _player.get_node_or_null("Health") as Health
		if target_health:
			target_health.apply_damage(ATTACK_DAMAGE)


func apply_hit(amount: float) -> void:
	_health.apply_damage(amount)
	# Brief flinch flash via modulate if MeshInstance present.
	_flash()


func is_weak_point(world_point: Vector3) -> bool:
	# The upper quarter of the scout capsule is the Vault Needle weak point.
	return world_point.y >= global_position.y + 0.88


func _flash() -> void:
	var meshes := _visual.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		var mat: Material = mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			var dup: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
			dup.emission_enabled = true
			dup.emission = Color(1.0, 0.4, 0.2)
			dup.emission_energy_multiplier = 4.0
			mesh.set_surface_override_material(0, dup)
	await get_tree().create_timer(0.08).timeout
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.set_surface_override_material(0, null)


func _on_died() -> void:
	velocity = Vector3.ZERO
	collision_layer = 0
	visible = false
	await get_tree().create_timer(0.35).timeout
	queue_free()
