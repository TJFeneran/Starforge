"""Fit the existing Dustcoat Meshy model to the player skeleton and transfer skin weights."""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


PROJECT = Path(__file__).resolve().parents[4]
OUTPUT = Path(__file__).resolve().parent
SOURCE = PROJECT / "assets/source/meshy/armor_starter_dustcoat/armor_starter_dustcoat.glb"
REFERENCE = PROJECT / "assets/models/characters/exo_gray_bind.glb"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(REFERENCE))
armature = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
armature.animation_data_clear()
armature.data.pose_position = "REST"
reference = bpy.data.objects["Exo_Suit"]
reference.data.calc_loop_triangles()
triangles = [tuple(tri.vertices) for tri in reference.data.loop_triangles]
reference_vertices = [reference.matrix_world @ vertex.co for vertex in reference.data.vertices]
bvh = BVHTree.FromPolygons(reference_vertices, triangles, all_triangles=True)
reference_weights = [
    {reference.vertex_groups[group.group].name: group.weight for group in vertex.groups}
    for vertex in reference.data.vertices
]

original_objects = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
body = next(obj for obj in set(bpy.data.objects) - original_objects if obj.type == "MESH")
body.name = "Dustcoat_Meshy7_Skinned"
raw_triangles = sum(len(poly.vertices) - 2 for poly in body.data.polygons)
minimum_z = min(vertex.co.z for vertex in body.data.vertices)
maximum_z = max(vertex.co.z for vertex in body.data.vertices)
height_factor = 1.9 / (maximum_z - minimum_z)


def smoothstep(start, end, value):
    t = max(0.0, min(1.0, (value - start) / (end - start)))
    return t * t * (3.0 - 2.0 * t)


# Meshy's A-pose arms are lifted to the Exo Gray bind pose. The middle of the coat
# stays put; only outward sleeve vertices rotate around their shoulder.
for vertex in body.data.vertices:
    x, y, z = vertex.co
    z = (z - minimum_z) * height_factor
    x *= 1.035
    side = 1.0 if x >= 0.0 else -1.0
    arm_mix = smoothstep(0.26, 0.41, abs(x))
    dx = abs(x) - 0.22
    dz = z - 1.49
    angle = math.radians(42.0)
    raised_x = 0.22 + dx * math.cos(angle) - dz * math.sin(angle)
    raised_z = 1.49 + dx * math.sin(angle) + dz * math.cos(angle)
    vertex.co = (side * (abs(x) * (1.0 - arm_mix) + raised_x * arm_mix),
                 y + arm_mix * 0.03,
                 z * (1.0 - arm_mix) + raised_z * arm_mix)

for bone in armature.data.bones:
    body.vertex_groups.new(name=bone.name)

distances = []
for vertex in body.data.vertices:
    point = body.matrix_world @ vertex.co
    position, _normal, triangle_index, distance = bvh.find_nearest(point)
    distances.append(distance)
    indices = triangles[triangle_index]
    a, b, c = [reference_vertices[index] for index in indices]
    edge0, edge1, offset = b - a, c - a, position - a
    d00, d01, d11 = edge0.dot(edge0), edge0.dot(edge1), edge1.dot(edge1)
    d20, d21 = offset.dot(edge0), offset.dot(edge1)
    denominator = d00 * d11 - d01 * d01
    bary_b = (d11 * d20 - d01 * d21) / denominator if abs(denominator) > 1e-15 else 0.0
    bary_c = (d00 * d21 - d01 * d20) / denominator if abs(denominator) > 1e-15 else 0.0
    barycentric = [max(0.0, 1.0 - bary_b - bary_c), max(0.0, bary_b), max(0.0, bary_c)]
    weights = {}
    for index, factor in zip(indices, barycentric):
        for bone, weight in reference_weights[index].items():
            weights[bone] = weights.get(bone, 0.0) + weight * factor

    # Keep the generated face/hair coherent, and avoid bending the coat body
    # around independently moving legs or fingers.
    if point.z > 1.62 and abs(point.x) < 0.25:
        weights = {"mixamorig:Head": 1.0}
    elif abs(point.x) > 0.24 and (point.z > 1.16 or abs(point.x) > 0.4):
        x = abs(point.x)
        side = "Left" if point.x >= 0.0 else "Right"
        upper = "mixamorig:" + side + "Arm"
        lower = "mixamorig:" + side + "ForeArm"
        hand = "mixamorig:" + side + "Hand"
        if x < 0.35:
            t = smoothstep(0.24, 0.35, x)
            weights = {"mixamorig:Spine2": 1.0 - t, upper: t}
        elif x < 0.47:
            weights = {upper: 1.0}
        elif x < 0.58:
            t = smoothstep(0.47, 0.58, x)
            weights = {upper: 1.0 - t, lower: t}
        elif x < 0.72:
            weights = {lower: 1.0}
        elif x < 0.82:
            t = smoothstep(0.72, 0.82, x)
            weights = {lower: 1.0 - t, hand: t}
        else:
            weights = {hand: 1.0}
    elif 0.68 < point.z < 1.07 and abs(point.x) < 0.38:
        weights = {"mixamorig:Hips": 1.0}
    elif point.z < 0.13:
        weights = {"mixamorig:LeftFoot" if point.x >= 0 else "mixamorig:RightFoot": 1.0}

    combined = {}
    for bone, weight in weights.items():
        for finger in ("Index", "Ring", "Pinky"):
            bone = bone.replace("Hand" + finger, "HandMiddle")
        combined[bone] = combined.get(bone, 0.0) + weight
    strongest = sorted(combined.items(), key=lambda item: item[1], reverse=True)[:4]
    total = sum(weight for _, weight in strongest)
    if total <= 0.0:
        strongest = [("mixamorig:Hips", 1.0)]
        total = 1.0
    for bone, weight in strongest:
        if weight > 1e-6:
            body.vertex_groups[bone].add([vertex.index], weight / total, "REPLACE")

modifier = body.modifiers.new("Exo Gray skeleton", "ARMATURE")
modifier.object = armature
body.parent = armature
body.matrix_parent_inverse = armature.matrix_world.inverted()
for obj in original_objects:
    if obj != armature:
        bpy.data.objects.remove(obj, do_unlink=True)

for image in bpy.data.images:
    if image.size[0] > 0:
        try:
            image.pack()
        except Exception:
            pass

bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "dustcoat_meshy_rigged.blend"))
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(filepath=str(OUTPUT / "dustcoat_meshy_rigged.glb"),
                           export_format="GLB", use_selection=True,
                           export_animations=False, export_skins=True)
report = {
    "source": str(SOURCE.relative_to(PROJECT)),
    "rigged_triangles": raw_triangles,
    "vertices": len(body.data.vertices),
    "bones": len(armature.data.bones),
    "mesh_objects": 1,
    "max_influences": max(len(vertex.groups) for vertex in body.data.vertices),
    "unweighted_vertices": sum(not vertex.groups for vertex in body.data.vertices),
    "transfer_distance_max": max(distances),
    "transfer_distance_mean": sum(distances) / len(distances),
}
(OUTPUT / "validation.json").write_text(json.dumps(report, indent=2))
print("RIG_REPORT", report)
