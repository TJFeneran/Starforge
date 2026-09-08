# Starforge Visual Bible

Status: v1.0 — frozen after Meshy forge-beacon pipeline validation

## Core promise

Starforge is bright, heroic space fantasy: recognizable human-scale frontier life beneath monumental celestial technology. Realistic materials make the world tangible; saturated color and luminous forge energy make it aspirational. The visual target is cinematic and readable at a third-person gameplay camera, not photorealism for its own sake.

## Visual pillars

1. **Monumental clarity** — large, legible masses before surface detail. Architecture reads as arches, fins, rings, and buttresses from a distance.
2. **Tactile optimism** — sunlit painted metal, pale ceramic, fabric, plants, and warm occupied spaces. Wear implies use, not collapse.
3. **Sacred technology** — forge mechanisms use radial symmetry, suspended elements, and precise amber-white light. Energy is rare and compositionally important.
4. **Colorful frontier** — cyan skies, mineral terrain, banners, and planted life give settlements identity without becoming neon noise.
5. **Hero readability** — the player is a dark-medium value silhouette with a restrained cobalt identity color and a small warm energy accent.

## Palette

Use color by role. The ratio is a target for a representative gameplay frame, not a per-object recipe.

| Role | Name | sRGB | Target use |
|---|---|---:|---:|
| Dominant light neutral | Starbone | `#D9D5C7` | 28% |
| Dominant dark neutral | Void Navy | `#172133` | 20% |
| Environmental ground | Sunbaked Ochre | `#A66A3F` | 14% |
| Environmental sky/fill | Horizon Cyan | `#52B7C8` | 12% |
| Human technology | Frontier Cobalt | `#245AA8` | 10% |
| Planted/alien life | Verdant Teal | `#287F78` | 7% |
| Forge energy | Solar Amber | `#FFB238` | 5% maximum |
| Friendly signal | Signal Mint | `#7FE0C3` | 2% |
| Danger only | Flare Coral | `#E64D45` | 1% |
| Peak emissive | Core White | `#FFF4D6` | 1% |

Rules:
- Neutrals and environment occupy at least 70% of a frame.
- Cobalt identifies inhabited frontier technology and the hero; it is not universal trim.
- Amber means active forge power, objectives, or wonder. Never use it as ambient decoration everywhere.
- Coral is reserved for danger, hostile telegraphs, and destructive heat.
- Keep UI mostly Void Navy, Starbone, and one contextual signal color.

## Shape language

### Frontier human technology
- Broad chamfers, practical rectangular masses, visible attachment points, fabric shade panels.
- One bold cobalt panel per major object; remaining surfaces are Starbone, dark understructure, or raw metal.
- Details cluster around function. Leave 60–70% of each large surface visually quiet.

### Celestial forge technology
- Rings, radial apertures, tall split fins, floating concentric parts, and impossible clean seams.
- Pale ceramic or dark iridescent metal around a narrow amber-white core.
- Symmetry communicates dormant order; controlled asymmetry shows human adaptation.

### Hero
- Athletic but believable proportions; clear head/shoulder/torso/leg separation.
- Long asymmetric mantle or hip panel only if it does not destroy the gameplay silhouette.
- Helmet and backpack form one memorable profile. No dense greeble over the whole suit.

### Alien nature
- Fan leaves, translucent edges, clustered vertical reeds, and smooth mineral growth.
- Nature uses teal and cyan families; it must not compete with amber forge energy.

## Materials

- **Painted alloy:** medium roughness, subtle edge wear, large color blocks, no uniform scratches.
- **Starbone ceramic:** warm off-white, low-frequency mottling, soft rough highlights, hairline seams.
- **Technical understructure:** dark navy-black metal, restrained specular response, detail mostly in shadow.
- **Forge glass/energy:** amber core toward Core White, tight bloom, surrounded by darker values.
- **Frontier textile:** woven matte cloth in cobalt, ochre, or muted coral; use for shade and human scale.
- **Ground:** ochre stone and dust with sparse teal vegetation; broad value shapes before decals.

## Lighting and atmosphere

- Default time: clear late morning, not orange sunset. Directional sunlight is warm-neutral; sky fill is cyan.
- Maintain readable local color in shadow. Avoid crushed blacks and gray overcast grading.
- Ambient world energy stays low; focal forge elements may bloom, but their silhouettes must remain visible.
- Use atmospheric depth to simplify distant monumental forms. Foreground contrast is strongest.
- Gameplay exposure must preserve Starbone surfaces and Core White emissives simultaneously.

## Camera and composition

- Third-person test camera: approximately 6–8 m behind and 2.5–3.5 m above the hero, 60–70° horizontal field of view.
- Compose settlements with one monumental vertical, one inhabited horizontal, and one luminous focal point.
- At gameplay distance the hero, traversal path, interactable, and hazard must be separable by silhouette and value before color.

## Anti-goals

- No grimdark blanket grime, skull motifs, or hopeless industrial decay.
- No generic NASA-white hard-surface realism or contemporary military camouflage.
- No cyberpunk city palette, omnipresent neon strips, or magenta/cyan on every asset.
- No procedural greeble noise used to compensate for weak primary forms.
- No toy-like plastic realism; materials need scale, roughness variation, and believable assembly.
- No literal copying of another franchise's symbols, armor, architecture, or branded motifs.

## Style-lab acceptance gate

A frame passes only when:
- The world reads as bright space fantasy without explanation.
- Hero, path, and active forge object read at gameplay camera distance.
- At least 70% of the frame remains neutral/environmental.
- Amber is the strongest focal accent and occupies no more than about 5%.
- Materials remain distinct without close-up inspection.
- Monumental forms read before secondary detail.
- The scene feels inhabited and hopeful rather than sterile or grim.


## Freeze note

Visual Bible **v1.0** is frozen after the forge-beacon Meshy 7 → Blender → Godot validation.

Known follow-ups before batch production (from forge-beacon v1 review):
- **Scale:** first Meshy beacon landed undersized vs hero/outpost; enforce real-world height in Meshy (`auto_size` / resize) and verify against a 1.8 m hero proxy in style lab before accepting.
- **Mesh fidelity:** rough edges / low silhouette clarity → raise remesh target (≈40–80k for hero props), prefer clean concept silhouettes with broad chamfers, avoid tiny surface noise in the source image.
- **Texture pixelation:** use cleaner concept pixels and consider 4K texture on hero/signature props; keep large flat material blocks instead of fine painted noise that Meshy bakes into mush.
- Prefer Starbone ceramic over gold on structural fins in texture prompts.
- Keep forge energy closer to Solar Amber / Core White; avoid greenish cores.
- Continue using isolated prop concepts for Meshy; keep environment keyframes inspirational only.
