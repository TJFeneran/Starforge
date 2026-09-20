"""Editable Monument Heart reconstruction. Blender 5.x; meters; +Y -> Godot -Z.
Run: blender -b --factory-startup -t 8 --python tools/build_monument_heart.py
Reference interpretation: side silhouette + concentric front disk; invisible back is authored.
"""
from pathlib import Path
import bpy, math, json, numpy as np
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
SRC=R/'assets/source/blender/monument_heart'; OUT=R/'assets/models/gear/guns/monument_heart'; PRE=SRC/'previews'
for p in (SRC,OUT,PRE): p.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene; scene.unit_settings.system='METRIC'
parts=[]; groups={}
def empty(n,pos=(0,0,0),parent=None):
 o=bpy.data.objects.new(n,None);scene.collection.objects.link(o);o.location=pos;o.parent=parent;return o
root=empty('MonumentHeart_GripOrigin');root['forward']='Blender +Y / Godot -Z';root['status']='refined_pending_review'
# Grip centre is origin. Disk is 0.78 m diameter; total length is 0.95 m.
for n,pos in [('Receiver',(0,0,0)),('Grip',(0,0,0)),('RingRotor',(0,.50,.30)),('Core',(0,.50,.30)),('Trigger',(0,.01,.13)),('MuzzleMount',(0,0,0))]:groups[n]=empty(n,pos,root)
def material(name,color,metal,rough,emission=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*color,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=rough
 if emission:
  b.inputs['Emission Color'].default_value=(*color,1);b.inputs['Emission Strength'].default_value=emission
 else:
  # Portable PBR pixels: each material carries color, packed roughness/metalness,
  # and tangent normals. Physical variation is shared across all three maps.
  size=1024;rng=np.random.default_rng(sum(map(ord,name)));yy,xx=np.mgrid[:size,:size]
  freq=np.fft.fftfreq(size);fy,fx=np.meshgrid(freq,freq)
  def field(radius):
   v=np.fft.ifft2(np.fft.fft2(rng.normal(size=(size,size)))*np.exp(-(fx*fx+fy*fy)*radius*radius)).real
   return v/max(v.std(),.0001)
  broad=field(95);medium=field(16);fine=field(3)
  stone=name.startswith('Ivory');navy=name=='Midnight_Stone'
  brass='Brass' in name;edge_wear=name=='Patinated_Panel_Edges'
  cracks=np.zeros((size,size));scuffs=np.zeros_like(cracks)
  def stroke(mask,x,y,angle,length,width,value):
   # Jagged, tapering fractures with short branches; wrap for seamless tiling.
   for step in range(length):
    angle+=rng.normal(0,.035) + (rng.normal(0,.40) if step%24==0 else 0);x+=math.cos(angle);y+=math.sin(angle)
    for dx,dy in [(0,0),(1,0),(-1,0),(0,1),(0,-1)][:width]:
     ix,iy=(int(x)+dx)%size,(int(y)+dy)%size
     mask[iy,ix]=max(mask[iy,ix],value*(.5+.5*math.sin(math.pi*step/max(length,1))))
   return x,y,angle
  if stone or navy:
   for k in range(17 if stone else 11):
    x,y=rng.uniform(0,size,2);angle=rng.uniform(0,math.tau)
    for branch in range(3):
     x,y,angle=stroke(cracks,x,y,angle,int(rng.integers(45,170)),5,.8)
     stroke(cracks,x,y,angle+rng.choice([-1,1])*.9,int(rng.integers(20,65)),2,.5)
  for k in range(110 if brass else 40):
   stroke(scuffs,*rng.uniform(0,size,2),rng.normal(.3,.35),int(rng.integers(7,60)),1,rng.uniform(.15,.5))
  pits=np.clip((fine-1.7)*.6,0,1)*np.clip(medium+.5,0,1)
  weather=np.clip((broad+medium*.4+.35)*.28,0,.8)
  variation=1+broad*.06+medium*.045+fine*.018
  rgb=np.array(color)[None,None,:]*variation[:,:,None]
  height=medium*.0009+fine*.00025-pits*.003-scuffs*.003
  roughness=np.clip(rough+broad*.06+medium*.025+pits*.18-scuffs*.13,.15,.95)
  metalness=np.full((size,size),metal)
  if stone:
   stain=weather*.22+pits*.17
   rgb*=1-stain[:,:,None]
   rgb=rgb*(1-cracks[:,:,None]*.7)
   height-=cracks*.016;roughness+=cracks*.08
  elif navy or edge_wear:
   # Bronze substrate is visible only along occasional fractures and abraded edges.
   worn=np.clip(cracks*.55+scuffs*.3+pits*.18,0,.7)
   if edge_wear:worn=np.clip((medium+broad*.2+.3)*.6,0,.85)
   substrate=np.array((.34,.255,.15))
   rgb=rgb*(1-worn[:,:,None])+substrate*worn[:,:,None]
   rgb*=1-weather[:,:,None]*.16
   height-=cracks*.018;metalness+=worn*.25
  elif brass:
   patina=np.clip(weather*.65+pits*.55,0,.8)
   rgb=rgb*(1-patina[:,:,None])+np.array((.095,.078,.046))*patina[:,:,None]
   rgb+=scuffs[:,:,None]*np.array((.10,.09,.06))
   metalness-=patina*.35
  else:
   rgb*=1-weather[:,:,None]*.2
  # Derivatives encode the same chips and fissures into the normal texture.
  du=(np.roll(height,-1,1)-np.roll(height,1,1))*size*.18
  dv=(np.roll(height,-1,0)-np.roll(height,1,0))*size*.18
  normal=np.stack((-du,-dv,np.ones_like(du)),axis=2)
  normal/=np.linalg.norm(normal,axis=2)[:,:,None];normal=normal*.5+.5
  orm=np.stack((np.ones_like(roughness),np.clip(roughness,0,1),np.clip(metalness,0,1)),axis=2)
  def texture(suffix,data,noncolor=False):
   pixels=np.ones((size,size,4),np.float32);pixels[:,:,:3]=np.clip(data,0,1)
   im=bpy.data.images.new(name+'_'+suffix,width=size,height=size,alpha=False)
   if noncolor:im.colorspace_settings.name='Non-Color'
   im.pixels.foreach_set(pixels.ravel());im.filepath_raw=str(OUT/(name+'_'+suffix+'.png'));im.file_format='PNG';im.save();im.pack()
   node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;return node
  t=texture('basecolor',rgb);m.node_tree.links.new(t.outputs['Color'],b.inputs['Base Color'])
  t=texture('orm',orm,True);sep=m.node_tree.nodes.new('ShaderNodeSeparateColor');m.node_tree.links.new(t.outputs['Color'],sep.inputs['Color'])
  m.node_tree.links.new(sep.outputs['Green'],b.inputs['Roughness']);m.node_tree.links.new(sep.outputs['Blue'],b.inputs['Metallic'])
  t=texture('normal',normal,True);n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.65
  m.node_tree.links.new(t.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],b.inputs['Normal'])

 return m
ivory=material('Ivory_CarvedStone',(.78,.74,.66),.06,.64);navy=material('Midnight_Stone',(.065,.105,.17),.32,.51);gold=material('Antique_Brass',(.48,.35,.20),.72,.44);edge=material('Worn_Brass_Edges',(.62,.49,.31),.72,.34);black=material('Recess_BlackSteel',(.015,.022,.028),.8,.39);core=material('Core_Emission_EDIT_COLOR',(1,.31,.003),.72,.19,.12);runes=material('Ring_Emission_EDIT_COLOR',(1,.38,.025),.1,.3,2)
panel_edge=material('Patinated_Panel_Edges',(.09,.115,.15),.45,.53)
stone_cut=material('Ivory_Engraved_Recess',(.26,.225,.175),.08,.82)
heart_fire=material('Core_Fissures_Emission_EDIT_COLOR',(1,.48,.008),.1,.28,6)
def finish(o,n,mat,g,bevel=.002):
 o.name=n;bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(mat)
 if bevel:
  mod=o.modifiers.new('Editable edge chamfer','BEVEL');mod.width=bevel;mod.segments=2
  if mat in (navy,gold):
   o.data.materials.append(panel_edge if mat==navy else edge);mod.material=1
  mod=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');mod.keep_sharp=True
 # Local triplanar UVs, every face independently mapped for repeatable stone grain.
 uv=o.data.uv_layers.new(name='SurfaceUV') if not o.data.uv_layers else o.data.uv_layers.active
 for face in o.data.polygons:
  axis=max(range(3),key=lambda j:abs(face.normal[j]));a,b=[(1,2),(0,2),(0,1)][axis]
  for i in face.loop_indices:
   v=o.data.vertices[o.data.loops[i].vertex_index].co;uv.data[i].uv=(v[a]*5+.5,v[b]*5+.5)
 world=o.matrix_world.copy();o.parent=groups[g];o.matrix_world=world;parts.append(o);return o
def box(n,loc,size,mat,g='Receiver',bevel=.003):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=size;return finish(o,n,mat,g,bevel)
def profile(n,points,width,mat,g='Receiver',x=0,bevel=.003):
 vs=[(x+s*width/2,y,z) for s in (-1,1) for y,z in points];l=len(points);faces=[tuple(range(l-1,-1,-1)),tuple(range(l,2*l))]+[(i,(i+1)%l,(i+1)%l+l,i+l) for i in range(l)]
 mesh=bpy.data.meshes.new(n);mesh.from_pydata(vs,[],faces);mesh.update();o=bpy.data.objects.new(n,mesh);scene.collection.objects.link(o);return finish(o,n,mat,g,bevel)
def annulus(n,ri,ro,y0,y1,mat,g='RingRotor',segments=96,start=0,end=2*math.pi):
 vs=[]
 for y in (y0,y1):
  for r in (ri,ro):
   vs.extend([(r*math.sin(start+(end-start)*i/segments),y,.30+r*math.cos(start+(end-start)*i/segments)) for i in range(segments+1)])
 q=segments+1;fs=[]
 for i in range(segments):
  fs.extend([(i,i+1,q+i+1,q+i),(2*q+i,3*q+i,3*q+i+1,2*q+i+1),(i,2*q+i,2*q+i+1,i+1),(q+i,q+i+1,3*q+i+1,3*q+i)])
 fs.extend([(0,q,3*q,2*q),(segments,2*q-1,4*q-1,3*q-1)])
 me=bpy.data.meshes.new(n);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(n,me);scene.collection.objects.link(o);return finish(o,n,mat,g,.0012)
def cyl(n,loc,r,depth,mat,g='Receiver',axis='Y',vertices=48):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc,rotation=(math.pi/2,0,0) if axis=='Y' else (0,math.pi/2,0));return finish(bpy.context.object,n,mat,g,.001)
# Stepped sculpted receiver: hand traced polygon sections, recessed inlays and brass seams.
body=[(-.33,.38),(.35,.38),(.39,.34),(.39,.18),(.26,.15),(.06,.15),(-.08,.22),(-.33,.24)]
profile('Receiver forged stone frame',body,.18,navy)
profile('Receiver top chamfer', [(-.32,.38),(.33,.38),(.33,.408),(-.30,.408)],.19,navy)
profile('Rear brass end cap',[(-.33,.24),(-.33,.39),(-.30,.405),(-.275,.39),(-.275,.265)],.195,gold)
for s in (-1,1):
 profile('Receiver side inset '+str(s),[(-.25,.33),(.30,.33),(.30,.20),(.06,.20),(-.08,.29),(-.25,.29)],.012,black,x=s*.096)
 profile('Stepped side armor '+str(s),[(-.24,.325),(.29,.325),(.29,.225),(.07,.225),(-.09,.303),(-.24,.303)],.014,navy,x=s*.104)
 profile('Brass angular side border '+str(s),[(-.25,.35),(-.19,.35),(-.19,.326),(-.09,.326),(.07,.20),(.26,.20),(.26,.187),(.058,.187),(-.105,.312),(-.25,.312)],.01,gold,x=s*.116)
 box('Side lock escutcheon '+str(s),(s*.122,.23,.30),(.018,.19,.064),gold,bevel=.009)
 box('Side lock dark slot '+str(s),(s*.133,.23,.30),(.006,.10,.023),black,bevel=.007)
 box('Side lock insert '+str(s),(s*.138,.23,.30),(.004,.073,.009),edge,bevel=.002)
for y,length,width in [(-.20,.23,.15),(.055,.25,.172),(.267,.13,.19)]:
 box('Receiver top layered armor',(0,y,.413),(width,length,.018),navy,bevel=.003)
for side in (-1,1):
 box('Top brass bracket rail',(side*.086,.09,.428),(.012,.20,.009),gold,bevel=.002)
box('Top brass bracket crosspiece',(0,-.008,.428),(.182,.014,.009),gold,bevel=.002)
# Raked grip with inset slabs and heel.
grip_pts=[(-.25,.255),(-.075,.20),(-.15,.04),(-.21,-.23),(-.42,-.29),(-.415,-.22),(-.32,.035)]
profile('Grip carved frame',grip_pts,.138,black,'Grip',bevel=.007)
for s in (-1,1):
 profile('Grip navy slab '+str(s),[(-.257,.22),(-.106,.18),(-.181,.027),(-.24,-.21),(-.388,-.25),(-.29,.04)],.018,navy,'Grip',s*.073,.006)
 profile('Grip brass inlaid edge '+str(s),[(-.27,.21),(-.279,.21),(-.314,.045),(-.405,-.244),(-.391,-.249),(-.30,.043)],.006,gold,'Grip',s*.085,.001)
 cyl('Grip brass fastener '+str(s),(s*.09,-.29,-.185),.016,.008,gold,'Grip','X',24)
 cyl('Grip fastener recess '+str(s),(s*.096,-.29,-.185),.008,.003,black,'Grip','X',24)
profile('Brass heel cap',[(-.43,-.225),(-.22,-.181),(-.20,-.235),(-.412,-.304),(-.443,-.287)],.171,gold,'Grip',bevel=.007)
# Open trigger guard constructed as a polygon strip, not a filled block.
profile('Trigger guard',[(-.083,.19),(-.04,.177),(-.018,.09),(.027,.007),(.135,-.005),(.16,.019),(.14,.04),(.048,.031),(.013,.101),(.005,.186)],.053,navy,'Receiver',bevel=.004)
profile('Curved brass trigger',[(.065,.18),(.107,.178),(.099,.127),(.074,.074),(.04,.044),(.026,.056),(.053,.095),(.071,.137)],.023,gold,'Trigger',bevel=.003)
# Upper mounts and concentric disk; rotation pivot exactly on emitter axis.
box('Upper locking bridge',(0,.31,.421),(.23,.12,.044),gold)
box('Upper locking bridge inset',(0,.31,.451),(.12,.10,.015),navy)
cyl('Rotor stationary bearing',(0,.395,.30),.15,.085,black,'MuzzleMount')
annulus('Stationary brass bearing lip',.115,.157,.39,.42,gold,'MuzzleMount')
annulus('Disk structural black backing',.095,.382,.43,.57,black)
annulus('Ivory outer annulus',.337,.385,.443,.595,ivory)
annulus('Navy concentric inlay',.300,.337,.441,.600,navy)
annulus('Ivory inner annulus',.258,.300,.446,.597,ivory)
annulus('Outer ivory barrel wrap',.384,.390,.448,.59,ivory)
annulus('Outer navy barrel band',.389,.392,.496,.539,navy)
for yy in (.444,.588):annulus('Outer rim fine brass trim',.383,.393,yy,yy+.006,gold)
for ri,ro in [(.334,.339),(.297,.302),(.250,.259)]:annulus('Fine brass ring %.3f'%ri,ri,ro,.441,.602,gold)
# Concentric recessed chamber follows the approved front orthographic reference.
annulus('Recessed emitter bowl',.106,.25,.448,.556,black)
for i in range(16):
 a=i*2*math.pi/16+.012;b=(i+1)*2*math.pi/16-.012
 annulus('Radial stone chamber tile %02d'%i,.122,.245,.545,.575,navy,segments=5,start=a,end=b)
for i in range(64):
 a=i*2*math.pi/64
 annulus('Fine radial amber ray %02d'%i,.159,.205 if i%4==0 else .191,.576,.578,runes,segments=1,start=a,end=a+.0028)
 annulus('Inner ray termination %02d'%i,.153,.162,.577,.580,runes,segments=1,start=a-.004,end=a+.004)
for i in range(4):
 a=i*math.pi/2
 annulus('Chamber cardinal brass brace %02d'%i,.118,.246,.577,.589,gold,segments=3,start=a-.065,end=a+.065)
# Each ivory course has chipped radial joints and branching incisions.
for ri,ro,yy,count in [(.34,.382,.596,40),(.260,.297,.599,32)]:
 for i in range(count):
  a=(i+.24)*2*math.pi/count
  annulus('Ivory carved joint %s %02d'%(ri,i),ri,ro,yy,yy+.0008,stone_cut,segments=1,start=a,end=a+.003)
  annulus('Ivory joint worn lip %s %02d'%(ri,i),ri,ro,yy+.0008,yy+.0014,ivory,segments=1,start=a+.003,end=a+.005)
  if i%3==0:
   annulus('Branched stone crack %s %02d'%(ri,i),ri+.008,ro-.006,yy+.0009,yy+.0015,stone_cut,segments=2,start=a+.008,end=a+.012)
  if i%4==1:
   annulus('Stone chipped edge %s %02d'%(ri,i),ro-.005,ro,yy+.001,yy+.002,stone_cut,segments=1,start=a-.018,end=a+.007)
for i in range(32):
 a=(i+.5)*2*math.pi/32
 annulus('Engraved navy index %02d'%i,.311,.323,.601,.602,gold,segments=1,start=a,end=a+.0025)
# Outer barrel course joints remain visible from the side.
for i in range(36):
 a=i*2*math.pi/36
 annulus('Outer barrel stone joint %02d'%i,.3895,.391,.452,.586,stone_cut,segments=1,start=a,end=a+.0025)
# Cardinal clamps turn with ring.
for i in range(4):
 a=i*math.pi/2;x=.348*math.sin(a);z=.30+.348*math.cos(a)
 o=box('Cardinal brass clamp %d'%i,(x,.527,z),(.071,.192,.114),gold,'RingRotor',.008);o.rotation_euler[1]=a
 o=box('Cardinal clamp face %d'%i,(x,.631,z),(.052,.023,.077),edge,'RingRotor',.004);o.rotation_euler[1]=a
 o=box('Cardinal clamp recess %d'%i,(x,.645,z),(.028,.004,.041),black,'RingRotor',.004);o.rotation_euler[1]=a
# The front reference specifies a round amber core, inset into a brass bezel.
annulus('Core brass bezel',.074,.118,.56,.612,gold,'Core')
annulus('Core inner polished rim',.069,.078,.599,.619,edge,'Core')
for i in range(12):
 a=i*math.pi/6
 annulus('Core bezel tooth %02d'%i,.081,.120,.607,.622,edge,'Core',segments=2,start=a+.025,end=a+.17)
# Coarse sphere facets preserve volume and amber reflections instead of a flat disk.
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1,location=(0,.594,.30))
o=bpy.context.object;o.scale=(.070,.039,.070);finish(o,'Amber core faceted orb',core,'Core',0)
def filament(name,points,radius,mat,g='Core'):
 bpy.ops.object.select_all(action='DESELECT')
 curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=radius;curve.bevel_resolution=0;curve.resolution_u=1
 spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
 for v,co in zip(spline.points,points):v.co=(*co,1)
 ob=bpy.data.objects.new(name,curve);scene.collection.objects.link(ob);bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.convert(target='MESH');return finish(bpy.context.object,name,mat,g,0)
# Fine branching light paths hug the curved orb; the shell and veins are separately
# emissive so their exported energy difference survives runtime color changes.
for i in range(9):
 a=i*2*math.pi/9
 points=[]
 for j in range(5):
  r=j*.014;t=a+(math.sin(i*3+j*2)*.15 if j else 0)
  points.append((r*math.sin(t),.595+.040*math.sqrt(max(0,1-(r/.071)**2)),.30+r*math.cos(t)))
 filament('Core luminous fracture %02d'%i,points,.00065,heart_fire)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=.007,location=(0,.635,.30));finish(bpy.context.object,'Core bright inner spark',heart_fire,'Core',0)
# Small exposed fasteners and double brass seams break up receiver slabs.
for side in (-1,1):
 for y,z in [(-.22,.322),(.15,.254),(.29,.33)]:
  cyl('Receiver countersunk rivet',(side*.119,y,z),.006,.004,gold,'Receiver','X',12)
 for k in range(4):
  y=-.13+k*.035
  profile('Receiver engraved step',[(y,.353),(y+.019,.353),(y+.019,.346),(y,.346)],.003,black,x=side*.097,bevel=.0005)
# Fine engraved panel cracks become deliberately shallow dark inlays.
for s in (-1,1):
 for k,(y,z) in enumerate([(-.22,.15),(-.28,-.04),(-.32,-.11)]):
  profile('Grip etched fracture %s %s'%(s,k),[(y,z),(y+.05,z-.015),(y+.067,z-.046),(y+.066,z-.05),(y+.046,z-.019),(y-.003,z-.004)],.002,gold,'Grip',s*.084,0)
# Animate rotor, keeping original objects and mesh detail editable.
rotor=groups['RingRotor'];rotor.rotation_mode='XYZ'
for frame,angle in [(1,0),(121,2*math.pi)]:rotor.rotation_euler[1]=angle;rotor.keyframe_insert('rotation_euler',frame=frame)
rotor.animation_data.action.name='Ring_Spin'
scene.frame_start=1;scene.frame_end=120;scene.render.fps=30;scene.frame_set(1)
# Match manifest target length from evaluated full bounds, preserving grip origin.
bpy.context.view_layer.update()
bounds=[o.matrix_world @ Vector(c) for o in parts for c in o.bound_box]
scale=.95/(max(v.y for v in bounds)-min(v.y for v in bounds))
root.scale=(scale,)*3
bpy.context.view_layer.update()
# Join evaluated duplicates only: preserve source mesh parts and non-destructive modifiers.
export_meshes=[]
depsgraph=bpy.context.evaluated_depsgraph_get()
for group_name,parent in groups.items():
 copies=[]
 for source in [p for p in parts if p.parent==parent]:
  mesh=bpy.data.meshes.new_from_object(source.evaluated_get(depsgraph))
  copy=bpy.data.objects.new(source.name+'_export',mesh);scene.collection.objects.link(copy);copy.matrix_world=source.matrix_world.copy();copies.append(copy)
 bpy.ops.object.select_all(action='DESELECT')
 for copy in copies:copy.select_set(True)
 bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();merged=bpy.context.object;merged.name=group_name+'_Mesh'
 world=merged.matrix_world.copy();merged.parent=parent;merged.matrix_world=world;export_meshes.append(merged)
bpy.ops.object.select_all(action='DESELECT')
for o in [root,*groups.values(),*export_meshes]:o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(OUT/'monument_heart.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_extras=True,export_animations=True,export_frame_range=True)
for o in export_meshes:bpy.data.objects.remove(o,do_unlink=True)
dg=bpy.context.evaluated_depsgraph_get();tri=0
for o in parts:
 me=o.evaluated_get(dg).to_mesh();me.calc_loop_triangles();tri+=len(me.loop_triangles);o.evaluated_get(dg).to_mesh_clear()
(OUT/'monument_heart_stats.json').write_text(json.dumps({'status':'refined_pending_review','length_m':.95,'triangles':tri,'editable_mesh_parts':len(parts),'assemblies':list(groups),'materials':len({m.name for p in parts for m in p.data.materials}),'runtime_meshes':6,'runtime_material_surfaces':sum(len({m.name for p in parts if p.parent==parent for m in p.data.materials}) for parent in groups.values()),'forward':'-Z in Godot','origin':'grip centre','animation':'Ring_Spin, 4 seconds','core_material':core.name,'ring_material':runes.name,'notes':'Reference geometry interpreted by hand; hidden reverse authored; 1024px tiled basecolor, packed ORM and tangent normal maps; patinated bevel materials; non-unique UVs; no collision or hand rig.'},indent=2))
# Actual Blender renders for review. Studio objects excluded from GLB.
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.075,.095,.14,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.view_settings.view_transform='AgX';scene.render.film_transparent=False
# Blender 5.2 compositor socket API; glow is a review effect, materials remain portable.
nt=bpy.data.node_groups.new('MonumentPreview','CompositorNodeTree');scene.compositing_node_group=nt
nt.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
rl=nt.nodes.new('CompositorNodeRLayers');gl=nt.nodes.new('CompositorNodeGlare')
gl.inputs['Type'].default_value='Fog Glow';gl.inputs['Threshold'].default_value=1.5;gl.inputs['Strength'].default_value=.35
out=nt.nodes.new('NodeGroupOutput');nt.links.new(rl.outputs['Image'],gl.inputs['Image']);nt.links.new(gl.outputs['Image'],out.inputs['Image'])
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,col,size in [('Key',(1.4,1.8,2),180,(1,.87,.70),1.7),('Rim',(-1.4,-.6,1.1),230,(.54,.73,1),1.2),('Fill',(2,1,.6),125,(1,.95,.85),1.0)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=col;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;aim(o,(0,.2,.2))
bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='ReviewCamera';cam.data.type='ORTHO';scene.camera=cam
views={'hero':((1.5,2.1,1.15),(0,.15,.18),1.25),'side':((2,.16,.19),(0,.16,.19),1.22),'front':((0,3,.18),(0,.20,.18),1.18),'top':((0,.16,3),(0,.16,.1),1.18)}
for name,(pos,target,scale) in views.items():
 cam.location=pos;aim(cam,target);cam.data.ortho_scale=scale;scene.render.filepath=str(PRE/(name+'.png'))
 if name=='hero':bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'monument_heart.blend'))
 bpy.ops.render.render(write_still=True)
print('MONUMENT_COMPLETE',tri,len(parts),flush=True)
