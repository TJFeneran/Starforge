# Enemy production reference pack

The user selected **Skitter B (Shieldback), Marksman A (Needlecrest), Bulwark A (Split Crown), and Ray A (Crescent)**. Their reference sets are complete: **18 body views and 3 separate weapon views**, created with the built-in image generator. This is concept/reference delivery only; no new Meshy models, Blender rigs, animations or Godot runtime changes were made.

Open [index.html](index.html) for the selected production gallery; [candidates.html](candidates.html) preserves the original A/B exploration. [BLENDER_HANDOFF.md](BLENDER_HANDOFF.md) gives the reconstruction, rigging, animation and Godot validation instructions. Each enemy also has a `brief.md`; the Marksman's separate carbine has its own `weapon/brief.md`.

| Selected design | Scale | Final body references |
| --- | --- | --- |
| Skitter B — Shieldback | 1.2 m overall height | `rift_skitter/views/`: `three_quarter.png`, `front_v2.png`, `side.png`, `back.png`, `top.png` |
| Marksman A — Needlecrest | 1.9 m overall height | `rift_marksman/views/`: `three_quarter.png`, `front.png`, `side.png`, `back.png` |
| Bulwark A — Split Crown | 2.8 m including crown | `forge_bulwark/views/`: `three_quarter.png`, `front.png`, `side.png`, `back.png` |
| Ray A — Crescent | 1.6 m neutral wingspan | `rift_ray/views/`: `three_quarter.png`, `front_v2.png`, `side.png`, `back.png`, `top.png` |

Carbine: `rift_marksman/weapon/side.png`, `front.png`, `top_v2.png`; target length 0.65 m. Keep it separate from the body and hands.

## How to use the pack

The selected three-quarter image is the approved appearance reference. The additional views complete hidden anatomy and help reconstruction; they are not individually user-approved designs or calibrated CAD drawings. Start a Meshy pilot with the Marksman body and its selected three-quarter image. Use consistent auxiliary views where useful; do not upload this gallery or a collage as a model source. Preserve the original Meshy mesh/materials, then inspect and refine in Blender.

The Skitter and Ray front/rear images retain slight camera elevation despite correction passes. Do not trace their apparent depths or foot baselines literally. Use their side/top views, overall scale and bilateral anatomy together. Detailed view findings, limitations and the rigid/deforming part rules are in the manifest and handoff. The Ray's ceramic fin border must be articulated in the mesh even where the render does not show segmentation. Bulwark crown clearance must be tested through an overhead slam.

The manifest explicitly identifies selected references and superseded drafts. Old Skitter/Ray `front.png` and weapon `top.png` remain for provenance; use their replacement filenames above. Exact generation and correction prompts are saved alongside their images as `*_prompt.txt`; the original candidate prompts remain in each enemy directory. `manifest.json` records image dimensions, SHA-256 hashes, source generation paths, reference inputs, review findings and the selected variants.

## Validation and next stage

All 21 selected reference files were decoded and visually inspected during generation; completeness, prompt links and provenance were checked. Major anatomy and color regions are consistent enough for modeling guidance, with projection and secondary-detail limitations documented. No deformation, topology, animation or gameplay success is implied by an image review.

The source directory is already excluded from Godot imports by `assets/source/.gdignore`; these images do not add runtime textures. The next production milestone is one Meshy-to-Blender Marksman pilot, followed by an enemy sandbox with a 1.8 m hero proxy, simple collision, animation controls and visual evidence. Follow `docs/art/meshy-pipeline.md`, including confirming credit spend before generation. Keep the current combat Skitter, lobby and forge field unchanged until a replacement passes the normal promotion gate.
