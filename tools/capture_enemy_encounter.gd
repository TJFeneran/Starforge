extends SceneTree
## Render a reproducible screenshot of the first-level enemy test encounter.
## godot --path . --script tools/capture_enemy_encounter.gd -- --capture=/tmp/enemies.png --focus=all

var capture_path := "/tmp/enemy_encounter.png"
var focus := "all"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--focus="):
			focus = arg.trim_prefix("--focus=")
	call_deferred("_run")


func _run() -> void:
	var field := load("res://scenes/field/forge_field.tscn").instantiate() as Node3D
	root.add_child(field)
	await process_frame
	var roster := field.get_node_or_null("EnemyTestEncounter") as Node3D
	if roster == null:
		push_error("EnemyTestEncounter missing")
		quit(1)
		return
	var camera := Camera3D.new()
	camera.fov = 55.0
	field.add_child(camera)
	var target := Vector3(0, 1.0, -27)
	if focus != "all":
		var actor := roster.get_node_or_null(focus) as Node3D
		if actor == null:
			push_error("Unknown enemy focus: " + focus)
			quit(1)
			return
		target = actor.global_position + Vector3(0, 0.0 if actor.get("flying") else float(actor.get("height_m")) * 0.5, 0)
		camera.position = target + Vector3(4.5, 2.4, 5.4)
	else:
		camera.position = target + Vector3(0, 17, 33)
	camera.look_at(target)
	camera.make_current()
	for frame in range(12):
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 30.0)
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(capture_path)
	if error != OK:
		push_error("Could not save enemy encounter image: " + capture_path)
		quit(1)
		return
	print("ENEMY_ENCOUNTER_CAPTURE: ", capture_path, " actors=", roster.get_child_count())
	quit()
