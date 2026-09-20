# Gun Options & Progression

Status: design contract (2026-09-10); nine-gun playable sandbox runtime complete as of 2026-09-20. Unlocks, workshop equip flow, and persistence remain planned.

This document is the source of truth for functional guns. Future weapon implementation, balancing, asset production, and Weapons / Forge workshop UI should follow it unless a later design decision updates this document.

The nine-gun art and runtime balance reference is `docs/production/gun-reference-sheet.md`; its machine-readable values are in `docs/production/gun-balance.json`. All nine are playable through the shared gun mount, with final balance tuning pending. Keys 1–9 and sandbox Tab cycling expose the full development catalog; they do not implement owned gear, primary-slot unlocks, or saved loadouts.

## Design promise

The player starts with one dependable but weak forge sidearm. Once that loop is proven, the loadout expands to sidearm plus primary. Primary families such as rifles and energy guns share the same Common, Uncommon, Rare, and Legendary progression, while remaining meaningfully different in how they solve combat problems.

No Legendary weapon is required to complete a mission. Progression should make weapon choice more expressive without invalidating the starter sidearm or turning rarity into automatic victory.

## Loadout slots and weapon families

The first implementation has one mandatory slot:

- **Sidearm** — equipped from the start; Emberflint and the pulse-bolt attack are the current reference baseline.

The expanded loadout adds:

- **Primary** — unlocked after the first sidearm loop is stable. Initial primary families are:
  - **Rifle** — practical sustained fire, reliable range, manageable recoil, and moderate per-shot impact.
  - **Energy gun** — a visibly distinct charge, beam, or energy-projectile behavior with a meaningful heat, charge, or cadence tradeoff.

Future families may include shotgun, burst weapon, precision weapon, or launcher, but they must not be added until the sidearm-plus-one-primary loop is readable and balanced.

A weapon definition owns its family, slot, firing mode, damage, rate of fire, magazine or capacity, reload behavior, range/falloff, projectile or beam behavior, recoil/aim behavior, and visual attachment metadata. These are data, not scattered constants in `player_controller.gd`.

## Starter state

A new player receives one starter sidearm automatically:

- low but reliable damage;
- simple single projectile behavior;
- forgiving enough to complete the current Frontier Outpost slice;
- clearly improved by the first Common sidearm;
- no primary weapon until the primary slot is intentionally unlocked;
- no starting blueprint or resource requirement that can block the first upgrade.

The sidearm must remain useful after the primary slot unlocks. The primary is an additional combat option, not permission to discard the starter weapon.

## Rarity contract

Rarity is a gameplay tier, not only a UI color. Names, silhouettes, stats, firing behavior, and trait text must communicate value without relying on color alone.

| Tier | Role | Design rule |
|---|---|---|
| Common | dependable baseline | First real upgrade over the starter weapon; one straightforward stat improvement or reliability benefit. |
| Uncommon | focused improvement | Better baseline performance plus one clear, low-complexity trait. |
| Rare | build-shaping | Stronger baseline plus a conditional or situational trait that changes weapon choice. |
| Legendary | named signature | Bespoke, bounded effect with clear counterplay; powerful and memorable, never mandatory. |

Higher rarity must not simply multiply every stat. A weapon may gain damage while losing cadence, gain range while losing magazine size, or gain a trait while retaining a lower raw stat. Every upgrade should communicate a reason to choose it.

Trait rules:

1. A Common weapon has no gameplay trait beyond its family behavior.
2. An Uncommon weapon has at most one simple trait.
3. A Rare weapon has at most one build-shaping trait, or one trait with a tightly bounded secondary clause.
4. A Legendary weapon has one signature trait with explicit caps and counterplay.
5. Traits cannot stack into runaway fire rate, damage, range, stun, area damage, or infinite-ammo loops.
6. Exact values, caps, falloff, rounding, and proc rates are tunable data and must be tested against the current outpost combat loop.

## Combat model

Weapon behavior is data-driven and separated from hit reception:

- the weapon owns firing, cooldown, ammo/capacity rules, muzzle origin, and payload construction;
- `gun_projectile.gd` carries projectile movement while the weapon definition supplies damage and effects;
- enemies continue to expose their existing hit contract such as `apply_hit()`;
- weapon code must not duplicate enemy-specific damage logic;
- the current Health/HUD behavior remains unchanged for player survivability and mission feedback.

Initial weapon data should expose at least:

- `weapon_id`, display name, family, slot, rarity;
- base damage and damage type label;
- fire mode, fire interval, burst/charge timing;
- magazine/capacity and reload duration, when applicable;
- projectile/beam speed, lifetime, spread, range, and falloff;
- recoil, aim behavior, and movement/ADS modifiers;
- trait identifier and tunable trait parameters;
- blueprint, resource, visual scene, and muzzle/payload references.

The shared gun runtime already supports magazine ammo, reloads, and heat for weapons that use it. Reserve ammunition inventories, durability, repairs, complex mod sockets, procedural rolls, and deep crafting parts for later work. Do not make the first progression implementation depend on those systems.

## Acquisition and economy

Progression uses mission-forged unlocks, matching the armor contract:

- mission completion grants forge resources and blueprint progress;
- the Weapons / Forge workshop crafts unlocked blueprints and equips owned weapons;
- the first Frontier Outpost completion supplies the first meaningful Common sidearm path;
- the primary slot unlocks at a deliberate milestone after the sidearm loop is validated;
- the first primary blueprint should be a readable rifle before an energy gun introduces a more complex firing model;
- later missions introduce Uncommon, Rare, and Legendary blueprints in controlled order;
- duplicates convert to salvage or upgrade progress rather than dead rewards;
- the player always retains a usable sidearm and cannot spend themselves into a progression dead end.

Legendary guns should be authored signature weapons, not random stat inflation. Costs and reward quantities remain tunable data.

## Player state and persistence

The shared player state planned by the armor contract must also own:

- owned weapon item IDs and blueprint IDs;
- equipped sidearm ID;
- equipped primary ID, nullable until the slot unlocks;
- forge resources, blueprint progress, and progression flags;
- versioned serialization data.

Lobby and mission read the same state. Scene transitions and mission restart must preserve the equipped loadout and must not duplicate completion rewards. A mission restart may reset encounter state, but it must not erase or multiply weapons.

## Weapons / Forge workshop UX

The existing Weapons / Forge bay is the authoritative functional gun entry point. It uses the existing proximity/hold-to-interact pattern and inspection anchor, then opens a focused UI with:

- sidearm and primary slot selection;
- weapon-family filtering;
- equipped, owned, locked, and blueprint states;
- current-versus-preview stat comparison;
- firing behavior and trait explanation;
- blueprint and resource requirements;
- visual preview before commit;
- explicit Apply and Cancel behavior.

The first experience should foreground the sidearm. Once primary weapons exist, the UI must make the distinction between sidearm and primary obvious without making the player manage unnecessary inventory complexity. Outfit / Skin remains cosmetic-only and separate.

## Technical and visual compatibility

The current reference implementation is in `scenes/player/player_controller.gd`, `scenes/combat/gun_mount.gd`, `scenes/combat/gun_projectile.gd`, and `scenes/player/player.tscn`. New weapons must preserve:

- `RightHand` attachment and weapon-follow behavior in third person, with a camera-parented gun in first person so mouse motion does not lag the gun;
- muzzle origin and projectile direction;
- ADS camera feel and alignment;
- pistol locomotion readability while the starter sidearm is equipped;
- holster/draw behavior and third-person camera framing;
- enemy collision layers and the current hit contract;
- mission HUD and crosshair behavior.

Use the visual bible’s Starbone, Void Navy, Frontier Cobalt, and restrained Solar Amber language. Keep family silhouettes distinct: compact sidearm, practical rifle, and unmistakable energy weapon. Avoid generic military camouflage, dense greebles, universal neon, franchise-like symbols, and shapes that obscure aiming or the hero silhouette.

Follow `docs/art/gun-blender-pipeline.md`: use the approved individual concept views to author editable Blender components, then export a Godot GLB. Record each item’s ID, family, slot, rarity, scale, pivot/origin, material slots, collision approach, muzzle marker, payload owner, and runtime scene. Test in `scenes/sandbox/` or `scenes/style_lab/` before promoting into the playable slice. Monument Heart is both the first isolated Blender example and a playable charged orb weapon.

## Delivery milestones

Playable catalog milestone complete: nine data-driven sidearm, rifle, and energy-gun examples span Starter through Legendary in `scenes/sandbox/gunplay_sandbox.tscn`. Ballistic shots retain their own visuals, Splitfin uses a beam, and pulse/echo/solar/orb shots use Binbun MagicProjectilesVFX. Held-fire behavior and target hits are checked by `tools/check_gunplay.gd`. Remaining progression milestones:

1. Add shared weapon state/persistence and sidearm inspection/equip flow at the Weapons / Forge bay.
2. Add the first Common sidearm unlock path and validate rarity/stat/trait presentation.
3. Unlock the primary slot at a deliberate point; validate sidearm-plus-rifle and energy-gun loadouts in the mission loop.
4. Tie Uncommon, Rare, and Legendary examples to acquisition and workshop rules, then tune combat balance.

## Balance and acceptance checklist

- [ ] Starter sidearm is weak but reliably completes the current mission loop.
- [ ] Sidearm remains useful after a primary is unlocked.
- [ ] Rifle and energy gun have clear tradeoffs and distinct silhouettes/behaviors.
- [ ] Common through Legendary feel like meaningful upgrades, not only color changes.
- [ ] Trait caps prevent runaway fire rate, damage, range, or crowd control.
- [ ] Reload/charge/cooldown and ADS behavior remain readable and fair.
- [ ] The outpost can be completed without top-tier gear.
- [ ] Primary unlock timing is understandable and cannot dead-end progression.
- [ ] Mission rewards cannot duplicate, disappear, or grant unusable weapons.
- [ ] Save/load, lobby travel, and mission restart preserve intended weapon state.
- [ ] Preview/apply/cancel and locked/owned/equipped states are unambiguous.
- [ ] Weapons preserve hand attachment, muzzle alignment, locomotion, and camera readability.
- [ ] Assets pass the art/promotion gates before entering the playable slice.
- [ ] Lobby and outpost scene boundaries remain intact.
