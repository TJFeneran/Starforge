# Starforge Handoff — 2026-09-08

Checkpoint for the next agent. Project is at a good pause point.

## What this project is

Godot 4.7 third-person space-fantasy game. Visual direction is locked in `docs/art/visual-bible.md` (bright Destiny-like PBR frontier + monumental forge tech).

## Current entry point

- `project.godot` → `res://scenes/main.tscn` → `res://scenes/lobby/lobby.tscn`
- Renderer: **Forward+** (switched from Compatibility so shadows work)
- Resolution: 1920×1080

## Scene boundaries (do not collapse these)

| Scene | Role |
|---|---|
| `scenes/main.tscn` | Launch wrapper only |
| `scenes/lobby/lobby.tscn` | **Active work** — hangar hub / staging area |
| `scenes/playable/outpost_slice.tscn` | Playable mission vertical slice (independent of style_lab) |
| `scenes/style_lab/style_lab.tscn` | Art / environment sandbox |
| `scenes/sandbox/controller_sandbox.tscn` | Isolated controller / weapon tests |

## Lobby hangar — current state

Environment-first hub. Interaction systems are **not** implemented yet (documented in `docs/production/lobby-plan.md`).

Present now:
- Enclosed hangar using outpost kit: scaled `outpost_wall_bay`, crates as workbench bottoms, planters as decoration, canopy/wall pieces as ceiling underside + solid void-navy ceiling deck
- Central forge beacon + procedural hologram WorldGlobe (`assets/lookdev/world_globe_hologram.*`)
- Forge Monument as unlabeled physical world-entry gate at rear
- Workbench identifiers: glowing console boxes + Label3D text
  - Armor / Loadout (teal)
  - Weapons / Forge (amber)
  - Utility / Gadgets (teal)
  - Skin / Outfit (violet)
  - World / Deploy (violet)
- Lighting pass: ceiling SpotLights with shadows, forge/portal Omni shadows, lowered ambient, SSAO, Forward+

Deferred lobby systems (remember these):
- Bench interact → focused UI / inspection
- Armor / weapons loadouts
- Utility gadgets
- Skin / outfit cosmetics
- World / Deploy map + destination select (globe should reflect selection)
- Walking through Forge Monument loads selected mission
- Persist player state across lobby ↔ mission

## Playable mission slice (stable enough, not current focus)

`scenes/playable/outpost_slice.tscn`:
- Objectives: attune beacon → monument → canopy → rift signal → complete
- Restart with `R` when DONE (deferred reload; zone `monitoring` uses `set_deferred`)
- Combat stub: forge sidearm + rift skitter + HP HUD + crosshair
- Player controller: third-person, jump visual polish, weapon follows `RightHand` (no procedural raised-arm pose — that deformed the mesh)

## Known soft spots

- Jump animation is procedural whole-body motion, not a real jump clip
- Weapon grip/aim pose is functional, not perfect
- Lobby ceiling currently reuses WallBay/canopy kit pieces + a solid deck; optional future Meshy modular ceiling bay (~20+10 credits Meshy 6)
- Outpost kit Meshy assets are large GLBs under `assets/models/outpost_kit/`
- Do not use Smart Topology for hard-surface props (see `docs/art/meshy-pipeline.md`)

## Production rules we agreed

1. Freeze broad asset churn; promote assets only via checklist in `docs/production/vertical-slice.md`
2. Test experiments in sandbox / style_lab, not by breaking the playable or lobby hubs
3. Prefer small, visible milestones over entangled sandbox+gameplay scenes
4. Confirm Meshy credit spend before generation

## Suggested next steps

1. Lobby interaction stubs (Area3D + E prompt) on workbenches — still no full UI
2. Wire World / Deploy → select destination → Forge Monument loads `outpost_slice`
3. Optional Meshy hangar ceiling bay matching kit materials
4. Only then expand mission content / combat polish

## Key files

- Lobby: `scenes/lobby/lobby.tscn`
- Player: `scenes/player/player_controller.gd`, `scenes/player/player.tscn`
- Mission: `scenes/style_lab/mission_controller.gd` (shared by outpost_slice)
- Collision proxies: `scenes/style_lab/outpost_collision.gd`
- Globe shader: `assets/lookdev/world_globe_hologram.gdshader`
- Plans: `docs/production/lobby-plan.md`, `docs/production/vertical-slice.md`
