extends Area3D

## Short-lived forge pulse bolt.

const SPEED := 42.0
const LIFETIME := 0.55

var velocity := Vector3.ZERO
var damage := 34.0
var _age := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 5 # world(1) + enemies(4)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	global_position += velocity * delta


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		return
	if body.has_method("apply_hit"):
		body.apply_hit(damage)
	queue_free()


func launch(from: Vector3, direction: Vector3, dmg: float) -> void:
	global_position = from
	velocity = direction.normalized() * SPEED
	damage = dmg
	look_at(from + direction, Vector3.UP)
