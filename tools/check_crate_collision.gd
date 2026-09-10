extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var lobby: Node = load("res://scenes/lobby/lobby.tscn").instantiate()
	root.add_child(lobby)
	await physics_frame
	await physics_frame
	var failures := 0
	for path: String in ["outpost_crate", "outpost_crate2"]:
		var crate: Node3D = lobby.get_node(path) as Node3D
		if crate == null or crate.get_node_or_null("Collision/Shape") == null:
			failures += 1
			push_error("Missing crate collision under " + path)
			continue
		var origin: Vector3 = crate.global_position + Vector3(0, 0.5, 0)
		var hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin + Vector3(0, 2, 0), origin + Vector3(0, -1, 0))
		)
		if hit.is_empty():
			failures += 1
			push_error("Crate collider not hittable at " + path)
	print("CRATE_COLLISION_CHECK failures=", failures)
	quit(failures)
