extends SceneTree

## Repeatable 1080p render/collision smoke review, without touching the active main scene.
## godot --path . --script tools/review_lobby.gd -- --catwalk (gallery views + stair traversal)
## Outputs review images to /tmp/starforge-lobby-review (not tracked game assets).
var _catwalk_only := false
var _room: Node3D
var _camera: Camera3D
var _failed := false

func _initialize() -> void:
	_catwalk_only = "--catwalk" in OS.get_cmdline_user_args()
	_run.call_deferred()

func _run() -> void:
	var scene_path := "res://scenes/lobby/lobby.tscn"
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
	var prefix := "lobby"
	var output_dir := "/tmp/starforge-lobby-review"
	DirAccess.make_dir_recursive_absolute(output_dir)
	var views: Array[Dictionary] = [
		{"name": "entrance", "at": Vector3(0, 2.8, 15.2), "target": Vector3(0, 2.1, -1)},
		{"name": "forge", "at": Vector3(6.5, 3.0, 7.5), "target": Vector3(0, 2.0, 0)},
		{"name": "weapons", "at": Vector3(9.2, 2.6, -3.4), "target": Vector3(17.3, 1.5, -6)},
		{"name": "overview", "at": Vector3(0, 8.1, 15.3), "target": Vector3(0, 1.0, -1)}
	]
	if _catwalk_only:
		prefix = "catwalk"
		views = [
			{"name": "hall", "at": Vector3(0, 4.2, 13.8), "target": Vector3(0, 7.5, -10)},
			{"name": "gallery", "at": Vector3(-13.3, 9.5, 12.5), "target": Vector3(4, 8, -21)},
			{"name": "rear_stairs", "at": Vector3(11, 3.0, -15), "target": Vector3(18, 4, -25)},
			{"name": "stairwell", "at": Vector3(19.1, 2, -24.7), "target": Vector3(18, 5.3, -32.8)},
			{"name": "behind_gate", "at": Vector3(13, 9.5, -21.6), "target": Vector3(-10, 8.6, -21.6)}
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
	await physics_frame
	if _catwalk_only:
		await _check_catwalk_routes()
	else:
		_check_routes()
	_check_camera_clearance()
	_check_monument_clearance()
	_check_hall_lighting()
	var reactor: Node = _room.get_node("CentralForge")
	if reactor.has_method("set_reduced_effects"):
		reactor.call("set_reduced_effects", true)
		for frame: int in range(30):
			await process_frame
		print("REVIEW_REDUCED_EFFECTS OK")
	quit(1 if _failed else 0)

func _check_hall_lighting() -> void:
	var group := _room.get_node("HallLighting")
	var fixtures := group.get_children()
	var valid := fixtures.size() == 31
	for fixture: Node in fixtures:
		valid = valid and not str(fixture.name).contains("@") and fixture.is_in_group("hall_lights")
		valid = valid and fixture.has_node("TaskLight") and fixture.has_node("Mount")
	var fixture := fixtures[0]
	var neighbor := fixtures[1]
	var light := fixture.get_node("TaskLight") as SpotLight3D
	var neighbor_light := neighbor.get_node("TaskLight") as SpotLight3D
	var original_energy: float = fixture.get("energy")
	var original_color: Color = fixture.get("light_color")
	var original_multiplier: float = group.get("energy_multiplier")
	var original_tint: Color = group.get("color_tint")
	group.set("energy_multiplier", 0.5)
	fixture.set("energy", 4.0)
	valid = valid and is_equal_approx(light.light_energy, 2.0)
	valid = valid and is_equal_approx(neighbor_light.light_energy, float(neighbor.get("energy")) * 0.5)
	fixture.set("light_color", Color(1, 0.5, 0.25))
	group.set("color_tint", Color(0.5, 1, 1))
	valid = valid and light.light_color.is_equal_approx(Color(0.5, 0.5, 0.25))
	group.set("lights_enabled", false)
	valid = valid and not light.visible and not neighbor_light.visible
	group.set("lights_enabled", true)
	fixture.set("energy", original_energy)
	fixture.set("light_color", original_color)
	group.set("energy_multiplier", original_multiplier)
	group.set("color_tint", original_tint)
	if not valid:
		_failed = true
		push_error("REVIEW_LIGHTING saved fixture or live control check failed")
	else:
		print("REVIEW_LIGHTING 31 named saved fixtures; individual and group controls OK")


func _check_catwalk_routes() -> void:
	var loop: Array[Vector3] = [
		Vector3(-13.3, 7.8, -21.6), Vector3(-13.3, 7.8, 16.2),
		Vector3(13.3, 7.8, 16.2), Vector3(13.3, 7.8, -21.6),
		Vector3(-13.3, 7.8, -21.6)
	]
	for index: int in range(loop.size() - 1):
		_check_walk_segment(loop[index], loop[index + 1])
	for side: float in [-1.0, 1.0]:
		var route: Array[Vector3] = [
			Vector3(side * 19.1, 0, -21.6), Vector3(side * 19.1, 0, -24.3),
			Vector3(side * 19.1, 3.9, -30.9), Vector3(side * 19.1, 3.9, -32.0),
			Vector3(side * 15.9, 3.9, -32.0), Vector3(side * 15.9, 3.9, -30.9),
			Vector3(side * 15.9, 7.8, -24.3), Vector3(side * 15.9, 7.8, -21.6),
			Vector3(side * 13.3, 7.8, -21.6)
		]
		for index: int in range(route.size() - 1):
			_check_walk_segment(route[index], route[index + 1])
		await _walk_stair_route(route)
		var reverse_route: Array[Vector3] = route.duplicate()
		reverse_route.reverse()
		await _walk_stair_route(reverse_route)
	print("REVIEW_CATWALK complete")


func _check_walk_segment(start: Vector3, end: Vector3) -> void:
	var space := _room.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var sweep := PhysicsShapeQueryParameters3D.new()
	sweep.shape = capsule
	sweep.collision_mask = 1
	# Raise slightly above the walk surface, including the slope-contact capsule offset.
	sweep.transform.origin = start + Vector3(0, 1.12, 0)
	sweep.motion = end - start
	var travel := space.cast_motion(sweep)
	if travel[0] < 0.999:
		_failed = true
		push_error("REVIEW_CATWALK blocked " + str(start) + " -> " + str(end))
	var count := maxi(1, ceili(start.distance_to(end) / 0.4))
	for index: int in range(count + 1):
		var at := start.lerp(end, float(index) / float(count))
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.35, 0), at - Vector3(0, 0.35, 0), 1)
		if space.intersect_ray(ray).is_empty():
			_failed = true
			push_error("REVIEW_CATWALK missing floor at " + str(at))
			break


func _walk_stair_route(route: Array[Vector3]) -> void:
	# Exercise actual move_and_slide with the same capsule/speeds as the player.
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	body.floor_snap_length = 0.1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.9
	body.add_child(collision)
	_room.add_child(body)
	body.position = route[0] + Vector3(0, 0.03, 0)
	for target: Vector3 in route.slice(1):
		var arrived := false
		for frame: int in range(500):
			await physics_frame
			var delta := body.get_physics_process_delta_time()
			var heading := Vector3(target.x - body.position.x, 0, target.z - body.position.z)
			if heading.length() < 0.09:
				arrived = true
				break
			heading = heading.normalized()
			body.velocity.x = heading.x * 5.4
			body.velocity.z = heading.z * 5.4
			body.velocity.y -= 9.8 * delta
			body.move_and_slide()
		if not arrived or absf(body.position.y - target.y) > 0.3:
			_failed = true
			push_error("REVIEW_STAIRS failed near " + str(body.position) + " target=" + str(target))
			body.queue_free()
			return
	body.queue_free()
	print("REVIEW_STAIRS traversed ", route[0], " -> ", route[-1])


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
