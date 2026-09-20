# Trail Warden — Meshy 7 rigged review asset

- Editable source: `trail_warden_meshy_rigged.blend` (packed original PBR images).
- Preview/game candidate: `trail_warden_meshy_rigged.glb` (one mesh, one PBR material, 35,581 triangles, four skin influences maximum).
- Raw generated source: `../../meshy/armor_common_trail_warden/armor_common_trail_warden.glb`; remains unchanged at 59,654 triangles.
- Exact 112-bone Exo Gray skeleton retained. Mesh T-pose fitted to its shoulders, elbows, wrists, hip/knee heights and head height. UVs preserved through decimation.
- Skin weights transferred barycentrically from the existing character, with rigid head/helmet, belt attachment and separate thigh ownership for the hip drape. 211 generated bridge faces were removed to open the fused center seam between moving legs, preserving the remaining UVs.
- Generated finger webbing is assigned shared four-finger flex, with independent thumb. This avoids tears from independent finger motion; individual trigger-finger posing would require finger topology cleanup.
- Existing run, pistol aim and idle clips tested in Blender. See `previews/` and `validation.json` for pose evidence and numeric checks.
- `.gdignore` intentionally excludes this review directory from Godot import. No game scenes were changed.

Rebuild with Blender from the project root:

```
blender -b --factory-startup -t 4 --python assets/source/blender/armor_common_trail_warden/rig_meshy_trail_warden.py
blender -b --factory-startup -t 4 --python assets/source/blender/armor_common_trail_warden/validate_meshy_trail_warden.py
```
