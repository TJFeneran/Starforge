# Starforge — agent operating guide

Starforge is a **Godot 4.7 third-person 3D game** (renderer: Forward+). Art assets
are stored with **Git LFS**. See `docs/production/HANDOFF.md` for design/status and
`project.godot` for the entry point (`res://scenes/main.tscn` → `scenes/lobby/lobby.tscn`).

## Environment

The Cloud Agent environment ships Godot 4.7.2 (`/usr/local/bin/godot`), `git-lfs`,
Mesa Vulkan (`llvmpipe` software renderer), `ffmpeg`, and `xdotool`. Setup is done by
the `install` step; you normally don't need to run it by hand.

`install` (idempotent) does:

```bash
git lfs pull                       # fetch ~3.4 GB of LFS art assets (real files, not pointers)
git add --renormalize .            # settle the LFS stat-cache so `git status` stays clean
godot --headless --import --path . # generate the .godot/ import cache
```

Notes:
- Do not run `git lfs install` in this repo — it conflicts with the managed git hooks.
  The LFS clean/smudge filters are already configured, so `git lfs pull` is enough.
- After a fresh `git lfs pull`, LFS files can show as modified in `git status` due to a
  stale index stat-cache; `git add --renormalize .` (run by `install`) clears this.

## Running / rendering the game

There is **no GPU**; rendering uses software Vulkan (`llvmpipe`). The platform provides
a VNC desktop X server on display `:1` automatically — use it (no custom Xvfb needed):

```bash
export DISPLAY=:1
export XAUTHORITY=/home/ubuntu/.Xauthority
godot --path . --resolution 1600x900
```

Capture a screenshot / recording of the running game with ffmpeg:

```bash
# screenshot
ffmpeg -y -f x11grab -video_size 1920x1200 -i :1 -frames:v 1 -update 1 shot.png
# short recording
ffmpeg -y -f x11grab -video_size 1920x1200 -framerate 30 -i :1 -t 10 -pix_fmt yuv420p demo.mp4
```

Drive input for demos with `xdotool` (window title is `Starforge`), e.g.
`xdotool search --name Starforge windowactivate --sync key space`.

Controls: WASD move, mouse look, Space jump, Shift sprint, E interact, LMB attack,
RMB aim, R restart mission (in the playable slice).

Expected, harmless startup messages: ALSA audio fails and falls back to the dummy
driver (headless, no sound card), and there is a non-fatal invalid-UID warning for
`lobby.tscn`.

## Validating changes

- Verify the project imports cleanly: `godot --headless --import --path .`
- For visual/scene changes, run the game on `:1` and capture a screenshot or recording
  as evidence (see above).
- Test experiments in `scenes/sandbox/` or `scenes/style_lab/`, not by breaking the
  playable slice (`scenes/playable/outpost_slice.tscn`) or the lobby hub. Keep the scene
  boundaries in `docs/production/HANDOFF.md` intact.
