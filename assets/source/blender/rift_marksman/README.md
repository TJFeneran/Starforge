# Needlecrest / Rift Marksman animated model

Editable asset: `marksman_rigged.blend`. Godot export: `assets/models/enemies/rift_marksman/marksman.glb`. Review scene: `scenes/sandbox/marksman_preview.tscn`.

The original Meshy GLB and its textures remain in `assets/source/meshy/rift_marksman/`. The working model is 1.90 m from sole to crest, centered on the ground. Blender forward is -Y; the GLB/Godot forward is +Z.

## Optimization and skin

The body was reduced from 117,898 to 88,423 triangles (25%). Its UVs and original texture resolution were retained. Comparing every original vertex to the optimized surface gives 0.106 mm at the 99th percentile and 0.239 mm maximum; the reverse 99th percentile is 0.099 mm. The crest/hand subset has a maximum measured difference of 0.194 mm. These measurements sample vertices against triangle surfaces; the source comparison view also allows visual inspection of the silhouette and texture.

The fitted 51-bone skeleton has separate root, pelvis, spine, chest, neck, head, clavicles, arm/leg chains, toes, fingers, and a weapon socket. Every body vertex is weighted; local rigid ownership protects the head, plates, and boots, with narrow blends at flexible joints. Unlike the three-finger concept brief, the generated model has four fingers plus a thumb per hand. All generated digits were retained and rigged to honor the request to preserve this model's fidelity.

The Blender file contains a hidden `Source_Comparison` object with the full original geometry, the optimized mesh, the rig, all named actions, and review lighting. Toggle the hidden object only for comparison; it is excluded from the GLB export. Rebuild with `blender -b --factory-startup -t 4 --python tools/build_marksman.py` from the project root.

## Animation set

All clips are authored at 30 fps. Locomotion is in place: move the game controller separately. Blender's authored foot paths and two-arm IK are baked to ordinary bone keyframes for reliable GLB playback.

| Clip | Seconds | Playback |
| --- | ---: | --- |
| idle | 3.0 | Loop; low ready, restrained scan and breathing |
| walk | 1.2 | Loop; rifle carry and planted stepping |
| run | 0.7 | Loop; compressed posture and faster stride |
| strafe_left / strafe_right | 1.2 each | Loop; lateral movement with weapon aimed |
| aim | 2.0 | Loop; settled two-hand aim |
| attack_anticipation | 0.8 | One shot; lift from ready and settle |
| attack | 0.6 | One shot; recoil, fire marker at frame 4 (0.133 s) |
| attack_recovery | 0.9 | One shot; settle and lower |
| hit | 0.8 | One shot; upper-body flinch with retained grips |
| death | 2.4 | One shot; buckle, release support hand, fall and settle |

Godot import settings retain constant pose tracks so switching out of death correctly resets all bones. `tools/marksman_post_import.gd` records looping and the attack's `fire` marker. Automatic mesh LOD generation is disabled for this asset, so inspection shows the deliberate 25% reduction.

## Weapon and review

`Carbine_Grip_Reference` is a separate removable 65 cm procedural reference, used to author and inspect two-hand contact; it is not the final modeled Needlecrest carbine. The weapon uses `weapon_socket` under the right hand. Blender also includes primary/support/muzzle markers. Support-hand release is intentional only during death.

In the sandbox: Tab / Shift+Tab select clips, Space pauses, R restarts, A toggles cycling, C compares the original and optimized bind poses, G hides the reference weapon, drag orbits, and the wheel zooms. The scale ruler is 1.8 m. `--demo` plays the complete labeled recording sequence.

Validation: `validation.json` records geometry, weights, clip timing and reach checks; `motion_checks.json` records sampled floor contacts. Run `godot --headless --path . --script tools/check_marksman.gd` to verify the imported animation set, loop continuity, in-place roots, and source comparison. This package is an asset and sandbox preview; enemy AI, navigation, damage, and final weapon art are not integrated into the field.
