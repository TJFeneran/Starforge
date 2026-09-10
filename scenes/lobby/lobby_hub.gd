extends Node3D
## Wires lobby interactables to focused UI (globe → hologram map).

@onready var _map: CanvasLayer = $HologramMap
@onready var _globe_interact: Area3D = $CentralForge/Navigation/MapInteract


func _ready() -> void:
	if _globe_interact and _globe_interact.has_signal("interacted"):
		_globe_interact.interacted.connect(_on_globe_interacted)
	if _map.has_signal("destination_selected"):
		_map.destination_selected.connect(_on_destination_selected)


func _on_globe_interacted() -> void:
	if _map.has_method("open_map"):
		_map.open_map()


func _on_destination_selected(destination: MapDestination) -> void:
	# Framework hook — monument travel / globe look updates land here later.
	print("Lobby map marked destination: ", destination.id)
