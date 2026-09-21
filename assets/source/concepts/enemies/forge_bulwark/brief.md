# Forge Bulwark — production brief

Status: **selected A — Split Crown; four reference views complete**. Slow heavy bruiser, total height 2.8 m including the crown fins. The ring-backed candidate is not selected.

## Anatomy and construction

Two thick legs, two large arms, compact head, torso, broad ground-contact feet and articulated hands. Warm Starbone ceramic armor over dark navy mechanical bearings. Teal inset panels are quiet accents; an inset amber-white core supplies forge power; coral is restricted to hostile indicators. No floating pieces.

Major plates and gauntlets should transform as rigid pieces. Reserve smooth deformation for joint boots or small flexible couplings. Shoulder, elbow, hip, knee and ankle bearings need consistent axes in the orthographic references. Hands need a consistent digit count and sufficient finger clearance for closing into slam-ready fists.

The selected tall split fins attach to the upper torso, not head motion; the rear reference defines their support bridges. There is no halo ring on this selected design. The head and crown must not collide with raised forearms; verify this in the modeled slam pose.

## Animation requirements

| Clip | Intended motion and acceptance |
| --- | --- |
| idle | Slow settling of weight; core remains inset and unobscured. |
| walk | Deliberate heavy steps, broad support, no foot sliding. |
| attack_anticipation | Plant feet and raise both forearms; obvious pause before slam. |
| attack | Two-arm ground slam with body compression and visible contact. |
| attack_recovery | Hold weight low briefly, then push back upright. |
| hit | Small mechanical stagger appropriate to mass. |
| death | Kneel and collapse with controlled heavy body motion; no ring/crown penetration. |

Use an anatomy-specific mechanical rig; do not smooth-weight a solid plate across multiple rotating joints. Keep walk in place for future controller integration. Verify overhead reach, full knee compression, and slam contact in Blender. Required views: front, side, back, three-quarter.

## Reference review

Four views preserve two crown fins, two massive arms/legs and circular front core. Back view establishes torso-mounted crown supports, without an invented rear core.

Rear support bridge shape is inferred from the approved front concept. Static images do not prove crown/shoulder/forearm clearance during an overhead slam.

See `../BLENDER_HANDOFF.md` for the later modeling and pose-validation workflow.
