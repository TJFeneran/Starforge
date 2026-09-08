"""Second Blender CLI hangar-wall POC. Destiny Tower / hangar observation bay.

Distinct from v1: panoramic trapezoid window, nested frames, overlapping plates.
Run: blender --background --python tools/create_hangar_wall_poc_v2.py
"""
from pathlib import Path
import math

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/source/blender/hangar_wall_poc_v2.blend"
PREVIEW = ROOT / "assets/source/blender/previews/hangar_wall_poc_v2.png"


def material(name, color, metallic=0.0, roughness=0.4, transmission=0.0, ior=1.45):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    alpha = 0.22 if transmission > 0.5 else 1.0
    mat.diffuse_color = (*color, alpha)
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, 1.0)
    node.inputs["Metallic"].default_value = metallic
    node.inputs["Roughness"].default_value = roughness
    node.inputs["Transmission Weight"].default_value = transmission
    node.inputs["IOR"].default_value = ior
    if transmission > 0.5 and hasattr(mat, "use_raytrace_refraction"):
        mat.use_raytrace_refraction = True
    return mat, node


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
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL").keep_sharp = True
    return obj


def box(name, loc, size, mat, bevel=0.04, collection=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, bevel, collection)


def polygon(name, points, front, back, mat, bevel=0.035, collection=None):
    count = len(points)
    verts = [(x, y, z) for y in (front, back) for x, z in points]
    faces = [tuple(range(count)), tuple(reversed(range(count, count * 2)))]
    faces += [(i, i + count, (i + 1) % count + count, (i + 1) % count) for i in range(count)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    (collection or ASSET).objects.link(obj)
    return finish(obj, mat, bevel, collection)


def trap(half_bottom, half_top, bottom, top):
    """Wide-bottom panoramic trapezoid, Destiny observation-bay silhouette."""
    return [(-half_bottom, bottom), (half_bottom, bottom), (half_top, top), (-half_top, top)]


def ring(name, outer, inner, front, back, mat, bevel=0.03):
    n = len(outer)
    if n != len(inner):
        raise ValueError("outer/inner must match")
    verts = [(x, y, z) for y in (front, back) for loop in (outer, inner) for x, z in loop]
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.extend([(i, j, n + j, n + i),
                      (2 * n + i, 3 * n + i, 3 * n + j, 2 * n + j),
                      (i, 2 * n + i, 2 * n + j, j),
                      (n + i, n + j, 3 * n + j, 3 * n + i)])
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
ASSET = bpy.data.collections.new("ASSET | Hangar Wall POC v2 | 14m Tower bay")
STAGE = bpy.data.collections.new("PRESENTATION | Camera, lights, floor, glass witnesses")
bpy.context.scene.collection.children.link(ASSET)
bpy.context.scene.collection.children.link(STAGE)

stone, _ = material("Clay | pale Golden Age stone | no textures", (0.58, 0.56, 0.51), 0.12, 0.42)
bronze, _ = material("Clay | warm bronze armor | no textures", (0.36, 0.29, 0.21), 0.55, 0.32)
dark, _ = material("Clay | void-dark structure | no textures", (0.06, 0.07, 0.08), 0.5, 0.38)
inset, _ = material("Clay | recessed service metal", (0.16, 0.17, 0.18), 0.4, 0.4)
gasket, _ = material("Window | opaque gasket", (0.02, 0.022, 0.025), 0.0, 0.7)
glass, glass_bsdf = material(
    "Window | pale Traveler-blue glass | NO TEXTURES",
    (0.72, 0.88, 0.96), metallic=0.0, roughness=0.08, transmission=1.0, ior=1.48,
)

# Panoramic window: wide, slightly tapering — hangar looking out at the Traveler.
opening = trap(5.15, 4.55, 1.55, 5.05)
shell = trap(7.0, 6.55, 0.0, 7.15)
ring("01 | Structural shell - true through-opening", shell, opening, -0.16, 0.55, dark, 0.05)
ring("02 | Nested bronze observation frame", trap(5.55, 4.95, 1.22, 5.38),
     trap(5.22, 4.62, 1.48, 5.12), -0.72, 0.18, bronze, 0.06)
ring("03 | Inner pale stone lip", trap(5.24, 4.64, 1.46, 5.14),
     opening, -0.58, 0.22, stone, 0.03)
ring("04 | Black gasket around glass", trap(5.17, 4.57, 1.53, 5.07),
     opening, -0.48, 0.2, gasket, 0.01)
pane = polygon("05 | GLASS - 28mm transmissive pane", opening, -0.12, -0.092, glass, 0.005)
pane["note"] = "Real transmission glass. Material Preview or Rendered, not Solid."
pane["thickness_m"] = 0.028

# Three slender chevron-cut mullions, not v1's two straight bars.
for x, lean in ((-2.35, 0.08), (0.0, 0.0), (2.35, -0.08)):
    polygon("Window | chevron mullion",
            [(x - 0.045 + lean, 1.62), (x + 0.045 + lean, 1.62),
             (x + 0.045 - lean, 4.98), (x - 0.045 - lean, 4.98)],
            -0.28, 0.05, inset, 0.01)
    box("Window | mullion facing", (x, -0.32, 3.3), (0.018, 0.04, 3.2), stone, 0.006)

# Deep projecting sill / balcony lip, Destiny hangar catwalk language.
polygon("Sill | overlapping armor lip",
        [(-6.4, 1.18), (6.4, 1.18), (6.15, 1.52), (-6.15, 1.52)],
        -0.95, 0.1, bronze, 0.05)
box("Sill | underside shadow mass", (0, -0.55, 1.08), (12.2, 0.9, 0.18), dark, 0.04)
box("Sill | pale walking edge", (0, -0.98, 1.42), (11.6, 0.12, 0.05), stone, 0.012)

# Monument pylons: overlapping plates, not v1's simple channelled ribs.
for side in (-1, 1):
    x = side * 6.05
    polygon("Pylon | outer overlapping plate",
            [(x - 0.72 * side, 0.2), (x + 0.22 * side, 0.2),
             (x + 0.42 * side, 1.4), (x + 0.42 * side, 5.7),
             (x + 0.18 * side, 6.95), (x - 0.78 * side, 6.95),
             (x - 0.62 * side, 5.7), (x - 0.62 * side, 1.4)],
            -0.88, 0.28, bronze, 0.07)
    polygon("Pylon | inner pale plate",
            [(x - 0.38 * side, 0.55), (x + 0.08 * side, 0.55),
             (x + 0.18 * side, 1.55), (x + 0.18 * side, 5.45),
             (x + 0.02 * side, 6.55), (x - 0.42 * side, 6.55),
             (x - 0.32 * side, 5.45), (x - 0.32 * side, 1.55)],
            -0.98, -0.2, stone, 0.04)
    box("Pylon | void channel", (x - 0.12 * side, -1.02, 3.5), (0.14, 0.06, 3.6), dark, 0.02)
    for z in (0.42, 6.72):
        box("Pylon | socket mass", (x, -0.55, z), (1.55, 1.2, 0.42), inset, 0.05)
        box("Pylon | socket facing", (x, -1.16, z), (0.9, 0.08, 0.22), stone, 0.02)
    for z in (1.85, 5.15):
        box("Pylon | coupling band", (x - 0.08 * side, -1.05, z), (0.72, 0.14, 0.14), dark, 0.015)
    for dx, z in ((-0.42, 0.95), (0.28, 0.95), (-0.42, 6.25), (0.28, 6.25)):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.055, depth=0.03,
            location=(x + dx * side, -1.08, z), rotation=(math.pi / 2, 0, 0))
        finish(bpy.context.object, dark, 0.006).name = "Pylon | hex fastener"

# Lower armor: overlapping chevron tiles instead of five identical vents.
for i, x in enumerate((-3.9, -1.95, 0.0, 1.95, 3.9)):
    peak = 0.18 if i % 2 == 0 else 0.0
    polygon("Lower | overlapping chevron tile",
            [(x - 0.92, 0.22), (x + 0.92, 0.22), (x + 0.78, 1.05 + peak),
             (x, 1.22 + peak), (x - 0.78, 1.05 + peak)],
            -0.52, -0.12, stone if i % 2 else bronze, 0.035)
    box("Lower | vent slot", (x, -0.56, 0.52), (1.15, 0.08, 0.22), dark, 0.015)
    for s in range(5):
        box("Lower | vent fin", (x + (s - 2) * 0.18, -0.62, 0.52), (0.05, 0.07, 0.16), inset, 0.008)
box("Base | kick plate", (0, -0.48, 0.11), (10.6, 0.7, 0.2), inset, 0.035)

# Crown: stepped lintel + Traveler-adjacent split diamond (original, not a logo).
polygon("Crown | stepped lintel",
        [(-5.4, 5.35), (-4.6, 5.18), (4.6, 5.18), (5.4, 5.35),
         (5.4, 6.85), (4.7, 7.12), (-4.7, 7.12), (-5.4, 6.85)],
        -0.55, 0.25, bronze, 0.05)
polygon("Crown | pale inner lintel plate",
        [(-4.35, 5.48), (4.35, 5.48), (4.35, 6.72), (3.85, 6.92),
         (-3.85, 6.92), (-4.35, 6.72)],
        -0.62, -0.18, stone, 0.03)
box("Crown | void channel left", (-2.4, -0.66, 6.18), (3.6, 0.05, 0.18), dark, 0.015)
box("Crown | void channel right", (2.4, -0.66, 6.18), (3.6, 0.05, 0.18), dark, 0.015)
polygon("Crown | split diamond keystone",
        [(-0.55, 6.85), (0.0, 6.05), (0.55, 6.85), (0.0, 7.05)],
        -0.74, -0.5, dark, 0.02)
polygon("Crown | raised chevron left",
        [(-0.38, 6.78), (-0.06, 6.28), (-0.06, 6.48), (-0.22, 6.78)],
        -0.78, -0.7, stone, 0.008)
polygon("Crown | raised chevron right",
        [(0.06, 6.28), (0.38, 6.78), (0.22, 6.78), (0.06, 6.48)],
        -0.78, -0.7, stone, 0.008)

# Side cheek plates overlapping the shell — more layered Destiny mass.
for side in (-1, 1):
    x = side * 5.15
    polygon("Cheek | overlapping armor",
            [(x - 0.55 * side, 1.7), (x + 0.15 * side, 1.7),
             (x + 0.35 * side, 2.2), (x + 0.35 * side, 4.7),
             (x + 0.15 * side, 5.15), (x - 0.55 * side, 5.15),
             (x - 0.35 * side, 4.7), (x - 0.35 * side, 2.2)],
            -0.42, 0.08, stone, 0.03)

root = bpy.data.objects.new("HangarWall_POC_v2 | origin at floor center", None)
ASSET.objects.link(root)
root["design"] = "Destiny Tower hangar observation bay — panoramic trapezoid, overlapping plates"
root["module_width_m"] = 14.0
root["height_m"] = 7.15
root["materials"] = "Untextured clay; physically transmissive glass"
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
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.16, 0.19, 0.24, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.4
scene.view_settings.view_transform = "AgX"

floor, _ = material("STAGE ONLY | matte floor", (0.11, 0.12, 0.14), 0.0, 0.75)
box("STAGE ONLY | studio floor", (0, 0, -0.16), (220, 220, 0.2), floor, 0, STAGE)
fin, _ = material("STAGE ONLY | glass witness", (0.42, 0.48, 0.52), 0.1, 0.5)
for x in (-7, -3.5, 0, 3.5, 7):
    box("STAGE ONLY | behind-glass witness", (x, 6.4, 2.4), (0.22, 0.4, 4.8), fin, 0.02, STAGE)
area("Key", (1, -10, 13), 2400, (1.0, 0.86, 0.72), 8, (0, 0, 3.4))
area("Fill", (-10, -4, 6), 1700, (0.7, 0.84, 1.0), 7, (0, 0, 3.4))
area("Rim", (3, 6, 11), 2500, (0.82, 0.9, 1.0), 6, (0, 0, 3.4))
area("Glass card", (6, -8, 5), 700, (0.85, 0.95, 1.0), 4, (0, 0, 3.4))
camera_data = bpy.data.cameras.new("Review camera")
camera = bpy.data.objects.new("Review camera", camera_data)
STAGE.objects.link(camera)
camera.location = (12.2, -23.5, 10.2)
aim(camera, (0, 0, 3.4))
camera_data.type = "ORTHO"
camera_data.ortho_scale = 17.5
scene.camera = camera

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

assert glass_bsdf.inputs["Transmission Weight"].default_value == 1.0
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
