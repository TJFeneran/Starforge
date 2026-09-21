"""Record and check a Godot enemy sandbox review as a phone-friendly MP4.

Example:
  python3 tools/record_enemy_preview.py \
    --scene scenes/sandbox/marksman_preview.tscn \
    --output assets/source/blender/rift_marksman/previews/marksman_animation_review.mp4

The scene must support --demo, exit when the sequence ends, and call
RenderingServer.force_draw() while recording. Use --verify-only to inspect an
existing MP4 without launching Godot.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str], *, timeout: int = 900, env: dict[str, str] | None = None) -> str:
    result = subprocess.run(
        command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=timeout
    )
    if result.returncode:
        raise RuntimeError(
            f"Command failed ({result.returncode}): {' '.join(command[:4])}\n"
            f"{result.stdout[-2500:]}\n{result.stderr[-2500:]}"
        )
    return result.stdout


def verify(path: Path) -> dict[str, object]:
    probe = json.loads(
        run(
            [
                "ffprobe", "-v", "error", "-show_entries",
                "format=duration,size:stream=codec_name,width,height,r_frame_rate",
                "-of", "json", str(path),
            ],
            timeout=30,
        )
    )
    video = next((s for s in probe.get("streams", []) if s.get("codec_name") == "h264"), None)
    duration = float(probe.get("format", {}).get("duration", 0))
    if video is None or duration < 8 or video.get("width", 0) < 720:
        raise RuntimeError("MP4 has no usable H.264 video, is too short, or is below 720p")
    hashes = run(
        [
            "ffmpeg", "-v", "error", "-i", str(path), "-vf",
            "fps=1,scale=32:18,format=gray", "-f", "framemd5", "-",
        ],
        timeout=120,
    )
    samples = [line.split(",")[-1].strip() for line in hashes.splitlines() if line and not line.startswith("#")]
    distinct = len(set(samples))
    if distinct < 5:
        raise RuntimeError(
            f"Only {distinct} distinct sampled frames; the desktop may have suppressed rendering"
        )
    return {
        "path": str(path), "duration_seconds": duration,
        "width": video["width"], "height": video["height"],
        "fps": video["r_frame_rate"], "sampled_frames": len(samples),
        "distinct_sampled_frames": distinct, "bytes": int(probe["format"]["size"]),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scene", type=Path, help="Godot sandbox scene with --demo support")
    parser.add_argument("--output", required=True, type=Path, help="Destination MP4")
    parser.add_argument("--display", default=os.environ.get("DISPLAY", ":0"))
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    if not args.verify_only:
        if args.scene is None or not (ROOT / args.scene).is_file():
            parser.error("--scene must point to an existing project scene")
        output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="enemy-preview-") as temp:
            raw = Path(temp) / "capture.avi"
            env = dict(os.environ, DISPLAY=args.display)
            print("Recording the sandbox sequence...", flush=True)
            run(
                [
                    "godot", "--path", str(ROOT), "--audio-driver", "Dummy",
                    "--disable-vsync", "--fixed-fps", "30", "--write-movie", str(raw),
                    str(args.scene), "--", "--demo",
                ],
                env=env,
            )
            print("Encoding H.264 MP4...", flush=True)
            run(
                [
                    "ffmpeg", "-y", "-v", "error", "-i", str(raw),
                    "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p",
                    "-movflags", "+faststart", "-an", str(output),
                ]
            )
    print(json.dumps(verify(output), indent=2))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"ENEMY_PREVIEW_FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
