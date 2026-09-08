@tool
extends Node3D

## Authored layout in meters. Generated visuals belong to this module, never shared assets.
const FIXTURE = preload("res://scenes/lobby/modules/hall_fixture.tscn")
const FLOOR_SHADER = preload("res://assets/materials/lobby/hall_floor.gdshader")
const PLANTER = preload("res://assets/models/outpost_kit/outpost_planter.glb")
var _navy: StandardMaterial3D
var _bone: StandardMaterial3D
var _metal: StandardMaterial3D
var _cobalt: StandardMaterial3D

func _ready() -> void:
	if has_node("Floor"):
		return
	_navy = _material("172133", 0.3, 0.65)
	_bone = _material("c4c3b6", 0.15, 0.68)
	_metal = _material("374650", 0.65, 0.45)
	_cobalt = _material("245aa8", 0.35, 0.55)
	var floor_material := ShaderMaterial.new()
	floor_material.shader = FLOOR_SHADER
	_box("Floor", Vector3(42, 0.4, 42), Vector3(0, -0.2, -3), floor_material, true)
	# Monument is 13.5 m tall and 10.86 m deep at its preserved 1.35 scale.
	# A raised rear vault clears its complete bounds, not just the portal opening.
	_box("Ceiling", Vector3(42, 0.35, 25), Vector3(0, 9.5, 5.5), _navy, true)
	_box("TransitVaultCeiling", Vector3(42, 0.35, 17), Vector3(0, 16, -15.5), _navy, true)
	_box("VaultFront", Vector3(42, 6.5, 0.3), Vector3(0, 12.75, -7), _navy, true)
	# Enclosed outer shell. Front entrance is a shallow recess, not an unbounded exit.
	_box("WestWall", Vector3(0.5, 9.5, 42), Vector3(-21, 4.75, -3), _navy, true)
	_box("EastWall", Vector3(0.5, 9.5, 42), Vector3(21, 4.75, -3), _navy, true)
	for x: float in [-21.0, 21.0]:
		_box("VaultSide", Vector3(0.5, 6.5, 17), Vector3(x, 12.75, -15.5), _navy, true)
	_box("BackWall", Vector3(42, 16, 0.5), Vector3(0, 8, -24), _navy, true)
	_box("EntranceWall", Vector3(42, 9.5, 0.5), Vector3(0, 4.75, 18), _navy, true)
	for side: float in [-1.0, 1.0]:
		for z: float in [-12.0, 0.0, 12.0]:
			_box("BayPier", Vector3(1.0, 6.2, 0.75), Vector3(side * 11.7, 3.1, z), _bone, true)
			_box("PierFoot", Vector3(1.25, 0.38, 1.0), Vector3(side * 11.7, 0.19, z), _metal, true)
			_box("BayPartition", Vector3(8.6, 5.6, 0.35), Vector3(side * 16.0, 2.8, z), _navy, true)
			_box("PartitionCap", Vector3(8.6, 0.2, 0.45), Vector3(side * 16.0, 5.7, z), _bone)
		for z: float in [-6.0, 6.0]:
			_box("BayLintel", Vector3(0.7, 0.45, 11.25), Vector3(side * 11.7, 6.05, z), _bone)
			_box("BayRoof", Vector3(8.5, 0.2, 11.8), Vector3(side * 16.0, 6.4, z), _navy)
			_box("BayBackPanel", Vector3(0.12, 3.6, 9.0), Vector3(side * 20.6, 2.5, z), _bone)
			_box("BayBackStripe", Vector3(0.14, 0.42, 9.0), Vector3(side * 20.5, 4.0, z), _cobalt)
		# Continuous upper gallery frames the hall without blocking the orbit lane.
		_box("GalleryFascia", Vector3(0.45, 1.25, 30), Vector3(side * 12.0, 7.1, 0), _metal)
		_box("GalleryTrim", Vector3(0.55, 0.10, 30), Vector3(side * 11.95, 6.5, 0), _bone)
	for z: float in [0.0, 12.0]:
		_box("RoofCrossbeam", Vector3(42, 0.6, 0.55), Vector3(0, 8.9, z), _metal)
	for z: float in [-8.0, -16.0, -23.0]:
		_box("VaultCrossbeam", Vector3(42, 0.6, 0.55), Vector3(0, 15.4, z), _metal)
	for x: float in [-7.0, 7.0]:
		_box("LightingRail", Vector3(0.22, 0.3, 22), Vector3(x, 8.4, 5), _metal)
		for z: float in [-5.0, 0.0, 10.0]:
			_box("FixtureStem", Vector3(0.12, 0.55, 0.12), Vector3(x, 8.1, z), _metal)
			var fixture: Node3D = FIXTURE.instantiate()
			fixture.name = "OverheadFixture"
			fixture.position = Vector3(x, 7.7, z)
			fixture.rotation_degrees.x = -90
			fixture.set("casts_shadow", z == 0.0)
			fixture.set("energy", 3.8)
			add_child(fixture)
	# A physical entry threshold and rear portal niche.
	for x: float in [-4.5, 4.5]:
		_box("EntryButtress", Vector3(0.75, 6.8, 1.0), Vector3(x, 3.4, 17), _bone, true)
	_box("EntryLintel", Vector3(9.75, 0.6, 1), Vector3(0, 6.8, 17), _bone)
	_box("EntryDoor", Vector3(7.8, 5.8, 0.18), Vector3(0, 2.9, 17.65), _metal)
	for x: float in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		_box("DoorFluting", Vector3(0.045, 5.1, 0.05), Vector3(x, 2.85, 17.52), _bone)
	_sign("EntrySign", "STARFORGE  /  OPERATIONS", Vector3(0, 5.8, 17.35), PI, 38)
	_sign("DeploySign", "EXPEDITION  /  TRANSIT", Vector3(0, 14.7, -23.5), 0.0, 48)
	for x: float in [-8.0, 8.0]:
		_box("PortalFrame", Vector3(0.6, 14.5, 0.8), Vector3(x, 7.25, -22), _bone, true)
	_box("PortalLintel", Vector3(16.6, 0.4, 0.8), Vector3(0, 14.5, -22), _bone)
	for x: float in [-10.0, 10.0]:
		_box("VaultLampMount", Vector3(0.18, 1.0, 0.18), Vector3(x, 15.0, -16), _metal)
		var vault_light: Node3D = FIXTURE.instantiate()
		vault_light.name = "VaultFixture"
		vault_light.position = Vector3(x, 14.4, -16)
		vault_light.rotation_degrees.x = -90
		vault_light.set("energy", 4.0)
		add_child(vault_light)
	# Surface markings sit just above the deck; they have no collision.
	for side: float in [-1.0, 1.0]:
		for z: float in [-6.0, 6.0]:
			_box("BayThreshold", Vector3(0.09, 0.004, 7.6), Vector3(side * 11.0, 0.004, z), _bone)
			for offset: float in [-3.8, 3.8]:
				_box("ThresholdEnd", Vector3(1.1, 0.004, 0.09), Vector3(side * 11.5, 0.004, z + offset), _bone)
	_add_planters()

func _add_planters() -> void:
	# Style-lab planter GLBs. Collision is a pot proxy only so foliage is walk-around, not a wall.
	var placements: Array[Dictionary] = [
		{"at": Vector3(-9.0, 0.0, 13.8), "yaw": 0.0},
		{"at": Vector3(9.0, 0.0, 13.8), "yaw": 0.34202},
		{"at": Vector3(-9.0, 0.0, -14.5), "yaw": -0.5},
		{"at": Vector3(9.0, 0.0, -14.5), "yaw": 0.5},
	]
	for placement: Dictionary in placements:
		var planter: Node3D = PLANTER.instantiate()
		planter.name = "Planter"
		planter.position = placement.at
		planter.rotation.y = placement.yaw
		add_child(planter)
		var body := StaticBody3D.new()
		body.name = "PotCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.6, 0.7, 1.1)
		collision.shape = shape
		collision.position = Vector3(0.0, 0.35, 0.0)
		planter.add_child(body)
		body.add_child(collision)

func _material(hex: String, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.metallic = metallic
	material.roughness = roughness
	return material

func _box(label: String, size: Vector3, at: Vector3, material: Material, solid: bool = false) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		mesh.add_child(body)
		body.add_child(collision)

func _sign(label: String, text: String, at: Vector3, yaw: float, size: int) -> void:
	var sign := Label3D.new()
	sign.name = label
	sign.text = text
	sign.position = at
	sign.rotation.y = yaw
	sign.font_size = size
	sign.pixel_size = 0.012
	sign.modulate = Color("d9d5c7")
	sign.no_depth_test = false
	sign.outline_size = 2
	add_child(sign)
