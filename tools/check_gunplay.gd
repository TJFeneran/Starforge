extends SceneTree

## Run with: godot --headless --path . --script tools/check_gunplay.gd
## Exercises live physics hits and the bounded weapon traits.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(42)
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var mount := (load("res://scenes/combat/gun_mount.tscn") as PackedScene).instantiate() as GunMount
	mount.position = Vector3(0, 1.2, 0)
	arena.add_child(mount)
	var target_scene := load("res://scenes/combat/rift_skitter.tscn") as PackedScene
	var targets: Array[Node3D] = []
	for z in [-5.0, -8.0]:
		var target := target_scene.instantiate() as Node3D
		target.get_node("Health").max_hp = 1000.0
		target.position = Vector3(0, 0, z)
		arena.add_child(target)
		targets.append(target)
	await create_timer(0.1).timeout
	var origin := Vector3(0, 0.8, 0)
	for i in range(9):
		mount.equip(i)
		for target in targets:
			target.get_node("Health").heal_full()
		mount.process_trigger(0.016, false, true, origin, Vector3.FORWARD)
		mount.process_trigger(0.016, true, true, origin, Vector3.FORWARD)
		await create_timer(0.8).timeout
		mount.process_trigger(0.016, false, true, origin, Vector3.FORWARD)
		var hp: float = targets[0].get_node("Health").hp
		if hp >= 1000.0:
			push_error("No hit from " + mount.definition.display_name)
			quit(1)
			return
		if i == 7 and targets[1].get_node("Health").hp >= 1000.0:
			push_error("Splitfin did not pierce the second target")
			quit(1)
			return
		print("HIT ", mount.definition.display_name, " damage=", 1000.0 - hp)

	# The precision multiplier uses the skitter's upper hit zone.
	mount.equip(3)
	targets[0].get_node("Health").heal_full()
	mount.call("_apply_hit", mount.definition, targets[0], Vector3(0, 1.05, -5), 5.0, 1.0)
	if absf(targets[0].get_node("Health").hp - 917.5) > 0.01:
		push_error("Vault Needle weak point multiplier failed")
		quit(1)
		return
	mount.equip(2)
	targets[0].get_node("Health").heal_full()
	mount.call("_apply_hit", mount.definition, targets[0], Vector3(0, 0.8, -5), 5.0, 1.0)
	mount.call("_emit_echo", mount.definition)
	if absf(targets[0].get_node("Health").hp - 966.0) > 0.01:
		push_error("Echo Bit repeat pulse failed")
		quit(1)
		return
	mount.equip(4)
	mount.reload()
	await create_timer(1.75).timeout
	targets[1].get_node("Health").heal_full()
	mount.call("_apply_hit", mount.definition, targets[1], Vector3(0, 0.8, -8), 8.0, 1.0)
	mount.call("_apply_hit", mount.definition, targets[1], Vector3(0, 0.8, -8), 8.0, 1.0)
	if absf(targets[1].get_node("Health").hp - 886.0) > 0.01:
		push_error("Dawnseal mark detonation failed")
		quit(1)
		return

	# Monument's direct hit damages a nearby second target once.
	mount.equip(8)
	targets[0].get_node("Health").heal_full()
	targets[1].get_node("Health").heal_full()
	targets[1].position = Vector3(1.5, 0, -5)
	mount.process_trigger(0.016, false, true, origin, Vector3.FORWARD)
	mount.process_trigger(0.016, true, true, origin, Vector3.FORWARD)
	await create_timer(0.8).timeout
	if targets[0].get_node("Health").hp > 880.01 or targets[1].get_node("Health").hp > 950.01:
		push_error("Monument direct hit or radial pulse failed")
		quit(1)
		return
	print("TRAITS weakpoint=82.5 echo=8 dawnseal_bonus=24 beam_pierce=15 monument_aoe=50")

	# Holding fire must repeat pulse, burst, solar, and charged shots at their
	# configured cadence without requiring another mouse press.
	for index in [0, 2, 4, 8]:
		mount.equip(index)
		mount.process_trigger(0.016, false, true, origin, Vector3.FORWARD)
		var ammo_before := int(mount.get("_ammo"))
		for frame in 96:
			mount.process_trigger(1.0 / 60.0, true, true, origin, Vector3.FORWARD)
			await physics_frame
		mount.process_trigger(0.016, false, true, origin, Vector3.FORWARD)
		var spent := ammo_before - int(mount.get("_ammo"))
		if spent < mount.definition.shots_per_trigger * 2:
			push_error("Held fire did not repeat for " + mount.definition.display_name)
			quit(1)
			return
		print("HOLD ", mount.definition.display_name, " rounds=", spent)

	# Longpath remains a kinetic semi-auto: holding one press fires one round.
	mount.equip(6)
	mount.process_trigger(0.016, false, true, origin, Vector3.FORWARD)
	var longpath_ammo := int(mount.get("_ammo"))
	for frame in 96:
		mount.process_trigger(1.0 / 60.0, true, true, origin, Vector3.FORWARD)
		await physics_frame
	mount.process_trigger(0.016, false, true, origin, Vector3.FORWARD)
	if longpath_ammo - int(mount.get("_ammo")) != 1:
		push_error("Longpath should remain semi-auto")
		quit(1)
		return
	quit(0)
