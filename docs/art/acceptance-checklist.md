# Style-lab acceptance checklist

Reviewed against Visual Bible v1.0 using:
- Cursor concept set in `assets/source/concepts/style-tests/`
- Meshy 7 forge beacon (`01a07df0-ca30-735c-b447-96ca7ddeea8a`, 30 credits)
- Runtime GLB `assets/models/style_tests/forge_beacon.glb`
- Fixed frames in `docs/art/screenshots/`

| Gate | Status | Notes |
|---|---|---|
| World identity recognizable as bright space fantasy | Pass | Concepts + cyan/ochre style lab |
| Hero / path / forge object readable at gameplay distance | Pass | Beacon silhouette reads against path and outpost |
| Neutrals + environment ≥ ~70% of frame | Pass | Ground/sky/outpost dominate |
| Solar Amber rare and focal (≤ ~5%) | Pass with note | Core remains focal; next textures should avoid greenish cast |
| Material families distinct without close-up | Pass with note | Dark fins, pale base, emissive core separate; reduce gold-on-fin drift |
| Monumental forms lead secondary detail | Pass | Split-ring and beacon primary forms read first |
| Scene feels inhabited and hopeful | Pass | Outpost + teal life + warm beacon |

## Freeze decision

**Visual Bible v1.0 frozen.** Pipeline is validated. Bulk Meshy generation may begin only for assets that obey `docs/art/concept-prompts.md` and this checklist.

## Forge-beacon remake (v2)

- Meshy task: `01a07dfc-bb4c-7759-b5a7-af07b5faf8e2` (Meshy 7, 4K, ~60k, 30 credits)
- Runtime height locked to **2.2 m** in Blender after import (auto_size produced 3.0 m)
- Texture map: 4096×4096
- Runtime GLB: `assets/models/style_tests/forge_beacon.glb` (~28 MB)

Review in style lab / Blender before declaring production-ready.
