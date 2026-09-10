extends SceneTree
## Quick smoke test for globe → map framework.
## godot --headless --path . --script tools/validate_hologram_map.gd

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_failures += 1
		push_error(msg)


func _run() -> void:
	var prompt := root.get_node_or_null("InteractPrompt")
	_check(prompt != null, "InteractPrompt autoload missing")

	var lobby_ps := load("res://scenes/lobby/lobby.tscn") as PackedScene
	_check(lobby_ps != null, "lobby.tscn failed to load")
	if lobby_ps == null:
		quit(1)
		return

	var lobby := lobby_ps.instantiate()
	root.add_child(lobby)
	await process_frame
	await process_frame

	var interact := lobby.get_node_or_null("CentralForge/Navigation/MapInteract")
	_check(interact != null, "MapInteract missing under Navigation")
	_check(interact is ProximityInteractable, "MapInteract must be ProximityInteractable")
	_check(str(interact.get("action_text")) == "Open Map", "Globe prompt should say Open Map")

	var map := lobby.get_node_or_null("HologramMap")
	_check(map != null and map.has_method("open_map"), "HologramMap missing")

	if map and prompt:
		map.open_map()
		_check(map.is_open(), "Map should open")
		_check(prompt.is_modal_blocking(), "Modal should block prompts while map open")
		_check(paused, "Map open should pause tree")
		map.close_map()
		_check(not map.is_open(), "Map should close")
		_check(not prompt.is_modal_blocking(), "Modal should clear on close")
		_check(not paused, "Tree should unpause on close")

	lobby.queue_free()
	await process_frame
	print("HOLOGRAM MAP VALIDATION: ", "PASS" if _failures == 0 else "FAIL", " (", _failures, " failures)")
	quit(0 if _failures == 0 else 1)
