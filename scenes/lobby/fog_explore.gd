extends Node

## Cycle lobby volumetric-fog look options in PIE.
## F6 = next preset, F5 = previous, F4 = baseline (no fog).

signal preset_changed(preset_id: String, title: String)

var _env: Environment
var _holder: Node3D
var _index := 0
var _presets: Array[Dictionary] = []


func setup(world_env: WorldEnvironment) -> void:
	_env = world_env.environment.duplicate(true)
	world_env.environment = _env
	_holder = Node3D.new()
	_holder.name = "FogExploreVolumes"
	world_env.get_parent().add_child(_holder)
	_presets = [
		{"id": "A_baseline", "title": "A — Baseline (no fog)", "apply": "_apply_baseline"},
		{"id": "B_forge_haze", "title": "B — Forge Haze (warm thin volumetric)", "apply": "_apply_forge_haze"},
		{"id": "C_cleanroom", "title": "C — Cleanroom Drift (soft clinical)", "apply": "_apply_cleanroom"},
		{"id": "D_rift_smog", "title": "D — Rift Smog (dense dramatic)", "apply": "_apply_rift_smog"},
		{"id": "E_shaft_pools", "title": "E — Shaft Pools (global + FogVolumes)", "apply": "_apply_shaft_pools"},
	]
	# Start on softened Cleanroom (user pick).
	_apply_index(2)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F6:
				_apply_index(_index + 1)
				get_viewport().set_input_as_handled()
			KEY_F5:
				_apply_index(_index - 1)
				get_viewport().set_input_as_handled()
			KEY_F4:
				_apply_index(0)
				get_viewport().set_input_as_handled()


func _apply_index(i: int) -> void:
	if _presets.is_empty() or _env == null:
		return
	_index = posmod(i, _presets.size())
	_clear_volumes()
	call(_presets[_index].apply)
	var title: String = _presets[_index].title
	print("FOG_PRESET ", title)
	preset_changed.emit(_presets[_index].id, title)


func _clear_volumes() -> void:
	if _holder == null:
		return
	for child in _holder.get_children():
		child.queue_free()


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


func _add_fog_volume(vol_name: String, pos: Vector3, size: Vector3, density: float, albedo: Color, emission: Color, emission_energy: float) -> void:
	var vol := FogVolume.new()
	vol.name = vol_name
	vol.size = size
	vol.shape = 0 # Ellipsoid (Local)
	_holder.add_child(vol)
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
