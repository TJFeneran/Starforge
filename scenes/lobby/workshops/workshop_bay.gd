@tool
extends Node3D
## Authored 10 m wide x 8 m deep workshop. Front is local +Z; parent owns floor.
## Instance workshop_bay.tscn, set purpose, and position/rotate the root.
## build() synchronously rebuilds only Visual/Collision content; changes also defer rebuild.

@export_enum("weapons", "armor", "utility", "outfit", "deploy") var purpose: String = "weapons":
	set(value):
		purpose = value
		_queue_build()

const PURPOSES: PackedStringArray = ["weapons", "armor", "utility", "outfit", "deploy"]
const STARBONE: Color = Color("d9d5c7")
const NAVY: Color = Color("172133")
const COBALT: Color = Color("245aa8")
const MINT: Color = Color("8dbfad")
const AMBER: Color = Color("d6a957")

var _queued: bool = false
var _visual: Node3D
var _collision: StaticBody3D
var _bone: StandardMaterial3D
var _navy: StandardMaterial3D
var _cobalt: StandardMaterial3D
var _metal: StandardMaterial3D
var _mint: StandardMaterial3D
var _amber: StandardMaterial3D
var _cloth: StandardMaterial3D
var _lamp: StandardMaterial3D


func _ready() -> void:
	build()


func _queue_build() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	call_deferred("_deferred_build")


func _deferred_build() -> void:
	if _queued and is_inside_tree():
		build()


func build() -> void:
	_queued = false
	if not is_inside_tree():
		return
	_visual = get_node_or_null("Visual") as Node3D
	if _visual == null:
		_visual = Node3D.new()
		_visual.name = "Visual"
		_adopt(self, _visual)
	_collision = get_node_or_null("Collision") as StaticBody3D
	if _collision == null:
		_collision = StaticBody3D.new()
		_collision.name = "Collision"
		_adopt(self, _collision)
	_collision.collision_layer = 1
	_collision.collision_mask = 0
	_clear(_visual)
	_clear(_collision)
	_anchor("InteractionAnchor", Vector3(0.0, 0.0, 1.5))
	_anchor("InspectionAnchor", Vector3(0.0, 1.65, -1.8))
	_materials()
	_chassis()
	var selected: String = purpose if PURPOSES.has(purpose) else "weapons"
	match selected:
		"armor":
			_armor()
		"utility":
			_utility()
		"outfit":
			_outfit()
		"deploy":
			_deploy()
		_:
			_weapons()
	_sign(selected)


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()


func _adopt(parent: Node, child: Node) -> void:
	parent.add_child(child)
	# Self is always an ancestor, including when this bay is an instanced scene.
	# Ownership makes generated geometry packable and visible in editor scene trees.
	child.owner = self


func _anchor(node_name: String, at: Vector3) -> void:
	if get_node_or_null(NodePath(node_name)) != null:
		return
	var marker: Marker3D = Marker3D.new()
	marker.name = node_name
	marker.position = at
	_adopt(self, marker)


func _material(color: Color, metallic: float = 0.0, roughness: float = 0.65) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result


func _materials() -> void:
	_bone = _material(STARBONE, 0.18)
	_navy = _material(NAVY, 0.25)
	_cobalt = _material(COBALT, 0.2)
	_metal = _material(Color("65717b"), 0.72, 0.4)
	_mint = _material(MINT, 0.15)
	_amber = _material(AMBER, 0.15)
	_cloth = _material(Color("85908e"), 0.0, 0.98)
	_lamp = _material(Color("fff2da"))
	_lamp.emission_enabled = true
	_lamp.emission = Color("fff2da")
	_lamp.emission_energy_multiplier = 0.7


func _mesh(node_name: String, mesh: Mesh, at: Vector3, material: Material, rotation_degrees_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rotation_degrees_value
	_adopt(_visual, instance)
	return instance


func _box(node_name: String, at: Vector3, size: Vector3, material: Material, rotation_degrees_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _mesh(node_name, mesh, at, material, rotation_degrees_value)


func _cylinder(node_name: String, at: Vector3, radius: float, height: float, material: Material, sides: int = 8, top_scale: float = 1.0) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius * top_scale
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return _mesh(node_name, mesh, at, material)


func _proxy(node_name: String, at: Vector3, size: Vector3, rotation_degrees_value: Vector3 = Vector3.ZERO) -> void:
	var proxy: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	proxy.name = node_name
	proxy.shape = shape
	proxy.position = at
	proxy.rotation_degrees = rotation_degrees_value
	_adopt(_collision, proxy)


func _layered(node_name: String, at: Vector3, size: Vector3, material: Material) -> void:
	# Recessed cap and foot soften the main silhouette without dense bevel meshes.
	_box(node_name + "Core", at, Vector3(size.x, size.y * 0.72, size.z), material)
	_box(node_name + "Foot", at - Vector3(0.0, size.y * 0.43, 0.0), Vector3(size.x * 0.94, size.y * 0.14, size.z * 0.94), _navy)
	_box(node_name + "Cap", at + Vector3(0.0, size.y * 0.43, 0.0), Vector3(size.x * 0.94, size.y * 0.14, size.z * 0.94), material)


func _chassis() -> void:
	for side: int in [-1, 1]:
		var suffix: String = "Left" if side < 0 else "Right"
		var x: float = float(side) * 4.35
		_layered("Frame" + suffix, Vector3(x, 2.05, -2.8), Vector3(0.4, 4.1, 0.65), _bone)
		_box("FrameInset" + suffix, Vector3(x, 2.3, -2.46), Vector3(0.19, 2.6, 0.035), _navy)
		_proxy("Frame" + suffix, Vector3(x, 2.05, -2.8), Vector3(0.4, 4.1, 0.65))
		# Human-scale tool cabinets: ~0.9 m work surface (player capsule is 1.8 m).
		var cabinet_at: Vector3 = Vector3(float(side) * 3.55, 0.42, -2.25)
		_layered("Cabinet" + suffix, cabinet_at, Vector3(0.92, 0.84, 0.72), _bone)
		_proxy("Cabinet" + suffix, cabinet_at, Vector3(0.92, 0.84, 0.72))
		_box("CabinetTop" + suffix, cabinet_at + Vector3(0.0, 0.46, 0.0), Vector3(0.98, 0.08, 0.76), _navy)
		for drawer: int in range(3):
			var drawer_y: float = 0.22 + float(drawer) * 0.2
			_box("Drawer" + suffix + str(drawer), Vector3(cabinet_at.x, drawer_y, -1.875), Vector3(0.76, 0.16, 0.03), _cobalt if drawer == 2 else _bone)
			_box("Handle" + suffix + str(drawer), Vector3(cabinet_at.x, drawer_y + 0.03, -1.845), Vector3(0.26, 0.03, 0.035), _navy)
		_box("FootGuard" + suffix, Vector3(x, 0.16, -2.35), Vector3(0.62, 0.32, 1.55), _navy)
		_proxy("FootGuard" + suffix, Vector3(x, 0.16, -2.35), Vector3(0.62, 0.32, 1.55))
	_layered("OverheadBeam", Vector3(0.0, 3.88, -2.8), Vector3(8.7, 0.48, 0.75), _bone)
	_proxy("OverheadBeam", Vector3(0.0, 3.88, -2.8), Vector3(8.7, 0.48, 0.75))
	_box("RearSpine", Vector3(0.0, 0.45, -3.35), Vector3(8.3, 0.28, 0.25), _navy)
	_proxy("RearSpine", Vector3(0.0, 0.45, -3.35), Vector3(8.3, 0.28, 0.25))
	for index: int in range(2):
		var x: float = -2.4 + float(index) * 4.8
		_box("TaskLightArm" + str(index), Vector3(x, 3.65, -2.1), Vector3(0.13, 0.13, 1.5), _metal)
		_box("TaskLightHousing" + str(index), Vector3(x, 3.48, -1.4), Vector3(1.25, 0.16, 0.4), _navy)
		_box("TaskLightDiffuser" + str(index), Vector3(x, 3.39, -1.4), Vector3(1.08, 0.025, 0.28), _lamp)
		var light: SpotLight3D = SpotLight3D.new()
		light.name = "TaskLight" + str(index)
		light.position = Vector3(x, 3.34, -1.35)
		light.rotation_degrees.x = -90.0
		light.light_color = Color("fff2e4")
		light.light_energy = 1.5
		light.spot_range = 5.0
		light.spot_angle = 52.0
		light.spot_attenuation = 1.2
		light.shadow_enabled = false
		_adopt(_visual, light)


func _sign(selected: String) -> void:
	_box("PhysicalSignBacking", Vector3(0.0, 3.88, -2.39), Vector3(4.3, 0.68, 0.085), _navy)
	# Emissive geometry uses the lobby's existing bloom; no extra lights.
	var neon := StandardMaterial3D.new()
	neon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	neon.albedo_color = Color("bceff5")
	neon.emission_enabled = true
	neon.emission = Color("65d9ed")
	neon.emission_energy_multiplier = 3.5
	var trim := _box("PhysicalSignTrim", Vector3(0.0, 3.59, -2.335), Vector3(3.9, 0.018, 0.025), neon)
	trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lettering: TextMesh = TextMesh.new()
	lettering.text = selected.to_upper()
	lettering.font_size = 96
	lettering.pixel_size = 0.006
	lettering.depth = 0.018
	var title := _mesh("PhysicalSignLettering", lettering, Vector3(0.0, 3.88, -2.325), neon)
	title.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	title.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_floor_plaque(selected)
	var index: int = PURPOSES.find(selected)
	for mark: int in range(index + 1):
		_box("BayIndex" + str(mark), Vector3(-3.78 + float(mark) * 0.12, 3.88, -2.4), Vector3(0.055, 0.2, 0.025), _amber)


func _floor_plaque(selected: String) -> void:
	# A shallow, non-colliding inset. All pieces rotate with their workshop.
	var surround := ShaderMaterial.new()
	surround.shader = preload("res://assets/materials/lobby/workshop_plaque.gdshader")
	surround.set_shader_parameter("face_color", Color("63717b"))
	surround.set_shader_parameter("metalness", 0.8)
	var face := ShaderMaterial.new()
	face.shader = preload("res://assets/materials/lobby/workshop_plaque.gdshader")
	face.set_shader_parameter("face_color", Color("172536"))
	_plaque_panel("PlaqueGasket", Vector2(4.5, 1.06), 0.13, 0.009, _navy)
	_plaque_panel("PlaqueMetalBezel", Vector2(4.42, 0.98), 0.12, 0.015, surround)
	_plaque_panel("PlaqueInset", Vector2(4.26, 0.82), 0.09, 0.021, face)
	var ink := _material(STARBONE, 0.15, 0.6)
	ink.emission_enabled = true
	ink.emission = STARBONE
	ink.emission_energy_multiplier = 0.35
	var title := TextMesh.new()
	title.text = selected.to_upper()
	title.font_size = 96
	title.pixel_size = 0.007
	title.depth = 0.001
	var text := _mesh("FloorName", title, Vector3(0, 0.026, 1.18), ink, Vector3(-90, 0, 0))
	text.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var accent := _material(AMBER, 0.45)
	accent.emission_enabled = true
	accent.emission = AMBER
	accent.emission_energy_multiplier = 0.45
	for side: float in [-1.0, 1.0]:
		_box("PlaqueAccent", Vector3(side * 1.88, 0.024, 1.15), Vector3(0.035, 0.005, 0.42), accent)
		for offset: float in [-0.32, 0.32]:
			_cylinder("PlaqueFastener", Vector3(side * 2.04, 0.023, 1.15 + offset), 0.026, 0.009, _metal, 8)

func _plaque_panel(label: String, size: Vector2, clip: float, height: float, material: Material) -> void:
	var x := size.x * 0.5
	var z := size.y * 0.5
	var outline := PackedVector2Array([
		Vector2(-x + clip, -z), Vector2(x - clip, -z),
		Vector2(x, -z + clip), Vector2(x, z - clip),
		Vector2(x - clip, z), Vector2(-x + clip, z),
		Vector2(-x, z - clip), Vector2(-x, -z + clip),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		# Clockwise when viewed from above: upward-facing Godot front face.
		for point: Vector2 in [Vector2.ZERO, outline[i], outline[(i + 1) % outline.size()]]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(point.x / size.x + 0.5, point.y / size.y + 0.5))
			surface.add_vertex(Vector3(point.x, 0, point.y))
	var panel := _mesh(label, surface.commit(), Vector3(0, height, 1.15), material)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.gi_mode = GeometryInstance3D.GI_MODE_DISABLED


func _weapons() -> void:
	# Standing workbench top ~0.92 m.
	for side: int in [-1, 1]:
		var x: float = float(side) * 1.45
		_layered("BenchPedestal" + str(side), Vector3(x, 0.4, -1.95), Vector3(0.55, 0.8, 1.15), _bone)
		_proxy("BenchPedestal" + str(side), Vector3(x, 0.4, -1.95), Vector3(0.55, 0.8, 1.15))
	_layered("WeaponsWorktop", Vector3(0.0, 0.86, -1.95), Vector3(3.6, 0.12, 1.35), _navy)
	_proxy("WeaponsWorktop", Vector3(0.0, 0.86, -1.95), Vector3(3.6, 0.12, 1.35))
	_box("ServiceMat", Vector3(0.0, 0.935, -1.85), Vector3(2.15, 0.02, 0.85), _cobalt)
	_box("ClampRail", Vector3(0.0, 0.99, -1.95), Vector3(1.55, 0.09, 0.2), _metal)
	for side: int in [-1, 1]:
		var x: float = float(side) * 0.58
		_box("ClampJaw" + str(side), Vector3(x, 1.16, -1.95), Vector3(0.12, 0.3, 0.3), _bone)
		_box("ClampPad" + str(side), Vector3(x - float(side) * 0.07, 1.2, -1.95), Vector3(0.045, 0.14, 0.22), _navy)
		var screw: MeshInstance3D = _cylinder("ClampScrew" + str(side), Vector3(x + float(side) * 0.15, 1.08, -1.95), 0.05, 0.3, _metal)
		screw.rotation_degrees.z = 90.0
	# A stripped receiver/barrel assembly, not a player weapon or gameplay pickup.
	_layered("ReceiverAssembly", Vector3(0.0, 1.12, -1.95), Vector3(0.9, 0.16, 0.2), _navy)
	_box("ReceiverShroud", Vector3(0.14, 1.22, -1.95), Vector3(0.4, 0.055, 0.18), _bone)
	var barrel: MeshInstance3D = _cylinder("BarrelAssembly", Vector3(-0.58, 1.15, -1.95), 0.05, 0.5, _metal)
	barrel.rotation_degrees.z = 90.0
	_box("PartsTray", Vector3(1.35, 0.95, -1.95), Vector3(0.42, 0.04, 0.6), _metal)
	for index: int in range(3):
		_box("Parts" + str(index), Vector3(1.35, 0.99, -2.12 + float(index) * 0.16), Vector3(0.24, 0.045, 0.07), _navy)
	_box("BenchRearToolRail", Vector3(0.0, 1.35, -2.72), Vector3(2.7, 0.1, 0.09), _bone)
	for side: int in [-1, 1]:
		_box("ToolRailUpright" + str(side), Vector3(float(side) * 1.25, 1.14, -2.72), Vector3(0.06, 0.48, 0.09), _metal)


func _armor() -> void:
	_cylinder("CradleBase", Vector3(0.0, 0.14, -2.0), 1.45, 0.28, _navy, 8, 0.94)
	_proxy("CradleBase", Vector3(0.0, 0.14, -2.0), Vector3(2.6, 0.28, 2.6))
	_layered("CradleSpine", Vector3(0.0, 1.62, -2.5), Vector3(0.3, 2.95, 0.3), _metal)
	_proxy("FittingCradle", Vector3(0.0, 1.65, -2.05), Vector3(2.5, 2.75, 1.15))
	_box("ShoulderSupport", Vector3(0.0, 2.45, -2.35), Vector3(2.45, 0.11, 0.18), _metal)
	# Separate display plates on an open mechanical cradle; no head, hands or body.
	_box("ChestPlateOuter", Vector3(0.0, 2.06, -1.85), Vector3(1.28, 0.92, 0.22), _navy)
	_box("ChestPlateUpper", Vector3(0.0, 2.25, -1.68), Vector3(1.08, 0.43, 0.18), _bone, Vector3(-12.0, 0.0, 0.0))
	_box("ChestPlateLower", Vector3(0.0, 1.84, -1.64), Vector3(0.86, 0.32, 0.18), _bone, Vector3(14.0, 0.0, 0.0))
	_box("ChestUnitStripe", Vector3(0.0, 2.25, -1.568), Vector3(0.14, 0.31, 0.025), _cobalt)
	for side: int in [-1, 1]:
		var x: float = float(side) * 0.96
		_box("ShoulderPlate" + str(side), Vector3(x, 2.49, -1.92), Vector3(0.57, 0.38, 0.62), _bone, Vector3(0.0, 0.0, float(side) * -18.0))
		_box("ShoulderInset" + str(side), Vector3(x, 2.48, -1.593), Vector3(0.4, 0.14, 0.035), _cobalt)
		_box("ShinMount" + str(side), Vector3(float(side) * 0.5, 0.89, -2.23), Vector3(0.1, 0.88, 0.12), _metal)
		_box("ShinPlate" + str(side), Vector3(float(side) * 0.5, 0.94, -1.88), Vector3(0.43, 0.72, 0.2), _bone, Vector3(-9.0, 0.0, float(side) * -6.0))
		_box("ShinPlateInset" + str(side), Vector3(float(side) * 0.5, 0.95, -1.75), Vector3(0.13, 0.53, 0.045), _navy)
	_box("CradleCrown", Vector3(0.0, 3.02, -2.36), Vector3(0.72, 0.16, 0.22), _cobalt)


func _utility() -> void:
	# Round diagnostic table top ~0.92 m; drone prop scaled to sit on it.
	_cylinder("DiagnosticStandBase", Vector3(-0.65, 0.12, -1.95), 0.7, 0.24, _navy, 8, 0.91)
	_layered("DiagnosticColumn", Vector3(-0.65, 0.5, -1.95), Vector3(0.4, 0.76, 0.4), _bone)
	_cylinder("DiagnosticTable", Vector3(-0.65, 0.9, -1.95), 0.85, 0.1, _cobalt, 8, 0.93)
	_proxy("DiagnosticStand", Vector3(-0.65, 0.5, -1.95), Vector3(1.55, 1.0, 1.55))
	_cylinder("DroneDock", Vector3(-0.65, 1.08, -1.95), 0.12, 0.28, _metal)
	_cylinder("DroneHull", Vector3(-0.65, 1.3, -1.95), 0.34, 0.26, _bone, 8, 0.75)
	_cylinder("DroneCrown", Vector3(-0.65, 1.46, -1.95), 0.17, 0.07, _navy)
	_box("DroneOpticHousing", Vector3(-0.65, 1.3, -1.62), Vector3(0.28, 0.12, 0.09), _navy)
	_box("DroneOptic", Vector3(-0.65, 1.3, -1.568), Vector3(0.14, 0.04, 0.02), _mint)
	for index: int in range(4):
		var angle: float = PI * 0.25 + float(index) * PI * 0.5
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var center: Vector3 = Vector3(-0.65, 1.26, -1.95)
		var arm: MeshInstance3D = _box("DroneArm" + str(index), center + direction * 0.42, Vector3(0.52, 0.07, 0.08), _metal)
		arm.rotation.y = -angle
		_cylinder("DronePod" + str(index), center + direction * 0.66, 0.18, 0.16, _navy, 12)
		_cylinder("DronePodCap" + str(index), center + direction * 0.66 + Vector3(0.0, 0.09, 0.0), 0.14, 0.03, _bone, 12)
	_layered("ChargingBank", Vector3(1.55, 0.36, -2.15), Vector3(0.85, 0.72, 0.85), _navy)
	_proxy("ChargingBank", Vector3(1.55, 0.6, -2.15), Vector3(0.85, 1.2, 0.85))
	for index: int in range(3):
		var x: float = 1.28 + float(index) * 0.27
		_cylinder("ChargingCell" + str(index), Vector3(x, 0.95, -2.15), 0.1, 0.5, _bone, 8)
		_cylinder("CellContact" + str(index), Vector3(x, 1.24, -2.15), 0.065, 0.06, _metal)
		_cylinder("CellBand" + str(index), Vector3(x, 1.08, -2.15), 0.105, 0.05, _mint, 8)
	_box("ChargingBankStripe", Vector3(1.55, 0.42, -1.715), Vector3(0.55, 0.045, 0.02), _amber)


func _outfit() -> void:
	for side: int in [-1, 1]:
		var x: float = -1.25 + float(side) * 1.05
		_box("RackFoot" + str(side), Vector3(x, 0.075, -2.4), Vector3(0.5, 0.15, 1.2), _navy)
		_box("RackUpright" + str(side), Vector3(x, 1.4, -2.4), Vector3(0.12, 2.65, 0.14), _bone)
		_proxy("RackUpright" + str(side), Vector3(x, 1.4, -2.4), Vector3(0.12, 2.65, 0.14))
		_proxy("RackFoot" + str(side), Vector3(x, 0.075, -2.4), Vector3(0.5, 0.15, 1.2))
	_box("TextileRail", Vector3(-1.25, 2.72, -2.4), Vector3(2.35, 0.12, 0.15), _metal)
	_proxy("TextileRail", Vector3(-1.25, 2.72, -2.4), Vector3(2.35, 0.12, 0.15))
	for index: int in range(4):
		var x: float = -2.0 + float(index) * 0.5
		_box("TextileHanger" + str(index), Vector3(x, 2.52, -2.4), Vector3(0.4, 0.045, 0.12), _metal)
		_box("HangerHook" + str(index), Vector3(x, 2.62, -2.4), Vector3(0.035, 0.21, 0.035), _metal)
		var textile_material: Material = _cobalt if index % 2 == 0 else _cloth
		var length: float = 1.4 + float(index % 2) * 0.25
		_box("HangingTextile" + str(index), Vector3(x, 2.45 - length * 0.5, -2.4), Vector3(0.43, length, 0.065), textile_material)
		for fold: int in range(3):
			_box("TextileFold" + str(index) + "_" + str(fold), Vector3(x - 0.14 + float(fold) * 0.14, 2.43 - length * 0.5, -2.345), Vector3(0.035, length - 0.05, 0.035), textile_material)
		_box("TextileHem" + str(index), Vector3(x, 2.47 - length, -2.327), Vector3(0.42, 0.045, 0.02), _bone)
	# Flush fitting inset: top at 2 mm, no step or extra floor collider.
	_cylinder("FlushFittingPlatform", Vector3(1.25, -0.018, -1.55), 1.13, 0.04, _metal, 12)
	_cylinder("FittingPlatformInset", Vector3(1.25, -0.016, -1.55), 0.96, 0.04, _navy, 12)
	for side: int in [-1, 1]:
		_box("FittingFootMark" + str(side), Vector3(1.25 + float(side) * 0.25, 0.005, -1.55), Vector3(0.11, 0.003, 0.4), _bone)
	_layered("FittingMirrorFrame", Vector3(1.25, 1.55, -3.0), Vector3(1.3, 3.1, 0.2), _bone)
	_box("FittingMirrorSurface", Vector3(1.25, 1.6, -2.886), Vector3(1.06, 2.67, 0.025), _metal)
	_proxy("FittingMirror", Vector3(1.25, 1.55, -3.0), Vector3(1.3, 3.1, 0.2))


func _deploy() -> void:
	_layered("NavigationFoot", Vector3(0.0, 0.1, -1.95), Vector3(1.9, 0.2, 1.35), _navy)
	_layered("NavigationPedestal", Vector3(0.0, 0.52, -2.05), Vector3(0.95, 0.84, 0.7), _bone)
	_box("PedestalInset", Vector3(0.0, 0.58, -1.69), Vector3(0.65, 0.55, 0.03), _cobalt)
	_proxy("NavigationFoot", Vector3(0.0, 0.1, -1.95), Vector3(1.9, 0.2, 1.35))
	_proxy("NavigationPedestal", Vector3(0.0, 0.52, -2.05), Vector3(0.95, 0.84, 0.7))
	var slope: Vector3 = Vector3(18.0, 0.0, 0.0)
	# Standing map table ~1.05 m at the near edge.
	var origin: Vector3 = Vector3(0.0, 1.0, -1.95)
	var map_basis: Basis = Basis.from_euler(slope * PI / 180.0)
	_box("MapLecternRim", origin, Vector3(2.45, 0.14, 1.5), _bone, slope)
	_proxy("MapLectern", origin, Vector3(2.45, 0.14, 1.5), slope)
	_box("PhysicalMapSurface", origin + map_basis * Vector3(0.0, 0.08, 0.0), Vector3(2.25, 0.025, 1.3), _navy, slope)
	# Raised cartographic relief and inlaid routes, deliberately not a screen or UI.
	for index: int in range(5):
		var x: float = -0.8 + float(index) * 0.4
		var z: float = sin(float(index) * 1.7) * 0.28
		var height: float = 0.035 + float(index % 3) * 0.02
		var relief: MeshInstance3D = _cylinder("MapRelief" + str(index), origin + map_basis * Vector3(x, 0.1 + height * 0.5, z), 0.21, height, _cobalt, 6, 0.73)
		relief.rotation_degrees = slope
		var marker: MeshInstance3D = _cylinder("MapPin" + str(index), origin + map_basis * Vector3(x, 0.14 + height, z), 0.025, 0.07, _amber if index == 4 else _bone, 8)
		marker.rotation_degrees = slope
	for index: int in range(3):
		_box("MapMeridian" + str(index), origin + map_basis * Vector3(-0.6 + float(index) * 0.6, 0.095, 0.0), Vector3(0.01, 0.006, 1.1), _metal, slope)
	_box("MapRouteInlay", origin + map_basis * Vector3(0.0, 0.097, 0.45), Vector3(1.95, 0.007, 0.02), _mint, slope)
	for side: int in [-1, 1]:
		_box("MapHandle" + str(side), origin + map_basis * Vector3(float(side) * 1.12, 0.16, 0.35), Vector3(0.05, 0.12, 0.4), _metal, slope)
	_layered("RouteArchive", Vector3(1.85, 0.45, -2.65), Vector3(0.42, 0.9, 0.55), _navy)
	_proxy("RouteArchive", Vector3(1.85, 0.45, -2.65), Vector3(0.42, 0.9, 0.55))
	for index: int in range(3):
		_box("ArchiveCartridge" + str(index), Vector3(1.85, 0.24 + float(index) * 0.22, -2.36), Vector3(0.3, 0.14, 0.06), _bone)
