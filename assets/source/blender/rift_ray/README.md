# Rift Ray A — Crescent

The untouched Meshy 7 source is `assets/source/meshy/rift_ray/ray_a.glb` (task `01a0c144-5132-7262-af6b-8cfcec957008`, 30 credits). Its selected appearance reference is `assets/source/concepts/enemies/rift_ray/views/three_quarter.png`. Front, side, back and top source inspection images are in the source `preview/` folder.

`ray_rigged.blend` is the editable Blender rig and `assets/models/enemies/rift_ray/ray.glb` is the Godot export. Rebuild with `blender -b --factory-startup -t 4 --python tools/build_ray.py`; check runtime clips with `godot --headless --path . --script tools/check_ray.gd`; open `scenes/sandbox/rift_ray_preview.tscn` for interactive review. The sandbox supports Tab/Shift+Tab clip selection, Space pause, R restart, A auto cycle, mouse drag orbit, wheel zoom, and C source comparison.

The body origin is at its neutral hover center; the sandbox alone displays it 1.35 m above the grid. Wingspan is 1.6 m, forward is Godot +Z, and flight clips have no travel. The `muzzle_socket` marks the facial energy aperture; the projectile remains a separate runtime effect. The attack contact is frame 6/30, 0.200 s into the 0.600 s `attack` clip.

The generated source had a longer rear taper than the selected brief. The Blender build compresses only the tail after its body seam (factor 0.42), retaining the original UVs, texture resolution and raw source file. Other geometry is conservatively reduced by 18%: 118,401 to 97,087 triangles. Sampled optimization error is 0.025 mm at the 99th percentile and 0.048 mm maximum, measured against the tail-corrected geometry; see `validation.json` for all measurements. The 13-bone rig has rigid body and fin segments with narrow hinge blends so the cream fin edge does not visibly stretch.

Nine authored 30 fps clips: `hover_idle`, `fly_forward`, `bank_left`, `bank_right`, `attack_anticipation`, `attack`, `attack_recovery`, `hit`, and `death`. The first four loop. The death pose tips and loses lift, while gameplay handles final descent and collision.
