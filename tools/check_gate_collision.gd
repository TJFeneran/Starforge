extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var body := StaticBody3D.new()
	body.set_script(load("res://scenes/lobby/modules/monument_stairs.gd"))
	root.add_child(body)
	await physics_frame
	await physics_frame
	var space := root.world_3d.direct_space_state
	var failures := 0
	for x in [-6.0, -3.0, 3.0, 6.0]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 1.5, 7), Vector3(x, 1.5, 0)))
		if hit.is_empty():
			failures += 1
			push_error("Missing outer collision at x=" + str(x))
	for z in [2.0, 2.5, 3.5, 4.5]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 2, z), Vector3(0, -1, z)))
		if hit.is_empty() or hit.position.y > 0.8:
			failures += 1
			push_error("Invalid stair/landing at z=" + str(z))
	var face := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1.5, 5.5), Vector3(0, 1.5, 0)))
	if face.is_empty() or absf(face.position.z - 1.7) > 0.05:
		failures += 1
		push_error("Gate face stop incorrect")
	print("GATE_COLLISION_CHECK failures=", failures)
	quit(failures)
