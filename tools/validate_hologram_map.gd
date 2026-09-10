extends SceneTree
## Smoke test for globe → map → armed gate → embark.
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
	_check(interact != null and is_equal_approx(float(interact.get("hold_duration")), 0.5), "Interact should default to a half-second hold")

	if prompt and interact:
		prompt.request(interact, "Open Map", "E", interact, interact.prompt_offset)
		_check(prompt.get_node("Root").visible, "Prompt should show after request")
		_check(prompt.get_node("Root/PromptRow/ActionBackdrop") != null, "Action text needs an unoutlined backdrop")
		_check(prompt.has_method("set_hold_progress"), "Prompt should expose hold progress")
		prompt.set_hold_progress(0.5)
		_check(is_equal_approx(prompt.get_hold_progress(), 0.5), "Hold progress should stick")
		prompt.set_hold_progress(0.0)
		prompt.release(interact)
		_check(not prompt.get_node("Root").visible, "Prompt should hide after release")

	var embark := lobby.get_node_or_null("ForgeMonumentPortal/EmbarkInteract") as ProximityInteractable
	_check(embark != null, "EmbarkInteract missing under ForgeMonumentPortal")
	_check(embark != null and not embark.enabled, "Embark should stay disabled until a destination is marked")

	var gem := lobby.get_node_or_null("ForgeMonumentPortal/GemVFX")
	_check(gem != null and gem.has_method("is_armed"), "GemVFX should expose armed state")
	_check(gem != null and not gem.is_armed(), "Gate should start dormant")

	var portal := lobby.get_node_or_null("ForgeMonumentPortal/PortalVFX")
	_check(portal != null and portal.has_method("is_armed"), "PortalVFX should expose armed state")
	_check(portal != null and not portal.is_armed(), "Aperture should start dormant")
	_check(portal != null and not portal.get_node("EnergyAperture").visible, "Dormant aperture should be hidden")

	var map := lobby.get_node_or_null("HologramMap")
	_check(map != null and map.has_method("open_map"), "HologramMap missing")

	if map and prompt:
		map.open_map()
		_check(map.is_open(), "Map should open")
		_check(prompt.is_modal_blocking(), "Modal should block prompts while map open")
		_check(paused, "Map open should pause tree")

		var dest := MapDestination.new()
		dest.id = "frontier_outpost"
		dest.title = "Frontier Outpost"
		dest.available = true
		dest.scene_path = "res://scenes/playable/outpost_slice.tscn"
		map.destination_selected.emit(dest)
		await process_frame

		_check(not map.is_open(), "Selecting a destination should close the map")
		_check(not paused, "Tree should unpause after destination select")
		_check(embark != null and embark.enabled, "Embark should enable after destination select")
		_check(embark != null and str(embark.action_text).begins_with("Embark"), "Embark prompt should be labeled")
		_check(gem != null and gem.is_armed(), "Gate VFX should arm after destination select")
		_check(ResourceLoader.exists(dest.scene_path), "Marked mission scene must exist")
		_check(portal != null and portal.is_armed(), "Destination selection should ignite the aperture")
		_check(portal.get_node("EnergyAperture").visible, "Igniting aperture should be visible")
		await create_timer(1.6).timeout
		_check(is_equal_approx(portal.get_activation(), 1.0), "Ignition should settle into a fully active portal")
		_check(portal.get_node("RimEmbers").emitting, "Armed portal should keep emitting rim sparks")
		portal.set_armed(true)
		_check(is_equal_approx(portal.get_activation(), 1.0), "Repeated selection should not restart a settled portal")
		map.open_map()
		map.close_map()
		_check(portal.is_armed(), "Closing map without a selection should preserve the active gate")
		portal.set_armed(false)
		await create_timer(0.5).timeout
		_check(is_zero_approx(portal.get_activation()), "Disarming should fade out the aperture")
		_check(not portal.get_node("EnergyAperture").visible, "Disarmed aperture should be hidden")
		portal.set_armed(true)
		await create_timer(0.2).timeout
		portal.set_armed(false)
		portal.set_armed(true)
		await create_timer(1.6).timeout
		_check(is_equal_approx(portal.get_activation(), 1.0), "Interrupted ignition should recover without a stale fade tween")

	lobby.queue_free()
	await process_frame
	print("HOLOGRAM MAP VALIDATION: ", "PASS" if _failures == 0 else "FAIL", " (", _failures, " failures)")
	quit(0 if _failures == 0 else 1)
