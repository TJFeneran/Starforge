extends Node3D

## Wires fog exploration helpers for the forge hall lobby.

@onready var _fog: Node = $FogExplore
@onready var _world_env: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	if _fog and _fog.has_method("setup"):
		_fog.setup(_world_env)
