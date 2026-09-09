extends SceneTree

## Capture lobby volumetric-fog look options for review.
## godot --path . --rendering-method forward_plus --script tools/review_fog_presets.gd
## Writes PNGs under /tmp/starforge-fog-review/

const OUTPUT_DIR := "/tmp/starforge-fog-review"
const SETTLE_FRAMES := 48

var _room: Node3D
var _camera: Camera3D
var _env: Environment


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/lobby/lobby.tscn")
	if packed == null:
		push_error("Cannot load lobby")
		quit(1)
		return

	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))

	_room = packed.instantiate()
	root.add_child(_room)
	await process_frame

	var player: Node = _room.get_node_or_null("Player")
	if player:
		player.set_process_input(false)
		player.set_physics_process(false)
		player.set_process(false)
		if player.has_method("set") and "visible" in player:
			pass
		# Keep player visible as scale reference, but park them.
		if player is Node3D:
			(player as Node3D).global_position = Vector3(0.0, 0.0, 8.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var world_env: WorldEnvironment = _room.get_node("WorldEnvironment")
	_env = world_env.environment.duplicate(true)
	world_env.environment = _env

	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.current = true
	root.add_child(_camera)

	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var views: Array[Dictionary] = [
		{"name": "hall", "at": Vector3(0.0, 2.6, 14.5), "target": Vector3(0.0, 1.8, -2.0)},
		{"name": "forge", "at": Vector3(7.0, 2.8, 8.0), "target": Vector3(0.0, 2.0, 0.0)},
		{"name": "monument", "at": Vector3(4.5, 2.4, -8.5), "target": Vector3(0.0, 2.2, -14.0)},
	]

	var presets: Array[Dictionary] = [
		{
			"id": "A_baseline",
			"title": "A — Baseline (no fog)",
			"apply": Callable(self, "_apply_baseline"),
		},
		{
			"id": "B_forge_haze",
			"title": "B — Forge Haze (warm thin volumetric)",
			"apply": Callable(self, "_apply_forge_haze"),
		},
		{
			"id": "C_cleanroom",
			"title": "C — Cleanroom Drift (cool clinical)",
			"apply": Callable(self, "_apply_cleanroom"),
		},
		{
			"id": "D_rift_smog",
			"title": "D — Rift Smog (dense dramatic)",
			"apply": Callable(self, "_apply_rift_smog"),
		},
		{
			"id": "E_shaft_pools",
			"title": "E — Shaft Pools (light global + local FogVolumes)",
			"apply": Callable(self, "_apply_shaft_pools"),
		},
	]

	for preset: Dictionary in presets:
		_clear_fog_volumes()
		(preset.apply as Callable).call()
		print("FOG_PRESET ", preset.id, " — ", preset.title)
		for view: Dictionary in views:
			_camera.global_position = view.at
			_camera.look_at(view.target, Vector3.UP)
			for _i in SETTLE_FRAMES:
				await process_frame
			if DisplayServer.get_name() == "headless":
				push_error("Need a real display for fog screenshots (not --headless)")
				quit(2)
				return
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var path := "%s/%s_%s.png" % [OUTPUT_DIR, preset.id, view.name]
			var err := image.save_png(path)
			print("FOG_IMAGE ", path, " status=", err)

	print("FOG_REVIEW_DONE ", OUTPUT_DIR)
	quit(0)


func _reset_fog_common() -> void:
	_env.fog_enabled = false
	_env.volumetric_fog_enabled = false
	_env.volumetric_fog_density = 0.0
	_env.volumetric_fog_albedo = Color(1, 1, 1)
	_env.volumetric_fog_emission = Color(0, 0, 0)
	_env.volumetric_fog_emission_energy = 0.0
	_env.volumetric_fog_anisotropy = 0.2
	_env.volumetric_fog_length = 64.0
	_env.volumetric_fog_detail_spread = 2.0
	_env.volumetric_fog_gi_inject = 0.0
	_env.volumetric_fog_ambient_inject = 0.0
	_env.volumetric_fog_sky_affect = 1.0
	_env.volumetric_fog_temporal_reprojection_enabled = true
	_env.volumetric_fog_temporal_reprojection_amount = 0.9


func _clear_fog_volumes() -> void:
	var holder := _room.get_node_or_null("FogExploreVolumes")
	if holder:
		holder.free()


func _ensure_volume_holder() -> Node3D:
	var holder := _room.get_node_or_null("FogExploreVolumes") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "FogExploreVolumes"
		_room.add_child(holder)
	return holder


func _add_fog_volume(name: String, pos: Vector3, size: Vector3, density: float, albedo: Color, emission: Color, emission_energy: float) -> void:
	var holder := _ensure_volume_holder()
	var vol := FogVolume.new()
	vol.name = name
	vol.size = size
	vol.shape = 0 # Ellipsoid (Local)
	holder.add_child(vol)
	vol.global_position = pos
	var mat := FogMaterial.new()
	mat.density = density
	mat.albedo = albedo
	mat.emission = emission
	mat.emission_energy = emission_energy
	mat.edge_fade = 0.55
	vol.material = mat


func _apply_baseline() -> void:
	_reset_fog_common()


func _apply_forge_haze() -> void:
	_reset_fog_common()
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.018
	_env.volumetric_fog_albedo = Color(1.0, 0.86, 0.72)
	_env.volumetric_fog_emission = Color(0.35, 0.18, 0.05)
	_env.volumetric_fog_emission_energy = 0.08
	_env.volumetric_fog_anisotropy = 0.35
	_env.volumetric_fog_length = 48.0
	_env.volumetric_fog_gi_inject = 0.35
	_env.volumetric_fog_ambient_inject = 0.15


func _apply_cleanroom() -> void:
	_reset_fog_common()
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.0065
	_env.volumetric_fog_albedo = Color(0.82, 0.9, 0.96)
	_env.volumetric_fog_emission = Color(0.1, 0.16, 0.22)
	_env.volumetric_fog_emission_energy = 0.02
	_env.volumetric_fog_anisotropy = 0.12
	_env.volumetric_fog_length = 64.0
	_env.volumetric_fog_gi_inject = 0.12
	_env.volumetric_fog_ambient_inject = 0.18


func _apply_rift_smog() -> void:
	_reset_fog_common()
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.045
	_env.volumetric_fog_albedo = Color(0.35, 0.42, 0.55)
	_env.volumetric_fog_emission = Color(0.08, 0.16, 0.35)
	_env.volumetric_fog_emission_energy = 0.22
	_env.volumetric_fog_anisotropy = 0.45
	_env.volumetric_fog_length = 40.0
	_env.volumetric_fog_gi_inject = 0.55
	_env.volumetric_fog_ambient_inject = 0.1
	# Soft classic fog layer for depth crush at distance.
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.18, 0.24, 0.38)
	_env.fog_light_energy = 0.55
	_env.fog_density = 0.0045
	_env.fog_aerial_perspective = 0.35


func _apply_shaft_pools() -> void:
	_reset_fog_common()
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.008
	_env.volumetric_fog_albedo = Color(0.95, 0.92, 0.88)
	_env.volumetric_fog_anisotropy = 0.55
	_env.volumetric_fog_length = 56.0
	_env.volumetric_fog_gi_inject = 0.45
	_env.volumetric_fog_ambient_inject = 0.05
	# Local denser pools around forge + monument for readable light shafts.
	_add_fog_volume(
		"ForgePool",
		Vector3(0.0, 2.2, 0.0),
		Vector3(14.0, 8.0, 14.0),
		0.06,
		Color(1.0, 0.82, 0.65),
		Color(1.0, 0.55, 0.2),
		0.15
	)
	_add_fog_volume(
		"MonumentPool",
		Vector3(0.0, 2.5, -14.0),
		Vector3(10.0, 7.0, 8.0),
		0.05,
		Color(1.0, 0.78, 0.5),
		Color(1.0, 0.6, 0.25),
		0.2
	)
