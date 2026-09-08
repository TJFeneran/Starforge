# Meshy → Blender → Godot defaults

Locked after Smart Topology kit quality failure (2026-09-07).

## Generation
- Default model: **Meshy 7**
- Default output: **`target_formats: ["glb"]`**
- Textured + PBR for production props
- Avoid Smart Topology for hard-surface architecture/props
- Characters intending rig/anim may still use FBX + T-pose when needed

## Blender
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
