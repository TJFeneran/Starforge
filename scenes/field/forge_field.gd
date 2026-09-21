extends Node3D
## Open field reached through the lobby gate. Scatters BinbunVFX loot effects
## around a forge monument; interacting at the monument returns to the lobby.

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"
const ENEMY_TEST_ACTOR := preload("res://scenes/combat/enemy_test_actor.tscn")
const ENEMY_TEST_ROSTER := [
	{"name": "Shieldback Skitter", "model": "res://assets/models/enemies/rift_skitter/skitter.glb", "at": Vector3(-16, 0, -16), "hp": 70.0, "height": 1.2, "radius": 0.55, "speed": 4.8, "damage": 11.0, "range": 1.5, "aggro": 17.0, "cooldown": 1.0, "contact_fraction": 0.380952, "move_clip": "run"},
	{"name": "Needlecrest Marksman", "model": "res://assets/models/enemies/rift_marksman/marksman.glb", "at": Vector3(13, 0, -19), "hp": 85.0, "height": 1.9, "radius": 0.42, "speed": 2.7, "damage": 13.0, "range": 15.0, "aggro": 20.0, "cooldown": 1.4, "contact_fraction": 0.222222, "move_clip": "walk"},
	{"name": "Crescent Rift Ray", "model": "res://assets/models/enemies/rift_ray/ray.glb", "at": Vector3(-14, 2, -34), "hp": 80.0, "height": 0.7, "radius": 0.48, "speed": 3.4, "damage": 10.0, "range": 12.0, "aggro": 18.0, "cooldown": 1.6, "contact_fraction": 0.333333, "flying": true, "idle_clip": "hover_idle", "move_clip": "fly_forward"},
	{"name": "Split Crown Bulwark", "model": "res://assets/models/enemies/forge_bulwark/bulwark.glb", "at": Vector3(20, 0, -38), "hp": 220.0, "height": 2.8, "radius": 0.7, "speed": 1.8, "damage": 22.0, "range": 2.5, "aggro": 16.0, "cooldown": 2.4, "contact_fraction": 0.5, "move_clip": "walk"},
]

const FLOATING_LOOT: Array[PackedScene] = [
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/floating/loot_vfx_common.tscn"),
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/floating/loot_vfx_uncommon.tscn"),
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/floating/loot_vfx_rare.tscn"),
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/floating/loot_vfx_epic.tscn"),
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/floating/loot_vfx_legendary.tscn"),
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/floating/loot_vfx_mythic.tscn"),
]
const GROUND_LOOT: Array[PackedScene] = [
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/ground/ground_loot_vfx_common.tscn"),
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/ground/ground_loot_vfx_uncommon.tscn"),
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/ground/ground_loot_vfx_rare.tscn"),
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/ground/ground_loot_vfx_epic.tscn"),
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/ground/ground_loot_vfx_legendary.tscn"),
	preload("res://assets/BinbunVFX/LootFX/BinbunVFX/loot_effects/effects/ground/ground_loot_vfx_mythic.tscn"),
]

@export var loot_count := 14
@export var scatter_seed := 7
@export var scatter_min_radius := 9.0
@export var scatter_max_radius := 30.0
@export var floating_height := 1.1
@export var enable_enemy_test_encounter := true

@onready var _loot_root: Node3D = $Loot
@onready var _return_interact: ProximityInteractable = $ForgeMonument/ReturnInteract

var _returning := false


func _ready() -> void:
	_scatter_loot()
	if enable_enemy_test_encounter:
		_spawn_enemy_test_encounter()
	if PlayerState.is_campaign_scene(self):
		if PlayerState.checkpoint(PlayerState.FIELD):
			_add_armor_blueprint()
	if _return_interact:
		_return_interact.interacted.connect(_on_return_interacted)


func _spawn_enemy_test_encounter() -> void:
	var roster := Node3D.new()
	roster.name = "EnemyTestEncounter"
	add_child(roster)
	for entry: Dictionary in ENEMY_TEST_ROSTER:
		var path: String = entry["model"]
		if not ResourceLoader.exists(path):
			push_warning("Enemy test model pending: " + path)
			continue
		var actor := ENEMY_TEST_ACTOR.instantiate() as CharacterBody3D
		actor.name = str(entry["name"]).replace(" ", "")
		actor.position = entry["at"]
		actor.set("model_scene", load(path))
		actor.set("display_name", entry["name"])
		actor.set("height_m", entry["height"])
		actor.set("radius_m", entry["radius"])
		actor.set("move_speed", entry["speed"])
		actor.set("attack_damage", entry["damage"])
		actor.set("attack_range", entry["range"])
		actor.set("aggro_range", entry["aggro"])
		actor.set("attack_cooldown", entry["cooldown"])
		actor.set("contact_fraction", entry.get("contact_fraction", 0.3))
		actor.set("flying", entry.get("flying", false))
		actor.set("idle_clip", entry.get("idle_clip", "idle"))
		actor.set("move_clip", entry.get("move_clip", "walk"))
		actor.set("forward_offset", entry.get("forward_offset", 0.0))
		(actor.get_node("Health") as Health).max_hp = entry["hp"]
		roster.add_child(actor)


func _scatter_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	for i in loot_count:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(scatter_min_radius, scatter_max_radius)
		var at := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		# Keep the approach lane in front of the monument clear.
		if absf(at.x) < 3.0 and at.z > 0.0:
			at.x = 3.5 * signf(at.x if at.x != 0.0 else 1.0)
		var rarity := rng.randi_range(0, FLOATING_LOOT.size() - 1)
		var use_ground := rng.randf() < 0.35
		var scene: PackedScene = GROUND_LOOT[rarity] if use_ground else FLOATING_LOOT[rarity]
		var vfx := scene.instantiate() as Node3D
		vfx.name = "%s_%02d" % ["Ground" if use_ground else "Loot", i]
		vfx.position = at + Vector3(0.0, 0.05 if use_ground else floating_height, 0.0)
		_loot_root.add_child(vfx)


func _on_return_interacted() -> void:
	if _returning:
		return
	if PlayerState.is_campaign_scene(self) and not PlayerState.return_to_forge():
		return
	_returning = true
	if _return_interact:
		_return_interact.enabled = false
	var transition := get_node_or_null("/root/SceneTransition")
	if transition and transition.has_method("change_scene"):
		transition.change_scene(LOBBY_SCENE)
	else:
		get_tree().change_scene_to_file(LOBBY_SCENE)


func _add_armor_blueprint() -> void:
	var id := PlayerState.next_armor_id()
	if id.is_empty() or not PlayerState.data.pending_blueprint.is_empty():
		return
	var cache := Node3D.new()
	cache.name = "ArmorBlueprint"
	cache.position = Vector3(12, 0, -24)
	add_child(cache)
	var vfx := FLOATING_LOOT[2].instantiate() as Node3D
	vfx.position.y = 1.0
	cache.add_child(vfx)
	var label := Label3D.new()
	label.position.y = 3.0
	label.text = "ARMOR BLUEPRINT\n" + str(PlayerState.armor(id).name)
	label.font_size = 44
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	cache.add_child(label)
	var interact := ProximityInteractable.new()
	interact.action_text = "Recover " + str(PlayerState.armor(id).name) + " blueprint"
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.5
	collision.shape = shape
	interact.add_child(collision)
	cache.add_child(interact)
	interact.interacted.connect(func() -> void:
		if PlayerState.recover_blueprint():
			interact.enabled = false
			cache.queue_free()
	)
