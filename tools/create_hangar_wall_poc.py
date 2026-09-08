"""Build a texture-free, editable hangar wall and its isolated review stage.

Run: blender --background --python tools/create_hangar_wall_poc.py
The ASSET collection is the wall; PRESENTATION contains only the review rig.
"""
from pathlib import Path
import math

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/source/blender/hangar_wall_poc.blend"
PREVIEW = ROOT / "assets/source/blender/previews/hangar_wall_poc.png"


def material(name, color, metallic=0.0, roughness=0.4):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, 1.0)
    node.inputs["Metallic"].default_value = metallic
    node.inputs["Roughness"].default_value = roughness
    return mat


def finish(obj, mat, bevel=0.04, collection=None):
    collection = collection or ASSET
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Editable edge bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
    return obj


def box(name, loc, size, mat, bevel=0.04, collection=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, bevel, collection)


def polygon(name, points, front, back, mat, bevel=0.035):
    """Extrude a counter-clockwise X/Z outline along Y (front is negative Y)."""
    count = len(points)
    verts = [(x, y, z) for y in (front, back) for x, z in points]
    faces = [tuple(range(count)), tuple(reversed(range(count, count * 2)))]
    faces += [(i, i + count, (i + 1) % count + count, (i + 1) % count)
              for i in range(count)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    ASSET.objects.link(obj)
    return finish(obj, mat, bevel)


def octagon(half_width, bottom, top, cut):
    return [(-half_width + cut, bottom), (half_width - cut, bottom),
            (half_width, bottom + cut), (half_width, top - cut),
            (half_width - cut, top), (-half_width + cut, top),
            (-half_width, top - cut), (-half_width, bottom + cut)]


def ring(name, outer, inner, front, back, mat, bevel=0.03):
    """Closed manifold annulus: a genuine opening, not glass over a solid wall."""
    verts = [(x, y, z) for y in (front, back) for loop in (outer, inner) for x, z in loop]
    faces = []
    for i in range(8):
        j = (i + 1) % 8
        faces.extend([(i, j, 8 + j, 8 + i),
                      (16 + i, 24 + i, 24 + j, 16 + j),
                      (i, 16 + i, 16 + j, j),
                      (8 + i, 8 + j, 24 + j, 24 + i)])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    ASSET.objects.link(obj)
    return finish(obj, mat, bevel)


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def area(name, loc, energy, color, size, target):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    STAGE.objects.link(obj)
    obj.location = loc
    aim(obj, target)


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    bpy.data.collections.remove(collection)
ASSET = bpy.data.collections.new("ASSET | Hangar Wall POC | 12m module")
STAGE = bpy.data.collections.new("PRESENTATION | Camera, lights, floor, glass-test fins")
bpy.context.scene.collection.children.link(ASSET)
bpy.context.scene.collection.children.link(STAGE)

armor = material("Clay | warm ceramic armor | no textures", (0.48, 0.49, 0.47), 0.25, 0.36)
edge = material("Clay | pale frame edges | no textures", (0.64, 0.66, 0.64), 0.35, 0.29)
core = material("Clay | dark structure | no textures", (0.095, 0.12, 0.135), 0.45, 0.4)
recess = material("Clay | recessed mechanical panels | no textures", (0.20, 0.235, 0.25), 0.45, 0.36)
gasket = material("Window | opaque rubber gasket", (0.018, 0.025, 0.031), 0.0, 0.62)
glass = material("Window | pale blue transmissive glass | NO TEXTURES", (0.79, 0.93, 0.97), 0.0, 0.12)
bsdf = glass.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Transmission Weight"].default_value = 1.0
bsdf.inputs["IOR"].default_value = 1.46
glass.diffuse_color = (0.55, 0.83, 0.91, 0.25)
if hasattr(glass, "use_raytrace_refraction"):
    glass.use_raytrace_refraction = True

opening = octagon(4.05, 1.85, 4.7, 0.40)
ring("01 | Main structural shell - open all the way through", octagon(6, 0, 6.2, 0.18),
     opening, -0.18, 0.48, core, 0.045)
ring("02 | Raised chamfered observation frame", octagon(4.40, 1.5, 5.05, 0.56),
     octagon(4.10, 1.8, 4.75, 0.43), -0.63, 0.17, edge, 0.055)
ring("03 | Separate black window gasket", octagon(4.11, 1.79, 4.76, 0.43),
     opening, -0.51, 0.25, gasket, 0.012)
pane = polygon("04 | GLASS - solid 24mm pane - editable separately", opening, -0.10, -0.076, glass, 0.006)
pane["note"] = "Real transmission glass. View in Material Preview or Rendered mode, not Solid."
pane["thickness_m"] = 0.024
for x in (-1.42, 1.42):
    box("Window | slender structural mullion", (x, -0.25, 3.275), (0.065, 0.27, 2.85), recess, 0.015)
    box("Window | mullion front edge", (x, -0.40, 3.275), (0.025, 0.04, 2.79), edge, 0.008)
box("Window | deep projecting sill", (0, -0.48, 1.48), (8.5, 0.78, 0.15), recess)

# Paired broad ribs and their visible stacked structural sockets.
for side in (-1, 1):
    x = side * 5.23
    shape = [(x - 0.53, 0.32), (x + 0.53, 0.32), (x + 0.53, 1.0),
             (x + 0.37, 1.60), (x + 0.37, 4.65), (x + 0.55, 5.35),
             (x + 0.55, 5.88), (x - 0.55, 5.88), (x - 0.55, 5.35),
             (x - 0.37, 4.65), (x - 0.37, 1.6), (x - 0.53, 1.0)]
    polygon("Pylon | sculpted load-bearing armor", shape, -0.82, 0.22, armor, 0.06)
    box("Pylon | inset central channel", (x, -0.836, 3.21), (0.19, 0.055, 2.71), core, 0.025)
    box("Pylon | channel spine", (x, -0.874, 3.21), (0.035, 0.028, 2.38), edge, 0.008)
    for z in (0.23, 5.98):
        box("Pylon | end socket", (x, -0.44, z), (1.31, 1.13, 0.37), recess, 0.055)
        box("Pylon | socket facing", (x, -1.015, z), (0.82, 0.08, 0.20), edge, 0.025)
    for z in (1.2, 5.13):
        box("Pylon | recessed coupling band", (x, -0.89, z), (0.84, 0.15, 0.16), recess, 0.018)
    for dx in (-0.38, 0.38):
        for z in (0.67, 5.6):
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.062, depth=0.025,
                                              location=(x + dx, -0.893, z),
                                              rotation=(math.pi / 2, 0, 0))
            bolt = bpy.context.object
            bolt.name = "Pylon | octagonal captive fastener"
            finish(bolt, core, 0.007)

# Panel gaps are modeled; no decals, normal maps, or surface textures.
for index in range(5):
    x = (index - 2) * 1.74
    points = [(x - 0.84, 0.29), (x + 0.84, 0.29), (x + 0.84, 1.12),
              (x + 0.64, 1.34), (x - 0.64, 1.34), (x - 0.84, 1.12)]
    polygon("Lower wall | removable chamfered armor panel", points, -0.43, -0.15, armor)
    box("Lower wall | recessed service strip", (x, -0.451, 0.59), (1.24, 0.04, 0.25), core, 0.02)
    for slot in range(7):
        box("Lower wall | grille fin", (x + (slot - 3) * 0.16, -0.49, 0.59),
            (0.055, 0.065, 0.18), recess, 0.01)
    box("Lower wall | panel latch", (x, -0.48, 1.08), (0.28, 0.08, 0.055), edge, 0.012)
box("Base | continuous kick rail", (0, -0.44, 0.125), (9.1, 0.57, 0.22), recess, 0.04)

polygon("Crown | central stepped armored lintel",
        [(-4.53, 5.28), (-3.82, 5.12), (3.82, 5.12), (4.53, 5.28),
         (4.53, 5.98), (4.25, 6.16), (-4.25, 6.16), (-4.53, 5.98)],
        -0.48, 0.21, armor, 0.045)
for side in (-1, 1):
    box("Crown | inset horizontal channel", (side * 2.63, -0.501, 5.70), (3.25, 0.045, 0.15), core, 0.018)
    box("Crown | fine structural rail", (side * 2.63, -0.539, 5.70), (2.90, 0.04, 0.035), edge, 0.008)
# Original abstract architectural motif, not a franchise logo.
polygon("Crown | abstract keystone escutcheon", [(-0.48, 5.91), (-0.23, 5.32),
        (0.23, 5.32), (0.48, 5.91)], -0.61, -0.47, recess, 0.025)
polygon("Crown | raised split-chevron left", [(-0.31, 5.82), (-0.055, 5.45),
        (-0.055, 5.65), (-0.18, 5.82)], -0.66, -0.60, edge, 0.01)
polygon("Crown | raised split-chevron right", [(0.055, 5.45), (0.31, 5.82),
        (0.18, 5.82), (0.055, 5.65)], -0.66, -0.60, edge, 0.01)

# Keep all asset pieces under a ground-centered root for easy selection/export.
root = bpy.data.objects.new("HangarWall_POC | origin at floor center", None)
ASSET.objects.link(root)
root["design"] = "Original Destiny-inspired monumental sci-fi observation wall, untextured POC"
root["module_width_m"] = 12.0
root["height_m"] = 6.2
root["materials"] = "Flat clay values only; separate physically transmissive glass; zero image textures"
for obj in list(ASSET.objects):
    if obj != root:
        obj.parent = root

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.length_unit = "METERS"
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 10
scene.cycles.transmission_bounces = 8
scene.render.resolution_x = 1600
scene.render.resolution_y = 1050
scene.render.resolution_percentage = 100
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.21, 0.26, 0.32, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45
scene.view_settings.view_transform = "AgX"

floor = material("STAGE ONLY | matte floor", (0.135, 0.16, 0.19), 0.0, 0.72)
box("STAGE ONLY | studio floor", (0, 0, -0.16), (200, 200, 0.2), floor, 0, STAGE)
# Sparse pale fins behind the wall make the glass transmission legible in the preview.
fin_mat = material("STAGE ONLY | glass visibility witness", (0.38, 0.43, 0.46), 0.15, 0.5)
for x in (-6, -3, 0, 3, 6):
    box("STAGE ONLY | behind-glass witness fin", (x, 6.0, 2.2), (0.20, 0.36, 4.4), fin_mat, 0.025, STAGE)
area("Key | broad warm softbox", (0, -9, 12), 2300, (1.0, 0.90, 0.79), 8, (0, 0, 3))
area("Fill | cool long softbox", (-9, -3, 6), 1800, (0.68, 0.82, 1.0), 7, (0, 0, 3))
area("Rim | roof softbox", (2, 5, 10), 2600, (0.79, 0.9, 1.0), 6, (0, 0, 3))
area("Glass | reflection card", (5, -7, 5), 650, (0.83, 0.94, 1.0), 4, (0, 0, 3))
camera_data = bpy.data.cameras.new("Review camera")
camera = bpy.data.objects.new("Review camera", camera_data)
STAGE.objects.link(camera)
camera.location = (10.6, -21, 9.4)
aim(camera, (0, 0, 3.0))
camera_data.type = "ORTHO"
camera_data.ortho_scale = 15.5
scene.camera = camera

# Default to a clean, glass-capable material preview when opening the .blend.
for screen in bpy.data.screens:
    for area_ui in screen.areas:
        if area_ui.type == "VIEW_3D":
            space = area_ui.spaces.active
            space.shading.type = "MATERIAL"
            space.overlay.show_extras = False
            space.region_3d.view_perspective = "CAMERA"
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active = root

# Sanity checks for the deliverable, independent of the presentation rig.
assert len([o for o in ASSET.objects if o.type == "MESH"]) > 20
assert bsdf.inputs["Transmission Weight"].default_value == 1.0
assert not any(n.type == "TEX_IMAGE" for m in bpy.data.materials if m.use_nodes for n in m.node_tree.nodes)
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
PREVIEW.parent.mkdir(parents=True, exist_ok=True)
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(PREVIEW)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
print(f"SAVED_ASSET={OUTPUT}", flush=True)
print(f"ASSET_MESHES={sum(o.type == 'MESH' for o in ASSET.objects)}", flush=True)
bpy.ops.render.render(write_still=True)
print(f"SAVED_PREVIEW={PREVIEW}", flush=True)
