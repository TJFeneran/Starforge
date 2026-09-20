# Meshy → Blender → Godot defaults

Updated 2026-09-20. Use this for Meshy props and armor; the nine current guns follow `gun-blender-pipeline.md`.

## Generation
- Default model: **Meshy 7**
- Default output: **`target_formats: ["glb"]`**
- Textured + PBR for production props
- Avoid Smart Topology for hard-surface architecture/props
- Characters intending rig/anim may still use FBX + T-pose when needed
- For armor, use the approved individual front, side, and back concept images; record the Meshy task ID, settings, and credit spend beside the source GLB. Get credit approval before starting a batch.

## Blender for static props
```bash
blender --background --factory-startup \
  --python tools/blender_asset_pipeline.py -- \
  "assets/source/meshy/<asset>/<asset>.glb" \
  "assets/models/<asset>.glb" \
  --blend "assets/source/blender/<asset>.blend" \
  --target-height <meters>
```
- Preserve Meshy materials when textures exist
- `--force-rebind` only if materials are missing textures

## Rigged armor

The nine armor previews use textured Meshy GLBs in `assets/source/meshy/armor_*/`, editable Blender rigs in `assets/source/blender/armor_*/`, and exported Godot GLBs in `assets/models/gear/armor/previews/`. Keep the original geometry, UVs, and textures; add a skeleton and skin weights in Blender. A single Meshy mesh can deform under one armature, but shoulders, hips, cloth, and helmet pieces need weight review across several poses. The current exports share a 112-bone skeleton and are checked in bind, walk, run, strafe, jump, and aim poses.

Import into `scenes/sandbox/armor_preview.tscn` for side-by-side comparison before any gameplay integration. The preview is a visual lineup, not a functional six-slot armor system. Its usual displayed total height is 1.8 m; Signal Mantle and Horizon Aegis are 2.16 m including tall helmet pieces. Keep the player rig and collision decisions separate from preview normalization.
