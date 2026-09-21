# Forge Bulwark A — Split Crown

Status: source generated, optimized, rigged, imported, and validated in the isolated Godot sandbox. Task `01a0c142-51e5-7489-bf44-2abff6c63644` consumed the approved 30 Meshy credits; no other paid operation was used.

Selected appearance: `assets/source/concepts/enemies/forge_bulwark/views/three_quarter.png`; front, side, and back references resolve bearings and torso-mounted crown supports. Target is 2.8 m tall including crown, feet on ground, Godot forward +Z.

## Planned clips and checks

| Clip | Loop | Review focus |
| --- | --- | --- |
| idle | yes | Slow weighted settling; chest core remains visible. |
| walk | yes | In-place heavy footfalls and planted intervals. |
| attack_anticipation | no | Both feet planted; forearms rise clear of shoulders and crown; visible hold. |
| attack | no | Two-arm overhead slam, obvious hand contact; record contact frame. |
| attack_recovery | no | Brief low hold, then push upright. |
| hit | no | Small mechanical stagger without implausible plate bending. |
| death | no | Kneel, collapse, and settle on floor; crown clears shoulder and ground. |

The original GLB is untouched at `assets/source/meshy/forge_bulwark/bulwark_a.glb`; unchanged embedded texture bytes are extracted in `bulwark_a_textures/`, and front, side, back, and hero inspection renders are beside it. The editable Blender rig is `bulwark_rigged.blend`; rebuild with `blender -b --factory-startup -t 4 --python tools/build_bulwark.py`. The Godot runtime GLB is `assets/models/enemies/forge_bulwark/bulwark.glb`.

The body was reduced from 114,658 to 94,019 triangles (18.0%) while preserving embedded 4K base/normal textures and original UVs. Sampled p99 source-to-optimized surface distance is 0.259 mm, maximum 0.626 mm. The model is 2.8 m tall including the crown, with a 44-bone mechanical rig and no unweighted vertices. The crown follows the upper torso. Major guards are rigid or nearly rigid, with blending through the dark couplings. The generated source retains apparent multi-digit hands, though exact four-finger-plus-thumb count is difficult to prove from rendered views.

`assets/models/enemies/forge_bulwark/animation_manifest.json` records all seven 30 fps clips. Attack lasts 1.2 s; **slam contact is frame 18 at 0.6 s**. The locomotion root remains in place. `godot --headless --path . --script tools/check_bulwark.gd` passes clip, movement, root, loop, and comparison checks. The sandbox preview is `scenes/sandbox/bulwark_preview.tscn`; record its labeled MP4 with `tools/record_enemy_preview.py`.
