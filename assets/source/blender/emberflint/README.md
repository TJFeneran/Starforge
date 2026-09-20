# Emberflint — starter sidearm

Editable Astra-authored Blender reconstruction from **only** the three approved `assets/source/concepts/gear/meshy_views_v2/gun_sidearm_starter_emberflint/{side,top,front}.png` references. No original Meshy view assets are used. This is a hand-authored interpretation of the orthographic references, not an image extrusion or a Meshy-generated mesh.

Rebuild from the repository root:

```sh
blender -b --factory-startup -t 8 --python tools/build_emberflint.py
```

The source is `emberflint.blend`; runtime output is `assets/models/gear/guns/emberflint/emberflint.glb`. The build regenerates the packed Blender source, portable GLB, four 1100px studio renders, four 1024px PBR texture sets, and `emberflint_stats.json` with measured mesh statistics.

The reference design is a worn, pale plated compact pistol with dark forged frame, overlapping charcoal grip wraps, stepped armor courses, rear slide serrations, iron sights, exposed fasteners, an open trigger guard, and a recessed square muzzle. It has **no emissive material or glow**. Paint chips, oxide variation, scratches, grain and normal detail are stored in exportable image textures; visible wrap seams, plate breaks, rivets, and muzzle walls are geometry.

`Emberflint_GripOrigin` is the attachment root near the center of the grip. Overall length is 0.30 m. Blender +Y exports as Godot -Z; Blender +Z exports as Godot +Y. The named Receiver, Slide, Grip, Trigger, Muzzle and Controls assemblies export as six combined meshes; the source retains individually editable components and bevel modifiers. Assembly origins share the hand root; set animation pivots before authoring future trigger or reload animation.

Review `previews/hero.png`, `side.png`, `top.png`, and `front.png`. The side silhouette, top armor layout, grip wrapping and front square aperture were inspected against all three v2 references; the render pass corrected backing surfaces protruding through top armor and buried grip wraps.

Known limits: the source views are interpreted rather than matched pixel for pixel; the wrap is a simplified layered construction, UVs overlap and repeat material details, and there are no LODs, collision, hand rig or firing/reload animations. The separate Godot integration owns player mounting, gameplay and in-engine validation. Visual approval remains with the user.
