@tool
extends Node3D

## Reusable physical light housing; local -Z is the emitted light direction.
@export_enum("Overhead", "Task", "Service") var style: int = 0
@export var casts_shadow: bool = false
@export var energy: float = 2.2

func _ready() -> void:
	if get_child_count() > 0:
		return
	var housing := StandardMaterial3D.new()
	housing.albedo_color = Color("293442")
	housing.metallic = 0.65
	housing.roughness = 0.42
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color("e2e7df")
	lens.emission_enabled = true
	lens.emission = Color("e2e7df")
	lens.emission_energy_multiplier = 1.8
	var width: float = 3.4 if style == 0 else (1.25 if style == 1 else 0.45)
	_box("Housing", Vector3(width, 0.48, 0.24), Vector3.ZERO, housing)
	_box("Diffuser", Vector3(width - 0.16, 0.30, 0.04), Vector3(0, 0, -0.14), lens)
	for x: float in [-width * 0.35, width * 0.35]:
		_box("Bracket", Vector3(0.09, 0.16, 0.32), Vector3(x, 0, 0.24), housing)
	var light := SpotLight3D.new()
	light.name = "TaskLight"
	light.position.z = -0.19
	light.light_color = Color("e6edee")
	light.light_energy = energy
	light.light_specular = 0.6
	light.spot_range = 19.0 if style == 0 else 8.0
	light.spot_angle = 58.0 if style == 0 else 48.0
	light.spot_attenuation = 0.7
	light.shadow_enabled = casts_shadow
	add_child(light)

func _box(label: String, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
