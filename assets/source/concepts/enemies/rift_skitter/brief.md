# Rift Skitter — production brief

Status: **selected B — Shieldback; five reference views complete**. Fast melee enemy, target height 1.2 m from ground to the highest neutral-pose point. Use `views/front_v2.png`; the original front view is superseded.

## Anatomy and materials

Exactly four walking legs, two forward and two rear, beneath a compact torso; no arms. Each leg uses a hip pivot, upper segment, lower segment, and terminal foot segment. Rigid navy carapace and warm pale mineral edge plates; teal flexible joint tissue; small coral eyes. Keep leg bases and feet separate in the neutral stance. The selected Shieldback has a broad beetle shell and short recessed head; do not restore the unselected tall neck/crest.

## Rigging and movement

Use a dedicated quadruped skeleton with body/root, optional short neck, head, and separate four-leg chains; do not reuse the humanoid armor rig. Rigid carapace follows body/head bones. Weight only joint tissue across bends. IK feet need stable contact; lift a foot rather than stretching the leg beyond its length. Resolve rear hip attachment with top/back views before rigging.

| Clip | Intended motion and acceptance |
| --- | --- |
| idle | Small body/neck movement; planted feet do not slide. |
| walk / run | Alternating diagonal support with readable foot lifts; faster run stays low. |
| attack_anticipation | Crouch body and draw front legs back; visible pause before release. |
| attack | Short forward lunge with front-leg sweep; hind legs supply the push. |
| attack_recovery | Front feet replant and body returns to stable stance. |
| hit | Brief recoil through body/neck; feet retain support where practical. |
| death | Body drops and legs fold away without passing through the shell. |

Future gameplay owns lunge translation and damage timing; keep reusable locomotion clips in place and provide an explicit attack contact cue. Inspect maximum crouch, full stride, and death for shell/leg intersections. Required views: front, side, back, top, three-quarter.

## Reference review

Five views preserve a four-legged Shieldback with separate paired hip sockets, broad shell, navy/teal regions and pale joints. Front correction reduces the rear-foot baseline mismatch.

Front/rear retain mild elevation and the stance is not pixel-calibrated across views. Top view resolves front/hind attachment order; use overall height and anatomical symmetry rather than tracing rear-leg perspective shortening.

See `../BLENDER_HANDOFF.md` for the later modeling and pose-validation workflow.
