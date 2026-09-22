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
- Weapons / utility / outfit workshop interfaces (Armor / Loadout is implemented)
- Weapons loadouts
- Utility gadgets
- Skin / outfit cosmetics
- Richer map destinations / globe visual reflecting selection (stub map is enough for outpost launch)
- Additional inventory and mission state beyond the armor campaign checkpoint

## Forge field (gate destination)

`scenes/field/forge_field.tscn` (`forge_field.gd`):
- Open ochre ground under the BinbunVFX GodotSkies sky
- Seeded scatter of BinbunVFX loot VFX (floating + ground variants, all rarities)
- Forge monument at the origin; E at its base returns to the lobby through the same wipe
- Player controller: third-person movement and ADS plus first-person camera mode; the weapon follows `RightHand` in third person and is parented to the camera in first person to stay steady during mouse movement

## Gun art and progression reference

Nine guns have editable Blender sources and imported runtime GLBs under `assets/source/blender/` and `assets/models/gear/guns/`. Emberflint is equipped at start, and all nine can be selected with keys 1–9. Dawnseal and Vault Needle also remain lobby displays. Use the individual `assets/source/concepts/gear/meshy_views_v2/` PNGs for gun geometry; the original combined sheets supply material cues. The previous `meshy_views/` directory was removed, with armor references moved to `armor_views/`.

`docs/production/gun-reference-sheet.md` and `.png` show all nine guns, tiers, runtime stats, and tradeoffs. `docs/production/gun-balance.json` is the numeric source; `tools/generate_gun_resources.py` produces the editable Godot resources in `assets/data/guns/`. `scenes/combat/gun_mount.gd` implements ammo, heat, reloads, charge, spread, recoil, falloff, and bounded traits. `gun_projectile.gd` uses Binbun MagicProjectilesVFX for pulse, echo, solar, and orb shots; ballistic shots keep their own visuals and Splitfin keeps its beam. Pulse, echo, solar, and orb fire repeatedly while held; Longpath remains one shot per press. Use `scenes/sandbox/gunplay_sandbox.tscn` to test all nine guns, with 1–9 or Tab / Shift+Tab to switch. `tools/check_gunplay.gd` checks hits, traits, and held fire. Combat balance remains open.

Firing VFX uses the free Binbun MuzzleFlashVFX, BeamVFXFree, and HitFXFree packs in separate `assets/BinbunVFX/` folders, with provenance in each `SOURCE.md`. `weapon_effect.gd` gives all guns directional muzzle flashes and brief impacts; Splitfin and Echo use narrow beams. Marksman and Rift Ray use animated beam warnings and distinct MagicProjectilesVFX shots. Warning timing, damage, and projectile collision remain controlled by the combat scripts.

`GunMount` keeps two reusable muzzle instances per equipped gun so sustained fire does not construct particle nodes on each shot. The forge field draws the shared muzzle, impact, beam, and energy projectile shaders while the gate wipe covers the scene; this avoids a first-shot shader compile hitch after entering from the lobby.

## Armor art and preview

Nine textured Meshy armor designs have raw GLBs and generation records in `assets/source/meshy/armor_*/`, editable rigged Blender files in `assets/source/blender/armor_*/`, and Godot GLBs in `assets/models/gear/armor/previews/`. The lineup is Dustcoat Field Kit, Outpost Plate, Trail Warden, Signal Mantle, Quarry Shell, Riftward Carapace, Nightwell Vaultsuit, Horizon Aegis, and Solar Heartplate. The models use matching 112-bone rigs and share six preview clips (walk, run, strafe, jump, aim, idle). Open `scenes/sandbox/armor_preview.tscn`; WASD moves the camera, Shift moves faster, drag orbits, wheel zooms, Space advances the animation, and R resets the view.

The preview normally fits models to 1.8 m. Signal Mantle and Horizon Aegis are 2.16 m including their tall helmet pieces, so their armored bodies match the lineup more closely. These models now also serve full-body campaign equipment. The six-slot loadout and mitigation remain deferred; the current model grants maximum HP per set. Preserve the Meshy geometry and textures when changing rigs or animation weights.

## Enemy concept references

The user selected Rift Skitter B (Shieldback), Rift Marksman A (Needlecrest), Forge Bulwark A (Split Crown), and Rift Ray A (Crescent). `assets/source/concepts/enemies/index.html` shows their 18 body reference views and three separate Marksman carbine views; `README.md`, `BLENDER_HANDOFF.md`, per-enemy briefs, and `manifest.json` record scale, anatomy, animation requirements, prompts, and review caveats. Skitter/Ray front and rear references retain some camera elevation; use these as appearance guides, not measured orthographic drawings. Follow the manifest's selected filenames, not superseded drafts.

All four selected enemies now have source GLBs in `assets/source/meshy/<slug>/`, editable rigs and phone-ready review videos in `assets/source/blender/<slug>/`, runtime GLBs in `assets/models/enemies/<slug>/`, and sandbox preview scenes. Marksman has 11 clips and a 51-bone rig; Shieldback Skitter has 8 clips and a 20-bone quadruped rig; Crescent Ray has 9 clips and a 13-bone fin/tail rig; Split Crown Bulwark has 7 clips and a 44-bone rig with rigid armor weighting. Each source was optimized conservatively, retaining its original textures and silhouette. The three later Meshy builds cost 30 credits each and did not use paid rig or animation services.

The first selectable level, Frontier Outpost (`scenes/field/forge_field.tscn`), now spawns the four as a test encounter through `scenes/combat/enemy_test_actor.tscn`. The test actors chase, attack on authored contact frames, take gun damage, and play hit/death clips. `tools/check_enemy_test_encounter.gd` checks all four models, required clips, rigs, gun damage, death, and a live Skitter attack against the player; it passes. These are a test roster for gameplay review, not the final authored enemy AI or campaign mission balance. Keep the older combat Skitter asset available until permanent encounter promotion.

For subsequent enemies and bosses, follow `docs/production/enemy-preview-pipeline.md` from concept choice and paid-generation approval through rig checks, sandbox video, and phone delivery through Google Drive.

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

## New Game, Continue, and armor HP campaign

The title menu offers New Game (current character or Dustcoat Field Kit, both 100 HP) and Continue from a saved lobby/field checkpoint. `PlayerState` owns one atomic versioned `user://campaign.json` save for starter, equipped/owned armor, pending recovery, and scene. Continue respawns at that scene's safe spawn with full HP; transient position/ammo are not saved. Pause → Main Menu preserves progress.

The preserved HP table is in `armor-progression-plan.md`, backed by `assets/data/armor/armor_balance.json`: 100 starter, then 125 / 145 / 170 / 195 / 225 / 250 / 275 / 300 HP. Recover the marked field blueprint and extract at the monument to unlock the next set, once per expedition. The existing Armor workshop compares and equips earned gear. Campaign armor hotkeys cannot bypass ownership; sandbox hotkeys remain unrestricted. Death loses an unextracted blueprint but preserves owned gear. This recovery loop is the initial progression path until authored combat missions exist.
