extends Node3D

## First outpost loop: attune → monument → canopy, with a combat scout on the plateau.

enum Phase { ATTUNE, MONUMENT, REPORT, RIFT, DONE }

@onready var _hud = $MissionHUD
@onready var _beacon = $Outpost/BeaconInteract
@onready var _monument_zone = $Outpost/MonumentZone
@onready var _canopy_zone = $Outpost/CanopyZone
@onready var _rift_zone = $RiftApproachZone
@onready var _player = $Player

var _phase: Phase = Phase.ATTUNE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_mission") and _phase == Phase.DONE:
		get_viewport().set_input_as_handled()
		call_deferred("_restart_mission")


func _restart_mission() -> void:
	if is_inside_tree():
		get_tree().reload_current_scene()


func _ready() -> void:
	_beacon.attuned.connect(_on_beacon_attuned)
	_monument_zone.player_entered.connect(_on_monument_reached)
	_canopy_zone.player_entered.connect(_on_canopy_reached)
	_rift_zone.player_entered.connect(_on_rift_reached)
	_monument_zone.set_deferred("monitoring", false)
	_canopy_zone.set_deferred("monitoring", false)
	_rift_zone.set_deferred("monitoring", false)
	var health := _player.get_node("Health") as Health
	health.damaged.connect(_on_player_damaged)
	_hud.set_player_hp(health.hp, health.max_hp)
	_set_phase(Phase.ATTUNE)


func _on_player_damaged(_amount: float, remaining: float) -> void:
	var health := _player.get_node("Health") as Health
	_hud.set_player_hp(remaining, health.max_hp)


func _set_phase(phase: Phase) -> void:
	_phase = phase
	match phase:
		Phase.ATTUNE:
			_hud.set_objective(
				"Attune the forge beacon",
				"Approach the amber beacon and press E — LMB fires the sidearm"
			)
		Phase.MONUMENT:
			_hud.set_objective(
				"Approach the celestial monument",
				"Pass through the doorway toward the split-ring"
			)
			_monument_zone.set_deferred("monitoring", true)
		Phase.REPORT:
			_hud.set_objective(
				"Report in at the canopy",
				"Return to the shade canopy and stand under it"
			)
			_canopy_zone.set_deferred("monitoring", true)
		Phase.RIFT:
			_hud.set_objective("Approach the rift field", "Leave the canopy and investigate the violet signal")
			_rift_zone.set_deferred("monitoring", true)
		Phase.DONE:
			_hud.set_objective("Outpost secured", "Press R to restart the mission — LMB fires the sidearm")
			await _hud.show_banner("OUTPOST SECURED", 3.2)


func _on_beacon_attuned() -> void:
	if _phase == Phase.ATTUNE:
		_set_phase(Phase.MONUMENT)


func _on_monument_reached() -> void:
	if _phase == Phase.MONUMENT:
		_monument_zone.set_deferred("monitoring", false)
		_set_phase(Phase.REPORT)


func _on_canopy_reached() -> void:
	if _phase == Phase.REPORT:
		_canopy_zone.set_deferred("monitoring", false)
		_set_phase(Phase.RIFT)


func _on_rift_reached() -> void:
	if _phase == Phase.RIFT:
		_rift_zone.set_deferred("monitoring", false)
		_set_phase(Phase.DONE)
