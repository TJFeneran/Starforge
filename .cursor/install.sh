#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for Starforge (Godot 4.7 / Forward+).
# Safe to re-run: it only installs what is missing and settles the LFS cache.
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ZIP}.zip"
GODOT_BIN="/usr/local/bin/godot"

log() { printf '\n=== %s ===\n' "$*"; }

# 1. System packages: software Vulkan (llvmpipe/lavapipe) plus the tools used to
#    run and capture the game headlessly. git-lfs/ffmpeg/xdotool ship in the base
#    image; install them too if a leaner base is ever used.
log "Installing system packages (Vulkan software renderer + capture tools)"
export DEBIAN_FRONTEND=noninteractive
NEED_PKGS=()
for pkg in mesa-vulkan-drivers vulkan-tools libvulkan1 git-lfs ffmpeg xdotool unzip; do
  dpkg -s "$pkg" >/dev/null 2>&1 || NEED_PKGS+=("$pkg")
done
if [ "${#NEED_PKGS[@]}" -gt 0 ]; then
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends "${NEED_PKGS[@]}"
else
  echo "All system packages already present."
fi

# 2. Godot editor/runtime (standard GDScript build, matches project.godot 4.7).
if [ -x "$GODOT_BIN" ] && "$GODOT_BIN" --version 2>/dev/null | grep -q "${GODOT_VERSION%-stable}"; then
  echo "Godot ${GODOT_VERSION} already installed at ${GODOT_BIN}."
else
  log "Installing Godot ${GODOT_VERSION}"
  tmp="$(mktemp -d)"
  curl -sSL -o "${tmp}/godot.zip" "$GODOT_URL"
  unzip -o "${tmp}/godot.zip" -d "$tmp"
  sudo mv "${tmp}/${GODOT_ZIP}" "$GODOT_BIN"
  sudo chmod +x "$GODOT_BIN"
  rm -rf "$tmp"
  "$GODOT_BIN" --version
fi

# 3. Fetch LFS art assets (~3.4 GB of real textures/GLBs, not pointer files).
#    Do NOT run `git lfs install` here — the repo's managed hooks already wire up
#    the clean/smudge filters; `git lfs pull` is enough.
log "Pulling Git LFS assets"
git lfs pull

# 4. Settle the LFS stat-cache so a fresh pull does not leave files showing as
#    modified in `git status`.
log "Renormalizing LFS stat-cache"
git add --renormalize .

# 5. Generate the .godot/ import cache (gitignored). Needs a Vulkan-capable
#    environment; the platform provides a software-Vulkan X server on :1.
log "Importing project (builds .godot/ cache)"
export DISPLAY="${DISPLAY:-:1}"
export XAUTHORITY="${XAUTHORITY:-/home/ubuntu/.Xauthority}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -un)}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
"$GODOT_BIN" --headless --import --path .

log "Starforge environment ready"
