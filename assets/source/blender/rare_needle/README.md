# Vault Needle — rare precision sidearm

The `rare_needle` runtime path is preserved for the existing lobby. Geometry is authored exclusively against `meshy_views_v2/gun_sidearm_rare_needle/{side,top,three_quarter}.png`; no original view directory is used.

```sh
blender -b --factory-startup -t 6 --python-exit-code 1 --python tools/build_rare_needle.py
```

The editable Blender file contains individually named components and packed modeling references. Updated v2 details include separate rear bolt cylinders, diagonal shroud vent louvers, and dorsal cyan status glass. Six 512 px PBR material sets have base color, packed roughness/metallic, and normal maps; maps are packed into the source and GLB. `Needle | pale cyan conductors` is independently recolorable and emissive.

`Fire` is a 0.4 second exported transform animation: a 14-degree trigger pull and 5 mm rear bolt travel, returning to rest. Named `Needle_Trigger_Pivot` and `Needle_Bolt_Pivot` keep the source animation editable. Gameplay timing is controlled by the central weapon catalog.

The grip origin, Godot -Z forward convention, and runtime GLB location remain unchanged. `rare_needle_stats.json` records measured dimensions and export metadata. The four images in `previews/` are hero, side, top and muzzle views. Textures use overlapping UVs; no collision is authored in this asset.
