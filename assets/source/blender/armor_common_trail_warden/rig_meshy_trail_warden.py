"""Rig the approved Meshy 7 character; no replacement/design geometry generated."""
import bpy,bmesh,json,math
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
P=Path('/home/tj/Documents/GodotProjects/Starforge');O=P/'assets/source/blender/armor_common_trail_warden';O.mkdir(exist_ok=True);(O/'previews').mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(P/'assets/models/characters/exo_gray_bind.glb'));arm=next(o for o in bpy.data.objects if o.type=='ARMATURE');arm.animation_data_clear();arm.data.pose_position='REST'
reference=bpy.data.objects['Exo_Suit'];reference.data.calc_loop_triangles();triangles=[tuple(t.vertices) for t in reference.data.loop_triangles];verts=[reference.matrix_world@v.co for v in reference.data.vertices];bvh=BVHTree.FromPolygons(verts,triangles,all_triangles=True)
source_weights=[{reference.vertex_groups[g.group].name:g.weight for g in v.groups} for v in reference.data.vertices]
original_objects=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(P/'assets/source/meshy/armor_common_trail_warden/armor_common_trail_warden.glb'));body=next(o for o in set(bpy.data.objects)-original_objects if o.type=='MESH');body.name='Trail_Warden_Meshy7_Skinned'
minimum=min(v.co.z for v in body.data.vertices)
# Fit the existing T-pose to the established player landmarks; never change the skeleton.
for v in body.data.vertices:
 x,y,z=v.co;z-=minimum
 v.co.x=float(np.interp(abs(x),[0,.19,.46,.70,.911],[0,.192,.478,.767,1.015]))*(1 if x>=0 else -1)
 v.co.z=float(np.interp(z,[0,.53,.99,1.42,1.63,1.89747],[-.017,.522,.988,1.488,1.64,1.90]))
 arm_factor=min(1,max(0,(abs(x)-.18)/.25));v.co.y=y+float(np.interp(z,[0,.9,1.42,1.897],[.005,.005,.018,.018]))+arm_factor*.04
# Decimation keeps UV coordinates and material textures; raw 59,654-triangle source is untouched.
bpy.context.view_layer.objects.active=body;body.select_set(True)
dec=body.modifiers.new('Game mesh 36k budget','DECIMATE');dec.ratio=.60;dec.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=dec.name)
bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS');bm.to_mesh(body.data);bm.free()
# Barycentric transfer of proven original skin weights, then rigid helmet and shoulder corrections.
for b in arm.data.bones:body.vertex_groups.new(name=b.name)
distances=[]
for v in body.data.vertices:
 co=body.matrix_world@v.co;pos,normal,idx,distance=bvh.find_nearest(co);distances.append(distance)
 a,b,c=[verts[i] for i in triangles[idx]];e0=b-a;e1=c-a;e2=pos-a;d00=e0.dot(e0);d01=e0.dot(e1);d11=e1.dot(e1);d20=e2.dot(e0);d21=e2.dot(e1);den=d00*d11-d01*d01
 bv=(d11*d20-d01*d21)/den if abs(den)>1e-15 else 0;cv=(d00*d21-d01*d20)/den if abs(den)>1e-15 else 0;bc=[max(0,1-bv-cv),max(0,bv),max(0,cv)];weights={}
 for vid,w in zip(triangles[idx],bc):
  for bone,value in source_weights[vid].items():weights[bone]=weights.get(bone,0)+value*w
 # The full generated head, helmet, and cheek guards move as one head volume.
 if co.z>1.605:weights={'mixamorig:Head':1}
 # Belt pouches should not stretch with the thighs.
 elif .963<co.z<1.09 and abs(co.x)<.225:weights={'mixamorig:Hips':1}
 # Generated finger topology has webbing: shared finger flex avoids divergent tears.
 combined={}
 for name,w in weights.items():
  for finger in ['Index','Ring','Pinky']:name=name.replace('Hand'+finger,'HandMiddle')
  combined[name]=combined.get(name,0)+w
 weights=combined
 # Keep each side of the split thigh garment attached to its owning thigh.
 if .57<co.z<.84:
  weights={'mixamorig:'+('Left' if co.x>=0 else 'Right')+'UpLeg':1}
 weights=dict(sorted(weights.items(),key=lambda kv:kv[1],reverse=True)[:4]);total=sum(weights.values())
 for name,w in weights.items():
  if w>1e-6:body.vertex_groups[name].add([v.index],w/total,'REPLACE')
mod=body.modifiers.new('Existing Exo Gray animation skeleton','ARMATURE');mod.object=arm;mod.use_deform_preserve_volume=False
body.parent=arm;body.matrix_parent_inverse=arm.matrix_world.inverted()
for o in original_objects:
 if o!=arm:bpy.data.objects.remove(o,do_unlink=True)
# Open the fused rear-drape seam where generated faces bridge independently moving thighs.
# Detect only posterior cloth faces that become long membrane bridges in the real run cycle.
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(P/'assets/models/characters/exo_gray_run.glb'));temp=set(bpy.data.objects)-before;run_rig=next(o for o in temp if o.type=='ARMATURE');arm.animation_data_create();arm.animation_data.action=run_rig.animation_data.action;arm.animation_data.action_slot=run_rig.animation_data.action_slot
for obj in temp:bpy.data.objects.remove(obj,do_unlink=True)
arm.data.pose_position='POSE';bridge_faces=set()
for frame in [1,6,12,18]:
 bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get());posed=evaluated.data.vertices
 for poly in body.data.polygons:
  ids=list(poly.vertices);rest=[body.data.vertices[i].co for i in ids];center=sum(rest,Vector())/len(rest)
  if not (.48<center.z<.84 and abs(center.x)<.18):continue
  if min(v.x for v in rest)<0<max(v.x for v in rest):bridge_faces.add(poly.index);continue
  owners=set()
  for vi in ids:
   lr=[sum(g.weight for g in body.data.vertices[vi].groups if label in body.vertex_groups[g.group].name) for label in ['Left','Right']]
   if max(lr)>.45:owners.add(lr.index(max(lr)))
  if len(owners)<2:continue
  for j in range(len(ids)):
   a,b=ids[j],ids[(j+1)%len(ids)];old=(body.data.vertices[a].co-body.data.vertices[b].co).length;new=(posed[a].co-posed[b].co).length
   if new>.045 and new>old*1.7:bridge_faces.add(poly.index);break
arm.animation_data_clear()
for bone in arm.pose.bones:bone.matrix_basis.identity()
bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
bm=bmesh.new();bm.from_mesh(body.data);bm.faces.ensure_lookup_table();bmesh.ops.delete(bm,geom=[bm.faces[i] for i in bridge_faces],context='FACES');bm.to_mesh(body.data);bm.free()
print('DETACHED_REAR_DRAPE_BRIDGE_FACES',len(bridge_faces))
for im in bpy.data.images:
 if im.size[0]>0:
  try:im.pack()
  except:pass
for p in body.data.polygons:p.use_smooth=True
arm.data.pose_position='POSE'
for b in arm.pose.bones:b.matrix_basis.identity()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.world.color=(.28,.28,.28)
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
for loc,power,size in [((2,-3,3.8),500,4),((-2,-2,2.6),280,3),((1,2,3.2),450,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;aim(o,(0,0,1))
bpy.ops.object.camera_add(location=(2.8,-4,2.1));cam=bpy.context.object;cam.name='Review Camera';cam.data.type='ORTHO';cam.data.ortho_scale=2.35;aim(cam,(0,0,.95));scene.camera=cam
bpy.ops.wm.save_as_mainfile(filepath=str(O/'trail_warden_meshy_rigged.blend'))
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);arm.select_set(True);bpy.context.view_layer.objects.active=arm
bpy.ops.export_scene.gltf(filepath=str(O/'trail_warden_meshy_rigged.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=True)
report={'source':'Meshy 7 generated armor_common_trail_warden.glb','raw_triangles':59654,'rigged_triangles':sum(len(p.vertices)-2 for p in body.data.polygons),'vertices':len(body.data.vertices),'bones':len(arm.data.bones),'mesh_objects':1,'max_influences':max(len(v.groups) for v in body.data.vertices),'unweighted_vertices':sum(not v.groups for v in body.data.vertices),'transfer_distance_max':max(distances),'transfer_distance_mean':sum(distances)/len(distances),'weight_sum_max_error':max(abs(sum(g.weight for g in v.groups)-1) for v in body.data.vertices),'uv_layers':len(body.data.uv_layers),'materials':len(body.data.materials),'rear_drape_bridge_faces_removed':len(bridge_faces),'status':'rigged, animation validation follows'}
(O/'validation.json').write_text(json.dumps(report,indent=2))
for name,loc in [('bind_front',(0,-4,1.4)),('bind_hero',(2.8,-4,2.1))]:
 cam.location=loc;aim(cam,(0,0,.95));scene.render.filepath=str(O/'previews'/f'{name}.png');bpy.ops.render.render(write_still=True)
print('RIG_REPORT',report)
