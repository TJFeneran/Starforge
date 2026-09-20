extends Node3D
class_name GunMount

## Shared firing runtime. All balance numbers come from generated GunDefinition
## resources, not from the imported gun meshes or player controller.

signal recoil(amount_degrees: float)
signal gun_changed(definition: GunDefinition)

const GUN_PATHS := [
	"res://assets/data/guns/emberflint.tres",
	"res://assets/data/guns/latch.tres",
	"res://assets/data/guns/echo.tres",
	"res://assets/data/guns/rare_needle.tres",
	"res://assets/data/guns/dawnseal.tres",
	"res://assets/data/guns/ridge.tres",
	"res://assets/data/guns/longpath.tres",
	"res://assets/data/guns/splitfin.tres",
	"res://assets/data/guns/monument_heart.tres",
]
const ENERGY_FIRE := preload("res://assets/audio/weapons/348164__djfroyd__laser-one-shot-1.wav")
const HELD_REPEAT_STYLES := ["pulse", "echo", "solar", "orb"]

@onready var _model_holder: Node3D = $Model
@onready var _muzzle: Marker3D = $Muzzle
@onready var _fire_sfx: AudioStreamPlayer3D = $FireSFX

var definition: GunDefinition
var selected_index := 0
var _definitions: Array[GunDefinition] = []
var _model: Node3D
var _animation: AnimationPlayer
var _shooter: CollisionObject3D
var _saved: Dictionary = {}
var _ammo := 0
var _heat := 0.0
var _reload_left := 0.0
var _cooldown := 0.0
var _lockout_left := 0.0
var _charge_left := 0.0
var _trigger_count := 0
var _trigger_was_held := false
var _trigger_held := false
var _wait_for_trigger_release := false
var _aim_hold := 0.0
var _aim_pressed := false
var _camera_origin := Vector3.ZERO
var _camera_direction := Vector3.FORWARD
var _last_hits: Dictionary = {}
var _marks: Dictionary = {}
var _mark_armed: Dictionary = {}
var _hud_label: Label
var _hud_panel: ColorRect


func _ready() -> void:
	for path in GUN_PATHS:
		var spec := load(path) as GunDefinition
		if spec == null:
			push_error("Missing GunDefinition: " + path)
			return
		_definitions.append(spec)
	_build_hud()
	equip(0)


func set_shooter(body: CollisionObject3D) -> void:
	_shooter = body


func equip(index: int) -> void:
	if index < 0 or index >= _definitions.size():
		return
	if definition != null:
		_saved[definition.gun_id] = {
			"ammo": _ammo, "heat": _heat, "reload": _reload_left,
			"lockout": _lockout_left, "cooldown": _cooldown, "triggers": _trigger_count,
		}
	selected_index = index
	definition = _definitions[index]
	if is_instance_valid(_model):
		_model_holder.remove_child(_model)
		_model.queue_free()
	_model = definition.model.instantiate() as Node3D
	_model_holder.add_child(_model)
	_model.scale = Vector3.ONE * definition.model_scale
	_muzzle.position = definition.muzzle_offset * definition.model_scale
	_fire_sfx.position = _muzzle.position
	_animation = _find_animation_player(_model)
	var state: Dictionary = _saved.get(definition.gun_id, {})
	_ammo = int(state.get("ammo", definition.magazine))
	_heat = float(state.get("heat", 0.0))
	_reload_left = float(state.get("reload", 0.0))
	_lockout_left = float(state.get("lockout", 0.0))
	_cooldown = float(state.get("cooldown", 0.0))
	_trigger_count = int(state.get("triggers", 0))
	_charge_left = 0.0
	_aim_hold = 0.0
	_trigger_was_held = true # Do not fire a held click when changing weapons.
	_wait_for_trigger_release = true
	if not _mark_armed.has(definition.gun_id):
		_mark_armed[definition.gun_id] = true
	_play_animation("Idle_Pulse")
	if definition.effect_style == "orb":
		_play_animation("Ring_Spin")
	_update_hud()
	gun_changed.emit(definition)


func process_trigger(delta: float, held: bool, aiming: bool, camera_origin: Vector3, camera_direction: Vector3) -> void:
	if definition == null:
		return
	_camera_origin = camera_origin
	_camera_direction = camera_direction.normalized()
	_aim_pressed = aiming
	_aim_hold = _aim_hold + delta if aiming else 0.0
	_trigger_held = held
	if not held:
		_wait_for_trigger_release = false
	var repeats_while_held := definition.fire_mode in ["auto", "beam"] or definition.effect_style in HELD_REPEAT_STYLES
	if held and not _wait_for_trigger_release and (repeats_while_held or not _trigger_was_held):
		_try_fire()
	_trigger_was_held = held
	_update_hud()


func reload() -> void:
	if definition == null or definition.uses_heat() or _reload_left > 0.0 or _ammo >= definition.magazine:
		return
	_reload_left = definition.reload_time
	_charge_left = 0.0
	_play_animation("Reload")
	_update_hud()


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _reload_left > 0.0:
		_reload_left = maxf(0.0, _reload_left - delta)
		if _reload_left == 0.0:
			_ammo = definition.magazine
			_mark_armed[definition.gun_id] = true
	if _lockout_left > 0.0:
		_lockout_left = maxf(0.0, _lockout_left - delta)
	if definition.uses_heat() and (not _trigger_held or _lockout_left > 0.0):
		_heat = maxf(0.0, _heat - definition.heat_cool_per_second * delta)
	if _charge_left > 0.0:
		_charge_left = maxf(0.0, _charge_left - delta)
		if _charge_left == 0.0:
			_fire_projectile(definition)
	_update_hud()


func _try_fire() -> void:
	if _cooldown > 0.0 or _reload_left > 0.0 or _lockout_left > 0.0 or _charge_left > 0.0:
		return
	if not definition.uses_heat() and _ammo < definition.shots_per_trigger:
		reload()
		return
	_cooldown = definition.fire_interval
	_trigger_count += 1
	if definition.fire_mode == "charge":
		_charge_left = definition.charge_time
		_play_animation("Charge")
		WeaponEffect.burst(_muzzle, _muzzle.global_position, definition.effect_color, 0.09, definition.charge_time, 2.5)
		return
	if definition.fire_mode == "beam":
		if not _trigger_was_held:
			_play_animation("Charge")
		_fire_beam()
		return
	_ammo -= definition.shots_per_trigger
	_fire_projectile(definition)
	if definition.fire_mode == "burst" and definition.shots_per_trigger > 1:
		_fire_delayed_burst(definition)
	if definition.echo_every_triggers > 0 and _trigger_count % definition.echo_every_triggers == 0:
		_emit_echo(definition)
	if _ammo == 0:
		reload()


func _fire_delayed_burst(spec: GunDefinition) -> void:
	for i in range(1, spec.shots_per_trigger):
		await get_tree().create_timer(spec.burst_spacing).timeout
		if not is_inside_tree() or definition != spec:
			return
		_fire_projectile(spec)


func _fire_projectile(spec: GunDefinition) -> void:
	if spec.fire_mode == "charge":
		if _ammo <= 0:
			reload()
			return
		_ammo -= 1
	var from := _muzzle.global_position
	var direction := _shot_direction(spec)
	var projectile := GunProjectile.new()
	_effect_host().add_child(projectile)
	projectile.launch(spec, from, direction, self, _shooter)
	WeaponEffect.burst(_muzzle, from, spec.effect_color, 0.08 * spec.effect_size)
	_play_animation("Fire")
	_play_sound(spec)
	recoil.emit(spec.recoil_degrees)
	if spec.fire_mode == "charge" and _ammo == 0:
		reload()


func _fire_beam() -> void:
	var spec := definition
	var from := _muzzle.global_position
	var direction := _shot_direction(spec)
	var remaining := spec.max_range
	var start := from
	var end := from + direction * remaining
	var excluded: Array[RID] = []
	if is_instance_valid(_shooter):
		excluded.append(_shooter.get_rid())
	for hit_number in range(spec.pierce_targets):
		var query := PhysicsRayQueryParameters3D.create(start, start + direction * remaining, 5)
		query.exclude = excluded
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			end = start + direction * remaining
			break
		end = hit.position
		var body: Object = hit.collider
		if not body.has_method("apply_hit"):
			break
		var distance := from.distance_to(end)
		_apply_hit(spec, body, end, distance, 1.0 if hit_number == 0 else spec.pierce_damage_fraction)
		WeaponEffect.burst(_effect_host(), end, spec.effect_color, 0.10)
		if body is CollisionObject3D:
			excluded.append((body as CollisionObject3D).get_rid())
		remaining = spec.max_range - distance
		if remaining <= 0.0:
			break
		start = end + direction * 0.02
	WeaponEffect.line(_effect_host(), from, end, spec.effect_color, 0.035 * spec.effect_size, spec.fire_interval + 0.04)
	WeaponEffect.burst(_muzzle, from, spec.effect_color, 0.08)
	_heat = minf(spec.heat_capacity, _heat + spec.heat_per_tick)
	if _heat >= spec.heat_capacity:
		_lockout_left = spec.overheat_lockout
	_play_sound(spec)


func _shot_direction(spec: GunDefinition) -> Vector3:
	var target := _camera_origin + _camera_direction * spec.max_range
	var query := PhysicsRayQueryParameters3D.create(_camera_origin, target, 5)
	if is_instance_valid(_shooter):
		query.exclude = [_shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = hit.position
	var from := _muzzle.global_position
	var forward := (target - from).normalized()
	if forward.length_squared() < 0.001:
		forward = _camera_direction
	var spread := spec.spread_ads if _aim_pressed else spec.spread_hip
	if _aim_pressed and spec.settle_aim_seconds > 0.0 and _aim_hold >= spec.settle_aim_seconds:
		spread = spec.settled_spread_ads
	if spread <= 0.0:
		return forward
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var theta := randf() * TAU
	var radius := tan(deg_to_rad(spread)) * sqrt(randf())
	return (forward + (right * cos(theta) + up * sin(theta)) * radius).normalized()


func on_projectile_impact(spec: GunDefinition, target: Object, point: Vector3, distance: float) -> void:
	if target.has_method("apply_hit"):
		_apply_hit(spec, target, point, distance, 1.0)
		if spec.aoe_radius > 0.0:
			_apply_aoe(spec, target, point)


func _apply_hit(spec: GunDefinition, target: Object, point: Vector3, distance: float, fraction: float) -> void:
	var damage := spec.damage_at(distance) * fraction
	if spec.weakpoint_multiplier > 1.0 and target.has_method("is_weak_point") and target.is_weak_point(point):
		damage *= spec.weakpoint_multiplier
	target.apply_hit(damage)
	if target is Node3D:
		_last_hits[spec.gun_id] = weakref(target)
	if spec.mark_bonus_damage <= 0.0:
		return
	var mark: Dictionary = _marks.get(spec.gun_id, {})
	var marked: Object = (mark.get("target") as WeakRef).get_ref() if mark.get("target") is WeakRef else null
	var now := Time.get_ticks_msec() * 0.001
	if marked == target and now <= float(mark.get("expires", 0.0)):
		target.apply_hit(spec.mark_bonus_damage)
		_marks.erase(spec.gun_id)
		WeaponEffect.burst(_effect_host(), point, spec.effect_color, 0.22, 0.22, 2.5)
	elif bool(_mark_armed.get(spec.gun_id, true)):
		_marks[spec.gun_id] = {"target": weakref(target), "expires": now + spec.mark_duration}
		_mark_armed[spec.gun_id] = false
		WeaponEffect.burst(_effect_host(), point, spec.effect_color, 0.12, 0.2, 1.8)


func _emit_echo(spec: GunDefinition) -> void:
	var reference: WeakRef = _last_hits.get(spec.gun_id)
	if reference == null:
		return
	var target: Object = reference.get_ref()
	if not is_instance_valid(target) or not target is Node3D or not target.has_method("apply_hit"):
		return
	var from := _muzzle.global_position
	var finish: Vector3 = (target as Node3D).global_position + Vector3(0, 0.6, 0)
	if from.distance_to(finish) > spec.max_range:
		return
	var query := PhysicsRayQueryParameters3D.create(from, finish, 1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	target.apply_hit(spec.echo_damage)
	WeaponEffect.line(_effect_host(), from, finish, spec.effect_color, 0.025, 0.22)
	WeaponEffect.burst(_effect_host(), finish, spec.effect_color, 0.10)


func _apply_aoe(spec: GunDefinition, direct_target: Object, point: Vector3) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = spec.aoe_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 4
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 32)
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["collider"] as Node3D).global_position.distance_squared_to(point) < (b["collider"] as Node3D).global_position.distance_squared_to(point)
	)
	var damaged := 0
	for hit in hits:
		var body: Object = hit.collider
		if body == direct_target or not body.has_method("apply_hit"):
			continue
		body.apply_hit(spec.aoe_damage)
		damaged += 1
		if damaged >= spec.aoe_max_targets:
			break
	WeaponEffect.burst(_effect_host(), point, spec.effect_color, 0.22, 0.24, spec.aoe_radius / 0.22)


func _play_animation(keyword: String) -> void:
	if not is_instance_valid(_animation):
		return
	for name in _animation.get_animation_list():
		if keyword.to_lower() in String(name).to_lower():
			_animation.play(name)
			return


func _play_sound(spec: GunDefinition) -> void:
	if spec.damage_type not in ["energy", "solar", "kinetic_energy"]:
		return
	_fire_sfx.stream = ENERGY_FIRE
	_fire_sfx.pitch_scale = {"echo": 1.35, "solar": 0.88, "beam": 1.55, "orb": 0.65}.get(spec.effect_style, 1.0)
	_fire_sfx.volume_db = -8.0 if spec.fire_mode == "beam" else -6.0
	_fire_sfx.play()


func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	for child in root_node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _effect_host() -> Node:
	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 7
	add_child(canvas)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(screen)
	_hud_panel = ColorRect.new()
	_hud_panel.color = Color(0.035, 0.065, 0.11, 0.84)
	_hud_panel.anchor_top = 1.0
	_hud_panel.anchor_bottom = 1.0
	_hud_panel.offset_left = 22.0
	_hud_panel.offset_right = 390.0
	_hud_panel.offset_top = -95.0
	_hud_panel.offset_bottom = -18.0
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(_hud_panel)
	_hud_label = Label.new()
	_hud_label.position = Vector2(12, 7)
	_hud_label.add_theme_font_size_override("font_size", 19)
	_hud_label.add_theme_color_override("font_color", Color("f6eee2"))
	_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_panel.add_child(_hud_label)


func _update_hud() -> void:
	if definition == null or not is_instance_valid(_hud_label):
		return
	_hud_panel.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var capacity := "%d / %d" % [_ammo, definition.magazine]
	if definition.uses_heat():
		capacity = "HEAT  %d / %d" % [roundi(_heat), roundi(definition.heat_capacity)]
	var state := ""
	if _reload_left > 0.0:
		state = "  ·  RELOADING %.1f s" % _reload_left
	elif _lockout_left > 0.0:
		state = "  ·  OVERHEATED %.1f s" % _lockout_left
	elif _charge_left > 0.0:
		state = "  ·  CHARGING %.1f s" % _charge_left
	_hud_label.text = "%02d  %s  /  %s\n%s%s     1–9 switch  ·  R reload" % [
		selected_index + 1, definition.display_name.to_upper(), definition.tier.to_upper(), capacity, state
	]
