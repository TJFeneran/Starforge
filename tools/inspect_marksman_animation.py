"""Sample the authored Blender clips for loop and ground contact evidence."""
import bpy,json,os,sys
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1]
out=root/'assets/source/blender/rift_marksman'
bpy.ops.wm.open_mainfile(filepath=str(out/'marksman_rigged.blend'))
rig=bpy.data.objects['Needlecrest_Rig'];body=bpy.data.objects['Needlecrest_Body'];scene=bpy.context.scene
report={}
for name in ['idle','walk','run','strafe_left','strafe_right','aim','attack','hit','death']:
 action=bpy.data.actions[name];rig.animation_data.action=action;frames=[]
 for frame in range(0,int(action.frame_range[1])+1,3):
  scene.frame_set(frame);deps=bpy.context.evaluated_depsgraph_get();o=body.evaluated_get(deps);mesh=o.to_mesh()
  bounds=[min((o.matrix_world@v.co).z for v in mesh.vertices),max((o.matrix_world@v.co).z for v in mesh.vertices)]
  feet=[]
  for side in [-1,1]:
   ids=[v.index for v in body.data.vertices if v.co.z<.035 and v.co.x*side>0]
   feet.append(min((o.matrix_world@mesh.vertices[i].co).z for i in ids))
  frames.append({'frame':frame,'floor_min_m':bounds[0],'height_max_m':bounds[1],'sole_min_m':feet})
  o.to_mesh_clear()
 report[name]=frames
(out/'motion_checks.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({n:{'floor_min':min(f['floor_min_m'] for f in fs),'floor_max':max(f['floor_min_m'] for f in fs)} for n,fs in report.items()}),flush=True)
sys.stdout.flush();os._exit(0)
