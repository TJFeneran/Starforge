extends Node3D

## Lightweight proxy colliders for Meshy props.
## Full AABBs block walk-under canopies and inflate doorways — use shaped proxies.

@export var doorway_prefix := "Doorway"
@export var canopy_prefix := "Canopy"
@export var barrier_prefix := "Barrier"


func _ready() -> void:
	for child in get_children():
		if _should_skip(child):
			continue
		if child is MeshInstance3D:
			continue
		var n := str(child.name)
		if n.begins_with(doorway_prefix):
			_add_door_frame(child)
		elif n.begins_with(canopy_prefix):
			_add_canopy_frame(child)
		elif n.begins_with(barrier_prefix):
			_add_barrier_post(child)
		elif child is Node3D:
			_add_boxes_under(child)


func _should_skip(node: Node) -> bool:
	var n := str(node.name)
	return (
		n.begins_with("Plant")
		or n.begins_with("Vegetation")
		or n.begins_with("BeaconInteract")
		or n.begins_with("MonumentZone")
		or n.begins_with("CanopyZone")
		or n == "MonumentLight"
		or n == "BeaconLight"
	)


func _add_boxes_under(root: Node) -> void:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		if mesh.find_child("StaticBody3D", false, false) != null:
			continue
		_add_inset_aabb_box(mesh)


func _add_inset_aabb_box(mesh: MeshInstance3D) -> void:
	var aabb := mesh.get_aabb()
	if aabb.size.x < 0.05 or aabb.size.y < 0.05 or aabb.size.z < 0.05:
		return

	# Shrink horizontal footprint so oversized Meshy bounds don't seal paths.
	var size := aabb.size
	size.x *= 0.78
	size.z *= 0.78
	size.y = maxf(size.y * 0.95, 0.2)

	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	body.collision_layer = 1
	body.collision_mask = 0

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = aabb.get_center()

	body.add_child(shape)
	mesh.add_child(body)


func _add_door_frame(door_root: Node3D) -> void:
	if door_root.get_node_or_null("ProxyCollision") != null:
		return

	var aabb := _combined_aabb(door_root)
	if aabb.size == Vector3.ZERO:
		return

	var gap := clampf(aabb.size.x * 0.5, 1.15, 1.85)
	var pillar_w := maxf((aabb.size.x - gap) * 0.5, 0.18)
	var depth := clampf(aabb.size.z * 0.55, 0.28, 0.55)
	var height := aabb.size.y
	var center := aabb.get_center()
	var lintel_h := clampf(height * 0.16, 0.22, 0.45)

	var body := _make_body(door_root, "ProxyCollision")
	_add_box(
		body,
		Vector3(pillar_w, height, depth),
		Vector3(center.x - gap * 0.5 - pillar_w * 0.5, center.y, center.z)
	)
	_add_box(
		body,
		Vector3(pillar_w, height, depth),
		Vector3(center.x + gap * 0.5 + pillar_w * 0.5, center.y, center.z)
	)
	_add_box(
		body,
		Vector3(aabb.size.x * 0.92, lintel_h, depth),
		Vector3(center.x, center.y + height * 0.5 - lintel_h * 0.5, center.z)
	)


func _add_canopy_frame(canopy_root: Node3D) -> void:
	if canopy_root.get_node_or_null("ProxyCollision") != null:
		return

	var aabb := _combined_aabb(canopy_root)
	if aabb.size == Vector3.ZERO:
		return

	var center := aabb.get_center()
	var post_w := 0.22
	var post_h := maxf(aabb.size.y * 0.72, 1.4)
	var roof_h := 0.28
	var inset := 0.35
	var half_x := maxf(aabb.size.x * 0.5 - inset, 0.6)
	var half_z := maxf(aabb.size.z * 0.5 - inset, 0.6)
	var post_y := aabb.position.y + post_h * 0.5
	var roof_y := aabb.position.y + aabb.size.y - roof_h * 0.5

	var body := _make_body(canopy_root, "ProxyCollision")
	for pos in [
		Vector3(center.x - half_x, post_y, center.z - half_z),
		Vector3(center.x + half_x, post_y, center.z - half_z),
		Vector3(center.x - half_x, post_y, center.z + half_z),
		Vector3(center.x + half_x, post_y, center.z + half_z),
	]:
		_add_box(body, Vector3(post_w, post_h, post_w), pos)
	_add_box(
		body,
		Vector3(aabb.size.x * 0.9, roof_h, aabb.size.z * 0.9),
		Vector3(center.x, roof_y, center.z)
	)


func _add_barrier_post(barrier_root: Node3D) -> void:
	if barrier_root.get_node_or_null("ProxyCollision") != null:
		return

	var aabb := _combined_aabb(barrier_root)
	if aabb.size == Vector3.ZERO:
		return

	var center := aabb.get_center()
	var height := maxf(aabb.size.y * 0.9, 1.0)
	var body := _make_body(barrier_root, "ProxyCollision")
	_add_box(
		body,
		Vector3(0.35, height, 0.35),
		Vector3(center.x, aabb.position.y + height * 0.5, center.z)
	)


func _make_body(parent: Node3D, body_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	return body


func _add_box(body: StaticBody3D, size: Vector3, local_pos: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = local_pos
	body.add_child(shape)


func _combined_aabb(root: Node) -> AABB:
	var started := false
	var combined := AABB()
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var local_aabb: AABB = mesh.get_aabb()
		var xf: Transform3D = root.global_transform.affine_inverse() * mesh.global_transform
		var worldish: AABB = _xform_aabb(local_aabb, xf)
		if not started:
			combined = worldish
			started = true
		else:
			combined = combined.merge(worldish)
	return combined if started else AABB()


func _xform_aabb(aabb: AABB, xf: Transform3D) -> AABB:
	var corners: Array[Vector3] = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size,
	]
	var out := AABB(xf * corners[0], Vector3.ZERO)
	for i in range(1, corners.size()):
		out = out.expand(xf * corners[i])
	return out
