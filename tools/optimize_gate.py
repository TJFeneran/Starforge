"""Blender-only gate reduction: separate candidates, original never overwritten.

blender --background --threads 8 --python-exit-code 1 --python tools/optimize_gate.py
Use --inspect for topology only, or --render-only to preview exported GLBs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from optimize_microscope import mesh_stats, weld, evaluated_copy, deviation, point_at

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/models/style_tests/forge_monument.glb"
OUTPUT = ROOT / "assets/models/style_tests/gate_high_fidelity"
WORK = ROOT / "assets/source/blender/gate_high_fidelity"
OPTIONS = [("fidelity_1200k", 1200000), ("fidelity_900k", 900000), ("fidelity_600k", 600000)]


def load(path):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    result = [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]
    if len(result) != 1:
        raise RuntimeError(f"Expected one mesh in {path}, got {len(result)}")
    return result[0]


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
        export_yup=True, export_materials="EXPORT", export_animations=False,
        export_cameras=False, export_lights=False, export_texcoords=True,
        export_normals=True, export_tangents=True, export_image_format="AUTO")
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    gltf = json.loads(raw[20:20 + length])
    return {
        "exported_triangles": sum(gltf["accessors"][p["indices"]]["count"] // 3 for m in gltf["meshes"] for p in m["primitives"]),
        "exported_vertices": sum(gltf["accessors"][p["attributes"]["POSITION"]]["count"] for m in gltf["meshes"] for p in m["primitives"]),
        "exported_materials": len(gltf.get("materials", [])),
        "exported_images": len(gltf.get("images", [])),
        "file_bytes": len(raw),
    }


def render_comparisons():
    # Reimport exports so previews show the actual deliverables, not modifiers.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    models = [load(SOURCE)] + [load(OUTPUT / f"forge_monument_{name}.glb") for name, _ in OPTIONS]
    for obj in models:
        obj.hide_render = True
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 2600
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("Gate comparison studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.11, .14, .19, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .6
    scene.view_settings.view_transform = "AgX"
    clay = bpy.data.materials.new("Geometry review clay")
    clay.use_nodes = True
    clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.4, .45, .5, 1)
    clay.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .7
    data = bpy.data.cameras.new("ComparisonCamera")
    camera = bpy.data.objects.new("ComparisonCamera", data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    data.type = "ORTHO"
    data.ortho_scale = 1.85
    lights = []
    for name, energy, size in [("Key", 90, 1.5), ("Fill", 45, 1.3), ("Rim", 110, 1.2)]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size = energy, size
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        lights.append(light)
    # Shared scale/center preserves small differences between variants.
    corners = [models[0].matrix_world @ Vector(c) for c in models[0].bound_box]
    center = sum(corners, Vector()) / 8
    factor = .35 / (max(c.z for c in corners) - min(c.z for c in corners))
    previews = []
    for obj in models:
        mesh = obj.data.copy()
        transform = obj.matrix_world.copy()
        for v in mesh.vertices:
            v.co = (transform @ v.co - center) * factor
        mesh.update()
        preview = bpy.data.objects.new("Preview_" + obj.name, mesh)
        scene.collection.objects.link(preview)
        previews.append(preview)
    views = [("front", Vector((0, -1, .12)), False),
             ("threequarter", Vector((.65, -1, .42)), False),
             ("back_clay", Vector((-.65, 1, .38)), True),
             ("front_clay", Vector((0, -1, .12)), True)]
    for name, direction, use_clay in views:
        direction.normalize()
        right = -direction.cross(Vector((0, 0, 1))).normalized()
        camera.location = direction * 2
        point_at(camera, Vector())
        for i, preview in enumerate(previews):
            preview.location = right * ((i - 1.5) * .46)
            if use_clay:
                preview.data.materials.clear()
                preview.data.materials.append(clay)
        for light, offset in zip(lights, [direction * .8 - right * .6 + Vector((0, 0, 1)), direction * .5 + right * .8 + Vector((0, 0, .4)), -direction * .7 + Vector((0, 0, .8))]):
            light.location = offset
            point_at(light, Vector())
        scene.render.filepath = str(WORK / f"comparison_{name}.png")
        bpy.ops.render.render(write_still=True)
        print("GATE_RENDER=" + name, flush=True)
    # Full-size, matching textured views reveal shading/edge damage hidden by
    # four-across thumbnails. Restore imported materials after the clay pass.
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 1400
    camera.data.ortho_scale = .43
    direction = Vector((.3, -1, .15)).normalized()
    camera.location = direction * 2
    point_at(camera, Vector())
    for preview in previews:
        preview.hide_render = True
    for i, preview in enumerate(previews):
        preview.data.materials.clear()
        for material in models[i].data.materials:
            preview.data.materials.append(material)
        preview.location = Vector()
        preview.hide_render = False
        label = "original" if i == 0 else OPTIONS[i - 1][0]
        scene.render.filepath = str(WORK / f"detail_{label}.png")
        bpy.ops.render.render(write_still=True)
        preview.hide_render = True
        print("GATE_DETAIL=" + label, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inspect", action="store_true")
    parser.add_argument("--render-only", action="store_true")
    parser.add_argument("--no-render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    WORK.mkdir(parents=True, exist_ok=True)
    if args.render_only:
        render_comparisons()
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    original = load(SOURCE)
    original.name = "Original_gate_1935526_triangles"
    report = {"source": str(SOURCE.relative_to(ROOT)), "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              "original": mesh_stats(original), "options": []}
    print("GATE_ORIGINAL=" + json.dumps(report["original"]), flush=True)
    base = original.copy()
    base.data = original.data.copy()
    base.name = "Welded_source"
    bpy.context.scene.collection.objects.link(base)
    weld(base)
    base_stats = mesh_stats(base)
    print("GATE_WELDED=" + json.dumps(base_stats), flush=True)
    report["welded_source"] = base_stats
    if args.inspect:
        return
    OUTPUT.mkdir(parents=True, exist_ok=True)
    original.hide_render = base.hide_render = True
    original.hide_set(True)
    base.hide_set(True)
    editables = []
    # Each candidate starts from the same full-detail mesh, not another reduction.
    for name, target in OPTIONS:
        print("GATE_REDUCING=" + name, flush=True)
        obj = base.copy()
        obj.name = name
        bpy.context.scene.collection.objects.link(obj)
        obj.hide_set(False)
        modifier = obj.modifiers.new("Editable geometric-error reduction", "DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = target / base_stats["triangles"]
        modifier.use_collapse_triangulate = True
        # Preserve source shading instead of relying on normals recalculated
        # over long decimated triangles, which can look warped on glossy metal.
        normals = obj.modifiers.new("Source surface normals", "DATA_TRANSFER")
        normals.object = original
        normals.use_loop_data = True
        normals.data_types_loops = {"CUSTOM_NORMAL"}
        normals.loop_mapping = "POLYINTERP_NEAREST"
        bpy.context.view_layer.update()
        reduced = evaluated_copy(obj, name + "_export")
        stats = mesh_stats(reduced)
        stats["deviation"] = deviation(original, reduced)
        stats["file"] = str((OUTPUT / f"forge_monument_{name}.glb").relative_to(ROOT))
        stats.update(export(reduced, ROOT / stats["file"]))
        stats["triangle_reduction_percent"] = 100 * (1 - stats["exported_triangles"] / report["original"]["triangles"])
        report["options"].append(stats)
        print("GATE_OPTION=" + json.dumps(stats), flush=True)
        mesh = reduced.data
        bpy.data.objects.remove(reduced, do_unlink=True)
        bpy.data.meshes.remove(mesh)
        obj.hide_set(name != "fidelity_1200k")
        obj.hide_render = name != "fidelity_1200k"
        editables.append(obj)
    bpy.data.objects.remove(base, do_unlink=True)
    report["source_unchanged"] = hashlib.sha256(SOURCE.read_bytes()).hexdigest() == report["source_sha256"]
    (WORK / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    bpy.ops.object.select_all(action="DESELECT")
    editables[0].select_set(True)
    bpy.context.view_layer.objects.active = editables[0]
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK / "forge_monument_options.blend"), compress=True)
    print("GATE_EXPORTS_COMPLETE", flush=True)
    if not args.no_render:
        render_comparisons()
    print("GATE_COMPLETE", flush=True)


if __name__ == "__main__":
    main()
