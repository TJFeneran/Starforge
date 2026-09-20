extends Node3D

## Cycle the playable gun loadout while testing shots in this scene.
@onready var _gun: GunMount = $Player/Visual/WeaponAnchor/GunMount
@onready var _hint: Label = $ShortcutHints/Panel/Label


func _ready() -> void:
	_gun.gun_changed.connect(_update_hint)
	_update_hint(_gun.definition)


func _update_hint(spec: GunDefinition) -> void:
	var mode := spec.fire_mode.capitalize()
	if spec.fire_mode == "burst":
		mode = "%d-shot burst" % spec.shots_per_trigger
	var damage_label := "Damage %.0f" % spec.damage
	if spec.fire_mode == "beam":
		damage_label += "/tick"
	var shot_label := "Beam: instant" if spec.fire_mode == "beam" else "Projectile %.0f m/s" % spec.projectile_speed
	var capacity := "Heat %.0f max  ·  +%.0f/tick" % [spec.heat_capacity, spec.heat_per_tick] if spec.uses_heat() else "Magazine %d  ·  Reload %.2fs" % [spec.magazine, spec.reload_time]
	var traits := PackedStringArray()
	if spec.charge_time > 0.0:
		traits.append("Charge %.2fs" % spec.charge_time)
	if spec.pierce_targets > 1:
		traits.append("Pierce %d" % spec.pierce_targets)
	if spec.aoe_radius > 0.0:
		traits.append("Blast radius %.1f m" % spec.aoe_radius)
	if spec.weakpoint_multiplier > 1.0:
		traits.append("Weak point x%.1f" % spec.weakpoint_multiplier)
	if spec.echo_every_triggers > 0:
		traits.append("Echo every %d triggers" % spec.echo_every_triggers)
	if spec.mark_bonus_damage > 0.0:
		traits.append("Mark bonus %.0f" % spec.mark_bonus_damage)
	if spec.settle_aim_seconds > 0.0:
		traits.append("Aim settles %.1fs" % spec.settle_aim_seconds)
	if spec.overheat_lockout > 0.0:
		traits.append("Overheat lock %.1fs" % spec.overheat_lockout)
	var lines := PackedStringArray([
		"%02d / %02d  %s  ·  %s" % [_gun.selected_index + 1, _gun.GUN_PATHS.size(), spec.display_name.to_upper(), spec.tier.to_upper()],
		"%s  ·  %s  ·  Fire interval %.2fs  ·  Range %.1f m" % [damage_label, mode, spec.fire_interval, spec.max_range],
		"%s  ·  %s" % [shot_label, capacity],
	])
	if not traits.is_empty():
		lines.append("Special: " + "  ·  ".join(traits))
	lines.append("TAB next  ·  SHIFT+TAB previous  ·  1–9 select  ·  RMB aim  ·  LMB fire  ·  R reload")
	_hint.text = "\n".join(lines)
	var panel_bottom := 20.0 + 25.0 * lines.size() + 40.0
	$ShortcutHints/Panel.offset_bottom = panel_bottom
	_hint.offset_bottom = panel_bottom - 28.0


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_TAB or _gun == null:
		return
	var count := _gun.GUN_PATHS.size()
	if count == 0:
		return
	var direction := -1 if event.shift_pressed else 1
	_gun.equip(posmod(_gun.selected_index + direction, count))
	get_viewport().set_input_as_handled()
