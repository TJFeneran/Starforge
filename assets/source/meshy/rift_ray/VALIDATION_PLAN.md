# Crescent Ray validation plan

Reference: selected `rift_ray/views/three_quarter.png`; use `front_v2.png`, side, back and top only to resolve hidden anatomy. The original `front.png` is superseded.

## Source inspection before rigging

- Render front, side, back, top and three-quarter. Confirm exactly two thick crescent fins, one short central tail, two coral eyes and one facial aperture. Check dorsal navy shell, pale underside, teal fin tissue and segmented ceramic edges.
- Compare the wings against the approved 1.6 m silhouette. Reject extra fins/legs, a long ribbon tail, paper-thin fin tissue or a continuous ceramic rim that would need rubber deformation.
- Preserve the untouched GLB and exported texture maps in this directory.

## Blender asset checks

- Body origin at its neutral hover center; +Z forward in Godot. Wingspan 1.6 m. A non-deforming shell/head core, left and right fin chains, and a short tail chain. Rigid shell and rim pieces follow local bones; teal tissue blends around roots and hinges.
- Compare source and optimized triangle counts, texture dimensions and UVs, plus sampled one-way/reverse surface error. Choose the smallest reduction that retains tip curvature, eye/aperture readability, shell panel edges and segmented rim. Inspect side-by-side silhouette in neutral and extreme fin poses.
- Ensure every vertex is weighted and test full up/down fin excursion, both banks and tail bend. Check for fin/body intersections, collapsed fin thickness or moving cream shell strips.
- Bake 30 fps clips: `hover_idle`, `fly_forward`, `bank_left`, `bank_right`, `attack_anticipation`, `attack`, `attack_recovery`, `hit`, `death`. Loops return to their first pose; locomotion has no forward translation. Attack manifest records the face-aperture contact frame. Death loses lift, folds fins and tips; gameplay will manage actual descent and collision.

## Godot/video checks

- Import `assets/models/enemies/rift_ray/ray.glb`; verify all nine named clips, loop flags, bone motion, facing and centered origin. Playback in `scenes/sandbox/rift_ray_preview.tscn` must show a hovering Ray at 1.35 m for review, with a 1.6 m ruler and the untouched source comparison.
- Record `--demo` with labels, all clips and a turntable through `tools/record_enemy_preview.py`. Inspect representative frames from every clip for deformation and readability, then send the H.264 MP4 through Google Drive.
