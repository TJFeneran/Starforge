"""Build the nine-gun reference sheet from the balance catalog and current art."""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs/production"
CATALOG = json.loads((DOC / "gun-balance.json").read_text())
MANIFEST = json.loads((ROOT / "assets/source/concepts/gear/manifest.json").read_text())
CONCEPTS = {c["id"]: c for c in MANIFEST["concepts"]}
ASSET_STEMS = {
    "gun_sidearm_starter_emberflint": "emberflint",
    "gun_sidearm_common_latch": "latch",
    "gun_sidearm_uncommon_echo": "echo",
    "gun_sidearm_rare_needle": "rare_needle",
    "gun_sidearm_legendary_dawnseal": "dawnseal",
    "gun_rifle_common_ridge": "ridge",
    "gun_rifle_uncommon_longpath": "longpath",
    "gun_energy_rare_splitfin": "splitfin",
    "gun_energy_legendary_monument": "monument_heart",
}
ART_FEATURES = {
    "emberflint": ("none", "none"),
    "latch": ("Fire_Recoil", "none"),
    "echo": ("Fire_Recoil, Core_Idle_Pulse", "mint capacitor rings"),
    "rare_needle": ("Fire", "cyan aim line"),
    "dawnseal": ("Fire, Charge", "solar chamber"),
    "ridge": ("Fire, Reload", "none"),
    "longpath": ("Fire, Reload", "cyan optic"),
    "splitfin": ("Splitfin_Charge", "amber core"),
    "monument_heart": ("Ring_Spin", "core and ring independently"),
}


def picture(item: dict) -> tuple[Path, str]:
    stem = ASSET_STEMS[item["id"]]
    candidates = [
        ROOT / f"assets/source/blender/{stem}/previews/hero.png",
        ROOT / f"assets/source/blender/{stem}/previews/{stem}_hero.png",
    ]
    for path in candidates:
        if path.is_file():
            return path, "Blender model"
    concept = CONCEPTS[item["id"]]
    views = concept["meshy_views"]
    key = "side" if "side" in views else "three_quarter"
    return ROOT / "assets/source/concepts/gear" / views[key], "v2 concept; model pending"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype(f"/usr/share/fonts/truetype/dejavu/{name}", size)


def short(text: str, width: int) -> str:
    return text if len(text) <= width else text[: width - 1].rstrip() + "…"


weapons = CATALOG["weapons"]
canvas = Image.new("RGB", (1920, 1390), "#131b29")
draw = ImageDraw.Draw(canvas)
draw.text((42, 27), "STARFORGE  /  GUN REFERENCE", fill="#f1eadb", font=font(42, True))
draw.text((44, 83), "Nine playable guns • current runtime balance values • tuning pending", fill="#a8b4c6", font=font(19))

for i, item in enumerate(weapons):
    col, row = i % 3, i // 3
    x, y = 35 + col * 635, 125 + row * 415
    draw.rounded_rectangle((x, y, x + 610, y + 394), radius=18, fill="#263348", outline="#526078", width=2)
    draw.text((x + 19, y + 15), item["name"], fill="#f5eee0", font=font(27, True))
    draw.text((x + 19, y + 50), f"{item['tier'].upper()}  •  {item['family'].upper()}", fill="#f5bd68", font=font(17, True))
    path, label = picture(item)
    art = Image.open(path).convert("RGBA")
    if label == "Blender model" and item["id"] != "gun_sidearm_legendary_dawnseal":
        background = Image.new("RGB", art.size, art.convert("RGB").getpixel((0, 0)))
        difference = ImageChops.difference(art.convert("RGB"), background).convert("L")
        bounds = difference.point(lambda value: 255 if value > 28 else 0).getbbox()
        if bounds:
            pad = 24
            art = art.crop((max(0, bounds[0] - pad), max(0, bounds[1] - pad),
                            min(art.width, bounds[2] + pad), min(art.height, bounds[3] + pad)))
    art.thumbnail((562, 238), Image.Resampling.LANCZOS)
    # A uniform card background shows true transparent reference crops cleanly.
    ax = x + 24 + (562 - art.width) // 2
    ay = y + 78 + (238 - art.height) // 2
    canvas.paste(art, (ax, ay), art)
    draw.text((x + 19, y + 316), label, fill="#9dacbf", font=font(14))
    speed = "instant beam" if item["projectile_speed"] is None else f"{item['projectile_speed']:g} m/s"
    damage = f"{item['damage']:g} HP"
    if item["shots_per_trigger"] > 1:
        damage += f" × {item['shots_per_trigger']}"
    draw.text((x + 19, y + 339), f"{damage}  |  {item['fire_interval']:g} s  |  {speed}", fill="#f4f1eb", font=font(17, True))
    draw.text((x + 19, y + 366), short(item["payload"], 62), fill="#b8c5d6", font=font(16))

canvas.save(DOC / "gun-reference-sheet.png", optimize=True)

lines = [
    "# Starforge gun reference sheet",
    "",
    "![All nine guns with tier and firing snapshot](gun-reference-sheet.png)",
    "",
    "**Status:** all nine guns are selectable and use these values in gameplay. Balance tuning and human visual review remain pending. All DPS figures ignore reloads, travel, falloff, and traits.",
    "",
    "The current Rift Skitter has **60 HP**. Projectile range below is speed × lifetime; beams are instantaneous within their listed range. A shot's first hit is at trigger time plus travel (and charge time where applicable).",
    "",
    "| Gun | Tier / slot | Payload | Damage | Interval | No-reload DPS | Speed / range | Capacity / recovery | Spread ADS / hip | Trait |",
    "|---|---|---|---:|---:|---:|---|---|---|---|",
]
for w in weapons:
    dps = w["damage"] * w["shots_per_trigger"] / w["fire_interval"]
    speed = "instant" if w["projectile_speed"] is None else f"{w['projectile_speed']:g} m/s"
    capacity = (f"{w['magazine']} shots / {w['reload']:g} s reload" if w["magazine"] is not None
                else f"{w['heat_capacity']} heat / {w['overheat_lockout']:g} s lockout")
    damage = f"{w['damage']:g}"
    if w["shots_per_trigger"] > 1:
        damage += f" × {w['shots_per_trigger']}"
    lines.append(f"| **{w['name']}** | {w['tier']} / {w['slot']} | {w['payload']} | {damage} | {w['fire_interval']:g} s | {dps:.1f} | {speed} / {w['max_range']:g} m | {capacity} | {w['spread_ads']:g}° / {w['spread_hip']:g}° | {w['trait']} |")
lines += [
    "",
    "## Why each step earns its tier",
    "",
    "- **Emberflint → Forge Latch:** 34 → 40 HP per shot and 23.1 → 34.8 m reach at the same 0.28 s cadence; Latch holds 9 rather than 10 and kicks harder.",
    "- **Forge Latch → Echo Bit:** two 26-HP bits make a 52-HP burst, and every third trigger can add one bounded 8-HP echo. Echo asks for two hits and a 1.60 s reload.",
    "- **Echo Bit → Vault Needle:** 100 m/s precision needles reach 100 m; a 1.5× weak-point hit deals 82.5 HP, enough for one 60-HP skitter. Six rounds and 0.42 s cadence reward aim over spam.",
    "- **Vault Needle → Dawnseal:** 0.27 s cadence, 12 rounds, and a one-per-reload 24-HP mark detonation improve sustained sidearm utility. Needle retains superior precision and range.",
    "- **Ridge Repeater → Longpath:** 45 vs 20 HP per round, 117 vs 72 m reach, and 0.20° settled ADS spread. Longpath gives up 30-round automatic fire for a 12-round semi-auto magazine.",
    "- **Splitfin Beam → Monument Heart:** Monument's 120-HP orb and bounded 50-HP radial pulse favor burst and clustered enemies. Splitfin keeps instant hits, sustained beam damage, and one-target pierce.",
    "",
    "## Exact firing rules and limits",
    "",
]
for w in weapons:
    travel = ("instant beam" if w["projectile_speed"] is None
              else f"{w['projectile_speed']:g} m/s for {w['projectile_lifetime']:g} s")
    lines += [
        f"### {w['name']} — {w['tier']} {w['family']}",
        "",
        f"- **Firing:** {w['payload']}; {w['damage']:g} HP per hit; {w['fire_interval']:g} s trigger interval."
        + (f" Burst spacing: {w['burst_spacing']:g} s." if "burst_spacing" in w else "")
        + (f" Charge: {w['charge_time']:g} s; recovery: {w['recovery_time']:g} s." if "charge_time" in w else ""),
        f"- **Travel and range:** {travel}; maximum {w['max_range']:g} m. Damage falloff begins at {w['falloff_start']:g} m and reaches {w['minimum_damage_fraction']*100:.0f}% at {w['falloff_end']:g} m.",
        f"- **Handling:** ADS/hip spread {w['spread_ads']:g}°/{w['spread_hip']:g}°; recoil {w['recoil_degrees']:g}°. "
        + (f"{w['magazine']} rounds; {w['reload']:g} s reload." if w['magazine'] is not None else f"{w['heat_capacity']} heat capacity; {w['heat_per_tick']} heat per tick, {w['heat_cool_per_second']} heat/s cooling, {w['overheat_lockout']:g} s overheat lockout."),
        f"- **Trait:** {w['trait']}",
        f"- **Tradeoff:** {w['tradeoff']}",
        f"- **Implementation:** {w['runtime_status'].replace('_', ' ')}.",
        "",
    ]
lines += [
    "## Art assets and review",
    "",
    "All nine models imported in Godot 4.7.2. Animation and emissive material names were inspected from the imported scenes. Open [`gunplay_sandbox.tscn`](../../scenes/sandbox/gunplay_sandbox.tscn) to test guns with 1–9 or Tab / Shift+Tab. The [Godot gallery contact sheet](gun-gallery-godot.png) records the nine runtime models. Final human visual review is pending.",
    "",
    "| Gun | Editable source | Runtime GLB | Render | Animation | Adjustable glow |",
    "|---|---|---|---|---|---|",
]
for w in weapons:
    stem = ASSET_STEMS[w["id"]]
    image_path, _ = picture(w)
    render = image_path.relative_to(ROOT)
    action, glow = ART_FEATURES[stem]
    lines.append(f"| {w['name']} | [Blender](../../assets/source/blender/{stem}/{stem}.blend) | [GLB](../../assets/models/gear/guns/{stem}/{stem}.glb) | [hero](../../{render}) | {action} | {glow} |")
lines.append("")
(DOC / "gun-reference-sheet.md").write_text("\n".join(lines))
print(f"Wrote {DOC / 'gun-reference-sheet.png'} and Markdown for {len(weapons)} guns")
