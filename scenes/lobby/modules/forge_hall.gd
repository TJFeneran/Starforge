@tool
extends Node3D

## Authored layout in meters. Generated visuals belong to this module, never shared assets.
const FLOOR_SHADER = preload("res://assets/materials/lobby/hall_floor.gdshader")
const PAINTED_ALLOY_SHADER = preload("res://assets/materials/lobby/painted_alloy.gdshader")
const CATWALK_HEIGHT := 7.8
const CATWALK_THICKNESS := 0.3
const STAIR_RUN := 6.6
const STAIR_RISE := CATWALK_HEIGHT * 0.5
const STAIR_STEPS := 22
const REAR_WALL_Z := -22.8
const REAR_SHIFT := REAR_WALL_Z + 24.0
var _navy: StandardMaterial3D
var _bone: ShaderMaterial
var _metal: StandardMaterial3D
var _cobalt: StandardMaterial3D

func _ready() -> void:
	if has_node("Floor"):
		return
	_navy = _material("172133", 0.3, 0.65)
	_bone = ShaderMaterial.new()
	_bone.shader = PAINTED_ALLOY_SHADER
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
	_build_window_wall(-1.0)
	_build_window_wall(1.0)
	for side: float in [-1.0, 1.0]:
		_build_vault_side(side)
		_box("VaultReturn", Vector3(4.5, 16, 0.5), Vector3(side * 18.75, 8, -12), _navy, true)
	# Stair doorways with observation windows on the pier beside each upper entrance.
	_build_rear_window_wall()
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
	for x: float in [-8.0, 8.0]:
		_box("PortalFrame", Vector3(0.6, 14.5, 0.8), Vector3(x, 7.25, -20.2), _bone, true)
	_box("PortalLintel", Vector3(16.6, 0.4, 0.8), Vector3(0, 14.5, -20.2), _bone)
	# Surface markings sit just above the deck; they have no collision.
	for side: float in [-1.0, 1.0]:
		for z: float in [-6.0, 6.0]:
			_box("BayThreshold", Vector3(0.09, 0.004, 7.6), Vector3(side * 11.0, 0.004, z), _bone)
			for offset: float in [-3.8, 3.8]:
				_box("ThresholdEnd", Vector3(1.1, 0.004, 0.09), Vector3(side * 11.5, 0.004, z + offset), _bone)

func _glass_material() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.25, 0.43, 0.52, 0.065)
	glass.roughness = 0.08
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	return glass


func _build_window_wall(side: float) -> void:
	# Real holes in both render geometry and collision, not glass over an opaque wall.
	var prefix := "West" if side < 0.0 else "East"
	var x := side * 16.5
	var bottom := 9.6
	var top := 14.2
	_box(prefix + "WallLower", Vector3(0.5, bottom, 30), Vector3(x, bottom * 0.5, 3), _navy, true)
	_box(prefix + "WallHeader", Vector3(0.5, 16.0 - top, 30), Vector3(x, (16.0 + top) * 0.5, 3), _navy, true)
	var glass := _glass_material()
	var cursor := -12.0
	for z: float in [-7.0, 3.0, 13.0]:
		var left := z - 3.5
		_box(prefix + "WindowPier", Vector3(0.5, top - bottom, left - cursor), Vector3(x, (top + bottom) * 0.5, (cursor + left) * 0.5), _navy, true)
		cursor = z + 3.5
		# Deep pressure-frame reveals, inset gasket and a slender central mullion.
		for y: float in [bottom, top]:
			_box(prefix + "WindowFrame", Vector3(0.9, 0.24, 7.3), Vector3(x, y, z), _bone, true)
			_box(prefix + "WindowSeal", Vector3(0.94, 0.07, 6.8), Vector3(x, y + (0.17 if y == bottom else -0.17), z), _metal)
		for edge: float in [-3.5, 3.5]:
			_box(prefix + "WindowJamb", Vector3(0.9, 4.6, 0.24), Vector3(x, 11.9, z + edge), _bone, true)
		_box(prefix + "WindowMullion", Vector3(0.34, 4.36, 0.085), Vector3(x, 11.9, z), _metal, true)
		_box(prefix + "WindowSill", Vector3(1.15, 0.12, 7.45), Vector3(x - side * 0.12, bottom - 0.16, z), _metal)
		_pane(prefix + "PressureGlass" + str(int(z) + 7), Vector2(4.36, 6.76), Vector3(x, 11.9, z), Vector3(0, 0, PI * 0.5), Vector3(0.08, 4.36, 6.76), glass)
	_box(prefix + "WallEnd", Vector3(0.5, top - bottom, 18.0 - cursor), Vector3(x, (top + bottom) * 0.5, (cursor + 18.0) * 0.5), _navy, true)


func _build_vault_side(side: float) -> void:
	# Outer vault shell with a pressure window beside each upper stair entrance.
	var prefix := "West" if side < 0.0 else "East"
	var x := side * 21.0
	var depth := 12.0 - REAR_SHIFT
	var z_center := -18.0 + REAR_SHIFT * 0.5
	var z_min := z_center - depth * 0.5
	var z_max := z_center + depth * 0.5
	var bottom := 7.6
	var top := 15.2
	var win_half := 2.1
	var win_z := REAR_WALL_Z + 3.4
	_box(prefix + "VaultSideLower", Vector3(0.5, bottom, depth), Vector3(x, bottom * 0.5, z_center), _navy, true)
	_box(prefix + "VaultSideHeader", Vector3(0.5, 16.0 - top, depth), Vector3(x, (16.0 + top) * 0.5, z_center), _navy, true)
	_box(prefix + "VaultSideRearPier", Vector3(0.5, top - bottom, win_z - win_half - z_min), Vector3(x, (top + bottom) * 0.5, (z_min + win_z - win_half) * 0.5), _navy, true)
	_box(prefix + "VaultSideFrontPier", Vector3(0.5, top - bottom, z_max - (win_z + win_half)), Vector3(x, (top + bottom) * 0.5, (win_z + win_half + z_max) * 0.5), _navy, true)
	var mid_y := (top + bottom) * 0.5
	var band_h := top - bottom
	for y: float in [bottom, top]:
		_box(prefix + "VaultWindowFrame", Vector3(0.9, 0.24, win_half * 2.0 + 0.3), Vector3(x, y, win_z), _bone, true)
		_box(prefix + "VaultWindowSeal", Vector3(0.94, 0.07, win_half * 2.0 - 0.2), Vector3(x, y + (0.17 if y == bottom else -0.17), win_z), _metal)
	for edge: float in [-win_half, win_half]:
		_box(prefix + "VaultWindowJamb", Vector3(0.9, band_h, 0.24), Vector3(x, mid_y, win_z + edge), _bone, true)
	_box(prefix + "VaultWindowMullion", Vector3(0.34, band_h - 0.24, 0.085), Vector3(x, mid_y, win_z), _metal, true)
	_box(prefix + "VaultWindowSill", Vector3(1.15, 0.12, win_half * 2.0 + 0.45), Vector3(x - side * 0.12, bottom - 0.16, win_z), _metal)
	var glass := _glass_material()
	var pane_h := band_h - 0.24
	var pane_w := win_half * 2.0 - 0.24
	_pane(prefix + "VaultPressureGlass", Vector2(pane_h, pane_w), Vector3(x, mid_y, win_z), Vector3(0, 0, PI * 0.5), Vector3(0.08, pane_h, pane_w), glass)


func _build_rear_window_wall() -> void:
	# Wide observation cutout behind the forge monument, matching the side gallery windows.
	# Pier windows sit beside each upper stair entrance (east + west).
	var bottom := 7.6
	var top := 15.2
	var half_span := 8.6
	var stair_inner := 14.4
	_box("BackWallLower", Vector3(28.8, bottom, 0.5), Vector3(0, bottom * 0.5, REAR_WALL_Z), _navy, true)
	_box("BackWallHeader", Vector3(28.8, 16.0 - top, 0.5), Vector3(0, (16.0 + top) * 0.5, REAR_WALL_Z), _navy, true)
	var glass := _glass_material()
	for side: float in [-1.0, 1.0]:
		var prefix := "West" if side < 0.0 else "East"
		_box(prefix + "StairEntryDivider", Vector3(0.4, 11, 0.5), Vector3(side * 17.5, 5.5, REAR_WALL_Z), _navy, true)
		_box(prefix + "StairEntryOuterPier", Vector3(0.5, 16, 0.5), Vector3(side * 20.75, 8, REAR_WALL_Z), _navy, true)
		_box(prefix + "StairEntryHeader", Vector3(6.1, 5, 0.5), Vector3(side * 17.45, 13.5, REAR_WALL_Z), _navy, true)
		_build_stair_pier_window(prefix, side, half_span, stair_inner, bottom, top, glass, 0.85)
	for y: float in [bottom, top]:
		_box("RearWindowFrame", Vector3(half_span * 2.0 + 0.3, 0.24, 0.9), Vector3(0, y, REAR_WALL_Z), _bone, true)
		_box("RearWindowSeal", Vector3(half_span * 2.0 - 0.2, 0.07, 0.94), Vector3(0, y + (0.17 if y == bottom else -0.17), REAR_WALL_Z), _metal)
	for edge: float in [-half_span, half_span]:
		_box("RearWindowJamb", Vector3(0.24, top - bottom, 0.9), Vector3(edge, (top + bottom) * 0.5, REAR_WALL_Z), _bone, true)
	for x: float in [-4.0, 0.0, 4.0]:
		_box("RearWindowMullion", Vector3(0.085, top - bottom - 0.24, 0.34), Vector3(x, (top + bottom) * 0.5, REAR_WALL_Z), _metal, true)
	_box("RearWindowSill", Vector3(half_span * 2.0 + 0.45, 0.12, 1.15), Vector3(0, bottom - 0.16, REAR_WALL_Z + 0.12), _metal)
	var pane_h := top - bottom - 0.24
	var pane_w := half_span * 2.0 - 0.24
	_pane("RearPressureGlass", Vector2(pane_w, pane_h), Vector3(0, (top + bottom) * 0.5, REAR_WALL_Z), Vector3(PI * 0.5, 0, 0), Vector3(pane_w, pane_h, 0.08), glass)


func _build_stair_pier_window(prefix: String, side: float, pier_inner: float, pier_outer: float, bottom: float, top: float, glass: Material, margin: float) -> void:
	# Cut a pressure-framed opening into the pier beside a stair doorway.
	var pier_width := pier_outer - pier_inner
	var win_half := (pier_width - margin * 2.0) * 0.5
	var win_center := side * (pier_inner + pier_width * 0.5)
	var mid_y := (top + bottom) * 0.5
	var band_h := top - bottom
	var inner_edge := side * pier_inner
	var outer_edge := side * pier_outer
	var win_inner := win_center - side * win_half
	var win_outer := win_center + side * win_half
	var inner_width := absf(win_inner - inner_edge)
	var outer_width := absf(outer_edge - win_outer)
	_box(prefix + "StairPierInner", Vector3(inner_width, band_h, 0.5), Vector3((inner_edge + win_inner) * 0.5, mid_y, REAR_WALL_Z), _navy, true)
	_box(prefix + "StairPierOuter", Vector3(outer_width, band_h, 0.5), Vector3((win_outer + outer_edge) * 0.5, mid_y, REAR_WALL_Z), _navy, true)
	var frame_w := win_half * 2.0 + 0.3
	for y: float in [bottom, top]:
		_box(prefix + "StairWindowFrame", Vector3(frame_w, 0.24, 0.9), Vector3(win_center, y, REAR_WALL_Z), _bone, true)
		_box(prefix + "StairWindowSeal", Vector3(win_half * 2.0 - 0.2, 0.07, 0.94), Vector3(win_center, y + (0.17 if y == bottom else -0.17), REAR_WALL_Z), _metal)
	for edge: float in [-win_half, win_half]:
		_box(prefix + "StairWindowJamb", Vector3(0.24, band_h, 0.9), Vector3(win_center + edge, mid_y, REAR_WALL_Z), _bone, true)
	_box(prefix + "StairWindowMullion", Vector3(0.085, band_h - 0.24, 0.34), Vector3(win_center, mid_y, REAR_WALL_Z), _metal, true)
	_box(prefix + "StairWindowSill", Vector3(win_half * 2.0 + 0.45, 0.12, 1.15), Vector3(win_center, bottom - 0.16, REAR_WALL_Z + 0.12), _metal)
	var pane_h := band_h - 0.24
	var pane_w := win_half * 2.0 - 0.24
	_pane(prefix + "StairPressureGlass", Vector2(pane_w, pane_h), Vector3(win_center, mid_y, REAR_WALL_Z), Vector3(PI * 0.5, 0, 0), Vector3(pane_w, pane_h, 0.08), glass)


func _pane(label: String, size: Vector2, at: Vector3, euler: Vector3, collision_size: Vector3, glass: Material) -> void:
	var pane := MeshInstance3D.new()
	pane.name = label
	var plane := PlaneMesh.new()
	plane.size = size
	pane.mesh = plane
	pane.rotation = euler
	pane.position = at
	pane.material_override = glass
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pane)
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = collision_size
	collision.shape = shape
	body.position = at
	body.add_child(collision)
	add_child(body)


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
	if material == _bone:
		mesh.set_instance_shader_parameter("half_extents", box.size * 0.5)
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
	if material == _bone:
		mesh.set_instance_shader_parameter("half_extents", box.size * 0.5)
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
