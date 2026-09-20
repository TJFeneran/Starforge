# Starforge

Third-person space-fantasy game built in **Godot 4.7** (Forward+ / Vulkan). Bright frontier settlements under monumental forge tech — see [`docs/art/visual-bible.md`](docs/art/visual-bible.md).

Entry scene: `scenes/main.tscn` (welcome screen) → forge-hall lobby. Gate destination: `scenes/field/forge_field.tscn`.

## Requirements

| Need | Notes |
| --- | --- |
| **Git LFS** | Art is stored in LFS (~3.3 GB). Install LFS *before* cloning or Godot will fail on pointer files instead of real textures/GLBs. |
| **Godot 4.7** | Standard build (GDScript, not .NET). [4.7.2](https://godotengine.org/download) matches this project. |
| **Vulkan GPU** | Forward+ renderer. Integrated GPUs work; software Vulkan (llvmpipe) is slow but usable. |
| **Disk** | ~4 GB for the clone plus Godot’s `.godot/` import cache after first open. |

Optional (asset pipeline only, not needed to run or export the game):

- **Blender 4.x** — `tools/blender_asset_pipeline.py` and related scripts run inside Blender (`import bpy`), not system Python.
- **Python 3** — only if you run those scripts; no pip packages.

### Install Git LFS

```bash
# Arch / CachyOS
sudo pacman -S git-lfs && git lfs install

# Debian / Ubuntu
sudo apt install git-lfs && git lfs install

# macOS
brew install git-lfs && git lfs install

# Windows: https://git-lfs.com then
git lfs install
```

`git lfs install` is once per machine (global Git filters). Skip it only if those filters are already configured.

## Clone and first import

```bash
git clone https://github.com/TJFeneran/Starforge.git
cd Starforge
git lfs pull
```

If PNGs/GLBs are ~130-byte text files (`version https://git-lfs.github.com/...`), LFS did not smudge — install Git LFS and run `git lfs pull`.

Open the project in Godot 4.7, or import from the CLI:

```bash
godot --headless --import --path .
```

First import builds `.godot/` (gitignored) and can take several minutes.

## Run

**Editor:** open `project.godot` and press Play (F5). Main scene is `res://scenes/main.tscn`.

**CLI:**

```bash
godot --path .
# or
godot --path . --resolution 1920x1080
```

Window is 1920×1080 (internal render 3840×2160).

### Controls

| Action | Input |
| --- | --- |
| Move | WASD |
| Look | Mouse |
| Camera zoom | Wheel up to move closer; wheel down to move back (final inward step enters first person) |
| Jump | Space |
| Sprint | Shift |
| Interact | E |
| Fire | LMB while aiming, or LMB directly in first person |
| Aim | RMB |
| Select gun | 1–9 |
| Reload | R (guns with magazines) |
| Pause | Esc |

For gunplay testing, run `res://scenes/sandbox/gunplay_sandbox.tscn` (F6). Use 1–9 or Tab / Shift+Tab to change guns.

For armor visual review, run `res://scenes/sandbox/armor_preview.tscn` (F6). Nine labeled Meshy models cycle through animations; WASD moves the camera, Shift moves faster, mouse drag orbits, wheel zooms, Space advances the animation, and R resets the camera. This scene previews art and rigs; it does not equip armor in gameplay.

## Build / export

`export_presets.cfg` is gitignored, so a fresh machine has no export presets yet.

1. Install **export templates** for Godot 4.7: Editor → Manage Export Templates (must match the editor version).
2. Project → Export → Add… (Linux, Windows, macOS, etc.).
3. Export from the dialog, or CLI once a preset exists:

```bash
mkdir -p build
godot --headless --path . --export-release "Linux" build/Starforge.x86_64
```

Replace `"Linux"` with the preset name you created. Release and debug templates are both required if you export both kinds.

No extra SDKs are required for desktop exports. Android/iOS need the usual Godot platform toolchains and are not set up in this repo.

## Repo layout

| Path | Role |
| --- | --- |
| `scenes/main.tscn` | Launch / welcome |
| `scenes/lobby/` | Forge-hall hub |
| `scenes/field/forge_field.tscn` | Open field reached through the lobby gate |
| `scenes/sandbox/gunplay_sandbox.tscn` | Isolated gunplay testing |
| `scenes/sandbox/armor_preview.tscn` | Nine-model armor and animation preview |
| `assets/models/` | Runtime GLBs Godot imports |
| `assets/source/` | Editable Blender sources, concept references, and original external assets (`.gdignore` — not imported) |
| `tools/` | Blender/Godot helper scripts |
| `docs/` | Art bible, pipeline, production notes |

Runtime GLBs under `assets/models/` are what the game loads. Gun `.blend` sources and their reproducible build scripts are kept under `assets/source/blender/` and `tools/`. Armor uses Meshy source GLBs under `assets/source/meshy/armor_*/`, editable Blender rigs under `assets/source/blender/armor_*/`, and preview exports under `assets/models/gear/armor/previews/`.

## Docs

- [`docs/production/HANDOFF.md`](docs/production/HANDOFF.md) — current status and scene boundaries
- [`docs/art/visual-bible.md`](docs/art/visual-bible.md) — visual direction
- [`docs/art/meshy-pipeline.md`](docs/art/meshy-pipeline.md) — Meshy → Blender → Godot
- [`docs/art/gun-blender-pipeline.md`](docs/art/gun-blender-pipeline.md) — authored Blender → Godot guns
- [`docs/production/gun-reference-sheet.md`](docs/production/gun-reference-sheet.md) — nine-gun art and numeric progression reference
- [`docs/production/vertical-slice.md`](docs/production/vertical-slice.md) — playable-slice rules
- [`assets/README.md`](assets/README.md) — asset folder layout
