# Starforge Concept Prompt Templates

These prompts describe an original visual language. Do not request franchise characters, symbols, or exact replicas.

## Shared style lock

Append to every concept prompt:

> Original bright heroic space-fantasy art direction, realistic physically based materials, monumental clean primary forms, sunlit late-morning atmosphere, warm light with cyan sky fill, Starbone warm ceramic, Void Navy understructure, restrained Frontier Cobalt panels, rare Solar Amber forge energy, teal alien vegetation, cinematic but designed for readable third-person gameplay. Tactile and inhabited, not grimdark, not cyberpunk, no logos, no text, no watermark, no excessive greebles.

## Frontier outpost keyframe

> Wide third-person gameplay keyframe of a colorful frontier outpost on an ochre alien plateau. A human-scale cobalt-and-Starbone shelter and market shade sit beneath one immense ancient split-ring forge monument. Teal fan plants frame a clear traversable path. One compact amber forge beacon is the focal point. Include a small back-facing hero for scale. 16:9, 65-degree gameplay camera, broad readable value groups.

Purpose: mood, composition, lighting, and scale only. Never send the full scene to Meshy.

## Hero turnaround

> Full-body original frontier guardian, realistic athletic human proportions, practical layered space armor with broad Starbone plates over Void Navy undersuit, one restrained cobalt shoulder-to-torso identity panel, compact backpack with a small amber power core, memorable clean helmet profile. Neutral T-pose, arms separated, legs separated, no weapon, no cape crossing the silhouette. Orthographic front, side, and back views of the exact same design, even neutral studio lighting, plain light-gray background, all parts uncropped.

Purpose: character bible and later character reconstruction.

## Signature forge beacon

> Single freestanding celestial forge beacon, clearly 2.2 meters tall next to an implied human scale, original design: heavy Starbone ceramic base, dark navy mechanical cradle, two clean split vertical fins around one suspended amber-white energy core, subtle cobalt human repair panel. Strong radial logic, broad hard-surface chamfers, razor-clean silhouette edges, 70 percent quiet surfaces, stable footprint. Isolated object, front three-quarter view, full silhouette, neutral gray background, even lighting, minimal perspective, no floor clutter, no fine noise, no soft painterly blur.

Purpose: first static Meshy validation asset. For remakes: prioritize sharp edges, large material blocks, and explicit height cues over decorative micro-detail.

## Meshy-ready concept rules

- Sharp silhouette; no motion blur, depth-of-field, or soft painterly edges.
- Large readable material blocks; avoid dense surface noise that becomes texture pixelation.
- One object only; full frame; no tiny distant props.
- State real-world size in the prompt and verify in Godot against a 1.8 m hero proxy.

## Armor loadout turnaround (Grok 2D)

Generate with Grok image models only. Do not use Meshy for 2D.

> Full-body original 1.8 m athletic frontier operative wearing one functional armor loadout, realistic athletic human proportions, clear head/shoulder/torso/leg separation. Neutral T-pose, arms separated, legs separated, no weapon, no cape crossing the silhouette. Orthographic front, side, and back views of the exact same design, even neutral studio lighting, plain light-gray background, all parts uncropped, sharp silhouette, large material blocks, no text, no logos, no watermark.

Purpose: the individual front/side/back images under `assets/source/concepts/gear/armor_views/` were used for the nine Meshy armor previews. Keep starter kits incomplete (no full helmet, no trinket) in future concepts, and escalate silhouette authorship by rarity without ambient glow. Send the individual images to Meshy, not the combined turnaround; see `docs/art/meshy-pipeline.md` for the current rigging and preview path.

## Gun turnaround (Grok 2D)

Generate with Grok image models only. Do not use Meshy for 2D.

> Isolated original hard-surface weapon, orthographic side, top, and front views of the exact same design, full silhouette, even studio lighting, plain light-gray background, no hands, no floor clutter, no text. Broad chamfers, quiet surfaces, readable muzzle and grip. State real-world length. Sidearms stay compact and holster-friendly; rifles are practical rectangular primaries; energy guns must not read as rifles.

Purpose: references for authored Blender gun geometry. Always include the starter pistol as the family parent. Produce **separate**, consistent orthographic views under `assets/source/concepts/gear/meshy_views_v2/`; inspect each manifest entry for its actual side, top, front, or three-quarter set. Use those views as geometry references and the combined sheet for material/detail cues. Follow `docs/art/gun-blender-pipeline.md` for modeling and validation.

## Modular outpost kit

> Orthographic design sheet of one coherent frontier outpost kit: wall bay, doorway, shade canopy, cargo crate, low barrier, light mast, and planter. Realistic PBR materials, shared broad chamfers and attachment language, mostly Starbone and Void Navy with restrained cobalt panels and ochre textile. Each module separated, full silhouette visible, neutral background, even light, no labels or text.

Purpose: establish a kit family. Generate individual reconstruction images later; do not send the whole sheet to Meshy.
