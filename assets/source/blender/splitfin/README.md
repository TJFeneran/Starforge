# Splitfin — rare energy emitter

Authored with Astra from `assets/source/concepts/gear/meshy_views_v2/gun_energy_rare_splitfin/{side,top,front}.png`. The original concept sheet supplies ivory ceramic, aged gold, charcoal and amber material cues only. The v2 views use unconventional labels: `front` describes the broad sculpted face, `side` the narrow edge, and `top` the four-fin cross section. Review renders preserve those labels.

Rebuild from repository root:

```sh
blender -b --factory-startup -t 6 --python tools/build_splitfin.py
```

- Editable source: `splitfin.blend`, with named individual plates, gold rims, engravings, pivot caps and energy filaments.
- Runtime: `assets/models/gear/guns/splitfin/splitfin.glb`, including embedded PBR textures and the synchronized `Splitfin_Charge` transform clip. Godot forward is -Z; grip center is the origin; length is 0.62 m.
- Four named fin pivots open nine degrees during the 2 s demonstration cycle. Amber core orbits independently. Mechanical transforms are exported; emissive color can be changed independently via `Splitfin_Amber_Emission`.
- Three textured material sets: ivory, gold, charcoal; each has 512 px base color, packed roughness/metallic and normal maps. Amber emission is a separate material. Source textures are also packed into the Blender file.
- `previews/hero.png`, `front.png`, `side.png`, `top.png` are studio review images; `splitfin_stats.json` contains measured export metadata.

Gameplay values and firing behavior are owned by the central weapon catalog; this source does not install gameplay scripts or collision. The animation is a demonstration of the charge mechanism, not a gameplay timing constraint.
