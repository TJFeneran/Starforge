# Latch

Astra-authored editable Blender asset reconstructed from `assets/source/concepts/gear/meshy_views_v2/gun_sidearm_common_latch`. Original concept informs material colors only.

Rebuild with `blender -b --factory-startup -t 6 --python tools/build_latch.py`. Runtime export: `assets/models/gear/guns/latch/latch.glb`. Blender +Y is Godot -Z, with grip-center origin. Separate assemblies preserve recoil and core transforms.

Five packed 1024px PBR material sets; non-emissive enamel and rubber; Fire_Recoil transform clip. No gameplay stats are encoded here. Art measurements are in the adjacent export stats JSON.

Four studio renders in previews: hero, side, top, front. This is a geometric interpretation, with surfaces traced/inferred from the provided views, not a photogrammetric scan.
