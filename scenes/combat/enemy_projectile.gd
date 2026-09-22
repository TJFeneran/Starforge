extends Node3D
class_name EnemyProjectile

## Enemy shots use a swept ray so fast bolts cannot pass through the player.
signal hit_target(target: Node3D)

const MARKSMAN_SHOT := preload("res://assets/BinbunVFX/MagicProjectilesVFX/magic_projectiles/effects/mprojectile_javelin/mprojectile_javelin_vfx_02.tscn")
const RAY_SHOT := preload("res://assets/BinbunVFX/MagicProjectilesVFX/magic_projectiles/effects/mprojectile_wave/mprojectile_wave_vfx_03.tscn")

var direction := Vector3.FORWARD
var speed := 30.0
var damage := 10.0
var lifetime := 1.5
var shooter: CollisionObject3D
var _age := 0.0
var _impact_color := Color.WHITE


func launch(from: Vector3, toward: Vector3, firing_body: CollisionObject3D, shot_damage: float, shot_speed: float, color: Color, radius: float) -> void:
	global_position = from
	direction = toward.normalized()
	shooter = firing_body
	damage = shot_damage
	speed = shot_speed
	_impact_color = color
	look_at(from + direction, Vector3.UP)
	var scene := MARKSMAN_SHOT if radius < 0.1 else RAY_SHOT
	var visual := scene.instantiate() as VFXController
	visual.autoplay = false
	visual.one_shot = false
	visual.scale = Vector3.ONE * (0.24 if radius < 0.1 else 0.32)
	visual.rotation.y = PI * 0.5
	visual.position.z = -0.35
	for child in visual.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			child.material_override = child.material_override.duplicate(true)
	add_child(visual)
	visual.primary_color = color.lightened(0.35)
	visual.secondary_color = color
	visual.tertiary_color = color.darkened(0.3)
	visual.light_color = color
	visual.light_energy = 0.8
	visual.play()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var finish := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, finish, 3)
	if is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = finish
		return
	var body := hit.get("collider") as Node3D
	if body != null:
		var health := body.get_node_or_null("Health") as Health
		if health != null and body.is_in_group("player"):
			health.apply_damage(damage)
			hit_target.emit(body)
	WeaponEffect.impact(get_parent(), hit.position, _impact_color, 0.22)
	queue_free()
