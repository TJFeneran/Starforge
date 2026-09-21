"""Inspect the untouched Crescent Meshy GLB in consistent Blender views.

Run after the approved source is downloaded:
blender -b --factory-startup -t 4 --python tools/inspect_ray_source.py
"""
from __future__ import annotations
import json, os, sys, traceback
from pathlib import Path
import bpy
from mathutils import Vector

def fail_fast(typ, value, tb):
    traceback.print_exception(typ, value, tb)
    sys.stderr.flush()
    os._exit(1)

sys.excepthook = fail_fast
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/meshy/rift_ray/ray_a.glb'
OUT = SOURCE.parent / 'preview'
if not SOURCE.exists():
    raise FileNotFoundError(SOURCE)
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
if not meshes:
    raise ValueError('Ray source has no mesh')
corners = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
low = Vector(tuple(min(v[i] for v in corners) for i in range(3)))
high = Vector(tuple(max(v[i] for v in corners) for i in range(3)))
span = high-low
scale = 1.6/max(span.x, span.y)
center = (low+high)/2
for o in meshes:
    o.location = scale*(o.location-center)
    o.scale *= scale
    o.rotation_mode = 'QUATERNION'

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.world.color = (.14,.14,.14)
for location, energy in [((2,-3,3),700),((-3,-2,2),500),((1,3,3),800)]:
    bpy.ops.object.light_add(type='AREA', location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = 3
    light.rotation_euler = (-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-3,0))
camera = bpy.context.object
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 2.2
scene.camera = camera
for name, pos in [('front',(0,-3,0)),('side',(3,0,0)),('back',(0,3,0)),('top',(0,0,3)),('hero',(2,-3,1.5))]:
    camera.location = pos
    camera.rotation_euler = (-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = str(OUT/f'{name}.png')
    bpy.ops.render.render(write_still=True)
triangles = 0
for o in meshes:
    o.data.calc_loop_triangles()
    triangles += len(o.data.loop_triangles)
report = {
    'source': str(SOURCE.relative_to(ROOT)),
    'mesh_count': len(meshes),
    'triangles': triangles,
    'original_dimensions': list(span),
    'original_bounds_low': list(low),
    'original_bounds_high': list(high),
    'materials': [m.name for m in bpy.data.materials],
    'textures': [{'name': im.name, 'size': list(im.size)} for im in bpy.data.images if im.size[0]],
    'review_views': ['front','side','back','top','hero'],
}
(OUT/'inspection.json').write_text(json.dumps(report, indent=2)+'\n')
print('RAY_SOURCE_INSPECTED', json.dumps(report), flush=True)
sys.stdout.flush()
os._exit(0)
