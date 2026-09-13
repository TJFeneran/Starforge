extends Node3D
## Open field reached through the lobby gate. Scatters BinbunVFX loot effects
## around a forge monument; interacting at the monument returns to the lobby.

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"

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

@onready var _loot_root: Node3D = $Loot
@onready var _return_interact: ProximityInteractable = $ForgeMonument/ReturnInteract

var _returning := false


func _ready() -> void:
	_scatter_loot()
	if _return_interact:
		_return_interact.interacted.connect(_on_return_interacted)


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
	_returning = true
	if _return_interact:
		_return_interact.enabled = false
	var transition := get_node_or_null("/root/SceneTransition")
	if transition and transition.has_method("change_scene"):
		transition.change_scene(LOBBY_SCENE)
	else:
		get_tree().change_scene_to_file(LOBBY_SCENE)
