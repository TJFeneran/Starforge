@tool
extends Node3D

## Saved fixture geometry and spotlight; local -Z is the emitted light direction.
## Edit these properties on the fixture root, not the derived TaskLight values.
@export var light_enabled: bool = true:
	set(value):
		light_enabled = value
		refresh_light()
@export_range(0.0, 16.0, 0.05) var energy: float = 2.2:
	set(value):
		energy = value
		refresh_light()
@export var light_color: Color = Color("e6edee"):
	set(value):
		light_color = value
		refresh_light()
@export var casts_shadow: bool = false:
	set(value):
		casts_shadow = value
		refresh_light()
@export_range(0.1, 60.0, 0.1) var light_range: float = 19.0:
	set(value):
		light_range = value
		refresh_light()
@export_range(1.0, 89.0, 0.5) var cone_angle: float = 58.0:
	set(value):
		cone_angle = value
		refresh_light()
@export var diffuser_color: Color = Color("e2e7df"):
	set(value):
		diffuser_color = value
		refresh_light()
@export_range(0.0, 8.0, 0.05) var diffuser_energy: float = 1.8:
	set(value):
		diffuser_energy = value
		refresh_light()

var _lens: StandardMaterial3D

func _ready() -> void:
	refresh_light()

func refresh_light() -> void:
	if not is_inside_tree():
		return
	var light := get_node_or_null("TaskLight") as SpotLight3D
	var diffuser := get_node_or_null("Diffuser") as MeshInstance3D
	if light == null or diffuser == null:
		return
	var multiplier := 1.0
	var tint := Color.WHITE
	var enabled := light_enabled
	var parent := get_parent()
	if parent != null and parent.has_method("_refresh") and parent.get("energy_multiplier") != null:
		multiplier = parent.get("energy_multiplier")
		tint = parent.get("color_tint")
		enabled = enabled and parent.get("lights_enabled")
	light.visible = enabled
	light.light_energy = energy * multiplier
	light.light_color = light_color * tint
	light.shadow_enabled = casts_shadow
	light.spot_range = light_range
	light.spot_angle = cone_angle
	if _lens == null:
		_lens = diffuser.material_override.duplicate() as StandardMaterial3D
		diffuser.material_override = _lens
	_lens.albedo_color = diffuser_color * tint
	_lens.emission = diffuser_color * tint
	_lens.emission_energy_multiplier = diffuser_energy * multiplier if enabled else 0.0
