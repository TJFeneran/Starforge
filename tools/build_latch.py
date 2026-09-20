"""Astra authored asset. Rebuild: blender -b --factory-startup -t 6 --python tools/build_latch.py"""
from pathlib import Path
import bpy, math, json, numpy as np
from mathutils import Vector
R=Path(__file__).resolve().parents[1];ID='latch';TITLE='Latch';REF='gun_sidearm_common_latch';LENGTH=0.34
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
# Trace the orthographic side silhouette and stack the widths shown in top/front.
profile('Receiver steel skeleton',[(60,373),(92,347),(843,346),(882,369),(888,394),(940,394),(941,432),(906,453),(880,480),(875,515),(802,563),(759,558),(731,506),(604,506),(580,605),(107,605),(59,570)],.056,steel,'Receiver',bev=.002)
profile('Front armored collar',[(49,378),(83,345),(184,345),(210,382),(210,450),(188,471),(144,470),(122,493),(113,598),(82,590),(51,552)],.067,steel,'Slide',bev=.002)
profile('Ivory barrel shroud',[(195,338),(352,338),(387,377),(449,391),(402,460),(250,460),(227,442),(208,450),(209,385),(182,356)],.062,paint,'Slide',bev=.0013)
profile('Top stepped rail',[(366,338),(499,338),(520,357),(520,382),(390,374),(355,348)],.043,steel,'Slide')
profile('Ivory lower frame',[(122,500),(164,485),(191,485),(218,450),(244,450),(261,468),(402,468),(449,397),(546,397),(564,417),(704,412),(737,379),(817,379),(834,397),(832,437),(785,461),(730,461),(710,490),(480,516),(453,497),(435,483),(289,483),(247,526),(209,557),(208,604),(120,604)],.060,paint,'Receiver',bev=.0017)
profile('Underbarrel midnight rail',[(218,556),(254,522),(396,522),(441,559),(575,559),(575,609),(557,620),(419,617),(381,573),(270,573),(244,605),(211,605)],.055,steel,'Receiver',bev=.001)
profile('Grip skeleton',[(792,466),(866,463),(885,498),(983,659),(996,693),(985,715),(887,750),(818,751),(801,735),(806,708),(748,580),(753,547)],.043,bare,'Grip',bev=.0025)
for side in (-1,1):
 profile('Cobalt removable service plate '+str(side),[(500,421),(707,421),(730,445),(729,481),(708,499),(639,499),(611,531),(496,531),(482,516),(482,439)],.004,blue,'Slide',side*.032,.001)
 profile('Plate diagonal relief '+str(side),[(521,518),(561,474),(570,473),(532,519)],.0006,steel,'Slide',side*.0345,.00015)
 profile('Grip textured inset '+str(side),[(812,519),(849,519),(880,550),(953,650),(955,682),(877,708),(847,699),(786,574)],.0035,wrap,'Grip',side*.024,.001)
 profile('Grip spine cladding '+str(side),[(750,583),(781,573),(838,703),(829,716),(806,708)],.004,steel,'Grip',side*.024,.001)
 profile('Magazine heel blue plate '+str(side),[(846,716),(970,680),(978,704),(863,745),(839,741)],.005,steel,'Grip',side*.023,.001)
 for p in [(172,370),(516,455),(699,454),(508,510),(802,396),(193,574)]:screw('Flush screw '+str(side)+str(p),p,side*.035)
 for i in range(4):box('Underbarrel heat fin '+str(side)+str(i),(316+i*27,501),.003,16,18,bare,'Receiver',side*.027)
profile('Open trigger guard',[(578,502),(603,507),(617,535),(613,575),(632,585),(695,585),(734,552),(735,517),(718,504),(739,499),(760,520),(757,562),(708,606),(610,607),(598,591),(603,535)],.022,bare,'Receiver',bev=.001)
profile('Curved trigger',[(674,501),(694,503),(697,528),(691,555),(680,575),(667,576),(675,554),(678,532)],.009,bare,'Trigger')
# Raised mechanical latch bridges the slide, with a blue central clamp.
profile('Latch upright left',[(512,229),(529,211),(565,212),(584,232),(586,273),(581,326),(530,326),(512,308)],.062,steel,'Controls',bev=.002)
profile('Latch rear riser',[(583,245),(663,245),(697,275),(734,276),(740,331),(692,331),(681,309),(590,309)],.047,steel,'Controls',bev=.0014)
box('Cobalt latch lever',(625,315),.047,57,90,blue,'Controls',bev=.003)
profile('Lever retaining shoe',[(561,323),(592,323),(593,363),(651,363),(653,322),(683,322),(685,393),(670,405),(574,404),(559,387)],.061,bare,'Controls',bev=.0015)
for s in (-1,1):
 rod('Latch forward pivot '+str(s),(542,245),.008,.003,bare,x=s*.034)
 rod('Latch rear pivot '+str(s),(715,302),.008,.003,bare,x=s*.027)
 rod('Latch pivot inset '+str(s),(542,245),.0045,.001,steel,x=s*.036)
 rod('Latch pivot inset rear '+str(s),(715,302),.0045,.001,steel,x=s*.029)
box('Front sight',(133,337),.017,65,20,bare,'Slide')
box('Rear sight',(831,340),.023,79,23,bare,'Slide')
o=ring('Ivory elongated front collar',(35,470),.033,.028,.004,paint)
for v in o.data.vertices:v.co.z=yz((35,470))[1]+(v.co.z-yz((35,470))[1])*1.40
ring('Octagonal muzzle crown',(32,470),.030,.022,.012,bare)
ring('Octagonal recessed bore',(28,470),.022,.012,.006,steel)
ring('Inner steel liner',(30,470),.014,.010,.014,bare)
rod('Bore shadow',(65,470),.010,.001,wrap,'Muzzle',axis='Y')
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
