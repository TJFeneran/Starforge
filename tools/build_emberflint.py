"""Emberflint: authored from the three meshy_views_v2 orthographic images.
blender -b --factory-startup -t 8 --python tools/build_emberflint.py
"""
from pathlib import Path
import bpy, math, json, numpy as np
from mathutils import Vector
R=Path(__file__).resolve().parents[1];SRC=R/'assets/source/blender/emberflint';OUT=R/'assets/models/gear/guns/emberflint';PRE=SRC/'previews'
for p in (SRC,OUT,PRE):p.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.unit_settings.system='METRIC';parts=[];groups={}
def empty(n,parent=None):
 o=bpy.data.objects.new(n,None);scene.collection.objects.link(o);o.parent=parent;return o
root=empty('Emberflint_GripOrigin');root['forward']='Godot -Z';root['reference']='meshy_views_v2/gun_sidearm_starter_emberflint';root['glow']=False
for n in ('Receiver','Slide','Grip','Trigger','Muzzle','Controls'):groups[n]=empty(n,root)
def material(name,color,metal,rough,paint=False,cloth=False):
 m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');N=1024;rng=np.random.default_rng(sum(map(ord,name)));yy,xx=np.mgrid[:N,:N];f=np.fft.fftfreq(N);fy,fx=np.meshgrid(f,f)
 def noise(rad):
  a=np.fft.ifft2(np.fft.fft2(rng.normal(size=(N,N)))*np.exp(-(fx*fx+fy*fy)*rad*rad)).real;return a/a.std()
 broad=noise(130);medium=noise(24);fine=noise(4);grain=rng.normal(0,1,(N,N));edge=np.minimum.reduce([xx,yy,N-1-xx,N-1-yy])/N
 wear=np.clip((.032+medium*.022+broad*.015-edge)*35,0,1) if paint else np.clip((medium+broad*.3-1.4)*.3,0,.6)
 pits=np.clip((fine-2)*.7,0,1);scratches=np.zeros((N,N))
 for k in range(170):
  x,y=rng.integers(0,N,2);l=int(rng.integers(4,65));angle=rng.normal(.3,.8)
  for t in range(l):scratches[int(y+t*math.sin(angle))%N,int(x+t*math.cos(angle))%N]=rng.uniform(.2,.9)
 variation=1+broad*.045+medium*.035+fine*.025+grain*.008
 rgb=np.array(color)[None,None,:]*variation[:,:,None]
 roughness=np.clip(rough+broad*.04+medium*.04+pits*.1,0,1);metalness=np.full((N,N),metal)
 height=fine*.00025+medium*.0002-pits*.001
 if paint:
  wear=np.maximum(wear,np.clip((medium-1.95)*1.6,0,1)*np.clip((fine+.8),0,1));wear=np.maximum(wear,scratches*.8)
  rgb=rgb*(1-wear[:,:,None])+np.array((.055,.06,.058))[None,None,:]*(1+fine[:,:,None]*.15)*wear[:,:,None]
  metalness=metalness*(1-wear)+.78*wear;roughness-=wear*.15;height-=wear*.007
 else:
  rgb*=1-wear[:,:,None]*.3;rgb+=scratches[:,:,None]*.025;height-=scratches*.002
 if cloth:
  weave=(np.sin(xx*math.pi)*.02+np.cos(xx*2.1)*np.cos(yy*2.1)*.06)
  rgb*=1+weave[:,:,None];height+=weave*.006;roughness+=.08
 du=(np.roll(height,-1,1)-np.roll(height,1,1))*N*.12;dv=(np.roll(height,-1,0)-np.roll(height,1,0))*N*.12
 norm=np.stack((-du,-dv,np.ones_like(du)),2);norm/=np.linalg.norm(norm,axis=2)[:,:,None]
 def tex(suffix,data,non=False):
  im=bpy.data.images.new(name+'_'+suffix,width=N,height=N,alpha=False)
  if non:im.colorspace_settings.name='Non-Color'
  pix=np.ones((N,N,4),np.float32);pix[:,:,:3]=np.clip(data,0,1);im.pixels.foreach_set(pix.ravel());im.filepath_raw=str(OUT/(im.name+'.png'));im.file_format='PNG';im.save();im.pack();t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;return t
 t=tex('basecolor',rgb);m.node_tree.links.new(t.outputs['Color'],b.inputs['Base Color'])
 t=tex('orm',np.stack((np.ones_like(du),roughness,metalness),2),True);s=m.node_tree.nodes.new('ShaderNodeSeparateColor');m.node_tree.links.new(t.outputs['Color'],s.inputs['Color']);m.node_tree.links.new(s.outputs['Green'],b.inputs['Roughness']);m.node_tree.links.new(s.outputs['Blue'],b.inputs['Metallic'])
 t=tex('normal',norm*.5+.5,True);n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.5 if paint else .16;m.node_tree.links.new(t.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],b.inputs['Normal']);return m
paint=material('Chipped_Pale_Ceramic_Paint',(.63,.625,.575),.15,.66,True)
steel=material('Oxidized_Charcoal_Steel',(.072,.08,.075),.72,.52)
wrap=material('Frayed_Charcoal_Grip_Wrap',(.035,.041,.037),.0,.88,cloth=True)
bare=material('Exposed_Worn_Steel',(.20,.22,.205),.8,.4)
S=.00036
def yz(p):return ((780-p[0])*S,(550-p[1])*S)
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
# Side silhouette traced in source pixel coordinates; cross sections from top/front.
profile('Forged frame',[(112,354),(885,354),(907,366),(912,407),(878,415),(852,439),(846,463),(858,498),(680,525),(651,502),(639,425),(470,424),(460,475),(120,471)],.037,steel,'Receiver',bev=.0018)
profile('Grip core',[(677,466),(847,460),(870,530),(918,665),(912,701),(892,713),(738,711),(720,675)],.033,wrap,'Grip',bev=.003)
# Upper main frame is below separate armor courses.
profile('Slide chassis',[(115,289),(865,289),(880,308),(888,360),(116,360)],.040,steel)
profile('Forward upper casing',[(119,281),(258,281),(258,364),(113,364),(112,307)],.047)
profile('Second upper casing',[(264,276),(443,276),(444,330),(407,332),(407,358),(326,356),(295,333),(277,346),(262,342)],.046)
box('Recessed central barrel cover',(519,306),.039,140,48)
profile('Rear upper stepped casing',[(595,276),(704,276),(723,358),(567,363),(561,400),(418,400),(412,383),(412,337),(589,337)],.044)
profile('Rear slide serration backing',[(711,285),(866,285),(878,301),(891,359),(733,359)],.043,steel)
profile('Rear slide upper plate',[(710,278),(870,278),(879,305),(730,305)],.046)
profile('Rear slide end plate',[(827,303),(881,300),(894,360),(850,360)],.046)
for side in (-1,1):
 for i in range(6):
  px=731+i*18
  profile('Angled slide serration %s %02d'%(side,i),[(px,307),(px+11,307),(px+25,360),(px+13,360)],.003,paint,'Slide',side*.023,.0003)
 profile('Forward lower cheek '+str(side),[(117,371),(269,371),(268,426),(254,435),(116,433)],.004,paint,'Receiver',side*.024)
 profile('Lower receiver service plate '+str(side),[(282,367),(299,358),(399,361),(412,373),(413,445),(280,447)],.004,paint,'Receiver',side*.023)
 profile('Underbarrel armor '+str(side),[(290,452),(422,451),(423,414),(467,414),(467,481),(291,481)],.0035,paint,'Receiver',side*.02)
 profile('Slide release paddle '+str(side),[(679,374),(751,373),(746,391),(680,391)],.004,bare,'Controls',side*.024)
 box('Release paddle inset '+str(side),(714,382),.001,52,5,steel,'Controls',side*.027,.0002)
 for p,depth in [((171,352),.024),((305,384),.0255),((319,426),.0255),((637,294),.0225),((682,488),.019),((843,289),.0235)]:screw('Flush fastener '+str(side)+' '+str(p),p,side*depth)
# Open guard, with a genuinely empty finger opening.
profile('Open trigger guard',[(468,410),(485,410),(481,489),(491,500),(612,501),(639,491),(654,478),(648,444),(634,414),(648,414),(666,450),(670,483),(656,502),(620,516),(461,516),(456,499)],.019,steel,'Receiver',bev=.0013)
profile('Curved trigger',[(567,412),(595,412),(602,435),(594,463),(579,490),(564,492),(573,470),(578,447),(575,428)],.008,bare,'Trigger',bev=.001)
# Fitted overlapping fabric/leather strips: raked grip cross sections.
# Each loop slopes around grip, its edges break up the dark silhouette.
for i in range(7):
 zpix=497+i*29;v=[];segments=24
 for row in (0,1):
  for j in range(segments):
   a=j*math.tau/segments;zp=zpix+row*25+math.sin(a)*11;centre=772+(zp-500)*.31;half=104
   x=.023*math.copysign(abs(math.cos(a))**.16,math.cos(a));px=centre+half*math.copysign(abs(math.sin(a))**.16,math.sin(a));y,z=yz((px,zp));v.append((x,y,z))
 faces=[(j,(j+1)%segments,(j+1)%segments+segments,j+segments) for j in range(segments)];me=bpy.data.meshes.new('Wrap');me.from_pydata(v,[],faces);me.update();o=bpy.data.objects.new('Overlapping grip wrap %02d'%i,me);scene.collection.objects.link(o);finish(o,o.name,wrap,'Grip',0)
 # narrow rolled seam follows the lower edge
 for j in range(segments):
  a=Vector(v[segments+j]);b=Vector(v[segments+(j+1)%segments]);mid=(a+b)/2;bpy.ops.mesh.primitive_cylinder_add(vertices=5,radius=.00028,depth=(b-a).length,location=mid);o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();finish(o,'Frayed wrap edge %02d %02d'%(i,j),bare if j%7==0 else wrap,'Grip',0)
profile('Magazine heel plate',[(733,708),(870,705),(873,718),(727,721),(723,715)],.043,steel,'Grip',bev=.001)
profile('Magazine latch',[(768,694),(864,693),(870,713),(767,714)],.046,bare,'Grip',bev=.0007)
# Square open muzzle: layered four-wall aperture, never a filled cylinder.
def square_ring(n,py,cx,cz,outer,inner,depth,mat):
 for s in (-1,1):
  box(n+' side '+str(s),(py,cz), (outer-inner)/2,depth,outer/S,mat,'Muzzle',s*(outer+inner)/4,.0006)
  box(n+' horizontal '+str(s),(py,cz+s*(outer+inner)/4/S),inner,depth,(outer-inner)/2/S,mat,'Muzzle',0,.0006)
square_ring('Square muzzle outer ferrule',102,0,326,.034,.026,17,bare)
square_ring('Square muzzle inner bore',97,0,326,.026,.019,9,steel)
box('Deep bore shadow',(110,326),.019,1,53,wrap,'Muzzle',bev=0)
box('Muzzle lower pale bridge',(105,426),.037,16,25,paint,'Muzzle')
box('Under muzzle recessed block',(177,452),.031,127,32,steel,'Muzzle')
box('Front sight base',(164,278),.015,42,8,steel)
box('Front sight blade',(164,268),.006,24,12,bare)
box('Rear sight base',(831,277),.027,43,9,steel)
for s in (-1,1):box('Rear sight ear '+str(s),(833,267),.006,26,12,bare,x=s*.010)
box('Rear slide striker cap',(903,325),.018,16,26,steel)
# Rivets in the five top armor courses, as visible in the top reference.
for index,(px,pz) in enumerate([(128,280),(243,280),(278,275),(428,275),(460,281),(570,281),(608,275),(688,275),(725,277),(862,277)]):
 for side in (-1,1):
  y,z=yz((px,pz));bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.0016,depth=.0005,location=(side*.016,y,z+.0003));finish(bpy.context.object,'Top plate rivet %02d %s'%(index,side),bare,'Slide',.00015)
# Add carefully placed short paint losses/edge nicks along major plate boundaries.
rng=np.random.default_rng(343)
for side in (-1,1):
 for i in range(65):
  px=float(rng.uniform(125,700));pz=float(rng.choice([284,354,375,429]));sz=float(rng.uniform(1.5,5.5))
  # Restrict to actual plated zones.
  if (pz==375 and px>410) or (pz==429 and px>405) or (pz==354 and 448<px<587):continue
  profile('Localized chipped paint %s %02d'%(side,i),[(px,pz),(px+sz,pz+1),(px+sz*.75,pz+sz),(px+sz*.2,pz+sz*.65)],.0002,steel,'Slide',side*.02365,.00005)
# Normalize length and position: hand grip center at origin.
bpy.context.view_layer.update();coords=[o.matrix_world@Vector(c) for o in parts for c in o.bound_box];length=max(v.y for v in coords)-min(v.y for v in coords);factor=.30/length
for o in parts:
 o.location*=factor
 for v in o.data.vertices:v.co*=factor
 for mod in o.modifiers:
  if mod.type=='BEVEL':mod.width*=factor
root['length_m']=.30
# Export merged copies per movable assembly, preserving the editable originals.
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();export=[];tri=0
for name,parent in groups.items():
 copies=[]
 for original in parts:
  if original.parent!=parent:continue
  me=bpy.data.meshes.new_from_object(original.evaluated_get(dg));me.calc_loop_triangles();tri+=len(me.loop_triangles);o=bpy.data.objects.new(original.name+'_runtime',me);scene.collection.objects.link(o);o.matrix_world=original.matrix_world.copy();copies.append(o)
 bpy.ops.object.select_all(action='DESELECT')
 for o in copies:o.select_set(True)
 bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();o=bpy.context.object;o.name=name+'_Mesh';o.parent=parent;export.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in [root,*groups.values(),*export]:o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(OUT/'emberflint.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_extras=True)
for o in export:bpy.data.objects.remove(o,do_unlink=True)
coords=[o.matrix_world@Vector(c) for o in parts for c in o.bound_box];mins=[min(v[i] for v in coords) for i in range(3)];maxs=[max(v[i] for v in coords) for i in range(3)]
(OUT/'emberflint_stats.json').write_text(json.dumps({'length_m':.30,'triangles':tri,'editable_mesh_parts':len(parts),'assemblies':list(groups),'runtime_meshes':len(groups),'materials':4,'textures':'Four sets of 1024px base color, ORM, normal maps','emissive':False,'forward':'Godot -Z','origin':'grip center','blender_bounds_min':mins,'blender_bounds_max':maxs,'reference':'meshy_views_v2/gun_sidearm_starter_emberflint side, top, front','limitations':'Authored interpretation, overlapping UVs, no animation or collision'},indent=2))
# Neutral studio: only authored asset is exported.
scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True;scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.065,.08,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.view_settings.view_transform='AgX'
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,col,size in [('Key',(.5,.7,.8),35,(1,.95,.86),.6),('Rim',(-.5,-.4,.4),42,(.7,.8,1),.5),('Fill',(.5,-.3,.1),15,(1,1,1),.5)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=col;d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;aim(o,(0,.09,.03))
bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='ReviewCamera';cam.data.type='ORTHO';scene.camera=cam
for name,pos,target,scale in [('hero',(-.55,.6,.34),(0,.085,.015),.40),('side',(-.8,.085,.015),(0,.085,.015),.37),('top',(0,.085,.8),(0,.085,0),.37),('front',(0,.8,.015),(0,.085,.015),.27)]:
 cam.location=pos;aim(cam,target);cam.data.ortho_scale=scale;scene.render.filepath=str(PRE/(name+'.png'))
 if name=='hero':bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'emberflint.blend'))
 bpy.ops.render.render(write_still=True)
print('EMBERFLINT_COMPLETE',tri,len(parts),flush=True)
