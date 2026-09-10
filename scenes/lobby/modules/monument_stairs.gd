@tool
extends StaticBody3D

## Low-cost solid gate envelope with a central stair/landing cutout.
## Coordinates are in ForgeMonumentPortal space: +Z faces the hall.
## No triangle-mesh physics is generated from the 600k visual asset.

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	if has_node("Approach"):
		return
	# Measured visual tread: z=4.95 at floor, z=2.70 at y=0.77.
	# A convex ramp is smooth for CharacterBody3D, without individual stair snags.
	_add_prism("Approach", PackedVector3Array([
		Vector3(-1.3, 0.0, 4.98), Vector3(1.3, 0.0, 4.98),
		Vector3(-1.3, 0.0, 2.7), Vector3(1.3, 0.0, 2.7),
		Vector3(-1.3, 0.77, 2.7), Vector3(1.3, 0.77, 2.7),
		Vector3(-1.3, 0.04, 4.98), Vector3(1.3, 0.04, 4.98),
	]))
	# One metre of usable landing immediately in front of the gate face.
	_add_box("Landing", Vector3(2.6, 0.77, 1.0), Vector3(0, 0.385, 2.2))
	# Solid rear/face stops walking through the monument from the landing.
	_add_box("GateFaceAndRear", Vector3(2.6, 13.6, 7.13), Vector3(0, 6.8, -1.865))
	# Polygon follows the stepped outer footprint, rather than a large box
	# projecting invisible walls across the space beside the stairs.
	var footprint := PackedVector2Array([
		Vector2(1.3, 5.44), Vector2(2.45, 5.44),
		Vector2(3.65, 3.47), Vector2(4.05, 2.60),
		Vector2(6.93, 2.60), Vector2(6.93, -2.60),
		Vector2(4.05, -2.60), Vector2(3.65, -3.47),
		Vector2(2.45, -5.44), Vector2(1.3, -5.44),
	])
	# Split into convex strips: preserves the concave shoulders of the base.
	for side in [-1.0, 1.0]:
		var prefix := "Left" if side < 0 else "Right"
		_add_footprint(prefix + "Inner", PackedVector2Array([
			footprint[0], footprint[1], footprint[8], footprint[9]]), side)
		_add_footprint(prefix + "Shoulder", PackedVector2Array([
			footprint[1], footprint[2], footprint[3], footprint[6], footprint[7], footprint[8]]), side)
		_add_footprint(prefix + "Outer", PackedVector2Array([
			footprint[3], footprint[4], footprint[5], footprint[6]]), side)

func _add_footprint(label: String, polygon: PackedVector2Array, side: float) -> void:
	var points := PackedVector3Array()
	for point in polygon:
		points.append(Vector3(point.x * side, 0, point.y))
		points.append(Vector3(point.x * side, 13.6, point.y))
	_add_prism(label, points)

func _add_prism(label: String, points: PackedVector3Array) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	add_child(collision)

func _add_box(label: String, size: Vector3, at: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	add_child(collision)
