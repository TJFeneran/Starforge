# Monument Heart — Blender prototype

Status: **visual direction approved; texture refinement ready for review**. This is an isolated art prototype, not a gameplay weapon. The editable Blender source is `monument_heart.blend`; the runtime export is `assets/models/gear/guns/monument_heart/monument_heart.glb`.

Build with `blender -b --factory-startup -t 8 --python tools/build_monument_heart.py` from the repository root. The script uses the side/top/front reference set in `assets/source/concepts/gear/meshy_views_v2/gun_energy_legendary_monument` as the design reference; modeling is authored geometry, not image extrusion.

The source retains 509 named component meshes and editable bevel modifiers. The GLB joins evaluated copies into six meshes: receiver, grip, rotating ring, core, trigger, and fixed muzzle mount. These six assemblies retain independent transform pivots. `RingRotor` pivots on the muzzle axis; `Trigger` pivots at its upper attachment. `MonumentHeart_GripOrigin` is the hand attachment root. Length is scaled to the manifest target of 0.95 m; the oversized disk is intentional. Blender +Y becomes Godot -Z.

To change the core glow in Blender, edit **Core_Emission_EDIT_COLOR** (faceted amber shell) and **Core_Fissures_Emission_EDIT_COLOR** (bright branching veins and center spark) → Principled BSDF → Emission Color / Emission Strength. The two materials intentionally retain different emission strengths. **Ring_Emission_EDIT_COLOR** independently controls the perimeter markings. These are separate exported glTF materials. The ring has a `Ring_Spin` animation; use frames 1–120 for preview.

Run `godot --path . res://scenes/sandbox/gunplay_sandbox.tscn` and select gun 9 to test Monument Heart in Godot. The runtime model retains its independent core and ring materials and `Ring_Spin` animation.

`previews/hero.png`, `side.png`, `front.png`, and `top.png` are actual Blender renders; `previews/godot_textures.png` is a Forward+ Godot capture. Non-emissive surfaces use 1024px tiled base color, packed roughness/metalness, and tangent normal maps that export to glTF. UVs intentionally overlap and are unsuitable for unique lightmap baking without an additional UV set.

Refinement follows the three v2 orthographic PNGs as the primary geometry reference: circular amber orb and concentric bezel, slab receiver with stepped top plates, angled grip, and open trigger guard. Ivory course joints, branching incisions, small chips, baked hairline weathering, fine amber radial rays, and navy index marks add detail. The original concept sheet supplies material and fine-detail guidance only.

Known limits: this is an authored interpretation of the reference, with simplified chipping and rear surfaces. It has no hand rig, collision, LODs, gameplay hookup, or firing/reload animation. The test demonstrates editable geometry, pivots, export, and independently controlled emission; visual approval is still required.
