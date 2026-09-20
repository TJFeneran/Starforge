"""Render a Meshy character GLB at player scale without importing it to Godot.

blender -b --factory-startup -t 4 --python tools/preview_meshy_armor.py -- \
  INPUT.glb OUTPUT_DIRECTORY
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1 :]
source, output = Path(argv[0]).resolve(), Path(argv[1]).resolve()
solid_preview = len(argv) > 2 and argv[2] == "--solid"
output.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
if not meshes:
    raise RuntimeError(f"No meshes in {source}")
if solid_preview:
    solid = bpy.data.materials.new("Solid_Geometry_Check")
    solid.diffuse_color = (0.62, 0.62, 0.62, 1)
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(solid)

def bounds():
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    return Vector(tuple(min(p[i] for p in points) for i in range(3))), Vector(
        tuple(max(p[i] for p in points) for i in range(3))
    )

minimum, maximum = bounds()
scale = 1.8 / (maximum.z - minimum.z)
for obj in bpy.context.scene.objects:
    if obj.parent is None and obj.type in {"MESH", "EMPTY", "ARMATURE"}:
        obj.scale *= scale
bpy.context.view_layer.update()
minimum, maximum = bounds()
center = (minimum + maximum) / 2
for obj in bpy.context.scene.objects:
    if obj.parent is None and obj.type in {"MESH", "EMPTY", "ARMATURE"}:
        obj.location.x -= center.x
        obj.location.y -= center.y
        obj.location.z -= minimum.z
bpy.context.view_layer.update()
minimum, maximum = bounds()

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.render.resolution_x = 900
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.world.color = (0.72, 0.72, 0.72)

def area(name, location, energy, size):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.rotation_euler = (Vector((0, 0, 0.95)) - light.location).to_track_quat("-Z", "Y").to_euler()

area("Key", (2, -3, 3.8), 850, 4)
area("Fill", (-2, -2, 2.6), 450, 3)
area("Rim", (1, 2, 3.2), 600, 3)
for label, point in {
    "front": (0, -4, 1.5), "hero": (2.8, -4.0, 2.1),
    "side": (4, 0, 1.5), "back": (0, 4, 1.5),
}.items():
    bpy.ops.object.camera_add(location=point)
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.90)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.25
    scene.camera = camera
    scene.render.filepath = str(output / f"{label}.png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)

report = {
    "source": str(source),
    "bounds_min_m": list(minimum),
    "bounds_max_m": list(maximum),
    "mesh_count": len(meshes),
    "face_count": sum(len(obj.data.polygons) for obj in meshes),
    "triangle_count": sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in meshes),
    "materials": sorted({mat.name for obj in meshes for mat in obj.data.materials if mat}),
}
(output / "inspection.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
