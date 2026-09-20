# 3D asset layout

- `models/`: runtime-ready GLB files imported by Godot
- `source/concepts/`: concept references, including separate armor front/side/back and gun views
- `source/meshy/`: original Meshy downloads and textures
- `source/mixamp/`: Mixamo FBX downloads (Exo Gray + clips)
- `source/blender/`: editable Blender working files and armor rigs

`source/` is isolated with `.gdignore`; Godot imports only runtime-ready assets.

The nine armor preview exports are in `models/gear/armor/previews/`; their Meshy originals and Blender rigs remain in `source/meshy/armor_*/` and `source/blender/armor_*/`.
