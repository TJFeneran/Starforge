extends Node3D

## Weapon visual root. Bone-attached at runtime; muzzle marks bolt spawn.

@export var fire_streams: Array[AudioStream] = []
@export_range(-40.0, 6.0, 0.1) var fire_volume_db: float = -6.0

@onready var _muzzle: Marker3D = $Muzzle
@onready var _fire_sfx: AudioStreamPlayer3D = $FireSFX

var _fire_index := 0


func get_muzzle_global() -> Vector3:
	return _muzzle.global_position


func play_fire() -> void:
	if _fire_sfx == null or fire_streams.is_empty():
		return
	var stream: AudioStream = fire_streams[_fire_index % fire_streams.size()]
	_fire_index = (_fire_index + 1) % maxi(fire_streams.size(), 1)
	if stream == null:
		return
	_fire_sfx.stream = stream
	_fire_sfx.pitch_scale = randf_range(0.94, 1.06)
	_fire_sfx.volume_db = fire_volume_db + randf_range(-1.0, 1.0)
	_fire_sfx.play()
