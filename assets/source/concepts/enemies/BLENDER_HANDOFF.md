# Enemy reconstruction and animation handoff

These are authored image references, not a measured multi-camera scan. The approved three-quarter image in each `views/` directory defines appearance; the manifest names the final auxiliary views and marks superseded drafts. Overall height/wingspan is authoritative. Small panel seams and apparent projected lengths must not be treated as independent dimensions.

## Model stage

Use Meshy for a textured starting mesh, beginning with the Marksman body. Keep its carbine separate. Start with the approved three-quarter image; only add auxiliary images when they agree on anatomy and proportions. Keep the source output untouched and work on a Blender copy. Do not turn highlights, scratches, coral light, or deep shadows into geometry.

Set meters and scale the neutral model before rigging: Skitter 1.2 m tall, Marksman 1.9 m tall, Bulwark 2.8 m including crown, Ray 1.6 m neutral wingspan, carbine 0.65 m long. Center a ground enemy's root on the ground beneath its support center; center the Ray's root inside its body. Export to the repository's established Godot-facing convention, then verify forward movement and muzzle direction in the sandbox rather than assuming Blender's axes transfer unchanged.

Check for fused fingers, fused legs, closed grip holes, duplicate surfaces, paper-thin fins, floating armor and inaccessible joint gaps. Repair/remodel only the affected areas while preserving the approved silhouette, UVs and useful materials. Add deformation topology around flexible joints; rigid armor does not need to be smoothly weighted across a bend. Prefer one rigid bone influence for a solid plate, with separate flexible tissue at the joint.

## Skeleton and rigid-part ownership

| Enemy | Skeleton and ownership | Critical pose checks |
| --- | --- | --- |
| Skitter | Body, short head articulation, four independent hip-to-foot chains; each leg's upper/lower/foot segment rotates independently. Shell follows body; no shell weights leak into legs. | Deep crouch, front-leg sweep, maximum stride, planted diagonal support, collapse. |
| Marksman | Humanoid anatomical rig adjusted to crest/neck proportions; three fingers plus thumb per hand. Head aim independent of torso. Armor follows relevant limb; flexible abdomen/neck bend. | Two-handed aim, elbow flexion, shoulder raise, strafe, hip/knee compression and death. |
| Bulwark | Mechanical humanoid; four fingers plus thumb per hand. Crown fins and support bridges follow upper torso, not head or arms. Bearing axes align across connected parts. | Raise both forearms for slam without striking crown; full elbow fold, heavy step and kneeling death. |
| Ray | Root/body, one short fin chain per side and one tail chain. Root shell rigid; teal fin tissue smooth-weighted. Divide pale fin rim into rigid segments following the fin chain. | Fin up/down extremes, left/right bank, tail correction and folded-fin death. |

Do not force the Skitter or Ray into the armor-preview humanoid skeleton. The body references do not include a verified deforming mesh or certified animation range. A neutral-pose match alone is insufficient.

## Animation authoring defaults

Use 30 fps for the initial preview clips. Keep locomotion in place, with translation driven later by the Godot controller. Loop idle and locomotion cleanly; attack, hit and death clips are one-shots. Record the attack contact frame separately so gameplay can later align damage/VFX without inferring it from clip length. No combat timing or damage API changes are part of this asset phase.

- Skitter walk: alternate diagonal leg pairs, visibly lifting each foot before moving it; body stays supported. Run compresses the body and increases cadence rather than sliding feet. Lunge has a low crouch, a visible hold, front-leg extension, contact, and deliberate replant.
- Marksman: aim settles before firing; recoil moves arms/chest while both grips stay attached. Keep head tracking restrained and readable. Weapon is parented to the dominant hand; support hand uses a target on the separate foregrip.
- Bulwark: weight transfers before each heavy foot lift. Slam has planted feet, a broad raised-arm silhouette, a visible hold, ground contact, and a slower recovery. Avoid stretching rigid pistons or folding plates.
- Ray: hover uses small fin motion around a stable body, forward flight adds coordinated strokes, and banking combines root roll with fin/tail compensation. Attack turns the forward aperture toward the target, steadies, pulses, and returns to hover. Projectile/beam effects remain outside the mesh.

Each per-enemy `brief.md` lists the required clips and visual acceptance. Capture at least bind/neutral, locomotion contact and passing poses, attack anticipation/contact/recovery, and hit/death extremes in Blender. Review front, side, and three-quarter cameras for intersections, collapsing weights and silhouette loss. Retiming is expected once gameplay is integrated; these notes specify movement intent, not final balance.

## Projection and design caveats

- Skitter front/back retain slight elevation. Use the top view to place four hip sockets in paired front/hind positions, and the side view for shell depth. Keep bilateral symmetry rather than reproducing perspective-shortened rear legs.
- Marksman's partially curled hands can hide a digit. The model contract is three fingers plus one thumb on each hand, regardless of visibility in a particular render.
- Bulwark back supports are a reasoned completion of previously unseen geometry. Use the rear view's torso attachments; adjust internal clearance without changing the visible crown outline.
- Ray front/back are elevated. Use side and top for body/tail depth and planform, and the selected three-quarter for appearance. The generated pale fin border is not consistently segmented: make it articulated in the mesh; never stretch it like skin.
- Carbine top_v2 corrects the first top view's shroud interpretation. The pale muzzle shrouds sit above and below the emitter, not on its left and right. Side controls length/profile; front controls cross-section; minor upper panel seams are secondary.

## Godot promotion later

Export a GLB with textures, skeleton and named clips into a new enemy sandbox. Include a 1.8 m hero proxy and simple intentional collision shapes. Verify meter scale, facing, ground/hover origin, material appearance under game lighting, looping, foot contacts, two-hand grip, attack readability and frame cost. Capture a screenshot or short recording. The lobby, forge field and existing combat Skitter remain unchanged until the pilot passes this check.

Meshy spend requires the repository's normal credit approval before generation. This reference pack incurred no Meshy spend and creates no runtime model.
