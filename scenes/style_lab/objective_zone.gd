extends Area3D

signal player_entered

@export var once := true

var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false


func _on_body_entered(body: Node3D) -> void:
	if once and _triggered:
		return
	if body is CharacterBody3D:
		_triggered = true
		player_entered.emit()
