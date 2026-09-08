extends Node3D

## Weapon visual root. Bone-attached at runtime; muzzle marks bolt spawn.

@onready var _muzzle: Marker3D = $Muzzle


func get_muzzle_global() -> Vector3:
	return _muzzle.global_position
