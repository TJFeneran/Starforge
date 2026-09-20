import bpy,json,math
from mathutils import Vector
from pathlib import Path
P=Path('/home/tj/Documents/GodotProjects/Starforge');O=P/'assets/source/blender/armor_common_trail_warden'
bpy.ops.wm.open_mainfile(filepath=str(O/'trail_warden_meshy_rigged.blend'));arm=next(o for o in bpy.data.objects if o.type=='ARMATURE');body=next(o for o in bpy.data.objects if o.type=='MESH');scene=bpy.context.scene;cam=scene.camera
report=json.loads((O/'validation.json').read_text());tests=[]
for label,file,frames in [('run','exo_gray_run.glb',[1,6,12,18]),('aim','exo_gray_pistol_aim.glb',[1,10,20]),('idle','exo_gray_idle.glb',[1])]:
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(P/'assets/models/characters'/file));new=set(bpy.data.objects)-before;src=next(o for o in new if o.type=='ARMATURE');error=max(max(abs(arm.data.bones[b.name].matrix_local[r][c]-b.matrix_local[r][c]) for r in range(4) for c in range(4)) for b in src.data.bones);action=src.animation_data.action;slot=src.animation_data.action_slot;arm.animation_data_create();arm.animation_data.action=action;arm.animation_data.action_slot=slot
 for o in new:bpy.data.objects.remove(o,do_unlink=True)
 for frame in frames:
  scene.frame_set(frame);bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();co=[body.matrix_world@v.co for v in body.evaluated_get(deps).data.vertices];assert all(math.isfinite(c) for v in co for c in v);tests.append({'animation':file,'frame':frame,'animation_skeleton_rest_max_error':error,'min':[min(v[i] for v in co) for i in range(3)],'max':[max(v[i] for v in co) for i in range(3)]})
  if (label=='run' and frame==12) or (label!='run' and frame==1):
   for view,loc in [('hero',(2.8,-4,2.1)),('side',(4,0,1.4))]:
    cam.location=loc;cam.rotation_euler=(Vector((0,0,.95))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(O/'previews'/f'{label}_{view}.png');bpy.ops.render.render(write_still=True)
report['animation_tests']=tests;report['status']='exact player skeleton; existing run, aim and idle sampled; rendered pose review';(O/'validation.json').write_text(json.dumps(report,indent=2));print('VALIDATION',report)
# Round-trip GLB skin check against the actual game bind asset.
import struct
import numpy as np
def read_glb(path):
 raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];d=json.loads(raw[20:20+n]);binary=raw[28+n:];acc=d['accessors'][d['skins'][0]['inverseBindMatrices']];view=d['bufferViews'][acc['bufferView']];offset=view.get('byteOffset',0)+acc.get('byteOffset',0);matrices=np.frombuffer(binary,dtype='<f4',count=acc['count']*16,offset=offset);return d,matrices
ref,refmat=read_glb(P/'assets/models/characters/exo_gray_bind.glb');out,outmat=read_glb(O/'trail_warden_meshy_rigged.glb');refnames=[ref['nodes'][i]['name'] for i in ref['skins'][0]['joints']];outnames=[out['nodes'][i]['name'] for i in out['skins'][0]['joints']]
report['export_validation']={'joint_names_and_order_match_exo_gray_bind':refnames==outnames,'joint_count':len(outnames),'inverse_bind_matrix_max_error_vs_exo_gray_bind':float(np.max(np.abs(refmat-outmat))),'mesh_count':len(out['meshes']),'embedded_images':len(out['images']),'skin_count':len(out['skins'])}
(O/'validation.json').write_text(json.dumps(report,indent=2))
