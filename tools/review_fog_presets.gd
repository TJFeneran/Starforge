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
	_apply_baseline()


func _apply_cleanroom() -> void:
	_apply_baseline()


func _apply_rift_smog() -> void:
	_apply_baseline()


func _apply_shaft_pools() -> void:
	_apply_baseline()
