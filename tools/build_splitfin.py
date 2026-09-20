"""Splitfin, authored from meshy_views_v2. Run blender -b -t 6 --python tools/build_splitfin.py."""
from pathlib import Path
import bpy, math, json, numpy as np
from mathutils import Vector
R=Path(__file__).resolve().parents[1]; SRC=R/'assets/source/blender/splitfin'; OUT=R/'assets/models/gear/guns/splitfin'; PRE=SRC/'previews'
for p in (SRC, OUT, PRE): p.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene; scene.unit_settings.system='METRIC'; parts=[]
def empty(n,parent=None):
 o=bpy.data.objects.new(n,None);scene.collection.objects.link(o);o.parent=parent;return o
root=empty('Splitfin_GripOrigin');root['reference']='meshy_views_v2/gun_energy_rare_splitfin';root['forward']='Godot -Z';root['length_m']=.62
frame=empty('Frame',root); core=empty('Amber_Core',root); fins={}
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
  wear*=.09
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
ivory=material('Splitfin_Ivory_Ceramic',(.72,.68,.56),.18,.5,True)
gold=material('Splitfin_Antique_Gold',(.46,.285,.095),.83,.3)
steel=material('Splitfin_Charcoal_Frame',(.026,.037,.052),.60,.47)
em=bpy.data.materials.new('Splitfin_Amber_Emission');em.use_nodes=True;b=em.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(1,.34,.025,1);b.inputs['Emission Color'].default_value=(1,.36,.016,1);b.inputs['Emission Strength'].default_value=4.0;b.inputs['Metallic'].default_value=.25;b.inputs['Roughness'].default_value=.25
S=.62/924
# Pixel trace of v2 front, with height mapped to forward +Y. Grip centered at zero.
def coord(px,py,z=0):return ((px-538)*S,(810-py)*S,z)
def finish(o,n,mat,parent=frame,bevel=.001):
 o.name=n;bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 if parent in fins.values():
  for v in o.data.vertices:
   py=810-v.co.y/S; t=max(0,min(1,(py-48)/646)); v.co.z*=.26+.74*math.sin(t*math.pi)**.65
 uv=o.data.uv_layers.new(name='SurfaceUV')
 for face in o.data.polygons:
  axis=max(range(3),key=lambda j:abs(face.normal[j]));aa,bb=[(1,2),(0,2),(0,1)][axis]
  for k in face.loop_indices:
   v=o.data.vertices[o.data.loops[k].vertex_index].co;uv.data[k].uv=(v[aa]*12+.5,v[bb]*12+.5)
 if bevel:
  m=o.modifiers.new('Editable edge bevel','BEVEL');m.width=bevel;m.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 o.parent=parent;parts.append(o);return o
def prism(n,pts,zlow,zhigh,mat,parent=frame,bevel=.001):
 vs=[coord(x,y,z) for z in (zlow,zhigh) for x,y in pts];l=len(pts);faces=[tuple(range(l-1,-1,-1)),tuple(range(l,2*l))]+[(i,(i+1)%l,(i+1)%l+l,i+l) for i in range(l)];me=bpy.data.meshes.new(n);me.from_pydata(vs,[],faces);me.update();o=bpy.data.objects.new(n,me);scene.collection.objects.link(o);return finish(o,n,mat,parent,bevel)
def curve(n,pts,r,mat,parent=frame):
 cu=bpy.data.curves.new(n,'CURVE');cu.dimensions='3D';cu.resolution_u=1;cu.bevel_depth=r;cu.bevel_resolution=2;sp=cu.splines.new('POLY');sp.points.add(len(pts)-1)
 for v,p in zip(sp.points,pts):v.co=(*p,1)
 o=bpy.data.objects.new(n,cu);scene.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o=bpy.context.object;o.select_set(False);return finish(o,n,mat,parent,0)
def orb(n,loc,r,mat,parent=core,scale=(1,1,1)):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=r,location=loc);o=bpy.context.object;o.scale=scale;return finish(o,n,mat,parent,.0)
# Charcoal grip with fitted gold ferrules and domed ivory heel.
handle=[(475,599),(497,690),(500,755),(496,830),(483,887),(483,921),(503,943),(570,943),(591,920),(590,887),(580,831),(576,753),(580,690),(601,599),(576,619),(538,675),(504,620)]
prism('Sculpted charcoal grip',handle,-.027,.027,steel,bevel=.004)
for s in (-1,1):
 curve('Grip gold longitudinal inlay', [coord(538,y,s*.028) for y in (940,900,830,755,701)],.0012,gold)
 for off in (-1,1):curve('Grip side gilded seam',[coord(538+off*w,y,s*z) for w,y,z in [(47,893,.023),(38,830,.026),(35,760,.027),(40,699,.027),(56,648,.027)]],.0009,gold)
prism('Pommel ivory heel',[(482,913),(591,913),(587,949),(570,969),(511,969),(487,953)],-.030,.030,ivory,bevel=.008)
prism('Pommel gold band',[(486,888),(587,888),(592,914),(481,914)],-.032,.032,gold,bevel=.002)
curve('Heel gold dividing stripe',[coord(538,913,-.031),coord(538,971,-.031),coord(538,971,.031),coord(538,913,.031)],.0012,gold)
# Four independently hinged, concave fins. Upper/lower matched pairs visible in v2 top.
outline=[(337,507),(345,400),(365,293),(401,187),(443,85),(497,48),(505,63),(506,222),(482,261),(458,315),(447,365),(448,452),(461,483),(503,515),(505,585),(517,694),(501,690),(463,602),(435,563),(393,531),(363,515)]
for side in (-1,1):
 for upper in (-1,1):
  g=empty(('Left' if side<0 else 'Right')+('_Upper' if upper>0 else '_Lower')+'_FinPivot',root);fins[(side,upper)]=g
  def mirror(pts):return [(538+side*(538-x),y) for x,y in pts]
  lo,hi=sorted([upper*.012,upper*.037]);prism(g.name+' gold rim',mirror(outline),lo,hi,gold,g,.0015)
  # Inset plate, preserving an actual open central chamber.
  inner=[(345,500),(354,400),(373,295),(409,190),(450,92),(491,62),(496,72),(496,218),(473,259),(450,313),(438,363),(439,455),(453,492),(492,522),(495,582),(506,678),(493,663),(472,602),(443,555),(397,522),(365,507)]
  lo,hi=sorted([upper*.019,upper*.041]);prism(g.name+' ivory plate',mirror(inner),lo,hi,ivory,g,.0016)
  for idx,line in enumerate([[(354,404),(381,413),(437,467)],[(366,348),(391,371),(444,421)],[(379,277),(412,281),(437,337)],[(410,186),(445,172),(480,99)],[(394,516),(395,490),(414,472)],[(488,522),(467,544),(475,591)]]):
   curve(g.name+' engraved gold seam '+str(idx),[coord(x,y,upper*.042) for x,y in mirror(line)],.00065,gold,g)
  curve(g.name+' bright inner channel',[coord(x,y,upper*.025) for x,y in mirror([(501,91),(501,217),(476,265),(452,326),(443,398),(446,458),(460,491),(498,520),(503,580)])],.0010,em,g)
  # Set pivot at the actual grip shoulder, preserving world geometry.
  g.location=coord(538+side*41,620,upper*.010)
  for o in [o for o in parts if o.parent==g]:o.location-=g.location
  g['hinge_axis']='local Y';g['charge_open_degrees']=9
# Gold cross braces and mechanical pins connect the split head to grip.
for side in (-1,1):
 pp=[(538+side*35,586),(538+side*74,577),(538+side*84,595),(538+side*38,613)]
 prism('Shoulder gold clasp '+str(side),pp,-.042,.042,gold,bevel=.0015)
 for upper in (-1,1):orb('Hinge cap',coord(538+side*44,601,upper*.045),.005,gold,frame,(1,1,.32))
# Core is a visible lattice of curved energy filaments around a small sun.
orb('Contained amber sun',coord(538,435),.020,em)
for axis in range(3):
 for k in range(3):
  pts=[]
  for i in range(97):
   t=i*math.tau/96;r=.028+k*.002;v=Vector((r*math.cos(t),r*math.sin(t),.005*math.sin(3*t+k)))
   if axis==1:v=Vector((v.z,v.x,v.y))
   if axis==2:v=Vector((v.y,v.z,v.x))
   pts.append(tuple(Vector(coord(538,435))+v))
  curve('Orbit filament %s %s'%(axis,k),pts,.00055,em,core)
for side in (-1,1):
 for upper in (-1,1):
  pts=[]
  for i in range(81):
   t=i/80;px=538+side*math.sin(t*math.pi)*34;py=179+t*451;z=upper*math.sin(t*math.pi)*.012;pts.append(coord(px,py,z))
  curve('Longitudinal plasma filament',pts,.0009,em,core)
# Named transform animation survives GLB export. Fin pivot action and rotating core.
scene.render.fps=30;scene.frame_start=1;scene.frame_end=61
for (side,upper),g in fins.items():
 for fr,angle in [(1,0),(20,0),(32,math.radians(9)*side*upper),(42,math.radians(9)*side*upper),(61,0)]:
  g.rotation_euler.y=angle;g.keyframe_insert(data_path='rotation_euler',frame=fr)
 g.animation_data.action.name='Splitfin_Charge_'+g.name
# Core rotates about the sun instead of grip.
core.location=coord(538,435)
for o in [o for o in parts if o.parent==core]:o.location-=core.location
for fr,angle in [(1,0),(61,math.tau)]:
 core.rotation_euler.y=angle;core.keyframe_insert(data_path='rotation_euler',frame=fr)
core.animation_data.action.name='Splitfin_CoreOrbit'
scene.frame_set(1);bpy.context.view_layer.update()
tri=sum(len(o.data.polygons) for o in parts)
bpy.ops.object.select_all(action='DESELECT')
for o in [root,frame,core,*fins.values(),*parts]:o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(OUT/'splitfin.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_extras=True,export_animations=True,export_animation_mode='SCENE',export_frame_range=True)
# Combine synchronized exported object clips into a single playable Godot action.
import struct
raw=(OUT/'splitfin.glb').read_bytes(); jlen=struct.unpack_from('<I',raw,12)[0]; data=json.loads(raw[20:20+jlen]); merged={'name':'Splitfin_Charge','samplers':[],'channels':[]}
for clip in data.get('animations',[]):
 offset=len(merged['samplers']); merged['samplers'].extend(clip['samplers'])
 for channel in clip['channels']:
  channel['sampler']+=offset;merged['channels'].append(channel)
data['animations']=[merged]; chunk=json.dumps(data,separators=(',',':')).encode();chunk+=b' '*((-len(chunk))%4);tail=raw[20+jlen:];(OUT/'splitfin.glb').write_bytes(struct.pack('<III',0x46546C67,2,20+len(chunk)+len(tail))+struct.pack('<II',len(chunk),0x4E4F534A)+chunk+tail)
# Studio and orthographic review set.
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True;scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.045,.065,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4;scene.view_settings.view_transform='AgX'
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,col,size in [('Key',(.5,.4,1),95,(1,.94,.83),.8),('Rim',(-.5,.6,-.6),100,(.69,.81,1),.7),('Fill',(.5,-.4,.4),45,(1,1,1),.5)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=col;d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;aim(o,(0,.2,0))
bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='ReviewCamera';cam.data.type='ORTHO';scene.camera=cam
# Emissive core exports independently; engine world glow can add bloom.
for name,pos,scale in [('hero',(.62,-.15,.90),.78),('front',(0,.20,1.5),.72),('side',(1.5,.20,0),.72),('top',(0,1.6,.04),.42)]:
 cam.location=pos;aim(cam,(0,.20,0));cam.data.ortho_scale=scale;scene.render.filepath=str(PRE/(name+'.png'))
 if name=='hero':bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'splitfin.blend'))
 bpy.ops.render.render(write_still=True)
# Verify runtime payload directly rather than infer from Blender parts.
import struct
raw=(OUT/'splitfin.glb').read_bytes();ln=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+ln]);tris=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
(OUT/'splitfin_stats.json').write_text(json.dumps({'asset':'Splitfin','tier':'Rare','length_m':.62,'triangles':tris,'editable_mesh_parts':len(parts),'runtime_meshes':len(doc['meshes']),'materials':len(doc['materials']),'embedded_images':len(doc.get('images',[])),'animations':[a.get('name') for a in doc.get('animations',[])],'animation_seconds':2,'emissive':True,'reference':'meshy_views_v2/gun_energy_rare_splitfin side/top/front','origin':'grip center','forward':'Godot -Z','textures':'512px basecolor ORM normal for ivory, gold, charcoal; separate amber emission','limitations':'Authored interpretation of the supplied views; no collision; overlapping material UVs'},indent=2))
print('SPLITFIN_COMPLETE',tris,len(parts),flush=True)
