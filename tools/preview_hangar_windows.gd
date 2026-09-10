extends SceneTree

## Isolated inspection: does not change the player's camera, UI or spawn.
var camera: Camera3D
var lobby: Node3D

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	lobby = load("res://scenes/lobby/lobby.tscn").instantiate()
	root.add_child(lobby)
	var player := lobby.get_node_or_null("Player")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.far = 250.0
	root.add_child(camera)
	camera.make_current()
	await physics_frame
	_validate_windows()
	var views := [
		["east", Vector3(-5, 3.5, 10), Vector3(16.5, 11.5, 0)],
		["west", Vector3(5, 4.0, -6), Vector3(-16.5, 11.5, 4)],
		["catwalk", Vector3(12.0, 9.5, 5), Vector3(110, 65, -32)],
		["rear", Vector3(0, 5.5, -2), Vector3(0, 11.5, -22.8)],
		["gate", Vector3(0, 8.5, -8), Vector3(0, 12.0, -22.8)],
	]
	for view: Array in views:
		camera.position = view[1]
		camera.look_at(view[2])
		for frame: int in range(45):
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "user://hangar_windows_%s.png" % view[0]
		root.get_texture().get_image().save_png(path)
		print("CAPTURE: ", ProjectSettings.globalize_path(path))
	quit()

func _validate_windows() -> void:
	var panes := 0
	for child: Node in lobby.get_node("Architecture").get_children():
		if child is MeshInstance3D and "PressureGlass" in str(child.name):
			panes += 1
	assert(panes == 7, "Expected six side panes plus one rear pane")
	for side: float in [-1.0, 1.0]:
		for z: float in [-7.0, 3.0, 13.0]:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(side * 15, 11.9, z + 1), Vector3(side * 18, 11.9, z + 1))
			var hit := lobby.get_world_3d().direct_space_state.intersect_ray(ray)
			assert(not hit.is_empty(), "Pressure glass must retain collision")
			assert(absf(absf(hit.position.x) - 16.46) < 0.02, "Opening still contains an opaque wall collider")
	var rear := PhysicsRayQueryParameters3D.create(Vector3(2.5, 11.5, -20), Vector3(2.5, 11.5, -24))
	var rear_hit := lobby.get_world_3d().direct_space_state.intersect_ray(rear)
	assert(not rear_hit.is_empty(), "Rear pressure glass must retain collision")
	assert(absf(rear_hit.position.z - (-22.8)) < 0.12, "Rear opening still contains an opaque wall collider")
	print("WINDOW_CHECK: seven glazed openings, collisions correct")
