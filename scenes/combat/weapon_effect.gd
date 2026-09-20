extends Node3D
class_name WeaponEffect

## Short, procedural emissive effects shared by every weapon. No external VFX asset.

var _age := 0.0
var _lifetime := 0.16
var _end_scale := 1.0
var _materials: Array[StandardMaterial3D] = []
var _start_energy: Array[float] = []


static func burst(parent: Node, position: Vector3, color: Color, radius: float, duration: float = 0.16, expansion: float = 1.8) -> WeaponEffect:
	var effect := WeaponEffect.new()
	parent.add_child(effect)
	effect.global_position = position
	effect._lifetime = duration
	effect._end_scale = expansion
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	effect._add_mesh(mesh, color, 4.0)
	return effect


static func line(parent: Node, start: Vector3, finish: Vector3, color: Color, radius: float, duration: float = 0.16) -> WeaponEffect:
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
	effect._add_mesh(outer, color, 3.8)
	var inner := CylinderMesh.new()
	inner.top_radius = radius * 0.37
	inner.bottom_radius = radius * 0.37
	inner.height = axis.length()
	effect._add_mesh(inner, Color.WHITE, 2.6)
	return effect


func _add_mesh(mesh: Mesh, color: Color, energy: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	if t >= 1.0:
		queue_free()
