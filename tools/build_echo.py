"""Astra authored asset. Rebuild: blender -b --factory-startup -t 6 --python tools/build_echo.py"""
from pathlib import Path
import bpy, math, json, numpy as np
from mathutils import Vector
R=Path(__file__).resolve().parents[1];ID='echo';TITLE='Echo';REF='gun_sidearm_uncommon_echo';LENGTH=0.32
SRC=R/('assets/source/blender/'+ID);OUT=R/('assets/models/gear/guns/'+ID);PRE=SRC/'previews'
for p in (SRC,OUT,PRE):p.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.unit_settings.system='METRIC';parts=[];groups={}
def empty(n,parent=None):
 o=bpy.data.objects.new(n,None);scene.collection.objects.link(o);o.parent=parent;return o
root=empty(TITLE+'_GripOrigin');root['forward']='Godot -Z';root['reference']='meshy_views_v2/'+REF
for n in ('Receiver','Slide','Grip','Trigger','Muzzle','Controls','Core'):groups[n]=empty(n,root)
def material(name,color,metal,rough,paint=False,cloth=False,cracked=False):
 m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');N=1024;rng=np.random.default_rng(sum(map(ord,name)));yy,xx=np.mgrid[:N,:N];f=np.fft.fftfreq(N);fy,fx=np.meshgrid(f,f)
 def noise(rad):
  a=np.fft.ifft2(np.fft.fft2(rng.normal(size=(N,N)))*np.exp(-(fx*fx+fy*fy)*rad*rad)).real;return a/a.std()
 broad=noise(130);medium=noise(24);fine=noise(4);grain=rng.normal(0,1,(N,N));edge=np.minimum.reduce([xx,yy,N-1-xx,N-1-yy])/N
 wear=np.clip(( .009+medium*.004+broad*.003-edge)*35,0,1) if paint else np.clip((medium+broad*.3-1.4)*.08,0,.6)
 pits=np.clip((fine-2)*.7,0,1);scratches=np.zeros((N,N))
 for k in range(170):
  x,y=rng.integers(0,N,2);l=int(rng.integers(4,65));angle=rng.normal(.3,.8)
  for t in range(l):scratches[int(y+t*math.sin(angle))%N,int(x+t*math.cos(angle))%N]=rng.uniform(.2,.9)
 variation=1+broad*.012+medium*.008+fine*.006+grain*.004
 rgb=np.array(color)[None,None,:]*variation[:,:,None]
 roughness=np.clip(rough+broad*.018+medium*.016+pits*.03,0,1);metalness=np.full((N,N),metal)
 height=fine*.00008+medium*.00006-pits*.0003
 if paint:
  wear=np.maximum(wear,np.clip((medium-2.7)*.5,0,1)*np.clip((fine+.8),0,1));wear=np.maximum(wear,scratches*.25)
  rgb=rgb*(1-wear[:,:,None])+np.array((.055,.06,.058))[None,None,:]*(1+fine[:,:,None]*.15)*wear[:,:,None]
  metalness=metalness*(1-wear)+.78*wear;roughness-=wear*.15;height-=wear*.007
 else:
  rgb*=1-wear[:,:,None]*.3;rgb+=scratches[:,:,None]*.025;height-=scratches*.002
 if cloth:
  weave=(np.sin(xx*math.pi)*.02+np.cos(xx*2.1)*np.cos(yy*2.1)*.06)
  rgb*=1+weave[:,:,None];height+=weave*.006;roughness+=.08
 if cracked:
  seeds=rng.uniform(0,N,(18,2));dist=np.stack([(xx-x)**2+(yy-y)**2 for x,y in seeds]);nearest=np.partition(dist,1,axis=0)[:2];cracks=np.clip(1-(np.sqrt(nearest[1])-np.sqrt(nearest[0]))/2.6,0,1)
  rgb*=1-cracks[:,:,None]*.82;height-=cracks*.009;roughness+=cracks*.15
 du=(np.roll(height,-1,1)-np.roll(height,1,1))*N*.12;dv=(np.roll(height,-1,0)-np.roll(height,1,0))*N*.12
 norm=np.stack((-du,-dv,np.ones_like(du)),2);norm/=np.linalg.norm(norm,axis=2)[:,:,None]
 def tex(suffix,data,non=False):
  im=bpy.data.images.new(name+'_'+suffix,width=N,height=N,alpha=False)
  if non:im.colorspace_settings.name='Non-Color'
  pix=np.ones((N,N,4),np.float32);pix[:,:,:3]=np.clip(data,0,1);im.pixels.foreach_set(pix.ravel());im.filepath_raw=str(OUT/(im.name+'.png'));im.file_format='PNG';im.save();im.pack();t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;return t
 t=tex('basecolor',rgb);m.node_tree.links.new(t.outputs['Color'],b.inputs['Base Color'])
 t=tex('orm',np.stack((np.ones_like(du),roughness,metalness),2),True);s=m.node_tree.nodes.new('ShaderNodeSeparateColor');m.node_tree.links.new(t.outputs['Color'],s.inputs['Color']);m.node_tree.links.new(s.outputs['Green'],b.inputs['Roughness']);m.node_tree.links.new(s.outputs['Blue'],b.inputs['Metallic'])
 t=tex('normal',norm*.5+.5,True);n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.22 if paint else .08;m.node_tree.links.new(t.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],b.inputs['Normal']);return m
paint=material(TITLE+'_IvoryCeramic',(.70,.69,.64),.12,.61,True,cracked=ID=='echo')
steel=material(TITLE+'_MidnightAlloy',(.042,.057,.102),.65,.48)
wrap=material(TITLE+'_GripRubber',(.025,.028,.032),.0,.84,cloth=True)
bare=material(TITLE+'_BrushedSteel',(.17,.18,.18),.8,.35)
blue=material(TITLE+'_CobaltEnamel',(.026,.065,.40),.35,.36,True)
glow=bpy.data.materials.new(TITLE+'_MintEmission');glow.use_nodes=True;b=glow.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(.04,.55,.39,1);b.inputs['Emission Color'].default_value=(.05,1,.64,1);b.inputs['Emission Strength'].default_value=4.0
S=.00036
def yz(p):return ((810-p[0])*S,(620-p[1])*S)
def finish(o,n,mat,g,bev=.0007):
 o.name=n;bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 uv=o.data.uv_layers.new(name='PBR_SurfaceUV')
 for f in o.data.polygons:
  axis=max(range(3),key=lambda j:abs(f.normal[j]));a,b=[(1,2),(0,2),(0,1)][axis];coords=[o.data.vertices[o.data.loops[i].vertex_index].co for i in f.loop_indices];amin=min(v[a] for v in coords);bmin=min(v[b] for v in coords);ar=max(v[a] for v in coords)-amin;br=max(v[b] for v in coords)-bmin
  for i,v in zip(f.loop_indices,coords):uv.data[i].uv=((v[a]-amin)/max(ar,1e-6),(v[b]-bmin)/max(br,1e-6))
 if bev:
  mod=o.modifiers.new('Editable edge chamfer','BEVEL');mod.width=bev;mod.segments=2;mod=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');mod.keep_sharp=True
 o.parent=groups[g];parts.append(o);return o
def profile(n,pts,w,mat=paint,g='Slide',x=0,bev=.0007):
 pts=[yz(p) for p in pts];vs=[(x+s*w/2,y,z) for s in (-1,1) for y,z in pts];l=len(pts);faces=[tuple(range(l-1,-1,-1)),tuple(range(l,2*l))]+[(i,(i+1)%l,(i+1)%l+l,i+l) for i in range(l)];me=bpy.data.meshes.new(n);me.from_pydata(vs,[],faces);me.update();o=bpy.data.objects.new(n,me);scene.collection.objects.link(o);return finish(o,n,mat,g,bev)
def box(n,p,w,h,d,mat=paint,g='Slide',x=0,bev=.0007):
 y,z=yz(p);bpy.ops.mesh.primitive_cube_add(size=1,location=(x,y,z));o=bpy.context.object;o.scale=(w,h*S,d*S);return finish(o,n,mat,g,bev)
def screw(n,p,x,mat=bare):
 y,z=yz(p);bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.0021,depth=.001,location=(x,y,z),rotation=(0,math.pi/2,0));finish(bpy.context.object,n,mat,'Controls',.0003)
 box(n+' screwdriver slot',p,.0004,5,1.2,steel,'Controls',x+math.copysign(.0007,x),.0001)
def ring(n,p,rad,inner,depth,mat=bare,g='Muzzle',x=0,axis='Y',verts=12):
 y,z=yz(p);vs=[]
 for d in (-depth/2,depth/2):
  for rr in (rad,inner):
   for j in range(verts):
    a=math.tau*j/verts
    vs.append((x+rr*math.cos(a),y+d,z+rr*math.sin(a)) if axis=='Y' else (x+d,y+rr*math.cos(a),z+rr*math.sin(a)))
 faces=[]
 for j in range(verts):
  k=(j+1)%verts
  faces.extend([(j,k,2*verts+k,2*verts+j),(verts+j,3*verts+j,3*verts+k,verts+k),(j,verts+j,verts+k,k),(2*verts+j,2*verts+k,3*verts+k,3*verts+j)])
 me=bpy.data.meshes.new(n);me.from_pydata(vs,[],faces);me.update();o=bpy.data.objects.new(n,me);scene.collection.objects.link(o);return finish(o,n,mat,g,.0003)
def rod(n,p,rad,depth,mat=bare,g='Controls',x=0,axis='X',verts=24):
 y,z=yz(p);bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=rad,depth=depth,location=(x,y,z),rotation=(0,math.pi/2,0) if axis=='X' else (math.pi/2,0,0));return finish(bpy.context.object,n,mat,g,.0005)
# Echo has no orthographic side: proportions inferred from supplied three-quarter,
# with narrow stacked muzzles from front and separated ivory armor from top.
profile('Twin channel receiver',[(154,313),(178,287),(518,256),(603,215),(727,213),(784,257),(804,414),(779,485),(695,513),(628,509),(600,524),(454,525),(414,563),(209,552),(158,520)],.058,steel,'Receiver',bev=.002)
profile('Raked grip core',[(631,488),(711,492),(760,550),(846,717),(829,756),(717,801),(664,784),(678,733),(612,565)],.043,steel,'Grip',bev=.0025)
# Broad layered ivory courses follow the broken shroud contours rather than boxes.
for side in (-1,1):
 profile('Front upper porcelain cap '+str(side),[(165,303),(248,298),(261,321),(251,391),(177,400),(157,382)],.006,paint,'Slide',side*.030,.0014)
 profile('Upper long porcelain course '+str(side),[(268,296),(380,278),(422,297),(412,353),(397,374),(279,385),(263,369)],.008,paint,'Slide',side*.032,.0015)
 profile('Swept upper shoulder '+str(side),[(399,274),(524,244),(566,224),(676,217),(685,230),(653,255),(644,283),(606,302),(583,329),(491,349),(435,337)],.010,paint,'Slide',side*.035,.002)
 profile('Forward lower porcelain '+str(side),[(159,434),(229,428),(251,445),(254,499),(238,527),(171,526),(154,503)],.007,paint,'Receiver',side*.031,.0015)
 profile('Lower broken shroud '+str(side),[(262,451),(320,454),(337,441),(423,442),(448,462),(422,491),(398,551),(358,563),(316,548),(258,527),(245,503)],.009,paint,'Receiver',side*.032,.0018)
 profile('Mid ivory bridge '+str(side),[(425,443),(505,443),(521,462),(509,479),(435,480)],.009,paint,'Receiver',side*.033)
 profile('Diagonal service buttress '+str(side),[(531,376),(574,354),(614,364),(648,414),(634,439),(583,486),(565,487),(525,446),(516,414)],.008,paint,'Receiver',side*.035,.0015)
 profile('Cobalt side seal frame '+str(side),[(409,376),(496,376),(513,391),(513,427),(495,441),(408,441),(393,426),(393,392)],.005,bare,'Receiver',side*.033,.001)
 profile('Cobalt side seal '+str(side),[(415,385),(491,385),(503,395),(503,422),(491,433),(415,433),(404,422),(404,397)],.002,blue,'Receiver',side*.037,.001)
 for p in [(417,394),(492,394),(417,424),(492,424)]:screw('Seal screw '+str(side)+str(p),p,side*.039)
 profile('Grip upper porcelain '+str(side),[(660,564),(705,542),(750,595),(742,639),(722,650),(682,609)],.006,paint,'Grip',side*.024,.0014)
 profile('Grip middle porcelain '+str(side),[(730,651),(750,627),(786,653),(809,703),(789,736),(744,711)],.006,paint,'Grip',side*.024,.0014)
 profile('Grip heel porcelain '+str(side),[(703,734),(730,716),(752,737),(789,739),(800,724),(824,726),(827,750),(724,792),(687,783),(686,765)],.006,paint,'Grip',side*.024,.001)
 profile('Grip collar porcelain '+str(side),[(621,534),(649,514),(675,544),(661,562),(636,573),(617,561)],.006,paint,'Grip',side*.024,.001)
 for i in range(5):profile('Grip embossed groove '+str(side)+str(i),[(633+i*10,596+i*23),(661+i*10,586+i*23),(665+i*10,594+i*23),(637+i*10,605+i*23)],.001,bare,'Grip',side*.022,.0002)
 for i in range(5):box('Central vent '+str(side)+str(i),(270+i*21,412),.003,15,22,bare,'Receiver',side*.031)
profile('Open armored trigger loop',[(442,496),(462,508),(448,533),(439,563),(450,588),(468,599),(550,594),(590,574),(606,547),(597,517),(620,511),(633,548),(615,590),(559,614),(453,623),(425,604),(414,571),(420,530)],.024,steel,'Receiver',bev=.0013)
profile('Trigger polished hook',[(552,510),(571,511),(580,537),(574,562),(561,581),(545,585),(556,564),(561,541)],.009,bare,'Trigger',bev=.001)
# Over-under hollow muzzles, reinforced segmented ivory collars.
for i,z in enumerate((353,476)):
 ring('Barrel outer ceramic '+str(i),(155,z),.024,.019,.025,paint)
 ring('Octagonal muzzle steel '+str(i),(125,z),.019,.013,.008,bare)
 ring('Dark recessed muzzle '+str(i),(127,z),.013,.009,.017,steel)
 rod('Deep bore '+str(i),(155,z),.009,.001,wrap,'Muzzle',axis='Y')
 if i==1:ring('Lower muzzle luminous channel',(141,z),.025,.024,.004,glow,'Core',verts=48)
# Distinctive paired lateral capacitor drums on both cheeks.
for side in (-1,1):
 for i,z in enumerate((300,443)):
  rod('Capacitor midnight housing '+str(side)+str(i),(726,z),.029,.025,steel,'Receiver',side*.035)
  ring('Capacitor porcelain band '+str(side)+str(i),(726,z),.0295,.027,.010,paint,'Receiver',side*.035,'X',24)
  rod('Capacitor face '+str(side)+str(i),(726,z),.026,.004,steel,'Receiver',side*.050)
  ring('Mint capacitor perimeter '+str(side)+str(i),(726,z),.022,.0205,.0012,glow,'Core',side*.0525,'X',64)
  ring('Mint capacitor inner orbit '+str(side)+str(i),(726,z),.0175,.0167,.0012,glow,'Core',side*.0527,'X',64)
  rod('Capacitor dark glass '+str(side)+str(i),(726,z),.0158,.001,steel,'Receiver',side*.052)
  for a in range(8):
   px=726+math.cos(a*math.tau/8)*76;pz=z+math.sin(a*math.tau/8)*76
   screw('Capacitor locking stud '+str(side)+str(i)+str(a),(px,pz),side*.047, bare)
# Top shroud split reveals structural spine, matching the top view.
for i in range(7):box('Top spine transverse brace '+str(i),(270+i*55,278-i*5),.015,21,12,steel,'Slide',bev=.0004)
# Full thickness porcelain crown meets the side courses without floating plates.
profile('Upper front crown',[(165,303),(248,298),(261,321),(251,391),(177,400),(157,382)],.060,paint,'Slide',bev=.0014)
profile('Upper mid crown',[(268,296),(380,278),(422,297),(412,353),(397,374),(279,385),(263,369)],.061,paint,'Slide',bev=.0015)
profile('Swept crown',[(399,274),(524,244),(566,224),(676,217),(685,230),(653,255),(644,283),(606,302),(583,329),(491,349),(435,337)],.066,paint,'Slide',bev=.002)
# Normalize editable geometry, leaving the hand origin and Godot -Z forward consistent.
bpy.context.view_layer.update();coords=[o.matrix_world@Vector(c) for o in parts for c in o.bound_box];factor=LENGTH/(max(v.y for v in coords)-min(v.y for v in coords))
for o in parts:
 o.location*=factor
 for v in o.data.vertices:v.co*=factor
 for mod in o.modifiers:
  if mod.type=='BEVEL':mod.width*=factor
root['length_m']=LENGTH
# Recoil is an authored transform clip on the upper assembly; energy core has a breathing clip.
scene.render.fps=30;scene.frame_start=1;scene.frame_end=60
slide=groups['Slide']
for f,y in [(1,0),(3,-.008),(7,0)]:slide.location.y=y;slide.keyframe_insert('location',frame=f)
slide.animation_data.action.name='Fire_Recoil'
if ID=='echo':
 core=groups['Core']
 for f,s in [(1,1),(30,1.035),(60,1)]:core.scale=(s,s,s);core.keyframe_insert('scale',frame=f)
 core.animation_data.action.name='Core_Idle_Pulse'
scene.frame_set(1)
# Runtime meshes are joined per assembly; originals retain parts and bevel modifiers.
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();export=[];tri=0
for name,parent in groups.items():
 copies=[]
 for original in parts:
  if original.parent!=parent:continue
  me=bpy.data.meshes.new_from_object(original.evaluated_get(dg));me.calc_loop_triangles();tri+=len(me.loop_triangles);o=bpy.data.objects.new(original.name+'_runtime',me);scene.collection.objects.link(o);o.matrix_world=original.matrix_world.copy();copies.append(o)
 if not copies:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in copies:o.select_set(True)
 bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();o=bpy.context.object;o.name=name+'_Mesh';o.parent=parent;export.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in [root,*groups.values(),*export]:o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(OUT/(ID+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_extras=True,export_animations=True)
for o in export:bpy.data.objects.remove(o,do_unlink=True)
coords=[o.matrix_world@Vector(c) for o in parts for c in o.bound_box];mins=[min(v[i] for v in coords) for i in range(3)];maxs=[max(v[i] for v in coords) for i in range(3)]
stats={'length_m':LENGTH,'triangles':tri,'editable_mesh_parts':len(parts),'assemblies':list(groups),'materials':5+int(ID=='echo'),'textures':'Five sets of 1024px base color, ORM, tangent normal','emissive':ID=='echo','animations':['Fire_Recoil']+(['Core_Idle_Pulse'] if ID=='echo' else []),'forward':'Godot -Z','origin':'grip center','blender_bounds_min':mins,'blender_bounds_max':maxs,'reference':'meshy_views_v2/'+REF,'limitations':'Reference-guided interpretation. Per-face overlapping UVs. No collision or gameplay hookup.'}
(OUT/(ID+'_stats.json')).write_text(json.dumps(stats,indent=2))
(SRC/'README.md').write_text('# '+TITLE+'\n\nAstra-authored editable Blender asset reconstructed from `assets/source/concepts/gear/meshy_views_v2/'+REF+'`. Original concept informs material colors only.\n\nRebuild with `blender -b --factory-startup -t 6 --python tools/build_'+ID+'.py`. Runtime export: `assets/models/gear/guns/'+ID+'/'+ID+'.glb`. Blender +Y is Godot -Z, with grip-center origin. Separate assemblies preserve recoil and core transforms.\n\nFive packed 1024px PBR material sets; '+('mint emissive rings and Core_Idle_Pulse animation; ' if ID=='echo' else 'non-emissive enamel and rubber; ')+'Fire_Recoil transform clip. No gameplay stats are encoded here. Art measurements are in the adjacent export stats JSON.\n\nFour studio renders in previews: hero, side, top, front. This is a geometric interpretation, with surfaces traced/inferred from the provided views, not a photogrammetric scan.\n')
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.065,.08,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.view_settings.view_transform='AgX'
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
centre=Vector([(a+b)/2 for a,b in zip(mins,maxs)])
for name,loc,power,col,size in [('Key',(.5,.7,.8),35,(1,.95,.86),.6),('Rim',(-.5,-.4,.4),42,(.7,.8,1),.5),('Fill',(.5,-.3,.1),15,(1,1,1),.5)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=col;d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;aim(o,centre)
bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='ReviewCamera';cam.data.type='ORTHO';scene.camera=cam
for name,offset,scale in [('hero',(-.65,.6,.30),LENGTH*1.35),('side',(-.8,0,0),LENGTH*1.15),('top',(0,0,.8),LENGTH*1.15),('front',(0,.8,0),LENGTH*.95)]:
 cam.location=centre+Vector(offset);aim(cam,centre);cam.data.ortho_scale=scale;scene.render.filepath=str(PRE/(name+'.png'))
 if name=='hero':bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(ID+'.blend')))
 bpy.ops.render.render(write_still=True)
print(ID.upper()+'_COMPLETE',tri,len(parts),flush=True)

# Avoid PulseAudio shutdown hanging Blender in this headless environment.
import os
os._exit(0)
