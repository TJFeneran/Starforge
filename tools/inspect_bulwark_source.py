"""Inspect and render the untouched Meshy Split Crown source GLB."""
import json, os, sys, traceback
from pathlib import Path
import bpy
from mathutils import Vector

def fail(typ, value, tb):
    traceback.print_exception(typ, value, tb)
    sys.stderr.flush()
    os._exit(1)
sys.excepthook = fail
root = Path(__file__).resolve().parents[1]
src = root / "assets/source/meshy/forge_bulwark/bulwark_a.glb"
out = root / "assets/source/meshy/forge_bulwark/preview"
out.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(src))
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
assert meshes, "No mesh in source"
verts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo = Vector(tuple(min(v[i] for v in verts) for i in range(3)))
hi = Vector(tuple(max(v[i] for v in verts) for i in range(3)))
report = {"meshes": [(o.name, len(o.data.vertices), len(o.data.polygons)) for o in meshes],
          "bbox_min": list(lo), "bbox_max": list(hi),
          "images": [(im.name, list(im.size)) for im in bpy.data.images],
          "materials": [m.name for m in bpy.data.materials]}
(out / "inspection.json").write_text(json.dumps(report, indent=2) + "\n")
print("BULWARK_SOURCE", json.dumps(report), flush=True)

center = (lo + hi) / 2
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.resolution_x = 800
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.world.color = (.16, .16, .16)
for loc, energy in [((3,-4,6), 500), ((-4,-2,3), 320), ((0,4,5), 530)]:
    bpy.ops.object.light_add(type="AREA", location=loc)
    lamp = bpy.context.object
    lamp.data.energy = energy
    lamp.data.shape = "DISK"
    lamp.data.size = 4
    lamp.rotation_euler = (center-lamp.location).to_track_quat("-Z", "Y").to_euler()
bpy.ops.object.camera_add()
cam = bpy.context.object
cam.data.type = "ORTHO"
cam.data.ortho_scale = max(hi.z-lo.z, hi.x-lo.x)*1.3
scene.camera = cam
radius = max(hi.z-lo.z, hi.x-lo.x)*1.7
for name, direction in [("front", (0,-1,.05)), ("side", (1,0,.05)), ("back", (0,1,.05)), ("hero", (1,-1,.24))]:
    vec = Vector(direction).normalized()
    cam.location = center + vec*radius
    cam.rotation_euler = (center-cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(out / f"{name}.png")
    bpy.ops.render.render(write_still=True)
sys.stdout.flush()
os._exit(0)
