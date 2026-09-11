extends Node3D
## Static wall-mounted Dawnseal plaque for the weapons bay. Display only.

@export_range(0.1, 4.0, 0.05) var model_scale := 1.7

const MODEL := preload("res://assets/models/gear/guns/dawnseal/dawnseal.glb")
const STARBONE := Color("d9d5c7")
const NAVY := Color("172133")
const METAL := Color("65717b")


func _ready() -> void:
	_build_mount()
	var model := MODEL.instantiate() as Node3D
	model.name = "Dawnseal"
	# Grip origin; hang in a clear side-profile so the medallion faces the bay.
	model.position = Vector3(0.0, -0.05, 0.06)
	model.rotation_degrees = Vector3(4.0, 90.0, 0.0)
	model.scale = Vector3.ONE * model_scale
	add_child(model)


func _build_mount() -> void:
	var plate := MeshInstance3D.new()
	plate.name = "MountPlate"
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(1.15, 0.78, 0.05)
	plate.mesh = plate_mesh
	plate.material_override = _mat(NAVY, 0.25)
	plate.position = Vector3(0.0, 0.0, -0.03)
	add_child(plate)

	var trim := MeshInstance3D.new()
	trim.name = "MountTrim"
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(1.24, 0.86, 0.025)
	trim.mesh = trim_mesh
	trim.material_override = _mat(STARBONE, 0.08, 0.48)
	trim.position = Vector3(0.0, 0.0, -0.055)
	add_child(trim)

	var peg := MeshInstance3D.new()
	peg.name = "MountPeg"
	var peg_mesh := CylinderMesh.new()
	peg_mesh.top_radius = 0.02
	peg_mesh.bottom_radius = 0.026
	peg_mesh.height = 0.14
	peg_mesh.radial_segments = 12
	peg.mesh = peg_mesh
	peg.material_override = _mat(METAL, 0.72, 0.4)
	peg.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	peg.position = Vector3(0.0, 0.08, 0.035)
	add_child(peg)

	for side: float in [-1.0, 1.0]:
		var bolt := MeshInstance3D.new()
		bolt.name = "MountBolt%s" % ("L" if side < 0.0 else "R")
		var bolt_mesh := CylinderMesh.new()
		bolt_mesh.top_radius = 0.018
		bolt_mesh.bottom_radius = 0.018
		bolt_mesh.height = 0.03
		bolt_mesh.radial_segments = 10
		bolt.mesh = bolt_mesh
		bolt.material_override = _mat(METAL, 0.72, 0.4)
		bolt.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		bolt.position = Vector3(side * 0.48, 0.32, 0.0)
		add_child(bolt)
		var bolt_b := bolt.duplicate() as MeshInstance3D
		bolt_b.name = bolt.name + "B"
		bolt_b.position = Vector3(side * 0.48, -0.32, 0.0)
		add_child(bolt_b)


func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.65) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
