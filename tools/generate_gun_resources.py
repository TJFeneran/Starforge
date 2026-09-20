"""Generate editable Godot GunDefinition resources from the balance catalog."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "docs/production/gun-balance.json"
OUT = ROOT / "assets/data/guns"

# Art attachment and effect choices live here; numeric gameplay values live in JSON.
VISUALS = {
    "gun_sidearm_starter_emberflint": ("emberflint", (0, 0.082, -0.247), "semi", "pulse", "ffb238", 1.0),
    "gun_sidearm_common_latch": ("latch", (0, 0.105, -0.280), "semi", "slug", "ffd09a", 0.9),
    "gun_sidearm_uncommon_echo": ("echo", (0, 0.085, -0.310), "burst", "echo", "67ffcf", 0.9),
    "gun_sidearm_rare_needle": ("rare_needle", (0, 0.030, -0.590), "semi", "needle", "91f3ff", 0.7),
    "gun_sidearm_legendary_dawnseal": ("dawnseal", (0, 0.045, -0.340), "semi", "solar", "ffe4a0", 1.15),
    "gun_rifle_common_ridge": ("ridge", (0, 0.130, -0.520), "auto", "tracer", "ffd59b", 0.65),
    "gun_rifle_uncommon_longpath": ("longpath", (0, 0.110, -0.880), "semi", "rail", "7cdbff", 0.75),
    "gun_energy_rare_splitfin": ("splitfin", (0, 0.000, -0.520), "beam", "beam", "ffb950", 1.0),
    "gun_energy_legendary_monument": ("monument_heart", (0, 0.220, -0.570), "charge", "orb", "ffac3c", 1.6),
}

FIRST_PERSON = {
    "emberflint": ((0.28, -0.24, -0.49), (0.10, -0.18, -0.48)),
    "latch": ((0.29, -0.24, -0.53), (0.10, -0.18, -0.52)),
    "echo": ((0.32, -0.26, -0.56), (0.11, -0.19, -0.55)),
    "rare_needle": ((0.31, -0.25, -0.60), (0.11, -0.19, -0.59)),
    "dawnseal": ((0.32, -0.25, -0.60), (0.10, -0.18, -0.58)),
    "ridge": ((0.38, -0.34, -0.84), (0.13, -0.22, -0.81)),
    "longpath": ((0.39, -0.33, -0.94), (0.13, -0.22, -0.92)),
    "splitfin": ((0.40, -0.27, -0.76), (0.14, -0.19, -0.74)),
    "monument_heart": ((0.55, -0.43, -1.08), (0.22, -0.28, -1.20)),
}

MODEL_SCALE = {
    "emberflint": 1.0,
    "latch": 1.0,
    "echo": 1.0,
    "rare_needle": 0.78,
    "dawnseal": 1.0,
    "ridge": 1.0,
    "longpath": 0.90,
    "splitfin": 1.0,
    "monument_heart": 0.58,
}

FIELDS = {
    "damage": (float, 0.0), "shots_per_trigger": (int, 1), "fire_interval": (float, 0.0),
    "burst_spacing": (float, 0.0), "charge_time": (float, 0.0), "recovery_time": (float, 0.0),
    "projectile_speed": (float, 0.0), "projectile_lifetime": (float, 0.0),
    "max_range": (float, 0.0), "magazine": (int, 0), "reload": (float, 0.0),
    "spread_ads": (float, 0.0), "spread_hip": (float, 0.0),
    "recoil_degrees": (float, 0.0), "falloff_start": (float, 0.0),
    "falloff_end": (float, 0.0), "minimum_damage_fraction": (float, 1.0),
    "heat_capacity": (float, 0.0), "heat_per_tick": (float, 0.0),
    "heat_cool_per_second": (float, 0.0), "overheat_lockout": (float, 0.0),
    "echo_every_triggers": (int, 0), "echo_damage": (float, 0.0),
    "weakpoint_multiplier": (float, 1.0), "mark_duration": (float, 0.0),
    "mark_bonus_damage": (float, 0.0), "settle_aim_seconds": (float, 0.0),
    "settled_spread_ads": (float, 0.0), "pierce_targets": (int, 1),
    "pierce_damage_fraction": (float, 0.0), "aoe_radius": (float, 0.0),
    "aoe_damage": (float, 0.0), "aoe_max_targets": (int, 0),
}


def color_expr(hex_color: str) -> str:
    values = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return "Color(%s, %s, %s, 1)" % tuple(f"{value:.8f}" for value in values)


def build(item: dict) -> tuple[str, str]:
    gun_id = item["id"]
    stem, muzzle, mode, style, color, size = VISUALS[gun_id]
    hip_offset, ads_offset = FIRST_PERSON[stem]
    model_path = f"res://assets/models/gear/guns/{stem}/{stem}.glb"
    assert (ROOT / model_path.removeprefix("res://")).is_file(), model_path
    assert item["damage"] > 0 and item["fire_interval"] > 0
    if item["projectile_speed"] is not None:
        assert abs(item["projectile_speed"] * item["projectile_lifetime"] - item["max_range"]) < 0.01
    lines = [
        "[gd_resource type=\"Resource\" script_class=\"GunDefinition\" load_steps=3 format=3]",
        "",
        '[ext_resource type="Script" path="res://scenes/combat/gun_definition.gd" id="1_script"]',
        f'[ext_resource type="PackedScene" path="{model_path}" id="2_model"]',
        "",
        "[resource]",
        'script = ExtResource("1_script")',
        f'gun_id = {json.dumps(gun_id)}',
        f'display_name = {json.dumps(item["name"])}',
        f'tier = {json.dumps(item["tier"])}',
        f'family = {json.dumps(item["family"])}',
        f'slot = {json.dumps(item["slot"])}',
        f'payload = {json.dumps(item["payload"])}',
        f'damage_type = {json.dumps(item["damage_type"])}',
        'model = ExtResource("2_model")',
        f'model_scale = {MODEL_SCALE[stem]}',
        "muzzle_offset = Vector3(%s, %s, %s)" % muzzle,
        "first_person_offset = Vector3(%s, %s, %s)" % hip_offset,
        "first_person_ads_offset = Vector3(%s, %s, %s)" % ads_offset,
        f'fire_mode = {json.dumps(mode)}',
        f'effect_style = {json.dumps(style)}',
        f'effect_color = {color_expr(color)}',
        f'effect_size = {size}',
    ]
    for source, (kind, default) in FIELDS.items():
        destination = "reload_time" if source == "reload" else source
        value = item.get(source, default)
        value = default if value is None else kind(value)
        lines.append(f"{destination} = {value}")
    return stem, "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if resources are out of sync")
    args = parser.parse_args()
    weapons = json.loads(CATALOG.read_text())["weapons"]
    assert len(weapons) == len(VISUALS) == 9
    assert {item["id"] for item in weapons} == set(VISUALS)
    OUT.mkdir(parents=True, exist_ok=True)
    stale = []
    for item in weapons:
        stem, content = build(item)
        destination = OUT / f"{stem}.tres"
        if args.check:
            if not destination.is_file() or destination.read_text() != content:
                stale.append(stem)
        else:
            destination.write_text(content)
    if stale:
        raise SystemExit("Out of sync GunDefinition resources: " + ", ".join(stale))
    print(f"{'Checked' if args.check else 'Generated'} {len(weapons)} GunDefinition resources")


if __name__ == "__main__":
    main()
