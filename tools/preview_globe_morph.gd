extends SceneTree

var camera: Camera3D
var frames := 0

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	var lobby: Node3D = load("res://scenes/lobby/lobby.tscn").instantiate()
	root.add_child(lobby)
	var player := lobby.get_node_or_null("Player")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	camera.fov = 35.0
	camera.far = 80.0
	root.add_child(camera)
	camera.make_current()
	var globe := lobby.find_child("Globe", true, false) as Node3D
	var target := globe.global_position if globe else Vector3(0.0, 1.15, 2.9)
	camera.position = target + Vector3(0.55, 0.2, 0.95)
	camera.look_at(target)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 120:
		_capture.call_deferred()
	return false

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var path := "user://globe_morph_preview.png"
	root.get_texture().get_image().save_png(path)
	print("CAPTURE: ", ProjectSettings.globalize_path(path))
	# Advance a bit more so orbit motion is obvious in a second frame.
	for _i in range(90):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://globe_orbit_later.png")
	print("CAPTURE: ", ProjectSettings.globalize_path("user://globe_orbit_later.png"))
	quit()
