extends Node3D

## Lobby bootstrap. Forces fog off if any fog helper is present.

@onready var _fog: Node = get_node_or_null("FogExplore")
@onready var _world_env: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	if _world_env and _world_env.environment:
		_world_env.environment.fog_enabled = false
		_world_env.environment.volumetric_fog_enabled = false
		_world_env.environment.volumetric_fog_density = 0.0
	if _fog and _fog.has_method("setup"):
		_fog.setup(_world_env)
