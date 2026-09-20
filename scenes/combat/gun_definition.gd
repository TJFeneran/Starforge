extends Resource
class_name GunDefinition

## Generated from docs/production/gun-balance.json by tools/generate_gun_resources.py.
## Values use HP, meters, seconds, degrees, and heat points.

@export var gun_id := ""
@export var display_name := ""
@export var tier := ""
@export var family := ""
@export var slot := ""
@export var payload := ""
@export var damage_type := ""
@export var model: PackedScene
@export_range(0.1, 2.0, 0.01) var model_scale := 1.0
@export var muzzle_offset := Vector3.ZERO
@export var first_person_offset := Vector3(0.28, -0.24, -0.49)
@export var first_person_ads_offset := Vector3(0.10, -0.18, -0.48)
@export var fire_mode := "semi" # semi, burst, auto, beam, charge
@export var effect_style := "pulse"
@export var effect_color := Color.WHITE
@export var effect_size := 1.0

@export var damage := 0.0
@export var shots_per_trigger := 1
@export var fire_interval := 0.3
@export var burst_spacing := 0.0
@export var charge_time := 0.0
@export var recovery_time := 0.0
@export var projectile_speed := 0.0
@export var projectile_lifetime := 0.0
@export var max_range := 0.0
@export var magazine := 0
@export var reload_time := 0.0
@export var spread_ads := 0.0
@export var spread_hip := 0.0
@export var recoil_degrees := 0.0
@export var falloff_start := 0.0
@export var falloff_end := 0.0
@export var minimum_damage_fraction := 1.0

@export var heat_capacity := 0.0
@export var heat_per_tick := 0.0
@export var heat_cool_per_second := 0.0
@export var overheat_lockout := 0.0

@export var echo_every_triggers := 0
@export var echo_damage := 0.0
@export var weakpoint_multiplier := 1.0
@export var mark_duration := 0.0
@export var mark_bonus_damage := 0.0
@export var settle_aim_seconds := 0.0
@export var settled_spread_ads := 0.0
@export var pierce_targets := 1
@export var pierce_damage_fraction := 0.0
@export var aoe_radius := 0.0
@export var aoe_damage := 0.0
@export var aoe_max_targets := 0


func damage_at(distance: float) -> float:
	if distance <= falloff_start or falloff_end <= falloff_start:
		return damage
	var t := clampf((distance - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0)
	return damage * lerpf(1.0, minimum_damage_fraction, t)


func uses_heat() -> bool:
	return heat_capacity > 0.0
