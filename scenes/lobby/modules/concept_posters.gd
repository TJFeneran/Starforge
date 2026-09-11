@tool
extends Node3D
## Scatter gear concept posters on the hall face of the entry door wall.
## Flanks the large EntryDoor; centers sit near eye height (~1.55–1.9 m).

const TEXTURE_DIR := "res://assets/textures/lobby/gear_concepts/"
const WALL_Z := 17.72
const POSTER_WIDTH := 0.95
const POSTER_HEIGHT := 0.54
const FRAME_DEPTH := 0.03

## Stable scatter order (west cluster then east). Armor first, then guns.
const POSTER_FILES: PackedStringArray = [
	"armor_starter_dustcoat.png",
	"armor_common_outpost_plate.png",
	"armor_common_trail_warden.png",
	"armor_uncommon_signal_mantle.png",
	"armor_uncommon_quarry_shell.png",
	"armor_rare_riftward.png",
	"armor_rare_nightwell.png",
	"armor_legendary_solar_heart.png",
	"armor_legendary_horizon_aegis.png",
	"gun_sidearm_starter_emberflint.png",
	"gun_sidearm_common_latch.png",
	"gun_sidearm_uncommon_echo.png",
	"gun_sidearm_rare_needle.png",
	"gun_sidearm_legendary_dawnseal.png",
	"gun_rifle_common_ridge.png",
	"gun_rifle_uncommon_longpath.png",
	"gun_energy_rare_splitfin.png",
	"gun_energy_legendary_monument.png",
]


func _ready() -> void:
	build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color("374650")
	frame_mat.metallic = 0.55
	frame_mat.roughness = 0.48

	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5f0a7e11

	# Nine posters per flank outside the ±4.5 m entry buttresses.
	var west_slots := _scatter_slots(rng, -15.2, -5.4, 9)
	var east_slots := _scatter_slots(rng, 5.4, 15.2, 9)
	var slots: Array[Vector2] = []
	slots.append_array(west_slots)
	slots.append_array(east_slots)

	for index: int in POSTER_FILES.size():
		var file_name: String = POSTER_FILES[index]
		var slot: Vector2 = slots[index]
		_add_poster(file_name, slot.x, slot.y, frame_mat)


func _scatter_slots(rng: RandomNumberGenerator, x_min: float, x_max: float, count: int) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	# Two loose rows near eye level — enough gap that 0.54 m sheets do not overlap.
	var row_ys: Array[float] = [1.42, 2.12]
	var per_row := int(ceili(float(count) / 2.0))
	var placed := 0
	for row: int in 2:
		var n: int = mini(per_row, count - placed)
		for i: int in n:
			var t := 0.08 + 0.84 * (float(i) + 0.5) / float(n)
			var x := lerpf(x_min, x_max, t) + rng.randf_range(-0.18, 0.18)
			var y := row_ys[row] + rng.randf_range(-0.03, 0.03)
			# Mild horizontal stagger only — keep vertical rows cleanly separated.
			if i % 2 == 1:
				x += rng.randf_range(-0.06, 0.06)
			slots.append(Vector2(x, y))
			placed += 1
	return slots


func _add_poster(file_name: String, x: float, y: float, frame_mat: StandardMaterial3D) -> void:
	var tex_path := TEXTURE_DIR + file_name
	var texture := _load_poster_texture(tex_path)
	if texture == null:
		push_warning("Concept poster missing texture: " + tex_path)
		return

	var root := Node3D.new()
	root.name = file_name.get_basename().to_pascal_case()
	# Face into the hall (−Z). QuadMesh faces +Z locally.
	root.position = Vector3(x, y, WALL_Z)
	root.rotation = Vector3(0.0, PI, 0.0)
	add_child(root)
	root.owner = self

	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(POSTER_WIDTH + 0.06, POSTER_HEIGHT + 0.06, FRAME_DEPTH)
	frame.mesh = frame_mesh
	frame.material_override = frame_mat
	frame.position = Vector3(0.0, 0.0, -FRAME_DEPTH * 0.5)
	root.add_child(frame)
	frame.owner = self

	var poster := MeshInstance3D.new()
	poster.name = "Poster"
	var quad := QuadMesh.new()
	quad.size = Vector2(POSTER_WIDTH, POSTER_HEIGHT)
	poster.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.roughness = 0.62
	mat.metallic = 0.05
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Keep readable under lobby lighting without turning into a lightbox.
	mat.emission_enabled = true
	mat.emission_texture = texture
	mat.emission_energy_multiplier = 0.18
	poster.material_override = mat
	poster.position = Vector3(0.0, 0.0, 0.002)
	root.add_child(poster)
	poster.owner = self


func _load_poster_texture(res_path: String) -> Texture2D:
	# Concept exports may be JPEG bytes with a .png extension; detect by magic.
	if not FileAccess.file_exists(res_path):
		return null
	var bytes := FileAccess.get_file_as_bytes(res_path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	var err := OK
	if bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = image.load_jpg_from_buffer(bytes)
	elif bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50:
		err = image.load_png_from_buffer(bytes)
	else:
		err = image.load_png_from_buffer(bytes)
		if err != OK:
			err = image.load_jpg_from_buffer(bytes)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)
