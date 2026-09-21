extends SceneTree
## Isolated persistence and real player/menu integration; never touches user saves.
var failures := 0
var state: Node

func _initialize() -> void:
	call_deferred("_check")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _check() -> void:
	state = root.get_node("PlayerState")
	state.save_path = "/tmp/starforge-campaign-check-%d.json" % OS.get_process_id()
	check(not state.has_save(), "Fresh slot must disable Continue")
	var menu: Node = load("res://scenes/ui/welcome_screen.tscn").instantiate()
	root.add_child(menu)
	check(menu._continue.disabled, "Menu Continue enabled without save")
	menu._on_start()
	check(menu._selection.visible, "New Game must show starter choice")
	menu._close_selection()
	check(not state.save_exists(), "Cancel must not create a save")
	menu.queue_free()
	await process_frame
	for starter in ["base_suit", "dustcoat"]:
		check(state.start_new(starter), "Could not create starter save")
		check(state.data.unlocked == [starter], "New game grants only the chosen starter")
		check(not state.equip("solar_heart"), "Locked armor must not equip")
		var scene := Node3D.new()
		scene.scene_file_path = state.LOBBY
		root.add_child(scene)
		current_scene = scene
		var player: Node = load("res://scenes/player/player.tscn").instantiate()
		scene.add_child(player)
		await process_frame
		var health: Health = player.get_node("Health")
		check(player.selected_armor_index == (-1 if starter == "base_suit" else 0), "Starter model not applied")
		check(health.max_hp == 100.0, "Starter HP must be 100")
		player.equip_armor(8)
		check(player.selected_armor_index != 8, "Campaign shortcuts bypassed locks")
		health.apply_damage(40)
		check(state.checkpoint(state.FIELD), "Field checkpoint failed")
		check(state.recover_blueprint(), "Blueprint recovery failed")
		check(not state.recover_blueprint(), "Duplicate recovery allowed")
		state.data = {}
		state.active = false
		check(state.continue_game(), "Continue failed")
		check(state.data.pending_blueprint == "outpost_plate", "Pending blueprint lost on restart")
		check(state.return_to_forge(), "Extraction failed")
		check(state.data.unlocked.size() == 2, "Extraction must grant exactly one armor")
		check(state.return_to_forge() and state.data.unlocked.size() == 2, "Return duplicated a reward")
		check(state.equip("outpost_plate"), "Unlocked armor could not equip")
		check(health.max_hp == 125.0 and is_equal_approx(health.hp, 75.0), "Equip must update max HP and preserve health fraction")
		check(state.equip(starter), "Could not restore starter")
		check(is_equal_approx(health.hp, 60.0), "Armor swapping healed the player")
		check(player._hand_bone_idx >= 0 and player._anim.has_animation("loco/walk"), "Armor broke weapon or animation bindings")
		var ui := root.get_node("CampaignUI")
		ui.open_workshop()
		ui._selected = "solar_heart"
		ui._refresh_detail()
		check(ui._apply.disabled, "Locked workshop armor can be applied")
		ui.close_workshop()
		check(not paused and not root.get_node("InteractPrompt").is_modal_blocking(), "Workshop leaked modal state")
		check(state.checkpoint(state.FIELD) and state.recover_blueprint(), "Second recovery failed")
		check(state.respawn() and state.data.pending_blueprint == "", "Death retained unextracted reward")
		check(state.data.unlocked.size() == 2, "Death changed owned gear")
		var previous_hp := 125
		while not state.next_armor_id().is_empty():
			var id: String = state.next_armor_id()
			check(state.checkpoint(state.FIELD) and state.recover_blueprint() and state.return_to_forge(), "Progressive reward failed")
			check(state.equip(id), "Earned armor cannot equip")
			check(health.max_hp > previous_hp, "Armor HP must strictly increase")
			previous_hp = int(health.max_hp)
		check(health.max_hp == 300, "Final armor must have 300 HP")
		check(not state.recover_blueprint(), "Completed catalog awarded extra blueprint")
		check(state.continue_game() and state.data.equipped == "solar_heart", "Equipped armor not persisted")
		scene.queue_free()
		await process_frame
	# Invalid/future saves must never be applied.
	for malformed in ["{", "[]", '{"version":99}', '{"version":1,"starter":"dustcoat","checkpoint":"res://bad.tscn","unlocked":[]}']:
		var file := FileAccess.open(state.save_path, FileAccess.WRITE)
		file.store_string(malformed)
		file.close()
		check(not state.has_save(), "Invalid save accepted")
	check(state.start_new("dustcoat"), "New game could not replace invalid save")
	menu = load("res://scenes/ui/welcome_screen.tscn").instantiate()
	root.add_child(menu)
	check(not menu._continue.disabled, "Saved campaign must enable Continue")
	menu._on_start()
	menu._on_begin()
	check(menu._confirm.visible and state.data.starter == "dustcoat", "Existing save must await overwrite confirmation")
	menu._confirm.hide()
	menu._close_selection()
	menu.queue_free()
	await process_frame
	var before: Dictionary = state.data.duplicate(true)
	var valid_path: String = state.save_path
	state.save_path = "/tmp/starforge-missing-folder-%d/campaign.json" % OS.get_process_id()
	check(not state.start_new("base_suit") and state.data == before, "Failed save destroyed active progress")
	state.save_path = valid_path
	DirAccess.remove_absolute(valid_path)
	state.active = false
	print("Campaign checks: %d failures; starters, menu, locks, HP, all unlocks, save/reload, death, corrupt saves and write failure" % failures)
	quit(1 if failures else 0)
