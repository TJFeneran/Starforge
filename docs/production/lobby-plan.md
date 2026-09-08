# Starforge Lobby Plan

## Active lobby — forge hall (2026-09-08)

`project.godot` → `scenes/main.tscn` → `scenes/lobby/lobby.tscn`. The previous crate-and-wall hangar is archived at `scenes/lobby/lobby_legacy.tscn`.

- Layout: 42 × 42 m enclosed hall, four recessed side workshops, central circulation loop, rear transit gate. Main ceiling is 9.5 m; the rear transit vault is 16 m high to clear the monument’s measured 13.5 m height and 10.86 m depth at its preserved scale. Armor/outfit occupy the west; weapons/utility the east. Deployment sits beside, not across, the portal approach.
- Architecture: `scenes/lobby/modules/forge_hall.gd` owns floor/shell, partitions, rails, physical overhead fixtures, and signs. Floor pattern is procedural world-space PBR shading in `assets/materials/lobby/hall_floor.gdshader`. Corner plants are style-lab `outpost_planter.glb` instances with pot-only collision.
- Fixtures: `scenes/lobby/modules/hall_fixture.tscn` combines housing, diffuser, brackets, and an actual spot light. Only selected overhead lights cast shadows.
- Workshops: `scenes/lobby/workshops/workshop_bay.tscn` exposes the purpose string and owns visual equipment, explicit collision, `InteractionAnchor`, and `InspectionAnchor`. All five variants use authored components; new AI hero props remain an optional, approval-gated asset pass.
- Reactor: `scenes/lobby/vfx/forge_reactor.tscn` owns contained energy, orbital elements, motes, scheduled arcs, a local navigation globe material, and reduced-effects mode. It does not modify the shared globe material.
- Collision: authored proxies, flush floors, no automatic per-mesh AABB generation. Camera retreat and capsule route checks live in `tools/review_lobby.gd`.
- Review: `godot --path . --script tools/review_lobby.gd` captures fixed 1080p views and reports timing/collision checks. Add `-- --baseline` for `lobby_legacy.tscn`. Images are written outside the repo to `/tmp/starforge-lobby-review/`.
- Promoted as the active lobby. No AI credits spent. No station UI, crafting, mission travel, or persistent state added.

## Existing lobby / deferred systems

The lobby is an environment-first hub. The stations are deliberately modeled as readable spatial anchors before interaction systems are implemented.

## Station layout

- Armor / Loadout: west rear bench.
- Weapons / Forge: east rear bench.
- Utility / Gadgets: west entry bench.
- Skin / Outfit: east entry bench.
- World / Deploy: rear-center station, visually tied to the central forge.
- Central forge: world-selection focal point with a floating globe/map indicator.

## Deferred systems to remember

- Each bench becomes an interaction point with a focused UI or 3D inspection view.
- Armor and weapons should expose loadout changes.
- Utility should expose gadgets and consumables.
- Skin / outfit should preview cosmetic changes.
- World / Deploy should open a map and select the next run location.
- The forge globe should update to show discovered destinations, mission status, and the selected deployment.
- Lobby-to-mission travel should load the selected playable slice without duplicating player state.

Do not implement these systems in the environment pass. Keep station nodes named and spatially stable so they can receive interaction Areas later.
