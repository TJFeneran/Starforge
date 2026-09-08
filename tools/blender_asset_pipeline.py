"""Import a Meshy model, optionally normalize height, and export GLB for Godot.

Defaults (Starforge):
- Prefer native Meshy GLB over FBX (FBX often loses embedded textures).
- Preserve Meshy materials/UVs when they already include texture images.
- Only rebind sidecar PNGs when imported materials have no usable textures.
"""
from __future__ import annotations

import argparse
import re
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
    parser.add_argument("--target-height", type=float, default=None, help="Uniform scale so mesh height becomes this many meters")
    parser.add_argument("--force-rebind", action="store_true", help="Always wipe materials and rebind sidecar PNGs")
    return parser.parse_args(argv)


def clean_name(value: str, fallback: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("_.")
    return value or fallback


def import_model(path: Path) -> None:
    suffix = path.suffix.lower()
    if suffix in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif suffix == ".fbx":
        bpy.ops.wm.fbx_import(filepath=str(path), use_anim=True, ignore_leaf_bones=True)
    elif suffix == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    else:
        raise ValueError(f"Unsupported input format: {suffix}; expected GLB, GLTF, FBX, or OBJ")


def materials_have_textures() -> bool:
    for material in bpy.data.materials:
        if not material.use_nodes:
            continue
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not None:
                return True
    return False


def find_sidecar_textures(source: Path) -> dict[str, Path]:
    candidates = [
        source.parent / f"{source.stem}_textures",
        source.parent / "textures",
        source.parent,
    ]
    names = {
        "Base Color": ["base_color.png", "basecolor.png", "albedo.png", "diffuse.png"],
        "Metallic": ["metallic.png", "metalness.png"],
        "Roughness": ["roughness.png"],
        "Normal": ["normal.png", "normal_dx.png", "normal_gl.png"],
        "Emission": ["emission.png", "emissive.png"],
    }
    found: dict[str, Path] = {}
    for folder in candidates:
        if not folder.exists():
            continue
        for role, filenames in names.items():
            if role in found:
                continue
            for filename in filenames:
                path = folder / filename
                if path.is_file():
                    found[role] = path
                    break
    return found


def bind_sidecar_textures(source: Path) -> None:
    maps = find_sidecar_textures(source)
    if "Base Color" not in maps:
        print("No sidecar textures found; leaving materials unchanged")
        return
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)
    mat = bpy.data.materials.new("ImportedPBR")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (500, 0)
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (200, 0)
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    def add_image(path: Path, colorspace: str, location: tuple[float, float]):
        node = nodes.new("ShaderNodeTexImage")
        node.location = location
        image = bpy.data.images.load(str(path))
        image.colorspace_settings.name = colorspace
        node.image = image
        return node

    base = add_image(maps["Base Color"], "sRGB", (-400, 200))
    links.new(base.outputs["Color"], bsdf.inputs["Base Color"])
    if "Metallic" in maps:
        metallic = add_image(maps["Metallic"], "Non-Color", (-400, 0))
        links.new(metallic.outputs["Color"], bsdf.inputs["Metallic"])
    if "Roughness" in maps:
        roughness = add_image(maps["Roughness"], "Non-Color", (-400, -180))
        links.new(roughness.outputs["Color"], bsdf.inputs["Roughness"])
    if "Normal" in maps:
        normal = add_image(maps["Normal"], "Non-Color", (-400, -360))
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.location = (-100, -360)
        links.new(normal.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    if "Emission" in maps:
        emission = add_image(maps["Emission"], "sRGB", (-400, -540))
        links.new(emission.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.data.materials.clear()
            obj.data.materials.append(mat)
    print(f"Rebound sidecar textures from {maps['Base Color'].parent}")


def maybe_bind_textures(source: Path, force_rebind: bool) -> None:
    if force_rebind:
        bind_sidecar_textures(source)
        return
    if materials_have_textures():
        print("Preserving imported Meshy materials (textures already present)")
        return
    print("Imported materials lack textures; attempting sidecar rebind")
    bind_sidecar_textures(source)


def mesh_height() -> float:
    min_z = max_z = None
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            min_z = world.z if min_z is None else min(min_z, world.z)
            max_z = world.z if max_z is None else max(max_z, world.z)
    if min_z is None or max_z is None:
        return 0.0
    return max(0.0, max_z - min_z)


def normalize_height(target_height: float) -> None:
    height = mesh_height()
    if height <= 0.001:
        print("Skipping height normalize; could not measure mesh")
        return
    factor = target_height / height
    print(f"HEIGHT_BEFORE={height:.4f} TARGET={target_height:.4f} FACTOR={factor:.4f}")
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    for obj in meshes:
        obj.scale = (obj.scale[0] * factor, obj.scale[1] * factor, obj.scale[2] * factor)
    bpy.context.view_layer.update()
    min_z = None
    for obj in meshes:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            min_z = world.z if min_z is None else min(min_z, world.z)
    if min_z is not None:
        for obj in meshes:
            obj.location.z -= min_z
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    print(f"HEIGHT_AFTER={mesh_height():.4f}")


def main() -> None:
    args = parse_args()
    source = args.input.expanduser().resolve()
    output = args.output.expanduser().resolve()
    blend = args.blend.expanduser().resolve() if args.blend else None
    if not source.is_file():
        raise FileNotFoundError(source)
    if output.suffix.lower() != ".glb":
        raise ValueError("Output must end in .glb")
    if source.suffix.lower() == ".fbx":
        print("WARNING: FBX often loses Meshy textures; prefer downloading Meshy GLB")

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    import_model(source)
    maybe_bind_textures(source, force_rebind=args.force_rebind)

    for index, obj in enumerate(bpy.data.objects, start=1):
        obj.name = clean_name(obj.name, f"Object_{index:03d}")
    for index, material in enumerate(bpy.data.materials, start=1):
        material.name = clean_name(material.name, f"Material_{index:03d}")

    if args.target_height is not None:
        normalize_height(args.target_height)

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
        export_morph=True,
        export_cameras=False,
        export_lights=False,
        export_texcoords=True,
        export_normals=True,
        export_image_format="AUTO",
    )
    print(f"Exported Godot GLB: {output}")


if __name__ == "__main__":
    main()
