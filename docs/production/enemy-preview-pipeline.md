# Enemy and boss production from a phone

Use this playbook when the user asks for another Starforge enemy or boss. The user can choose a design, approve a quoted Meshy spend, review pictures and the animation video, and request revisions from a phone. The agent performs local Blender, Godot, and video work on the connected computer. Google Drive carries the final MP4 to the phone; a local file link in chat does not.

## 1. Define one asset

Record the asset slug, role (enemy or boss), target height or wingspan, selected concept image, anatomy, separate props, and required moves. Use `assets/source/concepts/enemies/manifest.json` and the chosen `brief.md` for the four existing selected designs. Show a compact concept image or contact sheet in chat so the user can choose from the phone. Use the approved three-quarter view as the appearance reference and the other views to resolve hidden anatomy. Do not silently replace a selected design with another candidate.

Make a clip list for the asset, rather than assuming humanoid moves fit every creature. The usual minimum is idle or hover, walk/run or flight, turn/strafe when useful, attack anticipation, attack/contact, recovery, hit, and death. Bosses also need each named phase or signature attack and a phase transition. Record the gameplay contact frame for each attack.

## 2. Generate one source model

Use `docs/art/meshy-pipeline.md` for model defaults. Before a paid Meshy call, report the exact operation, credit cost, current balance, reference image, and settings in one phone-readable message; wait for explicit approval for that spend. One approval covers only the quoted operation. Record task ID, cost, inputs, settings, and result in `assets/source/meshy/<slug>/generation_request.json`. Download the untouched GLB and textures there. Inspect front, side, back, and three-quarter renders; report anatomy defects before rigging. A retry or paid rig/animation service is a new spend decision.

## 3. Optimize and rig in Blender

Keep the original source intact. Save an editable `.blend` in `assets/source/blender/<slug>/` and a runtime GLB in `assets/models/enemies/<slug>/`. Set metric scale and a consistent facing/origin. Fit a skeleton to the actual generated anatomy: quadruped legs for Skitter, rigid mechanical joints for Bulwark, fin and tail chains for Ray, and a humanoid rig only where appropriate. Keep a separate weapon/prop attached to a socket. Preserve usable UVs, texture resolution, silhouette, hands, crest, and attack surfaces.

Reduce triangles conservatively and measure the actual change against the source. Inspect the optimized silhouette and material side by side before accepting it. Record source and final triangle counts, material/texture status, scale, bone count, skin coverage, and sampled surface error in `assets/source/blender/<slug>/validation.json`. An asset can be accepted with less or no reduction if more would harm its shape. Rig and animate at 30 fps initially; keep locomotion in place. Test extreme poses, floor or hover clearance, joint intersections, weapon grips, loop seams, and death settling. Keep a named clip manifest with durations, looping, contact frames, and prop notes.

The Marksman pilot is a worked example: `tools/build_marksman.py`, `assets/source/blender/rift_marksman/README.md`, and `assets/models/enemies/rift_marksman/animation_manifest.json`. Its fitted coordinates and 25% reduction are asset-specific, not global targets.

## 4. Inspect and record in Godot

Create `scenes/sandbox/<slug>_preview.tscn` and its script by adapting the Marksman review scene. Set the new model path, display name, clip list and sequence, scale ruler, comparison source, and any optional prop. Keep gameplay scenes unchanged while reviewing. Support `--demo` to play every named clip with on-screen labels, source/optimized comparison where available, and a final turntable. Call `RenderingServer.force_draw(false, delta)` during the demo so an occluded desktop still renders each frame. Provide interactive clip selection, orbit, and a way to hide the reference prop. Adjust camera framing for large bosses and flying creatures.

Run the Godot import and a focused asset check; verify clip names, loops, root motion policy, facing, contact frames, and visibly moving bones. Capture the video with:

```bash
python3 tools/record_enemy_preview.py \
  --scene scenes/sandbox/<slug>_preview.tscn \
  --output assets/source/blender/<slug>/previews/<slug>_animation_review.mp4
```

The recorder writes an H.264, 30 fps, fast-start MP4 for phones and checks duration, resolution, and sampled frame changes. Also inspect representative frames from every clip before delivery; automatic checks cannot judge deformation or fidelity. Use `--verify-only --output <path>` to check an existing video. Keep the preview scene and validation files alongside the video so a revision is reproducible.

## 5. Deliver to the phone and promote

Upload the finished MP4 to the user's connected Google Drive. Put it in a clear `Starforge/Enemy Previews/<slug>/` folder with a versioned filename. Verify the upload completed and its link opens before sending it in chat. Prefer a Drive link that grants only the user's account access; request an access change if a broader share is desired. Include a small still/contact sheet, clip list, triangle comparison, and any known limitation in the same message. A local `/home/...` link is useful on the host but cannot serve as the phone download.

For a user-requested test encounter, place the new actor in the first selectable level and keep its behavior isolated from campaign progression. Verify animation, collision, AI, damage, performance, and the encounter before calling it ready. The user can review the Drive video and request revisions before the actor becomes a permanent campaign enemy. Track revisions with the source generation ID and a new local version; never treat a Blender adjustment as a new paid Meshy operation.

## Phone request format

The user can send a short message such as: “Build the selected Rift Skitter B next. Show the concept, quote Meshy credits, then make the optimized rig, sandbox clip review, and Drive video.” The agent supplies checkpoints in chat, runs the local work, and returns the Drive download link. For bosses, add the phase moves and scale in that request.
