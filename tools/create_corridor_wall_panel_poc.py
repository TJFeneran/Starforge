"""Reconstruct a single tileable corridor wall bay from a photo, in Blender only.

Brief (user photo): repeating grey hard-surface bays, deep inset plate,
lower analog control cluster, vertical light troughs, blue floor cove.
No image textures. No copied labels or logos — original analog greeble.

Run: blender --background --python tools/create_corridor_wall_panel_poc.py
ASSET = one 1.4m module. PRESENTATION = tiled run + review lighting.
"""
from pathlib import Path
import math

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/source/blender/corridor_wall_panel_poc.blend"
PREVIEW = ROOT / "assets/source/blender/previews/corridor_wall_panel_poc.png"

MODULE_W = 1.40  # panel 1.16 + 0.12 light trough on the right (tiles cleanly)


def principled(name, color, metallic=0.05, roughness=0.42):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, 1.0)
    node.inputs["Metallic"].default_value = metallic
    node.inputs["Roughness"].default_value = roughness
    return mat


def emission(name, color, strength):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1.0)
    em.inputs["Strength"].default_value = strength
    links.new(em.outputs["Emission"], out.inputs["Surface"])
    return mat


def finish(obj, mat, bevel=0.012, collection=None):
    collection = collection or ASSET
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Editable edge bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL").keep_sharp = True
    return obj


def box(name, loc, size, mat, bevel=0.012, collection=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, bevel, collection)


def cylinder(name, loc, radius, depth, mat, verts=16, bevel=0.004, rot=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat, bevel)


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def area(name, loc, energy, color, size, target):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "RECTANGLE"
    data.size = size
    data.size_y = size * 0.4
    obj = bpy.data.objects.new(name, data)
    STAGE.objects.link(obj)
    obj.location = loc
    aim(obj, target)


def build_module(origin_x, collection, parent):
    """One bay. Origin at floor, module center. Front faces -Y."""
    x0 = origin_x
    hull = MAT["hull"]
    recess = MAT["recess"]
    plate = MAT["plate"]
    dark = MAT["dark"]
    button = MAT["button"]
    light = MAT["light"]
    cove = MAT["cove"]

    def put(obj):
        obj.parent = parent
        return obj

    # Bulkhead + raised outer frame (kitbash plates, matching the miniature language).
    put(box("Bulkhead", (x0, 0.10, 1.40), (MODULE_W, 0.20, 2.80), recess, 0.008, collection))
    put(box("Outer frame", (x0 - 0.06, -0.02, 1.42), (1.16, 0.08, 2.68), hull, 0.018, collection))

    # Deep inset well — the photo's tall chamfered pocket.
    put(box("Inset well", (x0 - 0.06, 0.055, 1.46), (1.00, 0.07, 2.44), recess, 0.02, collection))
    put(box("Inner face", (x0 - 0.06, 0.028, 1.50), (0.90, 0.012, 2.28), plate, 0.01, collection))

    # Upper circular service port (photo: small round detail near the top).
    put(cylinder("Upper port ring", (x0 - 0.06, -0.01, 2.48), 0.055, 0.018, dark, 20, 0.003))
    put(cylinder("Upper port well", (x0 - 0.06, 0.00, 2.48), 0.032, 0.012, recess, 16, 0.002))

    # Two stacked horizontal bands in the upper third.
    for z in (2.18, 1.98):
        put(box("Upper rib", (x0 - 0.06, -0.012, z), (0.82, 0.028, 0.055), hull, 0.008, collection))
        put(box("Upper rib groove", (x0 - 0.06, -0.028, z), (0.70, 0.008, 0.018), dark, 0.003, collection))

    # Mid-panel horizontal break — photo has a thin shelf across the bay.
    put(box("Mid shelf", (x0 - 0.06, -0.018, 1.22), (0.88, 0.04, 0.04), hull, 0.008, collection))

    # Lower analog cluster on a darker plate, proud of the inset.
    put(box("Control plate", (x0 - 0.06, -0.02, 0.62), (0.84, 0.045, 0.72), dark, 0.01, collection))
    put(box("Control header bar", (x0 - 0.06, -0.048, 0.92), (0.78, 0.018, 0.04), hull, 0.006, collection))

    # Two columns of 3x2 rocker/indicator blocks. Colors are original, not copied art.
    colors = [
        MAT["led_red"], MAT["led_amber"], MAT["led_green"],
        MAT["led_cyan"], MAT["led_red"], MAT["led_amber"],
    ]
    for col, cx in enumerate((-0.22, 0.10)):
        for row in range(3):
            z = 0.78 - row * 0.16
            px = x0 - 0.06 + cx
            put(box("Rocker body", (px, -0.055, z), (0.20, 0.028, 0.12), button, 0.006, collection))
            put(box("Rocker split", (px, -0.072, z), (0.015, 0.008, 0.10), dark, 0.002, collection))
            led = colors[col * 3 + row]
            put(cylinder("Indicator", (px - 0.055, -0.072, z + 0.02), 0.018, 0.01, led, 12, 0.002))
            put(box("Caption pip", (px + 0.05, -0.070, z - 0.028), (0.05, 0.006, 0.018), hull, 0.002, collection))

    # Small round telltales under the header, matching the photo's extra dots.
    for dx, mat in ((-0.28, MAT["led_red"]), (0.16, MAT["led_cyan"])):
        put(cylinder("Telltale", (x0 - 0.06 + dx, -0.055, 0.42), 0.016, 0.01, mat, 12, 0.002))

    # Vertical light trough on the module's RIGHT edge — tiles into a full slot.
    put(box("Light trough housing", (x0 + 0.64, 0.02, 1.40), (0.12, 0.10, 2.72), dark, 0.01, collection))
    put(box("Light trough lamp", (x0 + 0.64, -0.022, 1.42), (0.055, 0.02, 2.55), light, 0.004, collection))

    # Blue floor cove in a kick channel (photo: neon strip at the base).
    put(box("Kick plate", (x0, -0.04, 0.055), (MODULE_W, 0.12, 0.11), dark, 0.01, collection))
    put(box("Cove lamp", (x0, -0.09, 0.035), (MODULE_W - 0.04, 0.02, 0.04), cove, 0.003, collection))
    return parent


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    bpy.data.collections.remove(collection)
ASSET = bpy.data.collections.new("ASSET | Corridor wall bay | 1.4m tile")
STAGE = bpy.data.collections.new("PRESENTATION | Tiled run, camera, lights")
bpy.context.scene.collection.children.link(ASSET)
bpy.context.scene.collection.children.link(STAGE)

MAT = {
    "hull": principled("Clay | cool grey hull", (0.45, 0.49, 0.52), 0.08, 0.38),
    "recess": principled("Clay | deep recess", (0.22, 0.25, 0.28), 0.12, 0.45),
    "plate": principled("Clay | inner plate", (0.38, 0.42, 0.45), 0.06, 0.40),
    "dark": principled("Clay | greeble dark", (0.10, 0.11, 0.12), 0.2, 0.42),
    "button": principled("Clay | analog rocker", (0.16, 0.17, 0.18), 0.15, 0.35),
    "light": emission("Lamp | vertical trough", (0.85, 0.92, 1.0), 18.0),
    "cove": emission("Lamp | floor cove blue", (0.15, 0.45, 1.0), 12.0),
    "led_red": emission("Lamp | indicator red", (1.0, 0.18, 0.12), 8.0),
    "led_amber": emission("Lamp | indicator amber", (1.0, 0.72, 0.12), 7.0),
    "led_green": emission("Lamp | indicator green", (0.25, 1.0, 0.35), 7.0),
    "led_cyan": emission("Lamp | indicator cyan", (0.25, 0.85, 1.0), 8.0),
}

root = bpy.data.objects.new("CorridorWallBay_POC | origin floor center", None)
ASSET.objects.link(root)
root["design"] = "Photo-matched corridor bay reconstruction — Blender CLI, no textures"
root["module_width_m"] = MODULE_W
root["height_m"] = 2.80
root["pipeline"] = "Human/agent reads photo → parametric kitbash in Blender. Not image-to-mesh."
build_module(0.0, ASSET, root)

# Presentation: four tiled bays so the repeat + light troughs + cove read like the photo.
for i in range(4):
    empty = bpy.data.objects.new(f"STAGE bay {i}", None)
    STAGE.objects.link(empty)
    empty.location.x = (i - 1.5) * MODULE_W
    build_module(0.0, STAGE, empty)

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.length_unit = "METERS"
scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 6
scene.render.resolution_x = 1600
scene.render.resolution_y = 1050
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.04, 0.045, 0.055, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.15
scene.view_settings.view_transform = "AgX"

floor = principled("STAGE ONLY | glossy floor", (0.03, 0.035, 0.04), 0.35, 0.12)
box("STAGE ONLY | floor", (0, 0, -0.04), (20, 12, 0.08), floor, 0, STAGE)

# Ceiling light bars receding down the run (photo: bright rectangular ceiling lamps).
ceil = emission("STAGE ONLY | ceiling lamp", (0.9, 0.95, 1.0), 22.0)
for i in range(4):
    box("STAGE ONLY | ceiling bar", ((i - 1.5) * MODULE_W, 0.05, 2.92),
        (0.22, 0.16, 0.08), ceil, 0.01, STAGE)

area("Key", (1.6, -3.4, 2.4), 280, (1.0, 0.95, 0.9), 2.4, (0, 0, 1.3))
area("Fill", (-2.2, -1.8, 1.8), 90, (0.7, 0.82, 1.0), 2.0, (0, 0, 1.2))
area("Rim", (0.5, 2.2, 2.6), 160, (0.75, 0.85, 1.0), 1.6, (0, 0, 1.4))

camera_data = bpy.data.cameras.new("Review camera")
camera = bpy.data.objects.new("Review camera", camera_data)
STAGE.objects.link(camera)
# Low 3/4 along the wall, similar to the photo.
camera.location = (2.55, -2.35, 1.05)
aim(camera, (-0.35, 0.15, 1.15))
camera_data.lens = 35
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
