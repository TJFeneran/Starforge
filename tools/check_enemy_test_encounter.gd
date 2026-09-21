extends SceneTree
## Focused gate for the four new field models and their playable test actors.

var failures := 0
const REQUIRED_CLIPS := {
	"ShieldbackSkitter": ["idle", "run", "attack_anticipation", "attack", "attack_recovery", "hit", "death"],
	"NeedlecrestMarksman": ["idle", "walk", "attack_anticipation", "attack", "attack_recovery", "hit", "death"],
	"CrescentRiftRay": ["hover_idle", "fly_forward", "attack_anticipation", "attack", "attack_recovery", "hit", "death"],
	"SplitCrownBulwark": ["idle", "walk", "attack_anticipation", "attack", "attack_recovery", "hit", "death"],
}


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("ENEMY_ENCOUNTER_FAIL: " + message)


func _run() -> void:
	var field: Node3D = load("res://scenes/field/forge_field.tscn").instantiate()
	root.add_child(field)
	await process_frame
	var roster: Node = field.get_node_or_null("EnemyTestEncounter")
	_check(roster != null, "missing field roster")
	if roster:
		_check(roster.get_child_count() == 4, "expected four field enemies")
		for actor: Node in roster.get_children():
			_check(REQUIRED_CLIPS.has(str(actor.name)), "unexpected actor " + str(actor.name))
			var visual := actor.get_node_or_null("Visual")
			_check(visual != null and visual.get_child_count() == 1, str(actor.name) + " has no model")
			if visual:
				var player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
				_check(player != null, str(actor.name) + " has no AnimationPlayer")
				if player:
					var available: Dictionary = {}
					for clip: String in player.get_animation_list():
						available[clip.get_slice("/", clip.get_slice_count("/") - 1)] = clip
					for clip: String in REQUIRED_CLIPS.get(str(actor.name), []):
						_check(available.has(clip), str(actor.name) + " missing " + clip)
						if available.has(clip):
							_check(player.get_animation(available[clip]).get_track_count() > 0, str(actor.name) + " has static " + clip)
					var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
					_check(skeleton != null and skeleton.get_bone_count() > 0, str(actor.name) + " has no rig")
			var health := actor.get_node_or_null("Health") as Health
			_check(health != null, str(actor.name) + " has no Health")
			if health:
				var before := health.hp
				actor.apply_hit(1.0)
				_check(health.hp == before - 1.0, str(actor.name) + " cannot take gun damage")
		var field_player := field.get_node_or_null("Player") as CharacterBody3D
		var player_health: Health = null
		if field_player:
			player_health = field_player.get_node_or_null("Health") as Health
		_check(player_health != null, "field player has no Health")
		if field_player and player_health:
			field_player.global_position = Vector3(-16.0, 0.1, -14.7)
			var before_attack := player_health.hp
			await create_timer(2.0).timeout
			_check(player_health.hp < before_attack, "Skitter did not damage the player during its attack")
		for actor: Node in roster.get_children():
			var health := actor.get_node_or_null("Health") as Health
			if health:
				actor.apply_hit(9999.0)
				_check(health.is_dead and health.hp == 0.0, str(actor.name) + " cannot die")
	field.queue_free()
	await process_frame
	if failures == 0:
		print("ENEMY_ENCOUNTER_PASS: four animated enemies, gun damage, death, and Skitter attack in Frontier Outpost")
	quit(1 if failures else 0)
