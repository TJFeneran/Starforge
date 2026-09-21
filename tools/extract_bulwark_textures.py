"""Extract unchanged embedded texture bytes from the Bulwark source GLB."""
import json, os, sys, traceback
from pathlib import Path
import bpy

def fail(typ, value, tb):
    traceback.print_exception(typ, value, tb)
    sys.stderr.flush()
    os._exit(1)
sys.excepthook=fail
root=Path(__file__).resolve().parents[1]
source=root/'assets/source/meshy/forge_bulwark/bulwark_a.glb'
out=root/'assets/source/meshy/forge_bulwark/bulwark_a_textures'
out.mkdir(parents=True,exist_ok=True)
bpy.ops.import_scene.gltf(filepath=str(source))
result=[]
for image in bpy.data.images:
    if image.name not in ('Image_0','Image_1','normal') or image.packed_file is None:continue
    data=bytes(image.packed_file.data)
    suffix='.png' if data.startswith(b'\x89PNG') else '.jpg' if data.startswith(b'\xff\xd8') else '.bin'
    filename=image.name+suffix
    (out/filename).write_bytes(data)
    result.append({'file':filename,'size':list(image.size),'bytes':len(data)})
(out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
print('BULWARK_TEXTURES',json.dumps(result),flush=True)
sys.stdout.flush();os._exit(0)
