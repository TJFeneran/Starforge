# Starforge Handoff — 2026-09-19

Checkpoint for the next agent. Project is at a good pause point.

## What this project is

Godot 4.7 third-person space-fantasy game. Visual direction is locked in `docs/art/visual-bible.md` (bright Destiny-like PBR frontier + monumental forge tech).

## Current entry point

- `project.godot` → `res://scenes/main.tscn` → `res://scenes/lobby/lobby.tscn` (forge hall)
- Renderer: **Forward+** (switched from Compatibility so shadows work)
- UI base resolution 1920×1080 with `canvas_items` stretch (aspect `expand`): 2D/UI scales to the window (4K = 2×), 3D renders at native window resolution
- Player-facing display mode / resolution live in the Options menu (`GameSettings` autoload, persisted to `user://settings.cfg`); `project.godot` only decides the first launch

## Scene boundaries (do not collapse these)

| Scene | Role |
|---|---|
| `scenes/main.tscn` | Launch wrapper only |
| `scenes/lobby/lobby.tscn` | **Active work** — forge hall hub / staging area |
| `scenes/field/forge_field.tscn` | Open field reached via the gate — scattered loot VFX, monument returns to lobby |
| `scenes/sandbox/gunplay_sandbox.tscn` | Isolated controller / weapon tests |

## Lobby forge hall — current state

Authored hub in `scenes/lobby/lobby.tscn`. Layout/shell owned by `forge_hall.gd`; hub wiring by `lobby_hub.gd`. Details in `docs/production/lobby-plan.md`.

Present now:
- Enclosed forge hall with side workshop bays, catwalks, rear transit vault, observation windows, orbital exterior through the glass
- Four recessed workshops only (`workshop_bay.tscn`): Weapons / Utility (east), Armor / Outfit (west)
- **No World / Deploy bench** — deployment moved off the workshop row
- Central forge reactor + navigation globe (`forge_reactor.tscn`); E on the globe opens the hologram deployment map
- Hologram map (`scenes/lobby/ui/hologram_map.*` + `MapDestination`) marks a destination; only *Frontier Outpost* is available (loads `scenes/field/forge_field.tscn`)
- Marking a destination arms the rear Forge Monument gate (glow + portal/gem VFX); E embark at the gate wipes (`SceneTransition` autoload, BinbunVFX TransitionWipe) into the marked scene
- Shared interact stack: `ProximityInteractable` + `InteractPrompt` (hold-to-interact, world-anchored billboard)
- Monument approach stairs (`monument_stairs.gd`), planters, crate + microscope prop near the gate
- Forward+ lighting / SSAO; authored collision proxies (no auto mesh AABB)

Deferred lobby systems (remember these):
- Workshop bench interact → focused UI / inspection (anchors exist; no loadout UI yet)
- Armor / weapons loadouts
- Utility gadgets
- Skin / outfit cosmetics
- Richer map destinations / globe visual reflecting selection (stub map is enough for outpost launch)
- Persist player state across lobby ↔ mission

## Forge field (gate destination)

`scenes/field/forge_field.tscn` (`forge_field.gd`):
- Open ochre ground under the BinbunVFX GodotSkies sky
- Seeded scatter of BinbunVFX loot VFX (floating + ground variants, all rarities)
- Forge monument at the origin; E at its base returns to the lobby through the same wipe
- Player controller: third-person, ADS pistol strafe locomotion, weapon follows `RightHand`

## Gun art and progression reference

Nine guns have editable Blender sources and imported runtime GLBs under `assets/source/blender/` and `assets/models/gear/guns/`. Emberflint is equipped at start, and all nine can be selected with keys 1–9. Dawnseal and Vault Needle also remain lobby displays. Use the individual `assets/source/concepts/gear/meshy_views_v2/` PNGs for gun geometry; the original combined sheets supply material cues. The previous `meshy_views/` directory was removed, with armor references moved to `armor_views/`.

`docs/production/gun-reference-sheet.md` and `.png` show all nine guns, tiers, runtime stats, and tradeoffs. `docs/production/gun-balance.json` is the numeric source; `tools/generate_gun_resources.py` produces the editable Godot resources in `assets/data/guns/`. `scenes/combat/gun_mount.gd` implements ammo, heat, reloads, charge, spread, recoil, falloff, and bounded traits; `gun_projectile.gd` and `weapon_effect.gd` render their distinct shots and impacts. Use `scenes/sandbox/gunplay_sandbox.tscn` to test every gun in play. Combat balance and human visual review are pending.

## Known soft spots

- Jump animation is procedural whole-body motion, not a real jump clip
- Weapon grip/aim pose is functional, not perfect
- `workshop_bay.gd` still has a leftover `"deploy"` purpose builder; do not place a fifth deploy bay in the lobby
- Outpost kit Meshy assets are large GLBs under `assets/models/outpost_kit/`
- Do not use Smart Topology for hard-surface props (see `docs/art/meshy-pipeline.md`)

## Production rules we agreed

1. Freeze broad asset churn; promote assets only via checklist in `docs/production/vertical-slice.md`
2. Test experiments in `scenes/sandbox/`, not by breaking the lobby hub or the forge field
3. Prefer small, visible milestones over entangled sandbox+gameplay scenes
4. Confirm Meshy credit spend before generation for assets that still use Meshy; guns use authored Blender builds

## Suggested next steps

1. Workshop interaction stubs (Area3D + E prompt) on the four bays — still no full UI
2. Optional: globe material / hologram feedback when a destination is marked
3. Persist player state across lobby ↔ mission
4. Only then expand mission content / combat polish

## Key files

- Lobby scene / hub: `scenes/lobby/lobby.tscn`, `scenes/lobby/lobby_hub.gd`
- Hall shell: `scenes/lobby/modules/forge_hall.gd`
- Workshops: `scenes/lobby/workshops/workshop_bay.tscn`
- Deploy flow: `scenes/lobby/ui/hologram_map.gd`, `scenes/lobby/ui/map_destination.gd`, gate VFX under `scenes/lobby/vfx/`
- Interact: `scenes/interact/proximity_interactable.gd`, `scenes/ui/interact_prompt.*`
- Player: `scenes/player/player_controller.gd`, `scenes/player/player.tscn`
- Field: `scenes/field/forge_field.gd`; scene wipe: `scenes/ui/scene_transition.*`
- Menus: `scenes/ui/welcome_screen.*`, `scenes/ui/pause_menu.*`, options overlay `scenes/ui/options_menu.*` (General / Video / Audio tabs; only Video populated), settings state `scenes/settings/game_settings.gd`; shared theme `assets/ui/starforge_ui_theme.tres`
- Plans: `docs/production/lobby-plan.md`, `docs/production/vertical-slice.md`, `docs/production/armor-progression-plan.md` (canonical armor design contract), `docs/production/gun-progression-plan.md` (canonical gun design contract)
