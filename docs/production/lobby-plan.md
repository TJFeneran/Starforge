# Starforge Lobby Plan

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
