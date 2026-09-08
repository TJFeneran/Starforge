# 3D asset layout

- `models/`: runtime-ready GLB files imported by Godot
- `source/concepts/`: Cursor-generated concept/sample images for Meshy
- `source/meshy/`: original Meshy downloads and textures
- `source/blender/`: editable Blender working files

`source/` is isolated with `.gdignore`; Godot imports only runtime-ready assets.
