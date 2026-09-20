"""Preserve the Meshy 7 character and textures; fit and skin to Exo Gray's exact rig."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3];ID=OUT.name;HORIZON='horizon' in ID
(OUT/'.gdignore').touch();(OUT/'previews').mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/characters/exo_gray_bind.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear();rig.data.pose_position='REST'
ref=bpy.data.objects['Exo_Suit'];ref.data.calc_loop_triangles();tris=[tuple(t.vertices) for t in ref.data.loop_triangles];points=[ref.matrix_world@v.co for v in ref.data.vertices];tree=BVHTree.FromPolygons(points,tris,all_triangles=True)
rweights=[{ref.vertex_groups[g.group].name:g.weight for g in v.groups} for v in ref.data.vertices];old=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/source/meshy'/ID/(ID+'.glb')))
body=next(o for o in set(bpy.data.objects)-old if o.type=='MESH');body.name=ID+'_Meshy7_Skinned';minimum=min(v.co.z for v in body.data.vertices);raw_triangles=sum(len(p.vertices)-2 for p in body.data.polygons)
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
# Fitting only: lift the generated relaxed arms to the shared T bind pose.
for v in body.data.vertices:
 x,y,z=v.co;z-=minimum;side=1 if x>=0 else -1;ax=abs(x)
 if HORIZON:
  x*=1.10;y*=1.10;z*=1.10;ax=abs(x)
  blend=smooth(.19,.29,ax)*smooth(1.08,1.3,z)
  dx=ax-.195;dz=z-1.485;angle=math.radians(43)
  xx=.195+dx*math.cos(angle)-dz*math.sin(angle);zz=1.485+dx*math.sin(angle)+dz*math.cos(angle)
  x=side*(ax*(1-blend)+xx*blend);z=z*(1-blend)+zz*blend
  # The relaxed fingertips end around x=.81 after lifting; match Exo hand span.
  x=side*(abs(x)+.12*smooth(.3,.80,abs(x)))
 else:
  z+=.015
  mix=smooth(.21,.38,ax);z+=mix*(.055+.105*max(0,ax-.3))
  x=side*(ax+.14*smooth(.22,.86,ax))
 # Feet/legs use the same knee and hip spacing as the animation skeleton.
 lower=1-smooth(.87,1.12,z);x-=side*(.060 if HORIZON else .071)*lower*smooth(.025,.105,abs(x))
 y+=.035*smooth(.22,.40,abs(x))*smooth(1.15,1.38,z)
 v.co=(x,y,z)
for b in rig.data.bones:body.vertex_groups.new(name=b.name)
distances=[]
for v in body.data.vertices:
 co=body.matrix_world@v.co;pos,_,ix,dist=tree.find_nearest(co);distances.append(dist)
 a,b,c=[points[i] for i in tris[ix]];e=b-a;f=c-a;d=pos-a;den=e.dot(e)*f.dot(f)-e.dot(f)**2
 bv=(f.dot(f)*d.dot(e)-e.dot(f)*d.dot(f))/den if abs(den)>1e-15 else 0;cv=(e.dot(e)*d.dot(f)-e.dot(f)*d.dot(e))/den if abs(den)>1e-15 else 0
 weights={}
 for i,w in zip(tris[ix],[max(0,1-bv-cv),max(0,bv),max(0,cv)]):
  for name,value in rweights[i].items():weights[name]=weights.get(name,0)+w*value
 side='Left' if co.x>=0 else 'Right';ax=abs(co.x)
 if co.z>1.61 and ax<.23:weights={'mixamorig:Head':1}
 elif ax>.25 and co.z>1.25:
  if ax<.45:weights={'mixamorig:'+side+'Arm':1}
  elif ax<.53:
   t=smooth(.45,.53,ax);weights={'mixamorig:'+side+'Arm':1-t,'mixamorig:'+side+'ForeArm':t}
  elif ax<.735:weights={'mixamorig:'+side+'ForeArm':1}
  else:weights={'mixamorig:'+side+'Hand':1}
 elif .965<co.z<1.08:weights={'mixamorig:Hips':1}
 # Keep backpack, breastplate and the diagonal sash attached to torso.
 elif co.y>.10 and co.z>1.1:weights={'mixamorig:Spine2':1}
 # Long central heraldic cloth stays with the hips; side flaps follow thighs.
 elif HORIZON and .49<co.z<.965 and abs(co.x)<.062 and abs(co.y)>.075:weights={'mixamorig:Hips':1}
 combined={}
 for name,w in weights.items():
  for f in ['Index','Pinky','Ring']:name=name.replace('Hand'+f,'HandMiddle')
  combined[name]=combined.get(name,0)+w
 strongest=sorted(combined.items(),key=lambda t:t[1],reverse=True)[:4];total=sum(w for _,w in strongest)
 for name,w in strongest:
  if w>1e-6:body.vertex_groups[name].add([v.index],w/total,'REPLACE')
mod=body.modifiers.new('Exact Exo Gray animation skeleton','ARMATURE');mod.object=rig;body.parent=rig;body.matrix_parent_inverse=rig.matrix_world.inverted()
for o in old:
 if o!=rig:bpy.data.objects.remove(o,do_unlink=True)
for im in bpy.data.images:
 if im.size[0]:
  try:im.pack()
  except:pass
# Retain Meshy normals, UVs, materials, textures, and all generated triangles.
rig.data.pose_position='POSE'
for b in rig.pose.bones:b.matrix_basis.identity()
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
for pos,power in [((2,-3,4),500),((-3,-1,3),320),((0,3,3),450)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=4;aim(l,(0,0,1))
bpy.ops.object.camera_add(location=(2.4,-4,2.0));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=2.5;aim(cam,(0,0,1.0));scene=bpy.context.scene;scene.camera=cam;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True;scene.render.resolution_x=850;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.world.color=(.2,.2,.2)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(ID+'_meshy_rigged.blend')))
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/gear/armor/previews'/(ID+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=True)
report={'source':str(('assets/source/meshy/'+ID+'/'+ID+'.glb')),'bones':len(rig.data.bones),'bone_names':[b.name for b in rig.data.bones],'raw_triangles':raw_triangles,'rigged_triangles':sum(len(p.vertices)-2 for p in body.data.polygons),'vertices':len(body.data.vertices),'unweighted_vertices':sum(not v.groups for v in body.data.vertices),'max_influences':max(len(v.groups) for v in body.data.vertices),'weight_sum_max_error':max(abs(sum(g.weight for g in v.groups)-1) for v in body.data.vertices),'uv_layers':len(body.data.uv_layers),'materials':len(body.data.materials),'textures':len([i for i in bpy.data.images if i.size[0]]),'transfer_distance_mean':sum(distances)/len(distances)}
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
scene.render.filepath=str(OUT/'previews/bind_hero.png');bpy.ops.render.render(write_still=True)
for label,asset,frame in [('walk','exo_gray_walk',12),('run','exo_gray_run',6),('aim','exo_gray_pistol_aim',8)]:
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/characters'/(asset+'.glb')));temp=set(bpy.data.objects)-before;other=next(o for o in temp if o.type=='ARMATURE');rig.animation_data_create();rig.animation_data.action=other.animation_data.action;rig.animation_data.action_slot=other.animation_data.action_slot
 for o in temp:bpy.data.objects.remove(o,do_unlink=True)
 scene.frame_set(frame);bpy.context.view_layer.update();scene.render.filepath=str(OUT/'previews'/(label+'_hero.png'));bpy.ops.render.render(write_still=True)
print('RIGGED_MESHY',json.dumps(report))
