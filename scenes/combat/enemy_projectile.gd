extends Node3D
class_name EnemyProjectile

## Enemy shots use a swept ray so fast bolts cannot pass through the player.
signal hit_target(target: Node3D)

var direction := Vector3.FORWARD
var speed := 30.0
var damage := 10.0
var lifetime := 1.5
var shooter: CollisionObject3D
var _age := 0.0


func launch(from: Vector3, toward: Vector3, firing_body: CollisionObject3D, shot_damage: float, shot_speed: float, color: Color, radius: float) -> void:
	global_position = from
	direction = toward.normalized()
	shooter = firing_body
	damage = shot_damage
	speed = shot_speed
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	core.mesh = sphere
	core.material_override = _material(color, 3.0)
	add_child(core)
	var tail := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.35
	cylinder.bottom_radius = radius * 0.7
	cylinder.height = radius * 4.0
	tail.mesh = cylinder
	tail.position = -direction * radius * 1.8
	tail.quaternion = Quaternion(Vector3.UP, direction)
	tail.material_override = _material(color.darkened(0.25), 2.0)
	add_child(tail)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.7
	light.omni_range = 2.0
	add_child(light)


func _material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


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
	queue_free()
