# Armor Options & Progression

Status: HP-based full-body armor, starter selection, ordered blueprint unlocks, Armor workshop equip, and campaign persistence implemented 2026-09-20. The HP model below supersedes the earlier mitigation proposal; six-slot equipment and rarity effects remain future work.

This document is the source of truth for functional armor. Future armor implementation, balancing, asset production, and workshop UI should follow it unless a later design decision updates this document.

The nine complete visual candidates are in `assets/models/gear/armor/previews/` and can be compared in `scenes/sandbox/armor_preview.tscn`. Their Meshy source, generation records, and Blender rigs live under `assets/source/meshy/armor_*/` and `assets/source/blender/armor_*/`. They are full-body preview models, not yet separated into the six functional equipment slots below.

## Design promise

The player begins as a vulnerable frontier operative with little more than a field outfit. Armor is earned progressively through missions and the forge: Common, Uncommon, Rare, then Legendary. Each step improves survivability and visual identity, but no mission should require a Legendary loadout.

Functional armor belongs to **Armor / Loadout**. Appearance-only skins belong to the separate **Outfit / Skin** workshop and must not silently change combat power.

## Future equipment slots

The earlier long-term proposal has six areas; the implemented HP model currently equips one full-body set:

- **Head / helmet** — protection and head silhouette. The starter has no full helmet (or a visibly improvised covering); the first proper helmet is a meaningful early upgrade.
- **Torso** — the primary protection slot and the visual anchor of a set.
- **Pants / leg armor** — lower-body protection while preserving readable locomotion.
- **Gloves / gauntlets** — hand and forearm protection; must preserve the `RightHand` weapon attachment and ADS readability.
- **Boots** — foot and lower-leg protection; do not alter the existing collision capsule without a deliberate movement pass.
- **Trinket** — one utility/passive slot at launch. A second trinket slot is reserved for a later progression milestone and is not part of the first implementation.

A future slot loadout may contain mixed rarities. Set bonuses are deferred; players should be free to replace one weak slot without losing a hidden full-set bonus.

## Starter state

The default new-player loadout is intentionally weak:

- improvised or uncovered head;
- light torso and leg layers;
- basic gloves and boots;
- no trinket equipped;
- no starting blueprint or resource requirement that can block the first upgrade.

The starter state must be survivable in the current Frontier Outpost slice, but clearly less forgiving than a complete Common set. A new save always receives the starter state and a guaranteed path to the first Common blueprint.

## Rarity contract

Rarity is a gameplay tier, not only a UI color. Item names, icons, stat comparison, and readable silhouettes must communicate value without relying on color alone.

| Tier | Role | Design rule |
|---|---|---|
| Common | dependable baseline | First real upgrade over starter gear; one straightforward protection value. |
| Uncommon | focused improvement | Better protection plus one clear, low-complexity identity trait. |
| Rare | build-shaping | Stronger protection plus a conditional or situational effect that changes decisions. |
| Legendary | named signature | Distinctive, bespoke effect with a hard budget and clear counterplay; powerful, bounded, and never mandatory. |

Suggested rarity presentation is neutral UI with restrained tier accents; avoid turning the hero into a rainbow of lights. The exact palette and values remain tunable data, not hard-coded scene logic.

## Preserved HP table — balance version 1

Runtime source: `assets/data/armor/armor_balance.json`. Change that data and this table together when deliberately rebalancing. HP is the equipped armor's **total maximum health**, not a stacking bonus. Both starter choices have identical combat stats; the current character uses the existing Exo Gray model and Dustcoat uses the existing Dustcoat Field Kit model.

| Unlock order | Armor | Tier | Base / maximum HP | Increase from previous upgrade |
|---|---|---|---:|---:|
| Starter choice | Current character (base suit) | Starter | 100 | — |
| Starter choice | Dustcoat Field Kit | Starter | 100 | — |
| 1 | Outpost Plate | Common | 125 | +25 |
| 2 | Trail Warden | Common | 145 | +20 |
| 3 | Signal Mantle | Uncommon | 170 | +25 |
| 4 | Quarry Shell | Uncommon | 195 | +25 |
| 5 | Riftward Carapace | Rare | 225 | +30 |
| 6 | Nightwell Vaultsuit | Rare | 250 | +25 |
| 7 | Horizon Aegis | Legendary | 275 | +25 |
| 8 | Solar Heartplate | Legendary | 300 | +25 |

The first Common upgrade provides 25% more health than the starter; the top armor caps this initial progression at three times starter HP. These are initial tuning values, not a claim that endgame combat has been balanced.

## Protection model

One equipped full-body set determines `Health.max_hp`. Enemy damage continues through the existing Health receiver and signals without mitigation. Equipping preserves the current HP percentage, so repeated swaps cannot heal the player. Scene checkpoints and respawn restore full HP. The earlier six-slot mitigation proposal is deferred in favor of this requested HP model; no protection ratings or rarity effects are active.

## Acquisition and economy

The current field has no authored combat mission-completion system. Its initial playable progression loop is **one blueprint recovery per expedition**:

1. Mark Frontier Outpost on the lobby globe and embark through the gate.
2. Find the labeled armor blueprint at `(12, 0, -24)` in the field and hold E to recover it.
3. Return to the forge monument and hold E to extract. Only successful extraction unlocks the next armor in the table.
4. Use the Armor / Loadout workshop to inspect owned and locked sets, compare HP, and apply equipment.
5. Deploy again for the next blueprint. After eight extractions, the catalog is complete.

Collecting saves the pending blueprint immediately. Quitting and continuing keeps that recovery; dying and respawning loses the unextracted blueprint. Returning without a blueprint grants nothing. Repeated interactions or scene reloads cannot duplicate rewards or skip the order. The chosen starter remains owned; the unchosen starter is not an earned upgrade. There are no crafting costs or resource requirements in this first loop. Later authored missions can replace the recovery trigger while preserving the table and ownership rules.

## Player state and persistence

`PlayerState` is the shared authority for a single versioned `user://campaign.json` slot. It stores starter ID, equipped armor ID, ordered unlocked armor IDs, pending blueprint, and checkpoint scene. Writes go to a temporary file and are renamed into place only after successful flush; failed writes leave the previous in-memory state and save intact and show an error.

- **New Game** opens a cancellable choice of current character or Dustcoat with live model previews. Begin Journey creates the save; replacing an existing slot requires an explicit confirmation.
- **Continue** is disabled without a valid supported save. Missing, malformed, future-version, unknown-ID, skipped-tier, or invalid-checkpoint data is not loaded.
- **Continue** restores the saved lobby or field at its authored safe spawn with full HP. Position, transient enemies, gun ammunition, and movement state are not serialized.
- Autosaves occur on creation, scene entry, blueprint recovery/extraction, armor equip, and respawn. Main Menu and Exit retain the latest checkpoint; returning to the menu does not start a new game.
- Death clears the pending blueprint and returns to the lobby; unlocked/equipped gear remains.
- Sandboxes remain independent, with unrestricted Shift+1–9 armor previews. Campaign play equips through the workshop and cannot bypass progression via those shortcuts.
- User video settings stay in the separate existing settings file.

## Armor workshop UX

`WorkbenchArmor` in the west rear Armor / Loadout bay opens the focused loadout panel using the existing hold-to-interact pattern. It shows equipped/owned/locked states, rarity, total HP, current-versus-selected HP, and explicit Apply and Cancel/Close actions. Selecting a row changes only the comparison; Apply commits and saves the equipment. The live player model and health are updated together. The Outfit / Skin bay remains deferred and separate.

## Art and asset rules

Armor must follow `docs/art/visual-bible.md`: broad practical plates over a Void Navy understructure, restrained Frontier Cobalt identity, and rare Solar Amber energy. Keep surfaces quiet and silhouettes clean. Do not use dense greebles, grimdark grime, generic camouflage, cyberpunk neon, franchise-like symbols, or cape/panel shapes that obscure gameplay readability.

For each armor asset, record item ID, slot, rarity, scale target, pivot/origin, material slots, collision approach, and runtime owner. Use production GLB output and the established Meshy 7 pipeline; avoid Smart Topology for hard-surface armor. Confirm credit spend before generation.

Test new armor in `scenes/sandbox/armor_preview.tscn` or `scenes/style_lab/` first. The current preview fits most full-body models to 1.8 m; Signal Mantle and Horizon Aegis use 2.16 m total height so their tall helmet pieces extend above otherwise comparable bodies. Those preview dimensions do not change the 1.8 m playable rig or collision capsule. Promote only after checking scale/facing, materials, intentional collision, performance, animation compatibility, and third-person readability on the player. Do not destabilize `scenes/field/forge_field.tscn` or add a fifth lobby workshop.

## Validation

- `godot --headless --path . --script tools/check_campaign.gd`: isolated temporary save checks for both starters, menu cancellation, all upgrades, lock enforcement, health ratio, weapon/animation bindings, ownership persistence, duplicate prevention, death, corrupt data, and failed writes.
- `godot --headless --path . --script tools/check_armor_switch.gd`: independent sandbox armor shortcuts remain available.
- `godot --headless --path . --script tools/check_gunplay.gd`: weapon regression coverage.
- `tools/capture_campaign.gd`: rendered menu, starter choice, lobby, field recovery, workshop and Continue evidence using a temporary save.

Future work: authored mission reward pacing, six-slot equipment if still desired, rarity effects, workshop model inspection, and combat balance tuning. Preserve lobby/field boundaries and the player rig, camera, collision capsule, and weapon attachment.
