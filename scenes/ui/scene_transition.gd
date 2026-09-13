extends CanvasLayer
## Full-screen wipe using the BinbunVFX TransitionWipe shader.
## Autoloaded as `SceneTransition`; call `change_scene(path)` to wipe out, swap, wipe in.

signal covered
signal revealed

@export var wipe_duration := 0.55
@export var hold_duration := 0.1

@onready var _rect: ColorRect = $Wipe

var _material: ShaderMaterial
var _busy := false


func _ready() -> void:
	_material = _rect.material as ShaderMaterial
	_rect.visible = false
	_material.set_shader_parameter("factor", 0.0)
	_update_resolution()
	get_viewport().size_changed.connect(_update_resolution)


func _update_resolution() -> void:
	_material.set_shader_parameter("node_resolution", Vector2(get_viewport().get_visible_rect().size))


func is_busy() -> bool:
	return _busy


## Wipe to full cover, change scene, then wipe away to reveal the new scene.
func change_scene(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	await cover()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout
	await reveal()
	_busy = false


## Animate the wipe from clear to fully covered.
func cover() -> void:
	_rect.visible = true
	await _animate(0.0, 1.0)
	covered.emit()


## Animate the wipe from fully covered back to clear.
func reveal() -> void:
	_rect.visible = true
	_material.set_shader_parameter("shape_rotation", 180.0)
	await _animate(1.0, 0.0)
	_material.set_shader_parameter("shape_rotation", 0.0)
	_rect.visible = false
	revealed.emit()


func _animate(from: float, to: float) -> void:
	_material.set_shader_parameter("factor", from)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_factor, from, to, wipe_duration)
	await tween.finished


func _set_factor(value: float) -> void:
	_material.set_shader_parameter("factor", value)
