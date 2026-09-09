@tool
extends Node3D

## Authored layout in meters. Generated visuals belong to this module, never shared assets.
const FLOOR_SHADER = preload("res://assets/materials/lobby/hall_floor.gdshader")
const CATWALK_HEIGHT := 7.8
const CATWALK_THICKNESS := 0.3
const STAIR_RUN := 6.6
const STAIR_RISE := CATWALK_HEIGHT * 0.5
const STAIR_STEPS := 22
const REAR_WALL_Z := -22.8
const REAR_SHIFT := REAR_WALL_Z + 24.0
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
	# Workshop walls sit 4.5 m closer on each side; retain the wider transit area.
	_box("Floor", Vector3(33, 0.4, 30), Vector3(0, -0.2, 3), floor_material, true)
	_box("TransitVaultFloor", Vector3(42, 0.4, 12 - REAR_SHIFT), Vector3(0, -0.2, -18 + REAR_SHIFT * 0.5), floor_material, true)
	# One 16 m ceiling height throughout, preserving clearance for the 13.5 m gate.
	_box("Ceiling", Vector3(33, 0.35, 30), Vector3(0, 16, 3), _navy, true)
	_box("TransitVaultCeiling", Vector3(42, 0.35, 12 - REAR_SHIFT), Vector3(0, 16, -18 + REAR_SHIFT * 0.5), _navy, true)
	# Enclosed outer shell. Front entrance is a shallow recess, not an unbounded exit.
	_box("WestWall", Vector3(0.5, 16, 30), Vector3(-16.5, 8, 3), _navy, true)
	_box("EastWall", Vector3(0.5, 16, 30), Vector3(16.5, 8, 3), _navy, true)
	for side: float in [-1.0, 1.0]:
		_box("VaultSide", Vector3(0.5, 16, 12 - REAR_SHIFT), Vector3(side * 21.0, 8, -18 + REAR_SHIFT * 0.5), _navy, true)
		_box("VaultReturn", Vector3(4.5, 16, 0.5), Vector3(side * 18.75, 8, -12), _navy, true)
	# Full-height stairwell openings at each end of the rear wall.
	_box("BackWall", Vector3(28.8, 16, 0.5), Vector3(0, 8, REAR_WALL_Z), _navy, true)
	for side: float in [-1.0, 1.0]:
		_box("StairEntryDivider", Vector3(0.4, 11, 0.5), Vector3(side * 17.5, 5.5, REAR_WALL_Z), _navy, true)
		_box("StairEntryOuterPier", Vector3(0.5, 16, 0.5), Vector3(side * 20.75, 8, REAR_WALL_Z), _navy, true)
		_box("StairEntryHeader", Vector3(6.1, 5, 0.5), Vector3(side * 17.45, 13.5, REAR_WALL_Z), _navy, true)
	_box("EntranceWall", Vector3(33, 16, 0.5), Vector3(0, 8, 18), _navy, true)
	for side: float in [-1.0, 1.0]:
		for z: float in [-12.0, 0.0, 12.0]:
			_box("BayPier", Vector3(1.0, 6.2, 0.75), Vector3(side * 11.7, 3.1, z), _bone, true)
			_box("PierFoot", Vector3(1.25, 0.38, 1.0), Vector3(side * 11.7, 0.19, z), _metal, true)
			_box("BayPartition", Vector3(4.55, 5.6, 0.35), Vector3(side * 13.975, 2.8, z), _navy, true)
			_box("PartitionCap", Vector3(4.55, 0.2, 0.45), Vector3(side * 13.975, 5.7, z), _bone)
		for z: float in [-6.0, 6.0]:
			_box("BayLintel", Vector3(0.7, 0.45, 11.25), Vector3(side * 11.7, 6.05, z), _bone)
			_box("BayRoof", Vector3(4.5, 0.2, 11.8), Vector3(side * 14.0, 6.4, z), _navy)
			_box("BayBackPanel", Vector3(0.12, 3.6, 9.0), Vector3(side * 16.1, 2.5, z), _bone)
			_box("BayBackStripe", Vector3(0.14, 0.42, 9.0), Vector3(side * 16.0, 4.0, z), _cobalt)
		# Continuous upper gallery frames the hall without blocking the orbit lane.
		_box("GalleryFascia", Vector3(0.45, 1.25, 30), Vector3(side * 12.0, 7.1, 0), _metal)
		_box("GalleryTrim", Vector3(0.55, 0.10, 30), Vector3(side * 11.95, 6.5, 0), _bone)
	for z: float in [-8.0, 0.0, 12.0]:
		_box("RoofCrossbeam", Vector3(33, 0.6, 0.55), Vector3(0, 15.4, z), _metal)
	for z: float in [-16.0, REAR_WALL_Z + 1.0]:
		_box("VaultCrossbeam", Vector3(42, 0.6, 0.55), Vector3(0, 15.4, z), _metal)
	_build_catwalk()
	for side: float in [-1.0, 1.0]:
		_build_rear_stairwell(side)
	# Light fixtures are authored under HallLighting, not generated with architecture.
	for side: float in [-1.0, 1.0]:
		_box("CatwalkLightingRail", Vector3(0.16, 0.16, 28), Vector3(side * 10.85, 7.35, 1), _metal)
	# A physical entry threshold and rear portal niche.
	for x: float in [-4.5, 4.5]:
		_box("EntryButtress", Vector3(0.75, 6.8, 1.0), Vector3(x, 3.4, 17), _bone, true)
	_box("EntryLintel", Vector3(9.75, 0.6, 1), Vector3(0, 6.8, 17), _bone)
	_box("EntryDoor", Vector3(7.8, 5.8, 0.18), Vector3(0, 2.9, 17.65), _metal)
	for x: float in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		_box("DoorFluting", Vector3(0.045, 5.1, 0.05), Vector3(x, 2.85, 17.52), _bone)
	_sign("EntrySign", "STARFORGE  /  OPERATIONS", Vector3(0, 5.8, 17.35), PI, 38)
	_sign("DeploySign", "EXPEDITION  /  TRANSIT", Vector3(0, 14.7, REAR_WALL_Z + 0.5), 0.0, 48)
	for x: float in [-8.0, 8.0]:
		_box("PortalFrame", Vector3(0.6, 14.5, 0.8), Vector3(x, 7.25, -20.2), _bone, true)
	_box("PortalLintel", Vector3(16.6, 0.4, 0.8), Vector3(0, 14.5, -20.2), _bone)
	# Surface markings sit just above the deck; they have no collision.
	for side: float in [-1.0, 1.0]:
		for z: float in [-6.0, 6.0]:
			_box("BayThreshold", Vector3(0.09, 0.004, 7.6), Vector3(side * 11.0, 0.004, z), _bone)
			for offset: float in [-3.8, 3.8]:
				_box("ThresholdEnd", Vector3(1.1, 0.004, 0.09), Vector3(side * 11.5, 0.004, z + offset), _bone)

func _build_catwalk() -> void:
	# Broad side decks sit above the workshop roofs; the center remains open to 16 m.
	for side: float in [-1.0, 1.0]:
		_deck("WorkshopCatwalk", Vector2(5.75, 35.55), Vector3(side * 13.375, CATWALK_HEIGHT, -3.025))
		_guardrail("GalleryRail", Vector3(side * 10.6, CATWALK_HEIGHT, -20.8), Vector3(side * 10.6, CATWALK_HEIGHT, 14.65))
		# The rear hall is wider. Guard the exposed outer edge until the rear bridge.
		_guardrail("RearOuterRail", Vector3(side * 16.15, CATWALK_HEIGHT, -20.8), Vector3(side * 16.15, CATWALK_HEIGHT, -12.3))
		_guardrail("RearBridgeRail", Vector3(side * 16.25, CATWALK_HEIGHT, -20.9), Vector3(side * 20.6, CATWALK_HEIGHT, -20.9))
		# Lower-flight doorway is NOT an upper-level exit. Keep its drop guarded.
		_guardrail("StairVoidRail", Vector3(side * 17.7, CATWALK_HEIGHT, REAR_WALL_Z + 0.4), Vector3(side * 20.5, CATWALK_HEIGHT, REAR_WALL_Z + 0.4))
		for z: float in [-18.0, -12.0, 0.0, 12.0]:
			_box("CatwalkSupport", Vector3(5.4, 0.4, 0.3), Vector3(side * 13.4, 7.3, z), _metal)
	_deck("EntryCatwalk", Vector2(32.5, 3.0), Vector3(0, CATWALK_HEIGHT, 16.25))
	_guardrail("EntryGalleryRail", Vector3(-10.6, CATWALK_HEIGHT, 14.85), Vector3(10.6, CATWALK_HEIGHT, 14.85))
	# Gate ends at z=-19.43; the bridge starts at -20.8, behind the entire mesh.
	_deck("RearCatwalk", Vector2(41.5, 2.95 - REAR_SHIFT), Vector3(0, CATWALK_HEIGHT, -22.275 + REAR_SHIFT * 0.5))
	_guardrail("BehindGateRail", Vector3(-10.6, CATWALK_HEIGHT, -20.9), Vector3(10.6, CATWALK_HEIGHT, -20.9))


func _deck(label: String, size: Vector2, top: Vector3) -> void:
	_box(label, Vector3(size.x, CATWALK_THICKNESS, size.y), top - Vector3(0, CATWALK_THICKNESS * 0.5, 0), _metal, true)
	# Thin, inset walking plates break up the deck without introducing collision lips.
	var count := maxi(1, ceili(size.y / 2.0))
	var length: float = size.y / float(count)
	for index: int in range(count):
		var at := top + Vector3(0, 0.006, -size.y * 0.5 + (float(index) + 0.5) * length)
		_box(label + "Plate", Vector3(size.x - 0.12, 0.012, length - 0.035), at, _navy)


func _guardrail(label: String, start: Vector3, end: Vector3) -> void:
	var delta := end - start
	var horizontal_length := Vector2(delta.x, delta.z).length()
	var along_x := absf(delta.x) > absf(delta.z)
	var count := maxi(1, ceili(horizontal_length / 2.0))
	for index: int in range(count + 1):
		var at := start.lerp(end, float(index) / float(count))
		_box(label + "Post", Vector3(0.09, 1.2, 0.09), at + Vector3(0, 0.6, 0), _bone)
	for height: float in [0.12, 0.58, 1.15]:
		_beam_between(label + "Bar", start + Vector3(0, height, 0), end + Vector3(0, height, 0), 0.075, _bone if height > 1.0 else _metal)
	# Invisible continuous guard collision prevents walking between the visible bars.
	var body := StaticBody3D.new()
	body.name = label + "Guard"
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	var width := Vector3(0, 0, 0.065) if along_x else Vector3(0.065, 0, 0)
	for at: Vector3 in [start, end]:
		for height: float in [0.0, 1.22]:
			points.append(at + Vector3(0, height, 0) - width)
			points.append(at + Vector3(0, height, 0) + width)
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _beam_between(label: String, start: Vector3, end: Vector3, width: float, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = Vector3(width, width, start.distance_to(end))
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = (start + end) * 0.5
	var direction := (end - start).normalized()
	mesh.basis = Basis.looking_at(direction, Vector3.FORWARD if absf(direction.y) > 0.99 else Vector3.UP)
	add_child(mesh)


func _build_rear_stairwell(side: float) -> void:
	# Paired switchbacks recessed BEHIND the back wall, clear of the gate approach.
	var first_child := get_child_count()
	var outer_x := side * 19.1
	var inner_x := side * 15.9
	_box("StairwellFloor", Vector3(6.6, 0.4, 10.5), Vector3(side * 17.5, -0.2, -29.25), _navy, true)
	_box("StairwellBack", Vector3(6.6, 11, 0.4), Vector3(side * 17.5, 5.5, -34.5), _navy, true)
	for x: float in [14.3, 20.7]:
		_box("StairwellWall", Vector3(0.4, 11, 10.5), Vector3(side * x, 5.5, -29.25), _navy, true)
	_box("StairwellCeiling", Vector3(6.6, 0.3, 10.5), Vector3(side * 17.5, 11, -29.25), _navy, true)
	_box("UpperDoorSill", Vector3(2.9, 7.5, 0.5), Vector3(inner_x, 3.75, -24), _navy, true)
	_deck("StairTopLanding", Vector2(2.8, 1.75), Vector3(inner_x, CATWALK_HEIGHT, -24.625))
	_deck("StairTurnLanding", Vector2(6.0, 2.2), Vector3(side * 17.5, STAIR_RISE, -33.2))
	_stair_flight("LowerStair", outer_x, -25.5, -32.1, 0.0)
	_stair_flight("UpperStair", inner_x, -32.1, -25.5, STAIR_RISE)
	# Close the sides of the upper landing, leaving the forward catwalk doorway open.
	for edge: float in [-1.4, 1.4]:
		_guardrail("TopLandingRail", Vector3(inner_x + edge, CATWALK_HEIGHT, -25.5), Vector3(inner_x + edge, CATWALK_HEIGHT, -23.85))
	_sign("StairAccessSign", "GALLERY  /  UP", Vector3(outer_x, 3.1, -23.68), 0.0, 30)
	# Shift the complete stair assembly, including ramp/rail physics.
	for index: int in range(first_child, get_child_count()):
		var part := get_child(index) as Node3D
		part.position.z += REAR_SHIFT


func _stair_flight(label: String, x: float, start_z: float, end_z: float, base_y: float) -> void:
	var direction := signf(end_z - start_z)
	var tread := STAIR_RUN / float(STAIR_STEPS)
	var riser := STAIR_RISE / float(STAIR_STEPS)
	for index: int in range(STAIR_STEPS):
		var top := base_y + float(index + 1) * riser
		var z := start_z + direction * (float(index) + 0.5) * tread
		_box(label + "Tread", Vector3(2.8, riser, tread), Vector3(x, top - riser * 0.5, z), _metal)
		_box(label + "Nosing", Vector3(2.65, 0.018, 0.045), Vector3(x, top + 0.009, z - direction * (tread * 0.5 - 0.025)), _bone)
	# A wedge instead of individual riser collisions avoids camera bob and stair snagging.
	var body := StaticBody3D.new()
	body.name = label + "Ramp"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for edge: float in [-1.4, 1.4]:
		points.append(Vector3(x + edge, base_y - 0.25, start_z))
		points.append(Vector3(x + edge, base_y, start_z))
		points.append(Vector3(x + edge, base_y - 0.25, end_z))
		points.append(Vector3(x + edge, base_y + STAIR_RISE, end_z))
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	for edge: float in [-1.4, 1.4]:
		var start := Vector3(x + edge, base_y, start_z)
		var end := Vector3(x + edge, base_y + STAIR_RISE, end_z)
		_guardrail(label + "Rail", start, end)
		_beam_between(label + "Stringer", start - Vector3(0, 0.18, 0), end - Vector3(0, 0.18, 0), 0.2, _metal)


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
