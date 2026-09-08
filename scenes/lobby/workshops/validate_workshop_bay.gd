extends SceneTree
## Run: godot --headless --path . --script scenes/lobby/workshops/validate_workshop_bay.gd

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_validate")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _validate() -> void:
	var scene: PackedScene = load("res://scenes/lobby/workshops/workshop_bay.tscn") as PackedScene
	if scene == null:
		push_error("Workshop scene could not load")
		quit(1)
		return
	var bay: Node3D = scene.instantiate() as Node3D
	root.add_child(bay)
	for selected: String in ["weapons", "armor", "utility", "outfit", "deploy"]:
		bay.set("purpose", selected)
		bay.call("build")
		var visual: Node3D = bay.get_node("Visual") as Node3D
		var collision: StaticBody3D = bay.get_node("Collision") as StaticBody3D
		var visual_count: int = visual.get_child_count()
		var collision_count: int = collision.get_child_count()
		_check(visual_count > 30, selected + ": missing authored visuals")
		_check(collision_count > 5, selected + ": missing equipment proxies")
		_check((bay.get_node("InteractionAnchor") as Marker3D).position == Vector3(0.0, 0.0, 1.5), "Interaction anchor changed")
		_check(bay.get_node_or_null("InspectionAnchor") is Marker3D, "Inspection anchor missing")
		for child: Node in visual.get_children():
			_check(child.owner == bay, selected + ": missing visual owner")
			if child is MeshInstance3D:
				var mesh_instance: MeshInstance3D = child as MeshInstance3D
				var bounds: AABB = mesh_instance.transform * mesh_instance.get_aabb()
				_check(bounds.position.x >= -5.0 and bounds.end.x <= 5.0, selected + ": visual outside bay width: " + str(child.name))
				_check(bounds.position.z >= -4.0 and bounds.end.z <= 4.0, selected + ": visual outside bay depth: " + str(child.name))
		for child: Node in collision.get_children():
			_check(child is CollisionShape3D, selected + ": unexpected collider type")
			_check(child.owner == bay, selected + ": missing proxy owner")
			if child is CollisionShape3D:
				_check((child as CollisionShape3D).shape is BoxShape3D, selected + ": non-simple proxy")
		bay.call("build")
		_check(visual.get_child_count() == visual_count, selected + ": rebuild duplicates visuals")
		_check(collision.get_child_count() == collision_count, selected + ": rebuild duplicates proxies")
		var packed: PackedScene = PackedScene.new()
		_check(packed.pack(bay) == OK, selected + ": generated ownership cannot pack")
		var restored: Node3D = packed.instantiate() as Node3D
		root.add_child(restored)
		_check(restored.get_node("Visual").get_child_count() == visual_count, selected + ": packed scene duplicates visuals")
		_check(restored.get_node("Collision").get_child_count() == collision_count, selected + ": packed scene duplicates proxies")
		restored.free()
		print("PASS ", selected, ": ", visual_count, " visual nodes / ", collision_count, " box proxies; rebuild + packed round-trip")
	bay.set("purpose", "invalid")
	bay.call("build")
	_check(bay.get_node_or_null("Visual/WeaponsWorktopCore") != null, "Invalid purpose fallback failed")
	bay.set("purpose", "armor")
	await process_frame
	await process_frame
	_check(bay.get_node_or_null("Visual/ChestPlateUpper") != null, "Deferred purpose rebuild failed")
	bay.free()
	print("Workshop validation failures: ", _failures)
	quit(0 if _failures == 0 else 1)
