# Gun asset pipeline: authored Blender → Godot

Status: current pipeline for the nine authored Blender guns (2026-09-20). This guide covers gun art assets; gameplay and progression remain defined in `docs/production/gun-progression-plan.md`. Meshy is used for the current armor art, not for these gun meshes. Each gun keeps an editable `.blend`, reproducible build script, runtime GLB, and review renders.

## References and geometry

1. Read the gun's entry in `assets/source/concepts/gear/manifest.json` for its target size and view paths. Use the current individual transparent views under `assets/source/concepts/gear/meshy_views_v2/<gun_id>/` as the **primary geometry references**. View labels vary by gun; inspect the actual files instead of assuming every set contains a front view.
2. Cross-check side, top, front or three-quarter views for the same silhouette, muzzle axis, grip, and feature placement. Resolve contradictions before building. The original concept sheet supplies material and fine-detail cues, not conflicting geometry.
3. Author the mesh in Blender with named, editable components. Give the receiver, grip, moving assemblies, trigger, and glow components separate geometry or material slots where the design requires them. Place pivots at real rotation points and retain a hand attachment root. Record the intended forward axis and real-world scale.

## Materials and export

- Use PBR base color, roughness/metalness, and normal maps with visible but restrained wear appropriate to each material. Check the appearance at the game's camera distance, not only in a close render.
- Keep independently adjustable emission materials for components whose glow color can change in gameplay. Avoid baking glow into the base color. Preserve their relative brightness when recoloring.
- Save the editable `.blend` and build script under `assets/source/blender/<gun_id>/` and `tools/`. Export a runtime GLB to `assets/models/gear/guns/<gun_id>/`. Keep named assemblies and animations in the GLB. Do not use a single fused static mesh for an articulated gun.
- Record dimensions, mesh/triangle count, material slots, pivots, animation names, texture resolution, and known limitations alongside the asset.

## Acceptance

Render side, top, front, and a three-quarter view from the actual Blender model. Compare them with the approved individual reference PNGs. Import the GLB into Godot, run it in `scenes/sandbox/gunplay_sandbox.tscn`, and check scale, orientation, attachment, moving components, independent glow colors, and material appearance. Verify muzzle placement, firing/reload behavior, and relevant collision before integrating a new or revised gun into gameplay. Add LODs when profiling shows a need. Keep current playable and lobby assets until a replacement passes those checks.

The nine-gun review is in `docs/production/gun-reference-sheet.md` and `docs/production/gun-reference-sheet.png`; `scenes/sandbox/gunplay_sandbox.tscn` exercises all nine playable guns. Firing values are in `docs/production/gun-balance.json`.

## Monument Heart example

`tools/build_monument_heart.py` builds `assets/source/blender/monument_heart/monument_heart.blend` and `assets/models/gear/guns/monument_heart/monument_heart.glb` from the three approved `meshy_views_v2/gun_energy_legendary_monument` views. Its `README.md` and previews document the art pass. Its charged orb, radial pulse, and ammo values run through `scenes/combat/gun_mount.gd`; test the weapon in `scenes/sandbox/gunplay_sandbox.tscn`.

## Emberflint starter example

`tools/build_emberflint.py` builds the 0.30 m pistol from the `meshy_views_v2/gun_sidearm_starter_emberflint` side, top, and front views. The editable source is `assets/source/blender/emberflint/emberflint.blend`; the runtime export is `assets/models/gear/guns/emberflint/emberflint.glb`. The player starts with Emberflint in the shared `scenes/combat/gun_mount.tscn`; the authored grip is at the hand origin and muzzle points along local -Z. Its own README and four renders record the art pass. Emberflint has no mesh emission; the shared runtime supplies its pulse and impact effects.
