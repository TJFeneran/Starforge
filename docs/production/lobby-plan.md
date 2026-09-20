# Starforge Lobby Plan

## Active lobby — forge hall (2026-09-10)

`project.godot` → `scenes/main.tscn` → `scenes/lobby/lobby.tscn`.

- Layout: enclosed hall with four recessed side workshops, central circulation, rear transit vault/gate. Shell, windows, catwalks, and stairwells are owned by `scenes/lobby/modules/forge_hall.gd`. Floor pattern is procedural world-space PBR shading in `assets/materials/lobby/hall_floor.gdshader`.
- Entry wall concept posters: `scenes/lobby/modules/concept_posters.gd` scatters gear concept sheets on the hall face of the large entry door wall (flanking panels, near eye height). Runtime textures live in `assets/textures/lobby/gear_concepts/` (copied from `assets/source/concepts/gear/`).
- Architecture extras: side + rear observation windows with orbital exterior (`orbital_exterior.gd`), rear stairwells to catwalks, monument approach stairs (`monument_stairs.gd`).
- Fixtures: `scenes/lobby/modules/hall_fixture.tscn` / `hall_lighting.gd`. Only selected overhead lights cast shadows.
- Workshops: `scenes/lobby/workshops/workshop_bay.tscn` exposes the purpose string and owns visual equipment, explicit collision, `InteractionAnchor`, and `InspectionAnchor`. **Active lobby instances are four only** — weapons, utility, armor, outfit. There is no deploy workshop in the scene.
- Reactor: `scenes/lobby/vfx/forge_reactor.tscn` owns contained energy, orbital elements, motes, a local navigation globe, and `MapInteract` (proximity). It does not mutate the shared globe material resource.
- Deploy flow (replaces the old World / Deploy bench): globe E → `HologramMap` UI → mark `MapDestination` → arms Forge Monument embark → E loads `scene_path` (`lobby_hub.gd`). Stub destinations live in `hologram_map.gd`; only Frontier Outpost is available.
- Interact stack: `scenes/interact/proximity_interactable.tscn` + `scenes/ui/interact_prompt.*`.
- Collision: authored proxies, flush floors, no automatic per-mesh AABB generation. Camera retreat and capsule route checks live in `tools/review_lobby.gd`.
- Review: `godot --path . --script tools/review_lobby.gd` captures fixed 1080p views and reports timing/collision checks. Images are written outside the repo to `/tmp/starforge-lobby-review/`.

## Station layout

- Armor / Loadout: west rear bay.
- Outfit / Skin: west entry bay.
- Weapons / Forge: east rear bay.
- Utility / Gadgets: east entry bay.
- **Deployment:** central forge navigation globe + hologram map + armed rear gate. Not a fifth workshop.

Note: `workshop_bay.gd` still accepts a `"deploy"` purpose for the builder/validator. Do not instance it in the lobby; deploy UX stays on the globe/gate path.

## Armor design contract

Functional armor progression, slot ownership, rarity, mitigation, acquisition, persistence, and Armor / Loadout UX are defined in [`docs/production/armor-progression-plan.md`](armor-progression-plan.md). Keep the Armor / Loadout bay as the functional entry point and keep Outfit / Skin cosmetic-only.

Functional gun progression, sidearm-first loadouts, primary weapon families, rarity, traits, acquisition, persistence, and Weapons / Forge UX are defined in [`docs/production/gun-progression-plan.md`](gun-progression-plan.md). Keep the Weapons / Forge bay as the functional gun entry point and keep Outfit / Skin cosmetic-only.

## Deferred systems to remember

- Each of the four workshop bays becomes an interaction point with a focused UI or 3D inspection view.
- Armor and weapons should expose loadout changes.
- Utility should expose gadgets and consumables.
- Skin / outfit should preview cosmetic changes.
- The hologram map / forge globe should grow richer destination data and visual selection feedback.
- Lobby-to-mission travel should keep player state without duplicating it.

Keep workshop nodes named and spatially stable so they can receive interaction Areas later.
