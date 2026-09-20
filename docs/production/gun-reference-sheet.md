# Starforge gun reference sheet

![All nine guns with tier and firing snapshot](gun-reference-sheet.png)

**Status:** all nine guns are selectable and use these values in gameplay. Balance tuning and human visual review remain pending. All DPS figures ignore reloads, travel, falloff, and traits.

The current Rift Skitter has **60 HP**. Projectile range below is speed × lifetime; beams are instantaneous within their listed range. A shot's first hit is at trigger time plus travel (and charge time where applicable).

| Gun | Tier / slot | Payload | Damage | Interval | No-reload DPS | Speed / range | Capacity / recovery | Spread ADS / hip | Trait |
|---|---|---|---:|---:|---:|---|---|---|---|
| **Emberflint** | starter / sidearm | single forge pulse bolt | 34 | 0.28 s | 121.4 | 42 m/s / 23.1 m | 10 shots / 1.35 s reload | 1.5° / 4° | none |
| **Forge Latch** | common / sidearm | single heavy slug | 40 | 0.28 s | 142.9 | 58 m/s / 34.8 m | 9 shots / 1.25 s reload | 1.2° / 3.5° | none |
| **Echo Bit** | uncommon / sidearm | two pulse bits per trigger | 26 × 2 | 0.36 s | 144.4 | 52 m/s / 36.4 m | 18 shots / 1.6 s reload | 1° / 3° | Every third trigger emits one 8-damage echo pulse at the last hit target; maximum one echo per trigger and no chaining. |
| **Vault Needle** | rare / sidearm | single precision needle | 55 | 0.42 s | 131.0 | 100 m/s / 100 m | 6 shots / 1.75 s reload | 0.25° / 5° | Weak-point hits deal 1.5× base damage (82.5 HP); this multiplier does not stack with other weapon traits. |
| **Dawnseal** | legendary / sidearm | single solar bolt | 45 | 0.27 s | 166.7 | 65 m/s / 52 m | 12 shots / 1.65 s reload | 0.9° / 3.2° | The first hit after a reload marks one target for 3.0 s; the next hit consumes it for 24 bonus solar damage. One mark per reload; no splash or chaining. |
| **Ridge Repeater** | common / primary | automatic ballistic rounds | 20 | 0.1 s | 200.0 | 90 m/s / 72 m | 30 shots / 2 s reload | 1.1° / 4.5° | none |
| **Longpath** | uncommon / primary | semi-auto high-velocity rounds | 45 | 0.22 s | 204.5 | 130 m/s / 117 m | 12 shots / 2.2 s reload | 0.65° / 6° | After 0.5 s continuously aiming, ADS spread drops from 0.65° to 0.20° until aim is released. |
| **Splitfin Beam** | rare / primary | continuous beam; one damage tick every 0.20 s | 30 | 0.2 s | 150.0 | instant / 45 m | 100 heat / 2 s lockout | 0° / 0° | Beam pierces one additional target for 50% tick damage (15 HP); maximum two targets total. |
| **Monument Heart** | legendary / primary | charged plasma orb | 120 | 0.7 s | 171.4 | 35 m/s / 42 m | 5 shots / 2.5 s reload | 0.5° / 2.5° | On direct hit, a 2.5 m radial pulse deals 50 HP to up to three other targets; excludes the direct target and cannot chain. |

## Why each step earns its tier

- **Emberflint → Forge Latch:** 34 → 40 HP per shot and 23.1 → 34.8 m reach at the same 0.28 s cadence; Latch holds 9 rather than 10 and kicks harder.
- **Forge Latch → Echo Bit:** two 26-HP bits make a 52-HP burst, and every third trigger can add one bounded 8-HP echo. Echo asks for two hits and a 1.60 s reload.
- **Echo Bit → Vault Needle:** 100 m/s precision needles reach 100 m; a 1.5× weak-point hit deals 82.5 HP, enough for one 60-HP skitter. Six rounds and 0.42 s cadence reward aim over spam.
- **Vault Needle → Dawnseal:** 0.27 s cadence, 12 rounds, and a one-per-reload 24-HP mark detonation improve sustained sidearm utility. Needle retains superior precision and range.
- **Ridge Repeater → Longpath:** 45 vs 20 HP per round, 117 vs 72 m reach, and 0.20° settled ADS spread. Longpath gives up 30-round automatic fire for a 12-round semi-auto magazine.
- **Splitfin Beam → Monument Heart:** Monument's 120-HP orb and bounded 50-HP radial pulse favor burst and clustered enemies. Splitfin keeps instant hits, sustained beam damage, and one-target pierce.

## Exact firing rules and limits

### Emberflint — starter sidearm

- **Firing:** single forge pulse bolt; 34 HP per hit; 0.28 s trigger interval.
- **Travel and range:** 42 m/s for 0.55 s; maximum 23.1 m. Damage falloff begins at 23.1 m and reaches 100% at 23.1 m.
- **Handling:** ADS/hip spread 1.5°/4°; recoil 1.8°. 10 rounds; 1.35 s reload.
- **Trait:** none
- **Tradeoff:** Reliable starter; short reach and modest capacity.
- **Implementation:** playable; balance tuning pending.

### Forge Latch — common sidearm

- **Firing:** single heavy slug; 40 HP per hit; 0.28 s trigger interval.
- **Travel and range:** 58 m/s for 0.6 s; maximum 34.8 m. Damage falloff begins at 24 m and reaches 80% at 34.8 m.
- **Handling:** ADS/hip spread 1.2°/3.5°; recoil 2.4°. 9 rounds; 1.25 s reload.
- **Trait:** none
- **Tradeoff:** Six more damage and longer reach than Emberflint, with one fewer round and more recoil.
- **Implementation:** playable; balance tuning pending.

### Echo Bit — uncommon sidearm

- **Firing:** two pulse bits per trigger; 26 HP per hit; 0.36 s trigger interval. Burst spacing: 0.075 s.
- **Travel and range:** 52 m/s for 0.7 s; maximum 36.4 m. Damage falloff begins at 25 m and reaches 75% at 36.4 m.
- **Handling:** ADS/hip spread 1°/3°; recoil 1.2°. 18 rounds; 1.6 s reload.
- **Trait:** Every third trigger emits one 8-damage echo pulse at the last hit target; maximum one echo per trigger and no chaining.
- **Tradeoff:** Faster two-hit burst and a bounded echo, but both bits must land and reload takes longer.
- **Implementation:** playable; balance tuning pending.

### Vault Needle — rare sidearm

- **Firing:** single precision needle; 55 HP per hit; 0.42 s trigger interval.
- **Travel and range:** 100 m/s for 1 s; maximum 100 m. Damage falloff begins at 65 m and reaches 80% at 100 m.
- **Handling:** ADS/hip spread 0.25°/5°; recoil 3.5°. 6 rounds; 1.75 s reload.
- **Trait:** Weak-point hits deal 1.5× base damage (82.5 HP); this multiplier does not stack with other weapon traits.
- **Tradeoff:** Precision and a conditional one-hit skitter kill, balanced by six rounds, slow cadence and poor hip accuracy.
- **Implementation:** playable; balance tuning pending.

### Dawnseal — legendary sidearm

- **Firing:** single solar bolt; 45 HP per hit; 0.27 s trigger interval.
- **Travel and range:** 65 m/s for 0.8 s; maximum 52 m. Damage falloff begins at 35 m and reaches 80% at 52 m.
- **Handling:** ADS/hip spread 0.9°/3.2°; recoil 2°. 12 rounds; 1.65 s reload.
- **Trait:** The first hit after a reload marks one target for 3.0 s; the next hit consumes it for 24 bonus solar damage. One mark per reload; no splash or chaining.
- **Tradeoff:** Higher direct output and a bounded two-hit signature, but the mark requires a reload and a follow-up hit.
- **Implementation:** playable; balance tuning pending.

### Ridge Repeater — common rifle

- **Firing:** automatic ballistic rounds; 20 HP per hit; 0.1 s trigger interval.
- **Travel and range:** 90 m/s for 0.8 s; maximum 72 m. Damage falloff begins at 45 m and reaches 75% at 72 m.
- **Handling:** ADS/hip spread 1.1°/4.5°; recoil 0.65°. 30 rounds; 2 s reload.
- **Trait:** none
- **Tradeoff:** First primary: sustained fire and capacity, but lower per-hit damage and slower reload than a sidearm.
- **Implementation:** playable; balance tuning pending.

### Longpath — uncommon rifle

- **Firing:** semi-auto high-velocity rounds; 45 HP per hit; 0.22 s trigger interval.
- **Travel and range:** 130 m/s for 0.9 s; maximum 117 m. Damage falloff begins at 75 m and reaches 80% at 117 m.
- **Handling:** ADS/hip spread 0.65°/6°; recoil 2.2°. 12 rounds; 2.2 s reload.
- **Trait:** After 0.5 s continuously aiming, ADS spread drops from 0.65° to 0.20° until aim is released.
- **Tradeoff:** More range and precision than Ridge, but 12 rounds, stronger recoil and poor hip accuracy.
- **Implementation:** playable; balance tuning pending.

### Splitfin Beam — rare energy

- **Firing:** continuous beam; one damage tick every 0.20 s; 30 HP per hit; 0.2 s trigger interval.
- **Travel and range:** instant beam; maximum 45 m. Damage falloff begins at 35 m and reaches 70% at 45 m.
- **Handling:** ADS/hip spread 0°/0°; recoil 0°. 100 heat capacity; 5 heat per tick, 25 heat/s cooling, 2 s overheat lockout.
- **Trait:** Beam pierces one additional target for 50% tick damage (15 HP); maximum two targets total.
- **Tradeoff:** Instant, accurate sustained damage and limited pierce; 4.0 s continuous fire overheats it.
- **Implementation:** playable; balance tuning pending.

### Monument Heart — legendary energy

- **Firing:** charged plasma orb; 120 HP per hit; 0.7 s trigger interval. Charge: 0.45 s; recovery: 0.25 s.
- **Travel and range:** 35 m/s for 1.2 s; maximum 42 m. Damage falloff begins at 32 m and reaches 80% at 42 m.
- **Handling:** ADS/hip spread 0.5°/2.5°; recoil 4°. 5 rounds; 2.5 s reload.
- **Trait:** On direct hit, a 2.5 m radial pulse deals 50 HP to up to three other targets; excludes the direct target and cannot chain.
- **Tradeoff:** Higher burst and bounded crowd damage than Splitfin, balanced by charge, five cells and projectile travel.
- **Implementation:** playable; balance tuning pending.

## Art assets and review

All nine models imported in Godot 4.7.2. Animation and emissive material names were inspected from the imported scenes. Open [`gunplay_sandbox.tscn`](../../scenes/sandbox/gunplay_sandbox.tscn) to test guns with 1–9 or Tab / Shift+Tab. Pulse, echo, solar, and orb use Binbun MagicProjectilesVFX and repeat while LMB is held; ballistic shots keep their own visuals, Splitfin keeps its beam, and Longpath remains one shot per press. In first person the gun is parented to the camera so it stays steady during mouse movement. The [Godot gallery contact sheet](gun-gallery-godot.png) records the nine runtime models. Final balance tuning remains pending.

| Gun | Editable source | Runtime GLB | Render | Animation | Adjustable glow |
|---|---|---|---|---|---|
| Emberflint | [Blender](../../assets/source/blender/emberflint/emberflint.blend) | [GLB](../../assets/models/gear/guns/emberflint/emberflint.glb) | [hero](../../assets/source/blender/emberflint/previews/hero.png) | none | none |
| Forge Latch | [Blender](../../assets/source/blender/latch/latch.blend) | [GLB](../../assets/models/gear/guns/latch/latch.glb) | [hero](../../assets/source/blender/latch/previews/hero.png) | Fire_Recoil | none |
| Echo Bit | [Blender](../../assets/source/blender/echo/echo.blend) | [GLB](../../assets/models/gear/guns/echo/echo.glb) | [hero](../../assets/source/blender/echo/previews/hero.png) | Fire_Recoil, Core_Idle_Pulse | mint capacitor rings |
| Vault Needle | [Blender](../../assets/source/blender/rare_needle/rare_needle.blend) | [GLB](../../assets/models/gear/guns/rare_needle/rare_needle.glb) | [hero](../../assets/source/blender/rare_needle/previews/hero.png) | Fire | cyan aim line |
| Dawnseal | [Blender](../../assets/source/blender/dawnseal/dawnseal.blend) | [GLB](../../assets/models/gear/guns/dawnseal/dawnseal.glb) | [hero](../../assets/source/blender/dawnseal/previews/dawnseal_hero.png) | Fire, Charge | solar chamber |
| Ridge Repeater | [Blender](../../assets/source/blender/ridge/ridge.blend) | [GLB](../../assets/models/gear/guns/ridge/ridge.glb) | [hero](../../assets/source/blender/ridge/previews/hero.png) | Fire, Reload | none |
| Longpath | [Blender](../../assets/source/blender/longpath/longpath.blend) | [GLB](../../assets/models/gear/guns/longpath/longpath.glb) | [hero](../../assets/source/blender/longpath/previews/hero.png) | Fire, Reload | cyan optic |
| Splitfin Beam | [Blender](../../assets/source/blender/splitfin/splitfin.blend) | [GLB](../../assets/models/gear/guns/splitfin/splitfin.glb) | [hero](../../assets/source/blender/splitfin/previews/hero.png) | Splitfin_Charge | amber core |
| Monument Heart | [Blender](../../assets/source/blender/monument_heart/monument_heart.blend) | [GLB](../../assets/models/gear/guns/monument_heart/monument_heart.glb) | [hero](../../assets/source/blender/monument_heart/previews/hero.png) | Ring_Spin | core and ring independently |
