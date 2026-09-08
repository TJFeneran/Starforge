extends Node
class_name Health

signal damaged(amount: float, remaining: float)
signal died

@export var max_hp := 100.0

var hp: float
var is_dead := false


func _ready() -> void:
	hp = max_hp


func apply_damage(amount: float) -> void:
	if is_dead:
		return
	hp = maxf(0.0, hp - amount)
	damaged.emit(amount, hp)
	if hp <= 0.0:
		is_dead = true
		died.emit()


func heal_full() -> void:
	hp = max_hp
	is_dead = false
