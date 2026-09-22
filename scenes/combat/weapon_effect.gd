extends Node3D
class_name WeaponEffect

## Shared visual wrappers for the free Binbun packs. Physics and damage stay in
## GunMount, GunProjectile, EnemyTestActor, and EnemyProjectile.

const BEAM_SCENE := preload("res://assets/BinbunVFX/BeamVFXFree/beam_vfx/effects/base/base_beam_vfx.tscn")
const BEAM_CORE_SHADER := preload("res://assets/BinbunVFX/BeamVFXFree/beam_vfx/src/shader/beam_core.gdshader")
const HIT_SCENE := preload("res://assets/BinbunVFX/HitFXFree/StylizedHitFX/effects/hit/vfx_hit_01.tscn")
const IMPACT_SCENE := preload("res://assets/BinbunVFX/HitFXFree/StylizedHitFX/effects/impact/vfx_impact_01.tscn")
const BIG_IMPACT_SCENE := preload("res://assets/BinbunVFX/HitFXFree/StylizedHitFX/effects/big_impact/vfx_big_impact_01.tscn")
const FLASH_VARIANTS := {
	"slug": preload("res://assets/BinbunVFX/MuzzleFlashVFX/muzzle_flash/effects/short_flash/short_flash_01.tscn"),
	"needle": preload("res://assets/BinbunVFX/MuzzleFlashVFX/muzzle_flash/effects/short_flash/short_flash_02.tscn"),
	"tracer": preload("res://assets/BinbunVFX/MuzzleFlashVFX/muzzle_flash/effects/short_flash/short_flash_03.tscn"),
	"rail": preload("res://assets/BinbunVFX/MuzzleFlashVFX/muzzle_flash/effects/muzzle_flash/muzzle_flash_02.tscn"),
	"pulse": preload("res://assets/BinbunVFX/MuzzleFlashVFX/muzzle_flash/effects/muzzle_flash/muzzle_flash_01.tscn"),
	"echo": preload("res://assets/BinbunVFX/MuzzleFlashVFX/muzzle_flash/effects/short_flash/short_flash_04.tscn"),
	"solar": preload("res://assets/BinbunVFX/MuzzleFlashVFX/muzzle_flash/effects/muzzle_flash/muzzle_flash_03.tscn"),
	"orb": preload("res://assets/BinbunVFX/MuzzleFlashVFX/muzzle_flash/effects/wide_flash/wide_flash_01.tscn"),
	"beam": preload("res://assets/BinbunVFX/MuzzleFlashVFX/muzzle_flash/effects/short_flash/short_flash_01.tscn"),
	"marksman": preload("res://assets/BinbunVFX/MuzzleFlashVFX/muzzle_flash/effects/short_flash/short_flash_02.tscn"),
	"ray": preload("res://assets/BinbunVFX/MuzzleFlashVFX/muzzle_flash/effects/wide_flash/wide_flash_03.tscn"),
}

var _age := 0.0
var _lifetime := 0.16
var _end_scale := 1.0
var _materials: Array[StandardMaterial3D] = []
var _start_energy: Array[float] = []


static func muzzle(parent: Node, position: Vector3, direction: Vector3, color: Color, size: float, style: String) -> Node3D:
	var effect := prepare_muzzle(parent, color, size, style)
	play_muzzle(effect, position, direction)
	_free_after(effect, 0.32)
	return effect


static func prepare_muzzle(parent: Node, color: Color, size: float, style: String) -> MuzzleVFXController:
	var scene: PackedScene = FLASH_VARIANTS.get(style, FLASH_VARIANTS["pulse"])
	var effect := scene.instantiate() as MuzzleVFXController
	effect.autoplay = false
	effect.one_shot = true
	_unique_visual_resources(effect, false)
	parent.add_child(effect)
	var flash_size := clampf(size, 0.08, 0.55)
	effect.set_meta("flash_size", flash_size)
	effect.scale = Vector3.ONE * flash_size
	# The pack's bright core is a sphere; the directional particle textures
	# provide the silhouette without that distracting solid shape.
	var glow := effect.get_node_or_null("Glow") as MeshInstance3D
	if glow:
		glow.hide()
	effect.primary_color = color.lightened(0.25)
	effect.secondary_color = color
	effect.light_color = color
	effect.light_energy = 0.6
	return effect


static func play_muzzle(effect: MuzzleVFXController, position: Vector3, direction: Vector3) -> void:
	effect.show()
	effect.global_position = position
	if direction.length_squared() > 0.000001:
		effect.global_basis = Basis(Quaternion(Vector3.RIGHT, direction.normalized()))
	effect.scale = Vector3.ONE * float(effect.get_meta("flash_size", 0.2))
	effect.play()


static func impact(parent: Node, position: Vector3, color: Color, size: float, strong: bool = false, blast: bool = false) -> Node3D:
	var scene := BIG_IMPACT_SCENE if blast else (IMPACT_SCENE if strong else HIT_SCENE)
	var effect := scene.instantiate() as VFXImpactBB
	effect.autoplay = false
	effect.one_shot = true
	_unique_visual_resources(effect, false)
	parent.add_child(effect)
	effect.global_position = position
	effect.scale = Vector3.ONE * clampf(size, 0.08, 2.5)
	effect.primary_color = color.lightened(0.2)
	effect.secondary_color = color
	effect.light_color = color
	effect.light_energy = 0.75
	effect.emission = 1.3
	effect.hide_core = true
	effect.speed_scale = 2.2
	effect.play()
	_free_after(effect, 1.0)
	return effect


static func beam(parent: Node, start: Vector3, finish: Vector3, color: Color, radius: float, duration: float = 0.0, focused: bool = false) -> Node3D:
	if focused:
		return _focused_beam(parent, start, finish, color, radius, duration)
	var effect := BEAM_SCENE.instantiate() as Node3D
	_unique_visual_resources(effect, true)
	parent.add_child(effect)
	effect.set("primary_color", color.lightened(0.35))
	effect.set("secondary_color", color)
	effect.set("tertiary_color", color.darkened(0.45))
	effect.set("beam_radius", radius)
	effect.set("start_radius", radius * 1.4)
	effect.set("show_caps", false)
	effect.get_node("BeamPivot/BeamFlare1").hide()
	effect.get_node("BeamPivot/BeamFlare2").hide()
	effect.set("pulse_strength", 0.12)
	effect.set("pulse_frequency", 18.0)
	effect.set("emission", 1.75)
	effect.set("enable_end", false)
	effect.set("start_emitting", false)
	effect.set("end_emitting", false)
	place_beam(effect, start, finish)
	effect.set("open_amount", 0.15)
	var tween := effect.create_tween()
	tween.tween_property(effect, "open_amount", 1.0, 0.12)
	if duration > 0.0:
		tween.tween_interval(maxf(0.0, duration - 0.18))
		tween.tween_property(effect, "open_amount", 0.0, 0.06)
		tween.tween_callback(effect.queue_free)
	return effect


static func _focused_beam(parent: Node, start: Vector3, finish: Vector3, color: Color, radius: float, duration: float) -> Node3D:
	var effect := Node3D.new()
	parent.add_child(effect)
	var axis := finish - start
	if axis.length_squared() < 0.000001:
		axis = Vector3.FORWARD * 0.001
	effect.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, axis.normalized())), (start + finish) * 0.5)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = axis.length()
	mesh.radial_segments = 12
	mesh.cap_top = false
	mesh.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = BEAM_CORE_SHADER
	material.set_shader_parameter("primary_color", color.lightened(0.35))
	material.set_shader_parameter("secondary_color", color)
	material.set_shader_parameter("emission", 1.75)
	material.set_shader_parameter("pulse_strength", 0.008)
	material.set_shader_parameter("pulse_frequency", 18.0)
	material.set_shader_parameter("open_amount", 1.0)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	effect.add_child(visual)
	_free_after(effect, maxf(duration, 0.01))
	return effect


static func place_beam(effect: Node3D, start: Vector3, finish: Vector3) -> void:
	var vector := finish - start
	if vector.length_squared() < 0.0001:
		return
	effect.global_position = start
	effect.look_at(finish, Vector3.UP)
	effect.set("beam_length", vector.length())


static func close_beam(effect: Node3D) -> void:
	if not is_instance_valid(effect):
		return
	var tween := effect.create_tween()
	tween.tween_property(effect, "open_amount", 0.0, 0.08)
	tween.tween_callback(effect.queue_free)


static func charge(parent: Node, position: Vector3, direction: Vector3, color: Color, duration: float) -> void:
	var effect := WeaponEffect.new()
	parent.add_child(effect)
	effect.global_position = position
	if direction.length_squared() > 0.000001:
		effect.global_basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	effect._lifetime = maxf(duration, 0.01)
	effect._end_scale = 0.45
	var ring := TorusMesh.new()
	ring.inner_radius = 0.045
	ring.outer_radius = 0.065
	effect._add_mesh(ring, color, 1.25)


static func line(parent: Node, start: Vector3, finish: Vector3, color: Color, radius: float, duration: float = 0.12) -> WeaponEffect:
	# A narrow ballistic tracer can remain procedural; it is not an aim warning.
	var effect := WeaponEffect.new()
	parent.add_child(effect)
	effect._lifetime = duration
	var axis := finish - start
	if axis.length_squared() < 0.000001:
		axis = Vector3.UP * 0.001
	effect.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, axis.normalized())), (start + finish) * 0.5)
	var outer := CylinderMesh.new()
	outer.top_radius = radius
	outer.bottom_radius = radius
	outer.height = axis.length()
	effect._add_mesh(outer, color, 2.2)
	return effect


static func _unique_visual_resources(root: Node, duplicate_geometry: bool) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mesh_node := child as MeshInstance3D
			if duplicate_geometry and mesh_node.mesh:
				mesh_node.mesh = mesh_node.mesh.duplicate(true)
			if mesh_node.material_override:
				mesh_node.material_override = mesh_node.material_override.duplicate(true)
		elif child is GPUParticles3D:
			var particles := child as GPUParticles3D
			if particles.material_override:
				particles.material_override = particles.material_override.duplicate(true)
			if duplicate_geometry and particles.process_material:
				particles.process_material = particles.process_material.duplicate(true)
			if duplicate_geometry and particles.draw_pass_1:
				particles.draw_pass_1 = particles.draw_pass_1.duplicate(true)
		_unique_visual_resources(child, duplicate_geometry)


static func _free_after(effect: Node, duration: float) -> void:
	var timer := effect.get_tree().create_timer(duration)
	var effect_ref: WeakRef = weakref(effect)
	timer.timeout.connect(func() -> void:
		var target := effect_ref.get_ref() as Node
		if target:
			target.queue_free()
	)


func _add_mesh(mesh: Mesh, color: Color, energy: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	_materials.append(material)
	_start_energy.append(energy)


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / _lifetime, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(1.0, _end_scale, t)
	for i in _materials.size():
		_materials[i].emission_energy_multiplier = _start_energy[i] * (1.0 - t)
		_materials[i].albedo_color.a = 1.0 - t
	if t >= 1.0:
		queue_free()
