# Rift Marksman — production brief

Status: **selected A — Needlecrest; four body and three weapon reference views complete**. Deliberate ranged attacker, target total height 1.9 m. The carbine is a separate 0.65 m prop.

## Anatomy and materials

Two arms, two legs, alien head, torso and neck. Model three thick fingers plus one thumb per hand; curled fingers can be partly occluded in the references. Use a relaxed A-pose with open separated digits, arms clear of torso, and feet apart. Selected A uses plantigrade legs.

Warm pale mineral/ceramic plates over navy flexible anatomy, muted teal tissue regions, small coral eyes/sensors. Hands and weapon stay separate. Avoid dangling cloth, cables, or extra appendages. Preserve the head crest as a rigid form.

## Rigging and weapon

Use a humanoid anatomical rig adapted to the selected proportions, with articulated fingers and independent head aim. Do not assume the armor-preview skeleton fits. Skin the flexible torso and joints; keep armor rigid or assigned to appropriate bones without bending its plates. Check shoulder caps, elbows, hip plates and knees at full range.

The separate carbine reference set is in `weapon/`; follow `weapon/brief.md` for primary-hand, support-hand and muzzle marker placement. In Blender preview poses, constrain support-hand IK to the gun while keeping the weapon a distinct object. Overall weapon length is 0.65 m; grip placement is defined anatomically and must be checked against the rigged hands.

| Clip | Intended motion and acceptance |
| --- | --- |
| idle | Alert small head scans; relaxed balance. |
| walk / strafe / run | Stable torso with clear foot placement; aiming can layer over walk/strafe. |
| attack_anticipation | Raise weapon, settle shoulders, hold a readable aiming beat. |
| attack | Controlled short recoil through arms/chest; grip remains attached. |
| attack_recovery | Return to aim, then lower if combat stops. |
| hit | Upper-body flinch without hands detaching from the weapon. |
| death | Clear collapse; weapon may release only when deliberately authored. |

Future locomotion clips should be in place. Check aiming up/down, turns, and two-hand grip for clipping. Required body views: front, side, back, three-quarter. Required separate weapon references: side, top, front.

## Reference review

Four views preserve the split crest, humanoid proportions, navy chest plates, teal torso and empty hands. Side view clarifies the three-finger-plus-thumb hand.

Small panel seams and curled digits vary in visibility. Enforce three fingers plus one thumb on BOTH hands in the mesh; do not infer a missing digit from occlusion.

See `../BLENDER_HANDOFF.md` for the later modeling and pose-validation workflow.
