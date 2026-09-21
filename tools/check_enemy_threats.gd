extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("ENEMY_THREAT_FAIL: " + message)


func _wait_for_stage(actor: Node, stage: String, max_frames := 180) -> bool:
	for frame in max_frames:
		await physics_frame
		if actor.get("_attack_stage") == stage:
			return true
	return false


func _run() -> void:
	var field: Node3D = load("res://scenes/field/forge_field.tscn").instantiate()
	root.add_child(field)
	await process_frame
	var roster := field.get_node("EnemyTestEncounter")
	var player := field.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	var health := player.get_node("Health") as Health
	var actors := {}
	for actor in roster.get_children():
		actor.set_physics_process(false)
		actors[str(actor.name)] = actor

	var marksman: CharacterBody3D = actors["NeedlecrestMarksman"]
	player.global_position = marksman.global_position + Vector3(0, 0, 9)
	marksman.set_physics_process(true)
	_check(await _wait_for_stage(marksman, "anticipation"), "Marksman did not aim")
	_check(marksman.get("_warning") != null, "Marksman has no visible aim line")
	_check(await _wait_for_stage(marksman, "attack"), "Marksman did not fire")
	var before := health.hp
	await create_timer(0.9).timeout
	_check(health.hp < before, "Marksman projectile missed a stationary player")
	_check(await _wait_for_stage(marksman, "", 180), "Marksman did not finish its first attack")
	health.heal_full()
	player.global_position = marksman.global_position + Vector3(0, 0, 9)
	_check(await _wait_for_stage(marksman, "anticipation"), "Marksman did not re-aim")
	_check(await _wait_for_stage(marksman, "attack"), "Marksman did not fire again")
	player.global_position += Vector3(5, 0, 0)
	await create_timer(0.9).timeout
	_check(health.hp == health.max_hp, "Marksman shot could not be dodged after aim lock")
	marksman.set_physics_process(false)
	for node in roster.get_children():
		if node is EnemyProjectile:
			node.queue_free()
	await process_frame
	health.heal_full()

	var ray: CharacterBody3D = actors["CrescentRiftRay"]
	player.global_position = Vector3(ray.global_position.x, 0.1, ray.global_position.z + 8.0)
	ray.set_physics_process(true)
	_check(await _wait_for_stage(ray, "anticipation"), "Ray did not wind up")
	_check(ray.get("_warning") != null, "Ray has no visible attack line")
	_check(await _wait_for_stage(ray, "attack"), "Ray did not attack")
	before = health.hp
	await create_timer(0.9).timeout
	_check(health.hp < before, "Ray volley missed a stationary player")
	ray.set_physics_process(false)
	for node in roster.get_children():
		if node is EnemyProjectile:
			node.queue_free()
	await process_frame
	health.heal_full()

	var bulwark: CharacterBody3D = actors["SplitCrownBulwark"]
	player.global_position = bulwark.global_position + Vector3(0, 0, 2.7)
	bulwark.set_physics_process(true)
	_check(await _wait_for_stage(bulwark, "anticipation"), "Bulwark did not wind up")
	_check(bulwark.get("_warning") != null, "Bulwark has no marked slam area")
	_check(await _wait_for_stage(bulwark, "attack"), "Bulwark did not slam")
	before = health.hp
	await create_timer(0.8).timeout
	_check(health.hp < before, "Bulwark slam missed inside its area")
	_check(await _wait_for_stage(bulwark, "", 180), "Bulwark did not finish its slam")
	health.heal_full()
	player.global_position = bulwark.global_position + Vector3(0, 0, 2.7)
	_check(await _wait_for_stage(bulwark, "anticipation"), "Bulwark did not wind up again")
	player.global_position += Vector3(0, 0, 4.0)
	await create_timer(2.0).timeout
	_check(health.hp == health.max_hp, "Bulwark warning could not be escaped")
	bulwark.set_physics_process(false)
	health.heal_full()

	field.queue_free()
	await process_frame
	if failures == 0:
		print("ENEMY_THREATS_PASS: aimed shot, dodge, ray volley, slam warning and escape")
	quit(1 if failures else 0)
