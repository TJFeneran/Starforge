extends Node

## Fog exploration helper — disabled.
## Kept so older lobby wiring does not break; always forces fog off.

signal preset_changed(preset_id: String, title: String)

var _env: Environment


func setup(world_env: WorldEnvironment) -> void:
	if world_env == null or world_env.environment == null:
		return
	_env = world_env.environment.duplicate(true)
	world_env.environment = _env
	_clear_fog()
	preset_changed.emit("disabled", "Fog disabled")


func _unhandled_input(_event: InputEvent) -> void:
	# F4/F5/F6 fog cycling removed.
	pass


func _clear_fog() -> void:
	if _env == null:
		return
	_env.fog_enabled = false
	_env.volumetric_fog_enabled = false
	_env.volumetric_fog_density = 0.0
	_env.volumetric_fog_emission_energy = 0.0
	_env.volumetric_fog_gi_inject = 0.0
	_env.volumetric_fog_ambient_inject = 0.0
	var parent := get_parent()
	if parent:
		var holder := parent.get_node_or_null("FogExploreVolumes")
		if holder:
			holder.queue_free()
