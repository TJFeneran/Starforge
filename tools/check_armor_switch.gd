extends SceneTree

func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var sandbox: Node = load("res://scenes/sandbox/gunplay_sandbox.tscn").instantiate()
	root.add_child(sandbox)
	await process_frame
	var player: Variant = sandbox.get_node("Player")
	var gun: GunMount = sandbox.get_node("Player/Visual/WeaponAnchor/GunMount")
	var original_gun := gun.selected_index
	for index in 9:
		player._select_number_key(index, true)
		assert(player.selected_armor_index == index, "Armor key %d did not equip" % (index + 1))
		assert(gun.selected_index == original_gun, "Armor key changed the gun")
		assert(player._skeleton != null and player._hand_bone_idx >= 0)
		assert(player._anim != null and player._anim.has_animation("loco/walk"))
	assert(sandbox.get_node("ShortcutHints/Panel/Label").text.contains("SOLAR HEART"))
	player._select_number_key(1, false)
	assert(gun.selected_index == 1, "Unshifted number did not select gun")
	assert(player.selected_armor_index == 8, "Gun key changed armor")
	print("Armor selection verified: 9 sets, animations, hand follow, and separate gun keys")
	quit()
