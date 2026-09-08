@tool
extends StaticBody3D

## Walkable collision for the monument approach. Visual mesh has no physics.
## Local +Z is the hall; the stair rises toward the gate at local Z ≈ 0.

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_strip_rails()
	if has_node("Approach"):
		return
	# Top surface from (z=5.3, y=0.04) to (z=0.6, y=0.86). +X rotation lowers +Z.
	_add_box("Approach", Vector3(2.6, 0.22, 4.8), Vector3(0.0, 0.34, 2.92), Vector3(10.0, 0.0, 0.0))
	_add_box("Landing", Vector3(2.6, 0.22, 2.0), Vector3(0.0, 0.86, -0.35), Vector3.ZERO)


func _strip_rails() -> void:
	for child in get_children():
		if str(child.name).ends_with("Rail"):
			child.queue_free()

func _add_box(label: String, size: Vector3, at: Vector3, degrees: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	collision.rotation_degrees = degrees
	add_child(collision)
