"""Reproducible v2 rifle authoring, invoked by build_ridge.py/build_longpath.py."""
from pathlib import Path
import bpy, math, json, numpy as np
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
def build(ID):
 global OUT
 OUT=R/'assets/models/gear/guns'/ID
 _build(ID)
def material(name,color,metal,rough,paint=False,cloth=False):
 m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');N=512;rng=np.random.default_rng(sum(map(ord,name)));yy,xx=np.mgrid[:N,:N];f=np.fft.fftfreq(N);fy,fx=np.meshgrid(f,f)
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
 t=tex('normal',norm*.5+.5,True);n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.2 if paint else .045;m.node_tree.links.new(t.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],b.inputs['Normal']);return m
def _build(ID):
 src=R/'assets/source/blender'/ID;pre=src/'previews'
 for p in (OUT,src,pre):p.mkdir(parents=True,exist_ok=True)
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 sc=bpy.context.scene;sc.unit_settings.system='METRIC';parts=[];groups={}
 def empty(n):
  o=bpy.data.objects.new(n,None);sc.collection.objects.link(o);return o
 root=empty(ID.title()+'_GripOrigin');root['forward']='Godot -Z';root['reference']='meshy_views_v2/gun_rifle_'+('common_ridge' if ID=='ridge' else 'uncommon_longpath')
 for n in ['Receiver','Stock','Barrel','Magazine','Bolt','Trigger','Optic','Bipod']:groups[n]=empty(n);groups[n].parent=root
 steel=material(ID+'_WornGunmetal',(.095,.108,.13),.75,.44)
 dark=material(ID+'_RecessedSteel',(.027,.032,.041),.7,.53)
 blue=material(ID+'_CobaltCeramic',(.055,.12,.36),.25,.42,True)
 pale=material(ID+'_WeatheredBonePolymer',(.49,.455,.355),.05,.77,True)
 rubber=material(ID+'_GripRubber',(.028,.033,.037),0,.85,cloth=True)
 bright=material(ID+'_MachinedEdges',(.23,.25,.28),.88,.34)
 glow=bpy.data.materials.new(ID+'_OpticCyan');glow.use_nodes=True;bs=glow.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.015,.3,.55,1);bs.inputs['Metallic'].default_value=.2;bs.inputs['Roughness'].default_value=.2;bs.inputs['Emission Color'].default_value=(.01,.6,1,1);bs.inputs['Emission Strength'].default_value=3
 s=(.78/916 if ID=='ridge' else 1.12/918);origin=(650,593) if ID=='ridge' else (255,568);direction=-1 if ID=='ridge' else 1
 def pos(p,x=0):return Vector((x,direction*(p[0]-origin[0])*s,(origin[1]-p[1])*s))
 def finish(o,n,mat,g,bev=.001):
  o.name=n;bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
  uv=o.data.uv_layers.new(name='SurfaceUV')
  for f in o.data.polygons:
   axis=max(range(3),key=lambda j:abs(f.normal[j]));a,b=[(1,2),(0,2),(0,1)][axis]
   for i in f.loop_indices:
    v=o.data.vertices[o.data.loops[i].vertex_index].co;uv.data[i].uv=(v[a]*5+.5,v[b]*5+.5)
  if bev:
   m=o.modifiers.new('Editable edge bevel','BEVEL');m.width=bev;m.segments=2;m=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');m.keep_sharp=True
  o.parent=groups[g];parts.append(o);return o
 def profile(n,pts,w,mat=steel,g='Receiver',x=0,bev=.001):
  vs=[pos(p,x+k*w/2) for k in (-1,1) for p in pts];l=len(pts);fs=[tuple(range(l-1,-1,-1)),tuple(range(l,2*l))]+[(i,(i+1)%l,(i+1)%l+l,i+l) for i in range(l)];me=bpy.data.meshes.new(n);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(n,me);sc.collection.objects.link(o);return finish(o,n,mat,g,bev)
 def box(n,p,w,h,d,mat=steel,g='Receiver',x=0):
  bpy.ops.mesh.primitive_cube_add(size=1,location=pos(p,x));o=bpy.context.object;o.scale=(w,h*s,d*s);return finish(o,n,mat,g)
 def rod(n,a,b,r,mat=steel,g='Barrel',x=0,vertices=20):
  a=pos(a,x);b=pos(b,x);bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=(b-a).length,location=(a+b)/2);o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return finish(o,n,mat,g,.0006)
 def ring(n,p,r,inner,depth,mat=bright,g='Barrel'):
  # Annular tube aligned to bore, genuinely open muzzle.
  v=[]
  for y in (-depth/2,depth/2):
   for rad in (r,inner):
    for i in range(32):
     a=i*math.tau/32;v.append(pos(p)+Vector((math.cos(a)*rad,y,math.sin(a)*rad)))
  f=[]
  for i in range(32):
   j=(i+1)%32;f.extend([(i,j,64+j,64+i),(32+i,96+i,96+j,32+j),(i,32+i,32+j,j),(64+i,64+j,96+j,96+i)])
  me=bpy.data.meshes.new(n);me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new(n,me);sc.collection.objects.link(o);return finish(o,n,mat,g,.0005)
 def screw(p,x):
  bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.003,depth=.0015,location=pos(p,x),rotation=(0,math.pi/2,0));finish(bpy.context.object,'Recessed fastener',bright,'Receiver',.0003)
 if ID=='ridge':
  profile('Main forged receiver',[(181,399),(648,399),(651,384),(737,383),(766,405),(762,507),(683,507),(664,510),(579,508),(495,508),(474,517),(336,516),(324,533),(214,533),(201,570),(178,569)],.087)
  profile('Grip',[(595,506),(660,506),(665,547),(707,649),(706,679),(624,679),(624,663),(634,655),(606,578)],.054,rubber)
  profile('Stock skeleton',[(744,409),(927,398),(970,410),(970,489),(944,620),(822,620),(765,530)],.091,steel,'Stock')
  profile('Stock upper mottled shell',[(746,377),(910,377),(927,390),(929,417),(914,429),(821,426),(799,414),(748,411)],.097,pale,'Stock')
  profile('Stock lower mottled shell',[(769,484),(849,483),(904,465),(914,495),(908,620),(820,619),(764,526)],.094,pale,'Stock')
  profile('Stock butt',[(929,398),(970,398),(975,474),(955,492),(945,620),(915,620),(919,478),(941,457)],.098,pale,'Stock')
  profile('Carry handle front upright',[(175,390),(183,366),(202,329),(282,326),(279,348),(251,370),(247,390)],.087)
  profile('Carry handle top bridge',[(204,328),(617,309),(637,348),(274,352),(250,375),(249,354),(190,354)],.035)
  profile('Carry handle rear upright',[(560,349),(644,349),(645,406),(563,406)],.087)
  # Twin rail edges leave a top channel.
  for x in (-.025,.025):profile('Carry handle rail',[(208,329),(614,310),(633,338),(268,342),(248,361),(199,354)],.009,steel,x=x)
  profile('Magazine',[(357,506),(480,506),(491,709),(365,697)],.062,dark,'Magazine')
  profile('Magazine blue protective shell',[(353,490),(469,490),(484,508),(486,570),(501,572),(500,650),(363,635),(360,552),(339,529),(341,505)],.084,blue,'Magazine')
  box('Magazine heel',(426,697),.071,134,18,steel,'Magazine')
  for x in (-.043,.043):
   profile('Blue shell inset border',[(365,508),(460,508),(471,521),(472,615),(461,630),(370,618)],.002,blue,'Magazine',x)
   for p in [(355,506),(468,506),(484,634),(193,394),(605,491)]:screw(p,x)
   box('Ejection recess',(365,444),.002,179,24,dark,'Receiver',x)
   box('Bolt',(365,442),.003,153,12,bright,'Bolt',x+math.copysign(.001,x))
   profile('Receiver lower angular plate',[(276,466),(322,466),(335,452),(449,452),(463,478),(526,479),(532,500),(482,500),(469,489),(341,488),(325,507),(277,507)],.003,steel,'Receiver',x)
   profile('Receiver upper service armor',[(461,403),(550,404),(555,423),(644,424),(645,473),(541,473),(524,464),(463,466)],.003,steel,'Receiver',x)
   box('Rear service plate',(606,385),.003,46,21,dark,'Receiver',x)
   box('Stock seam',(717,461),.002,88,9,dark,'Stock',x)
   for j in range(12):box('Grip traction rib',(653+j*1.7,571+j*6),.002,35,2,steel,'Receiver',x*.64)
  profile('Open trigger guard',[(487,505),(504,505),(504,553),(513,559),(574,559),(582,550),(581,510),(593,510),(594,556),(581,571),(499,571),(487,559)],.027)
  profile('Curved trigger',[(548,513),(557,513),(565,536),(559,551),(550,552),(554,535)],.010,bright,'Trigger')
  rod('Barrel',(70,457),(194,457),.017,dark);ring('Muzzle crown',(61,457),.020,.011,.023);ring('Muzzle collar',(154,457),.020,.017,.015)
  for x in (-.018,.018):box('Muzzle port',(105,454),.001,37,7,dark,'Barrel',x)
  for j in range(8):box('Receiver rail tooth',(282+j*8,408),.086,4,6,bright)
 else:
  profile('Receiver core',[(237,483),(350,473),(552,478),(560,501),(540,537),(494,550),(347,535),(334,526),(289,526),(283,526),(241,525)],.075)
  profile('Rear receiver armor',[(239,483),(331,483),(338,500),(331,519),(237,512)],.082,steel)
  profile('Blue forward receiver plate',[(395,480),(552,480),(552,506),(532,539),(487,547),(433,542),(420,525),(395,521)],.081,blue)
  profile('Grip',[(253,526),(289,532),(271,562),(261,606),(271,613),(259,620),(225,608),(211,587)],.047,rubber)
  profile('Butt vertical',[(56,489),(69,480),(83,486),(76,529),(80,593),(66,604),(62,592)],.064,steel,'Stock')
  profile('Stock upper beam',[(77,490),(230,487),(232,518),(174,521),(117,509),(82,518)],.060,steel,'Stock')
  profile('Stock lower open beam',[(73,591),(112,577),(153,555),(177,568),(256,611),(259,619),(230,616),(175,582),(147,576),(95,605),(70,605)],.056,steel,'Stock')
  profile('Stock diagonal brace',[(165,513),(187,516),(144,563),(123,573),(109,570)],.044,steel,'Stock')
  profile('Cheek cobalt pad',[(104,466),(198,467),(212,475),(205,488),(173,488),(160,501),(102,501),(94,485)],.069,blue,'Stock')
  profile('Handguard',[(560,481),(683,480),(696,493),(689,532),(544,535),(533,530)],.072,steel)
  for x in (-.038,.038):
   for j in range(6):box('Upper cooling slot',(568+j*12,496),.002,8,7,dark,x=x)
   for j in range(5):box('Lower cooling slot',(571+j*16,517),.002,10,4,dark,x=x)
   profile('Receiver angular inset',[(354,532),(391,532),(410,550),(397,567),(350,568)],.002,steel,'Magazine',x)
   box('Ejection port',(366,496),.002,43,14,dark,x=x)
   box('Reciprocating bolt',(369,496),.003,34,7,bright,'Bolt',x)
   for p in [(247,489),(326,489),(674,491),(442,500)]:screw(p,x)
  profile('Magazine box',[(343,530),(411,531),(435,550),(415,575),(340,577)],.060,dark,'Magazine')
  profile('Open trigger guard',[(285,526),(294,529),(294,552),(302,558),(328,558),(331,535),(341,535),(340,568),(296,568),(284,557)],.026)
  profile('Trigger',[(307,531),(315,531),(314,548),(320,553),(310,554),(304,544)],.009,bright,'Trigger')
  rod('Long precision barrel',(682,502),(955,502),.0135,dark);ring('Barrel receiver collar',(709,502),.017,.013,.045);ring('Muzzle brake',(943,502),.018,.011,.062);ring('Open muzzle crown',(963,502),.018,.010,.008)
  for j in range(3):ring('Barrel machined ring',(888+j*10,502),.0148,.013,.003)
  for j in range(18):box('Picatinny rail tooth',(280+j*13,469),.047,7,5,steel)
  for p in [(342,461),(413,461)]:box('Optic mounting foot',p,.050,24,10,dark,'Optic')
  profile('Optic housing',[(292,414),(305,404),(455,398),(466,410),(472,437),(462,451),(312,453),(292,440)],.068,steel,'Optic')
  for p in [(305,428),(346,426),(400,425),(441,424)]:box('Optic protective band',p,.071,7,42,dark,'Optic')
  ring('Scope front bezel',(474,427),.028,.021,.014,bright,'Optic');rod('Scope cyan glass',(478,427),(480,427),.020,glow,'Optic');ring('Scope rear eyepiece',(292,429),.021,.015,.012,dark,'Optic')
  for x in (-.048,.048):
   rod('Folded bipod leg',(606,550),(781,576),.0065,dark,'Bipod',x)
   for j in range(5):rod('Bipod telescopic collar',(748+j*7,571+j),(751+j*7,571+j),.008,steel,'Bipod',x)
   rod('Bipod mounting knuckle',(604,546),(616,549),.012,bright,'Bipod',x)
   box('Bipod foot',(782,577),.018,9,12,rubber,'Bipod',x)
 # Preserve named assembly animation in both Blender and glTF.
 sc.render.fps=30
 for n in ['Bolt','Trigger']:
  o=groups[n];o.location=(0,0,0);o.keyframe_insert('location',frame=1)
  o.location.y=-.024 if n=='Bolt' else -.003;o.keyframe_insert('location',frame=3)
  o.location.y=0;o.keyframe_insert('location',frame=7);o.animation_data.action.name='Fire_'+n
  track=o.animation_data.nla_tracks.new();track.name='Fire';track.strips.new('Fire',1,o.animation_data.action);o.animation_data.action=None
 o=groups['Magazine'];o.location.z=0;o.keyframe_insert('location',frame=1);o.location.z=-.16;o.keyframe_insert('location',frame=16);o.keyframe_insert('location',frame=30);o.location.z=0;o.keyframe_insert('location',frame=45);o.animation_data.action.name='Reload_Magazine';t=o.animation_data.nla_tracks.new();t.name='Reload';t.strips.new('Reload',1,o.animation_data.action);o.animation_data.action=None
 sc.frame_set(1);bpy.context.view_layer.update()
 # Merge evaluated runtime copies per assembly, keep source meshes editable.
 dg=bpy.context.evaluated_depsgraph_get();exports=[];tri=0
 for n,par in list(groups.items()):
  originals=[o for o in parts if o.parent==par]
  if not originals:continue
  copies=[]
  for original in originals:
   me=bpy.data.meshes.new_from_object(original.evaluated_get(dg));me.calc_loop_triangles();tri+=len(me.loop_triangles);o=bpy.data.objects.new(original.name+'_runtime',me);sc.collection.objects.link(o);o.matrix_world=original.matrix_world.copy();copies.append(o)
  bpy.ops.object.select_all(action='DESELECT')
  for o in copies:o.select_set(True)
  bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();o=bpy.context.object;o.name=n+'_Mesh';o.parent=par;exports.append(o)
 bpy.ops.object.select_all(action='DESELECT')
 for o in [root,*groups.values(),*exports]:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(ID+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_animations=True,export_animation_mode='NLA_TRACKS')
 for o in exports:bpy.data.objects.remove(o,do_unlink=True)
 bounds=[o.matrix_world@Vector(c) for o in parts for c in o.bound_box]
 stats={'id':ID,'length_m':round(max(v.y for v in bounds)-min(v.y for v in bounds),3),'triangles':tri,'editable_mesh_parts':len(parts),'runtime_meshes':len(exports),'reference':root['reference'],'forward':'Godot -Z','origin':'grip center','animations':['Fire','Reload'],'emissive':ID=='longpath','materials':6+(ID=='longpath'),'textures':'512px packed basecolor, ORM, normal; procedural wear baked reproducibly','limitations':'Authored interpretation of v2 views; shared tiled UVs; animation assembly travel only'}
 (OUT/(ID+'_stats.json')).write_text(json.dumps(stats,indent=2))
 (src/'README.md').write_text('# '+ID.title()+'\n\nAuthored from `'+root['reference']+'` side/top/front only. Editable beveled source meshes, packed PBR maps, named assembly groups, Fire bolt/trigger and Reload magazine animations. '+('Cyan emissive scope glass; folded bipod assembly. ' if ID=='longpath' else 'Non-emissive ballistic rifle with open carry handle and cobalt magazine shell. ')+'Godot forward -Z, origin at grip.\n\nRebuild: `blender -b --factory-startup -t 4 --python tools/build_'+ID+'.py`.\n\nAnimations are presentation-ready assembly motions; gameplay hookup is separate.\n')
 sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=True;sc.render.resolution_x=1200;sc.render.resolution_y=800;sc.render.resolution_percentage=100;sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.065,.08,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.5;sc.view_settings.view_transform='AgX'
 target=Vector((0,(max(v.y for v in bounds)+min(v.y for v in bounds))/2,(max(v.z for v in bounds)+min(v.z for v in bounds))/2));length=stats['length_m']
 def aim(o):o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
 for n,loc,power,col in [('Key',(-1,1,2),220,(1,.93,.85)),('Fill',(1,.3,1),160,(.7,.8,1)),('Rim',(0,-1,1),190,(.6,.75,1))]:
  d=bpy.data.lights.new(n,'AREA');d.energy=power;d.color=col;d.size=1.3;o=bpy.data.objects.new(n,d);sc.collection.objects.link(o);o.location=target+Vector(loc);aim(o)
 bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';sc.camera=cam
 for n,offset,scale in [('hero',(-1.4,.8,.65),length*1.2),('side',(-2,0,0),length*1.15),('top',(0,0,2),length*1.15),('front',(0,2,0),length*.8)]:
  cam.location=target+Vector(offset);aim(cam);cam.data.ortho_scale=scale;sc.render.filepath=str(pre/(n+'.png'))
  if n=='hero':bpy.ops.wm.save_as_mainfile(filepath=str(src/(ID+'.blend')))
  bpy.ops.render.render(write_still=True)
 print(ID.upper()+'_COMPLETE',json.dumps(stats),flush=True)
