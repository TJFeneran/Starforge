# Armor Options & Progression

Status: design contract (2026-09-10); nine Meshy armor visuals rigged and previewable as of 2026-09-20. Functional equipment and mitigation remain planned.

This document is the source of truth for functional armor. Future armor implementation, balancing, asset production, and workshop UI should follow it unless a later design decision updates this document.

The nine complete visual candidates are in `assets/models/gear/armor/previews/` and can be compared in `scenes/sandbox/armor_preview.tscn`. Their Meshy source, generation records, and Blender rigs live under `assets/source/meshy/armor_*/` and `assets/source/blender/armor_*/`. They are full-body preview models, not yet separated into the six functional equipment slots below.

## Design promise

The player begins as a vulnerable frontier operative with little more than a field outfit. Armor is earned progressively through missions and the forge: Common, Uncommon, Rare, then Legendary. Each step improves survivability and visual identity, but no mission should require a Legendary loadout.

Functional armor belongs to **Armor / Loadout**. Appearance-only skins belong to the separate **Outfit / Skin** workshop and must not silently change combat power.

## Equipment slots

The initial loadout has six areas:

- **Head / helmet** — protection and head silhouette. The starter has no full helmet (or a visibly improvised covering); the first proper helmet is a meaningful early upgrade.
- **Torso** — the primary protection slot and the visual anchor of a set.
- **Pants / leg armor** — lower-body protection while preserving readable locomotion.
- **Gloves / gauntlets** — hand and forearm protection; must preserve the `RightHand` weapon attachment and ADS readability.
- **Boots** — foot and lower-leg protection; do not alter the existing collision capsule without a deliberate movement pass.
- **Trinket** — one utility/passive slot at launch. A second trinket slot is reserved for a later progression milestone and is not part of the first implementation.

A loadout may contain mixed rarities. Set bonuses are deferred; players should be free to replace one weak slot without losing a hidden full-set bonus.

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

## Protection model

The first functional model is damage mitigation. Incoming damage is reduced by the equipped armor through one shared armor-aware damage receiver. Attackers such as `rift_skitter.gd` and `pulse_bolt.gd` should continue to submit damage; they must not each know armor rules.

Initial rules:

1. Every armor item supplies a readable protection rating. Unarmored slots contribute zero.
2. The equipped pieces combine into a total rating, then a single capped mitigation formula converts that rating into reduced incoming damage.
3. Mitigation is applied before `Health.apply_damage()`, preserving the existing `Health.damaged` signal and HUD behavior.
4. Damage is never reduced below a minimum post-mitigation amount; exact cap, curve, rounding, and damage-type modifiers are balance data to be established during the first combat test.
5. Uncommon and above may add one simple conditional modifier. Shields, elemental resistance tables, durability, repairs, set bonuses, and movement penalties are deferred until the base loop is proven.

The implementation target is a data-driven armor model plus a shared player-state service, not more constants in `player_controller.gd`.

## Acquisition and economy

Progression uses **mission-forged unlocks**:

- mission completion grants forge resources and blueprint progress;
- the armor workshop crafts unlocked blueprints and equips owned items;
- the first Frontier Outpost completion supplies the first meaningful Common path;
- later missions introduce Uncommon, Rare, and Legendary blueprints in controlled order;
- costs and resource quantities are tunable item data;
- duplicates convert to salvage or upgrade progress rather than dead rewards;
- the player always retains a usable loadout and cannot spend themselves into a progression dead end.

The initial implementation should prove one starter-to-Common path before adding a large catalog. Legendary items should be scarce and authored, not random stat inflation.

## Player state and persistence

One shared player state must own:

- owned armor item IDs and blueprint IDs;
- equipped item ID per slot;
- forge resources and blueprint progress;
- versioned serialization data.

The same state is read by the lobby and mission. Save/load timing, new-save defaults, scene transitions, and mission restart behavior must be explicit. Restarting the outpost must not duplicate rewards or silently discard an equipped loadout. No duplicate lobby and mission inventories are permitted.

The visual assembly must preserve the current 1.8 m player rig, animation assumptions, camera framing, collision capsule, head/shoulder/torso/leg separation, and `RightHand` weapon attachment.

## Armor workshop UX

`WorkbenchArmor` in the west rear Armor / Loadout bay is the authoritative functional armor entry point. It uses the existing proximity/hold-to-interact pattern and opens a focused inspection view with:

- slot navigation;
- equipped, owned, locked, and blueprint states;
- current-versus-preview stat comparison;
- resource and blueprint requirements;
- visual preview before commit;
- explicit Apply and Cancel behavior.

The Outfit / Skin bay remains separate and handles appearance-only changes. Armor UI must make that distinction obvious.

## Art and asset rules

Armor must follow `docs/art/visual-bible.md`: broad practical plates over a Void Navy understructure, restrained Frontier Cobalt identity, and rare Solar Amber energy. Keep surfaces quiet and silhouettes clean. Do not use dense greebles, grimdark grime, generic camouflage, cyberpunk neon, franchise-like symbols, or cape/panel shapes that obscure gameplay readability.

For each armor asset, record item ID, slot, rarity, scale target, pivot/origin, material slots, collision approach, and runtime owner. Use production GLB output and the established Meshy 7 pipeline; avoid Smart Topology for hard-surface armor. Confirm credit spend before generation.

Test new armor in `scenes/sandbox/armor_preview.tscn` or `scenes/style_lab/` first. The current preview fits most full-body models to 1.8 m; Signal Mantle and Horizon Aegis use 2.16 m total height so their tall helmet pieces extend above otherwise comparable bodies. Those preview dimensions do not change the 1.8 m playable rig or collision capsule. Promote only after checking scale/facing, materials, intentional collision, performance, animation compatibility, and third-person readability on the player. Do not destabilize `scenes/field/forge_field.tscn` or add a fifth lobby workshop.

## Delivery milestones

Visual milestone complete: nine textured Meshy candidates are rigged and animate in the sandbox lineup. Remaining functional milestones:

1. Implement starter state, armor item data, six-slot loadout, and persistence.
2. Add one Common path and shared damage mitigation while preserving Health signals.
3. Add armor-bay inspection, preview, equip, and lobby-to-mission handoff.
4. Add representative Uncommon, Rare, and Legendary data/effects incrementally.
5. Validate each step on the player in the sandbox and forge field before catalog expansion.

## Balance and acceptance checklist

- [ ] Starter armor feels vulnerable but survives the current mission loop.
- [ ] Each slot has a clear purpose and swapping one piece is understandable.
- [ ] Mitigation has a visible cap and does not trivialize enemy damage.
- [ ] Common through Legendary feel like meaningful upgrades, not only color changes.
- [ ] The outpost can be completed without top-tier gear.
- [ ] Mission rewards cannot duplicate, disappear, or dead-end progression.
- [ ] Save/load, lobby travel, and mission restart preserve the intended state.
- [ ] Preview/apply/cancel and locked/owned/equipped states are unambiguous.
- [ ] Armor preserves silhouette, weapon attachment, locomotion, and camera readability.
- [ ] Assets pass the art/promotion gates before entering the playable slice.
- [ ] Lobby and outpost scene boundaries remain intact.
