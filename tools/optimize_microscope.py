"""Non-destructive Blender reduction and comparison for the forge microscope.

blender --background --threads 8 --python tools/optimize_microscope.py -- --inspect
blender --background --threads 8 --python tools/optimize_microscope.py

Original runtime/source GLBs are never overwritten. The saved .blend retains
editable Decimate modifiers; exported GLBs have evaluated/triangulated geometry.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/models/props/forge_microscope.glb"
OUTPUT = ROOT / "assets/models/props/microscope_options"
WORK = ROOT / "assets/source/blender/microscope_optimization"
OPTIONS = [("closeup_30k", 30000), ("balanced_15k", 15000), ("economy_8k", 8000)]


def import_source():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def mesh_stats(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    visited = set()
    components = []
    for vert in bm.verts:
        if vert.index in visited:
            continue
        stack = [vert]
        visited.add(vert.index)
        count = 0
        while stack:
            current = stack.pop()
            count += 1
            for edge in current.link_edges:
                other = edge.other_vert(current)
                if other.index not in visited:
                    visited.add(other.index)
                    stack.append(other)
        components.append(count)
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    result = {
        "name": obj.name,
        "vertices": len(mesh.vertices),
        "triangles": len(mesh.loop_triangles),
        "polygons": len(mesh.polygons),
        "bounds_min": [min(v[i] for v in corners) for i in range(3)],
        "bounds_max": [max(v[i] for v in corners) for i in range(3)],
        "dimensions": list(obj.dimensions),
        "materials": [m.name if m else None for m in mesh.materials],
        "uv_layers": [uv.name for uv in mesh.uv_layers],
        "components": len(components),
        "largest_components_vertices": sorted(components, reverse=True)[:10],
        "boundary_edges": sum(e.is_boundary for e in bm.edges),
        "non_manifold_edges": sum(not e.is_manifold for e in bm.edges),
    }
    bm.free()
    return result


def weld(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # 0.00035 mm at this prop's scale: reconnect export splits, not nearby parts.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=max(obj.dimensions) * 1e-6)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.validate(verbose=True, clean_customdata=False)
    obj.data.update()


def evaluated_copy(obj, name):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), preserve_all_data_layers=True, depsgraph=depsgraph)
    # Welded source contains duplicate/degenerate faces; clean only invalid
    # topology, keeping UV/custom data and leaving intentional openings alone.
    mesh.validate(verbose=True, clean_customdata=False)
    mesh.update()
    mesh.calc_loop_triangles()
    result = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(result)
    result.matrix_world = obj.matrix_world.copy()
    return result


def deviation(source, candidate):
    def tree(obj):
        mesh = obj.data
        mesh.calc_loop_triangles()
        return BVHTree.FromPolygons([v.co for v in mesh.vertices], [t.vertices for t in mesh.loop_triangles], all_triangles=True)
    def samples(obj, target):
        stride = max(1, len(obj.data.vertices) // 10000)
        return sorted(target.find_nearest(obj.data.vertices[i].co)[3] for i in range(0, len(obj.data.vertices), stride))
    forward = samples(source, tree(candidate))
    reverse = samples(candidate, tree(source))
    return {
        "method": "bidirectional sampled vertex-to-surface distance, local meters; not a Hausdorff guarantee",
        "source_to_option_p95_mm": forward[int((len(forward) - 1) * .95)] * 1000,
        "source_to_option_max_mm": max(forward) * 1000,
        "option_to_source_p95_mm": reverse[int((len(reverse) - 1) * .95)] * 1000,
        "option_to_source_max_mm": max(reverse) * 1000,
    }


def point_at(obj, target):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def render_comparisons(models):
    scene = bpy.context.scene
    for obj in list(scene.objects):
        obj.hide_render = True
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 2200
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("ComparisonStudio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.11, .14, .19, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .65
    scene.view_settings.view_transform = "AgX"
    clay = bpy.data.materials.new("Comparison clay (not exported)")
    clay.diffuse_color = (.38, .43, .5, 1)
    clay.use_nodes = True
    clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.38, .43, .5, 1)
    clay.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .65
    camera_data = bpy.data.cameras.new("ComparisonCamera")
    camera = bpy.data.objects.new("ComparisonCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.18
    copies = []
    for obj in models:
        copy = bpy.data.objects.new("Preview_" + obj.name, obj.data.copy())
        scene.collection.objects.link(copy)
        copy.matrix_world = obj.matrix_world.copy()
        copies.append(copy)
    lights = []
    for name, energy, size in [("Key", 110, 1.8), ("Fill", 65, 1.5), ("Rim", 140, 1.3)]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        lights.append(light)
    center = sum((models[0].matrix_world @ Vector(c) for c in models[0].bound_box), Vector()) / 8
    for view, direction in [("front", Vector((.65, -1, .40))), ("back", Vector((-.65, 1, .35))), ("side_clay", Vector((1, -.08, .20)))]:
        direction.normalize()
        right = direction.cross(Vector((0, 0, 1))).normalized()
        # Camera local X is opposite direction cross world up.
        right = -right
        camera.location = center + direction * 2
        point_at(camera, center)
        for i, copy in enumerate(copies):
            copy.location = models[i].location + right * ((i - 1.5) * .29)
            if view == "side_clay":
                copy.data.materials.clear()
                copy.data.materials.append(clay)
        for light, offset in zip(lights, [direction * .8 - right * .6 + Vector((0, 0, 1)), direction * .5 + right * .8 + Vector((0, 0, .4)), -direction * .7 + Vector((0, 0, .8))]):
            light.location = center + offset
            point_at(light, center)
        scene.render.filepath = str(WORK / ("comparison_" + view + ".png"))
        bpy.ops.render.render(write_still=True)
    for copy in copies:
        bpy.data.objects.remove(copy, do_unlink=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inspect", action="store_true")
    parser.add_argument("--no-render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    meshes = import_source()
    original_stats = [mesh_stats(obj) for obj in meshes]
    if args.inspect:
        for obj in meshes:
            weld(obj)
        print("MICROSCOPE_INSPECT=" + json.dumps({"original": original_stats, "welded": [mesh_stats(obj) for obj in meshes]}, indent=2), flush=True)
        return
    if len(meshes) != 1:
        raise RuntimeError("Expected one microscope mesh; inspect before processing another asset")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    original = meshes[0]
    original.name = "Original_78809_triangles"
    report = {"source": str(SOURCE.relative_to(ROOT)), "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(), "original": original_stats[0], "options": []}
    original.hide_set(True)
    original.hide_render = True
    processed = []
    editables = []
    for name, target in OPTIONS:
        obj = original.copy()
        obj.data = original.data.copy()
        obj.name = name
        bpy.context.scene.collection.objects.link(obj)
        obj.hide_set(False)
        obj.hide_render = False
        weld(obj)
        # A near-zero weld preserves per-corner UVs and material assignments.
        # No voxel remesh, hole filling, smoothing, or component deletion.
        decimate = obj.modifiers.new("Editable structure-preserving reduction", "DECIMATE")
        decimate.decimate_type = "COLLAPSE"
        decimate.ratio = target / original_stats[0]["triangles"]
        decimate.use_collapse_triangulate = True
        bpy.context.view_layer.update()
        reduced = evaluated_copy(obj, name + "_export")
        stats = mesh_stats(reduced)
        stats["deviation"] = deviation(original, reduced)
        stats["triangle_reduction_percent"] = 100 * (1 - stats["triangles"] / original_stats[0]["triangles"])
        stats["file"] = str((OUTPUT / ("forge_microscope_" + name + ".glb")).relative_to(ROOT))
        bpy.ops.object.select_all(action="DESELECT")
        reduced.select_set(True)
        bpy.context.view_layer.objects.active = reduced
        bpy.ops.export_scene.gltf(filepath=str(ROOT / stats["file"]), export_format="GLB", use_selection=True, export_yup=True, export_materials="EXPORT", export_animations=False, export_cameras=False, export_lights=False, export_texcoords=True, export_normals=True, export_tangents=True, export_image_format="AUTO")
        exported_bytes = (ROOT / stats["file"]).read_bytes()
        json_length = struct.unpack_from("<I", exported_bytes, 12)[0]
        gltf = json.loads(exported_bytes[20:20 + json_length])
        stats["exported_triangles"] = sum(gltf["accessors"][primitive["indices"]]["count"] // 3 for mesh in gltf["meshes"] for primitive in mesh["primitives"])
        stats["exported_vertices"] = sum(gltf["accessors"][primitive["attributes"]["POSITION"]]["count"] for mesh in gltf["meshes"] for primitive in mesh["primitives"])
        stats["exported_materials"] = len(gltf.get("materials", []))
        stats["exported_images"] = len(gltf.get("images", []))
        stats["file_bytes"] = len(exported_bytes)
        report["options"].append(stats)
        print("MICROSCOPE_OPTION=" + json.dumps(stats), flush=True)
        reduced.hide_render = True
        reduced.hide_set(True)
        obj.hide_render = name != "balanced_15k"
        obj.hide_set(name != "balanced_15k")
        editables.append(obj)
        processed.append(reduced)
    report["source_unchanged"] = hashlib.sha256(SOURCE.read_bytes()).hexdigest() == report["source_sha256"]
    (WORK / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    # Save only original + editable versions. Export meshes are temporary previews.
    for obj in processed:
        bpy.context.scene.collection.objects.unlink(obj)
    bpy.ops.object.select_all(action="DESELECT")
    editables[1].select_set(True)
    bpy.context.view_layer.objects.active = editables[1]
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK / "forge_microscope_options.blend"))
    for obj in processed:
        bpy.context.scene.collection.objects.link(obj)
    if not args.no_render:
        render_comparisons([original] + processed)
    print("MICROSCOPE_COMPLETE", flush=True)


if __name__ == "__main__":
    main()
