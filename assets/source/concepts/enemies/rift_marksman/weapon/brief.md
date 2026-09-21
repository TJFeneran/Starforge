# Needlecrest energy carbine

Separate rigid prop for the selected Rift Marksman A; target overall length 0.65 m. Final references: `side.png`, `front.png`, and `top_v2.png`. `top.png` is superseded and must not be used for reconstruction.

Side view defines the two hand openings, primary angled pistol grip, broad forward support loop, short rear stock, and vertically stacked upper/lower muzzle shrouds. Front view defines the circular coral emitter and body cross-section. Corrected top view hides the lower shroud/emitter beneath the upper shroud. Small seams are surface details, not extra floating pieces.

Use navy structural body, pale ceramic outer panels, muted teal inset regions, small coral emitter/status accent. Leave grip openings open and large enough for the Marksman's three fingers plus thumb. Do not fuse hands or armor into the weapon during generation.

In Blender create three non-rendering attachment markers after the mesh is scaled:

- `grip_primary`: palm center on the angled rear pistol grip, just below the body and behind the trigger guard; align to the dominant hand's grip axis.
- `grip_support`: palm center on the sloping rear section of the large forward loop; orient to the support hand. Adjust the loop internally if needed for clearance without changing the main silhouette.
- `muzzle`: center of the coral emitter disk, pointing forward along the weapon's long axis.

These are anatomical placement instructions, not measured coordinates from the images. Verify both wrists, fingers, forearms and stock clearance in a two-hand aiming pose. The weapon has no deforming skin or internal firing animation requirement; recoil is driven by hand/body animation and projectiles by later gameplay.
