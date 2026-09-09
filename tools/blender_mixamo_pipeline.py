"""Convert Mixamo FBX (skinned + anim) to Godot-ready GLB.

Mixamo FBX imports into Blender with armature scale ~0.01. Applying that
scale without rewriting pose location keyframes turns centimeters of hip
root motion into meters — the character slides all over the place in Godot.

This pipeline:
1. Imports FBX with animation
2. Forces hips in-place (locks horizontal translation, keeps vertical bob)
3. Applies armature scale/rotation while scaling location keyframes to match
4. Plants feet at Z=0
5. Exports GLB with skins + animations
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	parser = argparse.ArgumentParser()
	parser.add_argument("input", type=Path)
	parser.add_argument("output", type=Path)
	parser.add_argument("--blend", type=Path)
	parser.add_argument(
		"--target-height",
		type=float,
		default=1.8,
		help="Uniform scale so mesh height becomes this many meters",
	)
	parser.add_argument(
		"--pin-hips",
		action="store_true",
		help="Lock all hips location axes (for jump/fall clips driven by gameplay physics)",
	)
	return parser.parse_args(argv)


def clear_scene() -> None:
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete(use_global=False)
	for block in (
		bpy.data.meshes,
		bpy.data.armatures,
		bpy.data.actions,
		bpy.data.materials,
		bpy.data.images,
	):
		for item in list(block):
			block.remove(item)


def import_fbx(path: Path) -> None:
	if hasattr(bpy.ops.wm, "fbx_import"):
		bpy.ops.wm.fbx_import(filepath=str(path), use_anim=True, ignore_leaf_bones=False)
	else:
		bpy.ops.import_scene.fbx(filepath=str(path), use_anim=True, ignore_leaf_bones=False)


def find_armature() -> bpy.types.Object | None:
	for obj in bpy.data.objects:
		if obj.type == "ARMATURE":
			return obj
	return None


def mesh_bounds() -> tuple[Vector, Vector] | tuple[None, None]:
	min_c = max_c = None
	for obj in bpy.data.objects:
		if obj.type != "MESH":
			continue
		for corner in obj.bound_box:
			world = obj.matrix_world @ Vector(corner)
			min_c = (
				world.copy()
				if min_c is None
				else Vector((min(min_c.x, world.x), min(min_c.y, world.y), min(min_c.z, world.z)))
			)
			max_c = (
				world.copy()
				if max_c is None
				else Vector((max(max_c.x, world.x), max(max_c.y, world.y), max(max_c.z, world.z)))
			)
	return min_c, max_c


def mesh_height() -> float:
	min_c, max_c = mesh_bounds()
	if min_c is None or max_c is None:
		return 0.0
	return max(0.0, max_c.z - min_c.z)


def iter_action_fcurves(action: bpy.types.Action):
	# Blender 5 layered actions store fcurves on channelbags; older builds use action.fcurves.
	if getattr(action, "is_action_layered", False):
		for layer in action.layers:
			for strip in layer.strips:
				for bag in strip.channelbags:
					yield from bag.fcurves
		return
	fcurves = getattr(action, "fcurves", None)
	if fcurves is not None:
		yield from fcurves


def scale_pose_location_keyframes(factor: float) -> None:
	if abs(factor - 1.0) < 1e-8:
		return
	for action in bpy.data.actions:
		for fc in iter_action_fcurves(action):
			if "pose.bones" not in fc.data_path or not fc.data_path.endswith("location"):
				continue
			for kp in fc.keyframe_points:
				kp.co[1] *= factor
				kp.handle_left[1] *= factor
				kp.handle_right[1] *= factor
			fc.update()


def force_hips_in_place(*, pin_all: bool = False) -> None:
	"""Lock hips translation. By default keeps the smallest-travel axis as bob."""
	for action in bpy.data.actions:
		hip_fcs = [
			fc
			for fc in iter_action_fcurves(action)
			if "Hips" in fc.data_path and fc.data_path.endswith("location")
		]
		if not hip_fcs:
			continue
		ranges: dict[int, float] = {}
		first_vals: dict[int, float] = {}
		for fc in hip_fcs:
			vals = [kp.co[1] for kp in fc.keyframe_points]
			if not vals:
				continue
			ranges[fc.array_index] = max(vals) - min(vals)
			first_vals[fc.array_index] = vals[0]
		if not ranges:
			continue
		if pin_all or len(ranges) < 2:
			lock_idxs = set(ranges.keys())
			keep_idx = None
		else:
			ordered = sorted(ranges.keys(), key=lambda idx: ranges[idx], reverse=True)
			lock_idxs = set(ordered[:2])
			keep_idx = ordered[-1]
		print(f"IN_PLACE action={action.name} keep_axis={keep_idx} lock={sorted(lock_idxs)} ranges={ranges}")
		for fc in hip_fcs:
			if fc.array_index not in lock_idxs:
				continue
			base = first_vals.get(fc.array_index, fc.keyframe_points[0].co[1])
			for kp in fc.keyframe_points:
				kp.co[1] = base
				kp.handle_left[1] = base
				kp.handle_right[1] = base
			fc.update()


def apply_armature_object_transforms(armature: bpy.types.Object) -> None:
	"""Bake armature object scale/rotation into data, keeping pose location units consistent."""
	sx, sy, sz = armature.scale
	# Mixamo uses uniform scale; use X as the location keyframe scale factor.
	scale_factor = float(sx)
	print(f"ARMATURE_SCALE_BEFORE=({sx}, {sy}, {sz}) ROT={tuple(armature.rotation_euler)}")

	bpy.ops.object.select_all(action="DESELECT")
	armature.select_set(True)
	bpy.context.view_layer.objects.active = armature
	bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
	scale_pose_location_keyframes(scale_factor)
	print(f"ARMATURE_SCALE_AFTER={tuple(armature.scale)}")


def normalize_height(target_height: float, armature: bpy.types.Object) -> None:
	height = mesh_height()
	if height <= 0.001:
		print("Skipping height normalize; could not measure mesh")
		return
	factor = target_height / height
	print(f"HEIGHT_BEFORE={height:.4f} TARGET={target_height:.4f} FACTOR={factor:.4f}")
	if abs(factor - 1.0) > 1e-4:
		armature.scale = (
			armature.scale[0] * factor,
			armature.scale[1] * factor,
			armature.scale[2] * factor,
		)
		bpy.context.view_layer.update()
		bpy.ops.object.select_all(action="DESELECT")
		armature.select_set(True)
		bpy.context.view_layer.objects.active = armature
		bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
		scale_pose_location_keyframes(factor)
	print(f"HEIGHT_AFTER={mesh_height():.4f}")


def plant_feet(armature: bpy.types.Object) -> None:
	min_c, _max_c = mesh_bounds()
	if min_c is None:
		return
	armature.location.z -= min_c.z
	bpy.context.view_layer.update()
	bpy.ops.object.select_all(action="DESELECT")
	armature.select_set(True)
	bpy.context.view_layer.objects.active = armature
	bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
	min_c, max_c = mesh_bounds()
	print(f"PLANTED min={min_c} max={max_c}")


def main() -> None:
	args = parse_args()
	source = args.input.expanduser().resolve()
	output = args.output.expanduser().resolve()
	blend = args.blend.expanduser().resolve() if args.blend else None
	if not source.is_file():
		raise FileNotFoundError(source)
	if output.suffix.lower() != ".glb":
		raise ValueError("Output must end in .glb")

	clear_scene()
	import_fbx(source)

	armature = find_armature()
	if armature is None:
		raise RuntimeError("No armature found in Mixamo FBX")

	# Kill residual Mixamo root motion first (keys still in pre-apply units).
	force_hips_in_place(pin_all=args.pin_hips)
	apply_armature_object_transforms(armature)
	normalize_height(args.target_height, armature)
	plant_feet(armature)
	bones = [b.name for b in armature.data.bones]
	print(f"ARMATURE={armature.name} BONES={len(bones)}")
	for needle in ("mixamorig:RightHand", "mixamorig_RightHand", "RightHand"):
		if needle in bones:
			print(f"HAND_BONE={needle}")
			break
	print(f"ACTIONS={[a.name for a in bpy.data.actions]}")

	if blend:
		blend.parent.mkdir(parents=True, exist_ok=True)
		bpy.ops.wm.save_as_mainfile(filepath=str(blend))

	output.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=str(output),
		export_format="GLB",
		export_yup=True,
		export_materials="EXPORT",
		export_animations=True,
		export_skins=True,
		export_morph=False,
		export_cameras=False,
		export_lights=False,
		export_texcoords=True,
		export_normals=True,
		export_image_format="AUTO",
	)
	print(f"Exported Godot GLB: {output}")


if __name__ == "__main__":
	main()
