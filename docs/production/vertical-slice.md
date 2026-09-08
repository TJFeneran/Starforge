# Starforge Vertical Slice

## Current target

A small, reliable third-person outpost slice:

- One courtyard and one connected rift approach.
- One player character with locomotion, jump, and sidearm.
- One Rift Skitter enemy.
- One objective chain: beacon → monument → canopy → rift signal.
- One completion state and safe replay.

The goal is a playable loop, not a showcase of every planned system.

## Scene boundaries

- `scenes/main.tscn`: shipping entry point only.
- `scenes/playable/outpost_slice.tscn`: playable mission composition.
- `scenes/style_lab/style_lab.tscn`: visual/environment development source.
- `scenes/sandbox/controller_sandbox.tscn`: isolated controller, camera, jump, and weapon testing.

Do not use the playable scene for asset experiments. Do not add experimental collision or animation code to the sandbox without first proving it in isolation.

## Asset promotion gate

An asset moves from source to playable only after it passes:

1. Correct real-world scale and facing.
2. Origin/pivot is useful for its gameplay role.
3. GLB opens in Godot with materials and textures intact.
4. Collision is simple, intentional, and performant.
5. It is visually consistent with the frozen visual bible.
6. It has a clear scene owner and does not depend on hidden editor state.

## Working loop

1. Build or clean one asset.
2. Test it in the relevant sandbox.
3. Add the smallest gameplay interaction needed to validate it.
4. Promote it into the playable slice only after the gate passes.
5. Leave broad asset generation and expansion until the loop is stable.
