# Rift Ray — production brief

Status: **selected A — Crescent; five reference views complete**. Flying harasser, neutral wingspan 1.6 m. Use `views/front_v2.png`; the original front view is superseded.

## Anatomy and materials

One substantial central body, exactly two lateral fins, and one tail assembly; no legs, arms, or tentacles. Navy rigid dorsal shell and warm pale underside/edge plates, muted teal flexible fins, two coral eyes and a small forward energy organ. The selected Crescent has broad curved fins and a short tapered tail; do not use the unselected Hammerhead's paddle fins or tall rudder.

Fin roots and undersides need top, back and side views. Generated ivory fin-edge material appears rigid: shorten it to the root or divide it into articulated segments before expecting the fins to bend. Do not elastically warp a continuous ceramic rim. Keep thick fin volume and avoid paper-thin membranes.

## Rigging and animation

Use root/body/head as needed, a short chain per fin from root to tip, and a short tail chain. Weight fin roots smoothly; dorsal plates follow rigid body bones. Banking primarily rotates the body, with secondary fin/tail motion. Preserve left/right anatomical symmetry even when the reference camera foreshortens one fin.

| Clip | Intended motion and acceptance |
| --- | --- |
| hover_idle | Small fin undulation; stable average body position. |
| fly_forward | Gentle coordinated fin stroke; no hard-coded forward travel. |
| bank_left / bank_right | Body roll plus fin/tail adjustment, without fins clipping the shell. |
| attack_anticipation | Head pitches toward target, fins steady, readable short hold. |
| attack | Brief forward-body pulse aligned with the facial energy aperture; projectile is a separate runtime effect. |
| attack_recovery | Return smoothly to level flight. |
| hit | Small roll/pitch recoil followed by correction. |
| death | Fins lose support and fold as the body tips; later gameplay handles descent and ground collision. |

Blender must verify extreme fin up/down poses and banks, not just a neutral hover. Required views: front, side, back, top, three-quarter. Future Godot origin should be centered in the body at the neutral hover position, with flight height managed by gameplay.

## Reference review

Five views preserve two thick crescent fins, one central tail, navy dorsal shell, pale belly and coral face. Top and side clarify planform and body depth.

Front and back retain an elevated angle; they are appearance aids, not calibrated elevations. Tail foreshortening varies. Fin-rim segmentation is not consistently visible in generated views: keep root shell rigid and segment the pale rim when modeling, as specified in the brief.

See `../BLENDER_HANDOFF.md` for the later modeling and pose-validation workflow.
