"""Fit the two approved Meshy armor meshes to the unchanged production skeleton.
Preserves source triangles, UVs and texture images; no procedural replacement geometry.
"""
import bpy,math,json
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
P=Path(__file__).resolve().parents[4]
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def rig(ident):
 O=P/'assets/source/blender'/ident;O.mkdir(exist_ok=True);(O/'.gdignore').touch();(O/'previews').mkdir(exist_ok=True)
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(P/'assets/models/characters/exo_gray_bind.glb'))
 arm=next(o for o in bpy.data.objects if o.type=='ARMATURE');arm.animation_data_clear();arm.data.pose_position='REST'
 ref=bpy.data.objects['Exo_Suit'];ref.data.calc_loop_triangles();tris=[tuple(t.vertices) for t in ref.data.loop_triangles];vs=[ref.matrix_world@v.co for v in ref.data.vertices];bvh=BVHTree.FromPolygons(vs,tris,all_triangles=True)
 weights_ref=[{ref.vertex_groups[g.group].name:g.weight for g in v.groups} for v in ref.data.vertices]
 old=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(P/'assets/source/meshy'/ident/(ident+'.glb')));body=next(o for o in set(bpy.data.objects)-old if o.type=='MESH');body.name=ident+'_Meshy7_Skinned'
 minz=min(v.co.z for v in body.data.vertices);height=max(v.co.z for v in body.data.vertices)-minz
 for v in body.data.vertices:
  x,y,z=v.co;z=(z-minz)*1.835/height
  arm_mix=smooth(.21,.39,abs(x))*smooth(1.15,1.3,z)
  # Legs are narrower in the animation rig than the generated stance.
  leg_mix=1-smooth(.82,1.02,z)
  nx=x*(1-.24*leg_mix)
  nx=(1-arm_mix)*nx+arm_mix*(float(np.interp(abs(x),[0,.20,.49,.765,.944],[0,.192,.478,.767,.995]))*(1 if x>=0 else -1))
  nz=float(np.interp(z,[0,.50,.95,1.375,1.60,1.835],[-.017,.522,.988,1.488,1.64,1.90]))
  v.co=(nx,y+.015+arm_mix*.038,nz)
 for bone in arm.data.bones:body.vertex_groups.new(name=bone.name)
 distances=[]
 for v in body.data.vertices:
  co=body.matrix_world@v.co;pos,normal,idx,dist=bvh.find_nearest(co);distances.append(dist)
  ids=tris[idx];a,b,c=[vs[i] for i in ids];e0=b-a;e1=c-a;e2=pos-a;d00=e0.dot(e0);d01=e0.dot(e1);d11=e1.dot(e1);d20=e2.dot(e0);d21=e2.dot(e1);den=d00*d11-d01*d01
  bv=(d11*d20-d01*d21)/den if abs(den)>1e-15 else 0;cv=(d00*d21-d01*d20)/den if abs(den)>1e-15 else 0;bc=[max(0,1-bv-cv),max(0,bv),max(0,cv)];w={}
  for i,fac in zip(ids,bc):
   for name,val in weights_ref[i].items():w[name]=w.get(name,0)+fac*val
  side='Left' if co.x>=0 else 'Right';x=abs(co.x)
  if co.z>1.62 and x<.145:w={'mixamorig:Head':1}
  elif x>.145 and co.z>1.30:
   if x<.235:
    t=smooth(.145,.235,x);w={'mixamorig:Spine2':1-t,'mixamorig:'+side+'Arm':t}
   elif x<.445:w={'mixamorig:'+side+'Arm':1}
   elif x<.53:
    t=smooth(.445,.53,x);w={'mixamorig:'+side+'Arm':1-t,'mixamorig:'+side+'ForeArm':t}
   elif x<.72:w={'mixamorig:'+side+'ForeArm':1}
   elif x<.8:
    t=smooth(.72,.8,x);w={'mixamorig:'+side+'ForeArm':1-t,'mixamorig:'+side+'Hand':t}
   else:w={'mixamorig:'+side+'Hand':1}
  elif .96<co.z<1.075 and x<.24:w={'mixamorig:Hips':1}
  elif .595<co.z<.86:w={'mixamorig:'+side+'UpLeg':1}
  elif .18<co.z<.435:w={'mixamorig:'+side+'Leg':1}
  elif co.z<.115:w={'mixamorig:'+side+'Foot':1}
  # Quarry's central apron hangs from the pelvis; do not pull it between moving legs.
  if ident.endswith('quarry_shell') and .70<co.z<1.04 and abs(co.x)<.16 and co.y<-.035:
   apron=(1-smooth(.075,.15,abs(co.x)))*(1-smooth(-.095,-.035,co.y))
   w={name:val*(1-apron) for name,val in w.items()};w['mixamorig:Hips']=w.get('mixamorig:Hips',0)+apron
  w=dict(sorted(w.items(),key=lambda i:i[1],reverse=True)[:4]);total=sum(w.values())
  for name,val in w.items():
   if val>1e-7:body.vertex_groups[name].add([v.index],val/total,'REPLACE')
 mod=body.modifiers.new('Exo Gray animation skeleton','ARMATURE');mod.object=arm;body.parent=arm;body.matrix_parent_inverse=arm.matrix_world.inverted()
 for o in old:
  if o!=arm:bpy.data.objects.remove(o,do_unlink=True)
 for im in bpy.data.images:
  if im.size[0]:
   try:im.pack()
   except:pass
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=20;scene.cycles.use_denoising=True;scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.world.color=(.25,.25,.25)
 def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
 for loc,power,size in [((2,-3,3.8),500,4),((-2,-2,2.6),280,3),((1,2,3.2),450,3)]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;aim(o,(0,0,1))
 bpy.ops.object.camera_add(location=(2.8,-4,2.1));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=2.25;aim(cam,(0,0,.95));scene.camera=cam
 bpy.ops.wm.save_as_mainfile(filepath=str(O/(ident+'_meshy_rigged.blend')))
 bpy.ops.object.select_all(action='DESELECT');body.select_set(True);arm.select_set(True);bpy.context.view_layer.objects.active=arm
 bpy.ops.export_scene.gltf(filepath=str(P/'assets/models/gear/armor/previews'/(ident+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=True)
 report={'source':'assets/source/meshy/'+ident+'/'+ident+'.glb','bones':len(arm.data.bones),'vertices':len(body.data.vertices),'triangles':sum(len(p.vertices)-2 for p in body.data.polygons),'unweighted_vertices':sum(not v.groups for v in body.data.vertices),'max_influences':max(len(v.groups) for v in body.data.vertices),'source_geometry_preserved':True,'uv_layers':len(body.data.uv_layers),'materials':len(body.data.materials),'transfer_distance_mean':sum(distances)/len(distances)}
 (O/'validation.json').write_text(json.dumps(report,indent=2));print('VALIDATION',report)
 scene.render.filepath=str(O/'previews/bind_hero.png');bpy.ops.render.render(write_still=True)
 for clip,frame in [('run',6),('walk',9),('pistol_aim',1)]:
  path=P/'assets/models/characters'/('exo_gray_'+clip+'.glb')
  if not path.exists():continue
  before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));temp=set(bpy.data.objects)-before;temp_arm=next(o for o in temp if o.type=='ARMATURE');arm.animation_data_create();arm.animation_data.action=temp_arm.animation_data.action;arm.animation_data.action_slot=temp_arm.animation_data.action_slot
  for o in temp:bpy.data.objects.remove(o,do_unlink=True)
  arm.data.pose_position='POSE';scene.frame_set(frame);bpy.context.view_layer.update();scene.render.filepath=str(O/'previews'/(clip+'_hero.png'));bpy.ops.render.render(write_still=True)
for ident in ['armor_common_outpost_plate','armor_uncommon_quarry_shell']:rig(ident)
