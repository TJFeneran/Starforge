extends SceneTree

## Repeatable 1080p render/collision smoke review, without touching the active main scene.
## godot --path . --script tools/review_lobby.gd -- --baseline
## Outputs review images to /tmp/starforge-lobby-review (not tracked game assets).
var _baseline := false
var _room: Node3D
var _camera: Camera3D
var _failed := false

func _initialize() -> void:
	_baseline = "--baseline" in OS.get_cmdline_user_args()
	_run.call_deferred()

func _run() -> void:
	var scene_path: String = "res://scenes/lobby/lobby_legacy.tscn" if _baseline else "res://scenes/lobby/lobby.tscn"
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("Cannot load review scene: " + scene_path)
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	_room = packed.instantiate()
	root.add_child(_room)
	await process_frame
	var player: Node3D = _room.get_node("Player")
	player.set_process_input(false)
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_camera = Camera3D.new()
	_camera.fov = 55.0
	root.add_child(_camera)
	_camera.current = true
	var prefix: String = "baseline" if _baseline else "redesign"
	var output_dir := "/tmp/starforge-lobby-review"
	DirAccess.make_dir_recursive_absolute(output_dir)
	var views: Array[Dictionary] = [
		{"name": "entrance", "at": Vector3(0, 2.8, 15.2), "target": Vector3(0, 2.1, -1)},
		{"name": "forge", "at": Vector3(6.5, 3.0, 7.5), "target": Vector3(0, 2.0, 0)},
		{"name": "weapons", "at": Vector3(9.2, 2.6, -3.4), "target": Vector3(17.3, 1.5, -6)},
		{"name": "overview", "at": Vector3(0, 8.1, 15.3), "target": Vector3(0, 1.0, -1)}
	]
	for view: Dictionary in views:
		_camera.position = view.at
		_camera.look_at(view.target)
		for frame: int in range(40):
			await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var image_path: String = output_dir + "/" + prefix + "_" + str(view.name) + ".png"
			var error: Error = image.save_png(image_path)
			print("REVIEW_IMAGE ", image_path, " status=", error)
	_camera.position = views[0].at
	_camera.look_at(views[0].target)
	var frames_ms: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for frame: int in range(180):
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames_ms.append(float(now - previous) / 1000.0)
		previous = now
	frames_ms.sort()
	print("REVIEW_PERF ", prefix, " median_ms=", frames_ms[90], " p95_ms=", frames_ms[171],
		" draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if not _baseline:
		await physics_frame
		_check_routes()
		_check_camera_clearance()
		_check_monument_clearance()
		var reactor: Node = _room.get_node("CentralForge")
		if reactor.has_method("set_reduced_effects"):
			reactor.call("set_reduced_effects", true)
			for frame: int in range(30):
				await process_frame
			print("REVIEW_REDUCED_EFFECTS OK")
	quit(1 if _failed else 0)

func _check_routes() -> void:
	var space: PhysicsDirectSpaceState3D = _room.get_world_3d().direct_space_state
	var segments: Array = [
		[Vector3(0, 1, 10), Vector3(7, 1, 5)],
		[Vector3(7, 1, 5), Vector3(7, 1, -8)],
		[Vector3(7, 1, -8), Vector3(0, 1, -10)],
		[Vector3(0, 1, -10), Vector3(0, 1, -16)],
		[Vector3(-7, 1, 5), Vector3(-7, 1, -8)],
		[Vector3(8, 1, -6), Vector3(15, 1, -6)],
		[Vector3(8, 1, 6), Vector3(15, 1, 6)],
		[Vector3(-8, 1, -6), Vector3(-15, 1, -6)],
		[Vector3(-8, 1, 6), Vector3(-15, 1, 6)]
	]
	for segment: Array in segments:
		var query := PhysicsRayQueryParameters3D.create(segment[0], segment[1], 1)
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			_failed = true
			push_error("REVIEW_ROUTE blocked " + str(segment) + " by " + str(hit.collider.get_path()))
		else:
			print("REVIEW_ROUTE clear ", segment)
		# Sweep the real player-sized capsule, not only a zero-width ray.
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.32
		capsule.height = 1.8
		var sweep := PhysicsShapeQueryParameters3D.new()
		sweep.shape = capsule
		sweep.collision_mask = 1
		sweep.transform.origin = segment[0]
		sweep.motion = segment[1] - segment[0]
		var travel: PackedFloat32Array = space.cast_motion(sweep)
		if travel[0] < 0.999:
			_failed = true
			push_error("REVIEW_CAPSULE blocked " + str(segment) + " fraction=" + str(travel[0]))
		else:
			print("REVIEW_CAPSULE clear ", segment)

func _check_monument_clearance() -> void:
	var monument: Node3D = _room.get_node("ForgeMonumentPortal/Monument")
	var bounds := AABB()
	var started := false
	for child: Node in monument.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(box) if started else box
		started = true
	print("REVIEW_MONUMENT bounds=", bounds)
	for child: Node in _room.get_node("Architecture").get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			# Floor contact at y=0 is intentional; compare all overhead/shell geometry.
			if box.position.y > 0.5 and bounds.intersects(box):
				_failed = true
				push_error("REVIEW_MONUMENT intersects architecture: " + str(child.name))
	if bounds.end.y > 15.8 or bounds.position.z < -23.7:
		_failed = true
		push_error("REVIEW_MONUMENT exceeds transit vault envelope")

func _check_camera_clearance() -> void:
	var space: PhysicsDirectSpaceState3D = _room.get_world_3d().direct_space_state
	for center: Vector3 in [Vector3(0, 1.55, 10), Vector3(7, 1.55, 5), Vector3(-7, 1.55, 5)]:
		var blocked := 0
		for index: int in range(16):
			var angle: float = TAU * float(index) / 16.0
			var end := center + Vector3(sin(angle), 0, cos(angle)) * 5.55
			end.y = 2.75
			var query := PhysicsRayQueryParameters3D.create(center, end, 1)
			if not space.intersect_ray(query).is_empty():
				blocked += 1
		print("REVIEW_CAMERA orbit ", center, " obstructions=", blocked, "/16 (spring arm retracts at walls)")
	# Each bay's work position must have a clear retreat toward the hall.
	for name: String in ["WorkbenchWeapons", "WorkbenchUtility", "WorkbenchArmor", "WorkbenchOutfit"]:
		var bay: Node3D = _room.get_node("Workshops/" + name)
		var from: Vector3 = bay.to_global(Vector3(0, 1.55, 1.5))
		var to: Vector3 = bay.to_global(Vector3(0, 2.75, 7.05))
		var query := PhysicsRayQueryParameters3D.create(from, to, 1)
		if not space.intersect_ray(query).is_empty():
			_failed = true
			push_error("REVIEW_CAMERA blocked bay retreat: " + name)
		else:
			print("REVIEW_CAMERA clear bay retreat: ", name)
