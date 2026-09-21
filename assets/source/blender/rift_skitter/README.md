# Rift Skitter B — Shieldback

Selected source: `../../meshy/rift_skitter/shieldback_b.glb`, task `01a0c13f-d3ec-7325-ae43-8c48111b7bdf` (Meshy 7, one 30-credit textured/PBR 4K build). This is distinct from the older `rift_skitter.glb`, which depicts the superseded tall-crested design.

Rebuild with `blender -b --factory-startup -t 4 --python tools/build_skitter.py`. It preserves the source file, normalizes the creature to 1.20 m, applies an 18% conservative triangle reduction, fits a 20-bone four-leg rig, and bakes eight 30 fps clips. Output is `skitter_rigged.blend` and `../../../models/enemies/rift_skitter/skitter.glb`. Meshy textures remain embedded. `validation.json` records geometry and rig checks; the runtime `animation_manifest.json` records clip durations and the attack contact cue.

Use `godot --headless --import --path .` and `godot --headless --path . --script tools/check_skitter.gd` to check the imported rig. The review scene is `scenes/sandbox/rift_skitter_preview.tscn`; Tab changes clips, C compares source and optimized meshes, mouse drag orbits, and `--demo` plays the complete sequence. The phone video is `previews/skitter_animation_review.mp4`; verify it with `python3 tools/record_enemy_preview.py --verify-only --output assets/source/blender/rift_skitter/previews/skitter_animation_review.mp4`.

Animation uses in-place movement. Gameplay owns translation, collision, damage, and navigation. The attack clip is 0.700 s, with the melee contact marker at frame 8 (0.2667 s). Blender front is -Y; the Godot imported model faces +Z. The generated source is one contiguous mesh, so rigid plates and joint tissue use nearest-bone assignment. Review extreme movement in the first-level encounter before treating this as final combat art.
