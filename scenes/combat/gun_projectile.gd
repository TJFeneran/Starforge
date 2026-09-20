extends Node3D
class_name GunProjectile

## Visible shot with a swept physics ray each tick, so fast needles cannot tunnel.

const ENERGY_SHOTS := {
	"pulse": preload("res://assets/BinbunVFX/MagicProjectilesVFX/magic_projectiles/effects/mprojectile_basic/mprojectile_basic_vfx_04.tscn"),
	"echo": preload("res://assets/BinbunVFX/MagicProjectilesVFX/magic_projectiles/effects/mprojectile_wave/mprojectile_wave_vfx_02.tscn"),
	"solar": preload("res://assets/BinbunVFX/MagicProjectilesVFX/magic_projectiles/effects/mprojectile_javelin/mprojectile_javelin_vfx_01.tscn"),
	"orb": preload("res://assets/BinbunVFX/MagicProjectilesVFX/magic_projectiles/effects/mprojectile_basic/mprojectile_basic_vfx_01.tscn"),
}

var definition: GunDefinition
var shooter: CollisionObject3D
var source: Node
var direction := Vector3.FORWARD
var traveled := 0.0
var _age := 0.0


func launch(spec: GunDefinition, from: Vector3, toward: Vector3, firing_source: Node, firing_body: CollisionObject3D) -> void:
	definition = spec
	shooter = firing_body
	source = firing_source
	direction = toward.normalized()
	global_position = from
	look_at(from + direction, Vector3.UP)
	_build_visual()


func _build_visual() -> void:
	var style := definition.effect_style
	if ENERGY_SHOTS.has(style):
		_build_energy_visual(style)
		return
	var mesh: Mesh
	if style in ["slug", "needle", "tracer", "rail"]:
		var dart := CylinderMesh.new()
		dart.top_radius = 0.009 if style == "needle" else 0.018
		dart.bottom_radius = dart.top_radius
		dart.height = (0.28 if style in ["needle", "rail"] else 0.12) * definition.effect_size
		mesh = dart
	else:
		var orb := SphereMesh.new()
		orb.radius = (0.18 if style == "orb" else 0.075) * definition.effect_size
		orb.height = orb.radius * 2.0
		mesh = orb
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	if mesh is CylinderMesh:
		visual.rotation.x = PI * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = definition.effect_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = definition.effect_color
	material.emission_energy_multiplier = 4.5 if style in ["echo", "solar", "orb"] else 2.4
	visual.material_override = material
	add_child(visual)
	if style in ["echo", "solar", "orb"]:
		var light := OmniLight3D.new()
		light.light_color = definition.effect_color
		light.light_energy = 0.8
		light.omni_range = 2.4 if style == "orb" else 1.3
		add_child(light)


func _build_energy_visual(style: String) -> void:
	var visual := (ENERGY_SHOTS[style] as PackedScene).instantiate() as VFXController
	visual.autoplay = false
	# The pack points along +X, with its meshes behind its scene origin.
	# Rotate that axis onto the projectile's -Z direction and move the head forward.
	var visual_size := (0.42 if style == "orb" else 0.30) * definition.effect_size
	visual.scale = Vector3.ONE * visual_size
	visual.rotation.y = PI * 0.5
	visual.position.z = -1.2 * visual_size
	for child in visual.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			child.material_override = child.material_override.duplicate(true)
	add_child(visual)
	visual.primary_color = definition.effect_color.lightened(0.45)
	visual.secondary_color = definition.effect_color
	visual.tertiary_color = definition.effect_color.darkened(0.25)
	visual.light_color = definition.effect_color
	visual.light_energy = 2.0 if style == "orb" else 1.0
	visual.play()


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	_age += delta
	var remaining := definition.max_range - traveled
	if _age >= definition.projectile_lifetime or remaining <= 0.0:
		queue_free()
		return
	var start := global_position
	var step := minf(definition.projectile_speed * delta, remaining)
	var finish := start + direction * step
	var query := PhysicsRayQueryParameters3D.create(start, finish, 5)
	if is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var point: Vector3 = result.position
		traveled += start.distance_to(point)
		global_position = point
		if is_instance_valid(source) and source.has_method("on_projectile_impact"):
			source.on_projectile_impact(definition, result.collider, point, traveled)
		WeaponEffect.burst(get_tree().current_scene, point, definition.effect_color, 0.07 * definition.effect_size)
		queue_free()
		return
	global_position = finish
	traveled += step
	if definition.effect_style != "slug" and not ENERGY_SHOTS.has(definition.effect_style):
		WeaponEffect.line(get_tree().current_scene, start, finish, definition.effect_color, 0.013 * definition.effect_size, 0.12)
