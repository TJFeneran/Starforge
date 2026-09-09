@tool
extends Node3D

## Lobby-local lighting group. Fixtures under this node can be moved, duplicated, or deleted
## in lobby.tscn. Bulk controls multiply each fixture's individual settings.
@export var lights_enabled: bool = true:
	set(value):
		lights_enabled = value
		_refresh()
@export_range(0.0, 8.0, 0.05) var energy_multiplier: float = 1.0:
	set(value):
		energy_multiplier = value
		_refresh()
@export var color_tint: Color = Color.WHITE:
	set(value):
		color_tint = value
		_refresh()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if not is_inside_tree():
		return
	for fixture: Node in get_children():
		if fixture.has_method("refresh_light"):
			fixture.call("refresh_light")
