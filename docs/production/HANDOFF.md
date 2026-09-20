# Starforge Handoff — 2026-09-20

Current implementation and next production work.

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
| `scenes/sandbox/armor_preview.tscn` | Nine rigged Meshy armors in a labeled, animated lineup |

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
- Player controller: third-person movement and ADS plus first-person camera mode; the weapon follows `RightHand` in third person and is parented to the camera in first person to stay steady during mouse movement

## Gun art and progression reference

Nine guns have editable Blender sources and imported runtime GLBs under `assets/source/blender/` and `assets/models/gear/guns/`. Emberflint is equipped at start, and all nine can be selected with keys 1–9. Dawnseal and Vault Needle also remain lobby displays. Use the individual `assets/source/concepts/gear/meshy_views_v2/` PNGs for gun geometry; the original combined sheets supply material cues. The previous `meshy_views/` directory was removed, with armor references moved to `armor_views/`.

`docs/production/gun-reference-sheet.md` and `.png` show all nine guns, tiers, runtime stats, and tradeoffs. `docs/production/gun-balance.json` is the numeric source; `tools/generate_gun_resources.py` produces the editable Godot resources in `assets/data/guns/`. `scenes/combat/gun_mount.gd` implements ammo, heat, reloads, charge, spread, recoil, falloff, and bounded traits. `gun_projectile.gd` uses Binbun MagicProjectilesVFX for pulse, echo, solar, and orb shots; ballistic shots keep their own visuals and Splitfin keeps its beam. Pulse, echo, solar, and orb fire repeatedly while held; Longpath remains one shot per press. Use `scenes/sandbox/gunplay_sandbox.tscn` to test all nine guns, with 1–9 or Tab / Shift+Tab to switch. `tools/check_gunplay.gd` checks hits, traits, and held fire. Combat balance remains open.

## Armor art and preview

Nine textured Meshy armor designs have raw GLBs and generation records in `assets/source/meshy/armor_*/`, editable rigged Blender files in `assets/source/blender/armor_*/`, and Godot GLBs in `assets/models/gear/armor/previews/`. The lineup is Dustcoat Field Kit, Outpost Plate, Trail Warden, Signal Mantle, Quarry Shell, Riftward Carapace, Nightwell Vaultsuit, Horizon Aegis, and Solar Heartplate. The models use matching 112-bone rigs and share six preview clips (walk, run, strafe, jump, aim, idle). Open `scenes/sandbox/armor_preview.tscn`; WASD moves the camera, Shift moves faster, drag orbits, wheel zooms, Space advances the animation, and R resets the view.

The preview normally fits models to 1.8 m. Signal Mantle and Horizon Aegis are 2.16 m including their tall helmet pieces, so their armored bodies match the lineup more closely. These are visual preview assets; the six-slot armor loadout, mitigation, persistence, and workshop UI in `armor-progression-plan.md` are not implemented yet. Preserve the Meshy geometry and textures when changing rigs or animation weights.

## Known soft spots

- Jump animation is procedural whole-body motion, not a real jump clip
- Weapon grip/aim pose is functional, not perfect
- Armor preview rigs and cloth should be checked again under final gameplay locomotion before promotion from the sandbox
- `workshop_bay.gd` still has a leftover `"deploy"` purpose builder; do not place a fifth deploy bay in the lobby
- Outpost kit Meshy assets are large GLBs under `assets/models/outpost_kit/`
- Do not use Smart Topology for hard-surface props (see `docs/art/meshy-pipeline.md`)

## Production rules we agreed

1. Freeze broad asset churn; promote assets only via checklist in `docs/production/vertical-slice.md`
2. Test experiments in `scenes/sandbox/`, not by breaking the lobby hub or the forge field
3. Prefer small, visible milestones over entangled sandbox+gameplay scenes
4. Confirm Meshy credit spend before generation; armor uses Meshy 7 source plus Blender rigging, while the current guns use authored Blender builds

## Suggested next steps

1. Build the first functional Armor / Loadout and Weapons / Forge inspection and equip flow using the existing workshop bays
2. Persist owned and equipped gear across lobby ↔ mission before tying these catalogs to progression
3. Integrate and validate armor on the playable player rig, including cloth, weapon attachment, and camera readability
4. Tune gun balance and combat visuals in the gunplay sandbox and mission loop

## Key files

- Lobby scene / hub: `scenes/lobby/lobby.tscn`, `scenes/lobby/lobby_hub.gd`
- Hall shell: `scenes/lobby/modules/forge_hall.gd`
- Workshops: `scenes/lobby/workshops/workshop_bay.tscn`
- Deploy flow: `scenes/lobby/ui/hologram_map.gd`, `scenes/lobby/ui/map_destination.gd`, gate VFX under `scenes/lobby/vfx/`
- Interact: `scenes/interact/proximity_interactable.gd`, `scenes/ui/interact_prompt.*`
- Player: `scenes/player/player_controller.gd`, `scenes/player/player.tscn`
- Combat: `scenes/combat/gun_mount.gd`, `scenes/combat/gun_projectile.gd`, `scenes/combat/weapon_effect.gd`; sandbox: `scenes/sandbox/gunplay_sandbox.tscn`, `scenes/sandbox/armor_preview.tscn`
- Field: `scenes/field/forge_field.gd`; scene wipe: `scenes/ui/scene_transition.*`
- Menus: `scenes/ui/welcome_screen.*`, `scenes/ui/pause_menu.*`, options overlay `scenes/ui/options_menu.*` (General / Video / Audio tabs; only Video populated), settings state `scenes/settings/game_settings.gd`; shared theme `assets/ui/starforge_ui_theme.tres`
- Plans: `docs/production/lobby-plan.md`, `docs/production/vertical-slice.md`, `docs/production/armor-progression-plan.md` (canonical armor design contract), `docs/production/gun-progression-plan.md` (canonical gun design contract)
