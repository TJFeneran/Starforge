"""Blender-only Rare Needle reconstruction. No network or generation services.
Run: blender -b --factory-startup --python-exit-code 1 --python tools/build_rare_needle.py
Editable source in assets/source/blender/rare_needle; Godot -Z forward GLB.
"""
from pathlib import Path
import json
import math
import bpy
import bmesh
import numpy as np
import struct
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/blender/rare_needle'
OUTPUT = ROOT / 'assets/models/gear/guns/rare_needle'
for directory in (SOURCE, OUTPUT):
    directory.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
parts = []
materials = {}


def material(name, color, metallic=0.0, roughness=.35, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1)
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Metallic'].default_value = metallic
    node.inputs['Roughness'].default_value = roughness
    node.inputs['Emission Color'].default_value = (*color, 1)
    node.inputs['Emission Strength'].default_value = emission
    if emission == 0:
        # Exportable worn satin PBR maps, packed in source and GLB.
        N=512; rng=np.random.default_rng(sum(map(ord,name))); yy,xx=np.mgrid[:N,:N]
        fine=rng.normal(size=(N,N)); band=np.sin(xx*.035+np.sin(yy*.019))*0.5
        scratches=np.zeros((N,N))
        for k in range(90):
            x,y=rng.integers(0,N,2); length=int(rng.integers(4,35)); scratches[y,x:min(N,x+length)]=rng.uniform(.1,.35)
        rgb=np.array(color)[None,None,:]*(1+fine[:,:,None]*.015+band[:,:,None]*.025)+scratches[:,:,None]*.045
        rough=np.clip(roughness+fine*.018+band*.025+scratches*.05,0,1)
        h=fine*.001+scratches*.003; dx=np.roll(h,-1,1)-np.roll(h,1,1);dy=np.roll(h,-1,0)-np.roll(h,1,0)
        norm=np.stack((-dx*3,-dy*3,np.ones_like(dx)),2);norm/=np.linalg.norm(norm,axis=2)[:,:,None]
        def tex(suffix,data,non=False):
            safe=name.replace(' | ','_').replace(' ','_');im=bpy.data.images.new(safe+'_'+suffix,width=N,height=N,alpha=False)
            if non:im.colorspace_settings.name='Non-Color'
            pixels=np.ones((N,N,4),np.float32);pixels[:,:,:3]=np.clip(data,0,1);im.pixels.foreach_set(pixels.ravel());im.filepath_raw=str(OUTPUT/(im.name+'.png'));im.file_format='PNG';im.save();im.pack();t=mat.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;return t
        t=tex('basecolor',rgb);mat.node_tree.links.new(t.outputs['Color'],node.inputs['Base Color'])
        t=tex('orm',np.stack((np.ones_like(dx),rough,np.full_like(dx,metallic)),2),True);sep=mat.node_tree.nodes.new('ShaderNodeSeparateColor');mat.node_tree.links.new(t.outputs['Color'],sep.inputs['Color']);mat.node_tree.links.new(sep.outputs['Green'],node.inputs['Roughness']);mat.node_tree.links.new(sep.outputs['Blue'],node.inputs['Metallic'])
        t=tex('normal',norm*.5+.5,True);nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.3;mat.node_tree.links.new(t.outputs['Color'],nm.inputs['Color']);mat.node_tree.links.new(nm.outputs['Normal'],node.inputs['Normal'])
    materials[name] = mat
    return name


def finish(obj, name, mat, bevel=0, smooth=False, group='Receiver'):
    obj.name = name
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if obj.type != 'MESH':
        bpy.ops.object.convert(target='MESH')
        obj = bpy.context.object
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    if bevel:
        mod = obj.modifiers.new('Machined edge radius', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for face in obj.data.polygons:
        face.use_smooth = smooth
    if bevel:
        mod = obj.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
        mod.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(materials[mat])
    uv=obj.data.uv_layers.new(name='SurfaceUV')
    for face in obj.data.polygons:
        axis=max(range(3),key=lambda j:abs(face.normal[j]));a,b=[(1,2),(0,2),(0,1)][axis]
        for i in face.loop_indices:
            v=obj.data.vertices[obj.data.loops[i].vertex_index].co;uv.data[i].uv=(v[a]*8+.5,v[b]*8+.5)
    obj['assembly'] = group
    parts.append(obj)
    obj.select_set(False)
    return obj


def profile(name, points, width, mat, y=0, bevel=.004, group='Receiver'):
    n = len(points)
    verts = [(x, y + sign*width/2, z) for sign in (-1, 1) for x, z in points]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, bevel, group=group)


def tube(name, points, radius, mat, cyclic=False, group='Detail'):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 8
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for point, co in zip(spline.bezier_points, points):
        point.co = co
        point.handle_left_type = 'AUTO'
        point.handle_right_type = 'AUTO'
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, smooth=True, group=group)


def trim(name, points, y, radius, mat, cyclic=False, group='Detail'):
    return tube(name, [(x, y, z) for x, z in points], radius, mat, cyclic, group)


def cylinder(name, center, radius, depth, mat, axis='X', vertices=32, group='Mechanism'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center)
    obj = bpy.context.object
    if axis == 'X':
        obj.rotation_euler[1] = math.pi/2
    elif axis == 'Y':
        obj.rotation_euler[0] = math.pi/2
    return finish(obj, name, mat, .001, True, group)


def ring(name, center, radius, thickness, mat, axis='X', group='Barrel'):
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=8, location=center,
                                   major_radius=radius, minor_radius=thickness)
    obj = bpy.context.object
    if axis == 'X':
        obj.rotation_euler[1] = math.pi/2
    elif axis == 'Y':
        obj.rotation_euler[0] = math.pi/2
    return finish(obj, name, mat, smooth=True, group=group)


def bolt(x, y, z, mat, dark, radius=.005):
    sign = 1 if y > 0 else -1
    cylinder('Flush fastener', (x,y,z), radius, .0025, mat, 'Y', 16, 'Detail')
    trim('Fastener slot', [(x-radius*.55,z),(x+radius*.55,z)], y+sign*.0017, .00055, dark)


def faceted_lance(stations, silver, edge, dark):
    # Six-sided flattened blade section: ridged crown, wide planar cheeks,
    # sharpened lateral edges and a nearly straight ventral line.
    section = [(0,1), (.72,.58), (1,-.18), (0,-1), (-1,-.18), (-.72,.58)]
    vertices = [(x, y*width, z+height*dz) for x,width,height,z in stations for y,dz in section]
    faces = [tuple(reversed(range(6)))]
    for j in range(len(stations)-1):
        for i in range(6):
            faces.append((j*6+i, j*6+(i+1)%6, (j+1)*6+(i+1)%6, (j+1)*6+i))
    faces.append(tuple(range((len(stations)-1)*6, len(stations)*6)))
    mesh = bpy.data.meshes.new('Faceted continuous Needle shroud')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('Faceted continuous Needle shroud', mesh)
    bpy.context.collection.objects.link(obj)
    finish(obj, obj.name, silver, group='Barrel')
    obj.data.materials.append(materials[edge])
    obj.data.materials.append(materials[dark])
    for i, face in enumerate(obj.data.polygons):
        if 0 < i < len(faces)-1:
            face.material_index = 1 if (i-1)%6 in (1,2,3,4) else 0
    return obj


def guard_band(outer, inner, mat):
    n = len(outer)
    assert len(inner) == n
    width = .027
    vertices = [(x,y,z) for y in (-width/2,width/2) for ring_ in (outer,inner) for x,z in ring_]
    faces = []
    for i in range(n):
        j = (i+1)%n
        faces += [(i,j,n+j,n+i), (2*n+i,3*n+i,3*n+j,2*n+j),
                  (i,2*n+i,2*n+j,j), (n+i,n+j,3*n+j,3*n+i)]
    mesh = bpy.data.meshes.new('Open trigger guard')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('Open trigger guard', mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, obj.name, mat, .003, group='Frame')


def export_asset():
    # Same authored-coordinate mapping and grip attachment as build_dawnseal.py.
    # Neither grip nor receiver is stretched to create the extra barrel length.
    transform = Matrix.Scale(.42, 4) @ Matrix.Rotation(-math.pi/2, 4, 'Z') @ Matrix.Translation(Vector((-.80, 0, .105)))
    editable = bpy.data.collections.new('NEEDLE | editable components')
    bpy.context.scene.collection.children.link(editable)
    for obj in parts:
        obj.matrix_world = transform @ obj.matrix_world
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        editable.objects.link(obj)
    export_collection = bpy.data.collections.new('EXPORT | game assemblies')
    bpy.context.scene.collection.children.link(export_collection)
    exports = []
    for group in sorted({obj['assembly'] for obj in parts}):
        bpy.ops.object.select_all(action='DESELECT')
        duplicates = []
        for original in (obj for obj in parts if obj['assembly'] == group):
            obj = original.copy()
            obj.data = original.data.copy()
            export_collection.objects.link(obj)
            obj.select_set(True)
            duplicates.append(obj)
        bpy.context.view_layer.objects.active = duplicates[0]
        bpy.ops.object.join()
        merged = bpy.context.object
        merged.name = 'RareNeedle_' + group
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        # Real UVs for later texture work; materials already export as glTF PBR.
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.015)
        bpy.ops.object.mode_set(mode='OBJECT')
        bm = bmesh.new()
        bm.from_mesh(merged.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0000001)
        bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=0.0000001)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        collapsed = [face for face in bm.faces if face.calc_area() <= 1e-14]
        if collapsed:
            bmesh.ops.delete(bm, geom=collapsed, context='FACES_ONLY')
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(merged.data)
        bm.free()
        merged.data.update()
        exports.append(merged)
    points = [obj.matrix_world @ vertex.co for obj in exports for vertex in obj.data.vertices]
    dims = [max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
    assert .65 < dims[1] < .72, f'Needle must retain its long concept silhouette: {dims}'
    grip_points = [obj.matrix_world @ v.co for obj in exports if obj.name == 'RareNeedle_Grip' for v in obj.data.vertices]
    grip_height = max(p.z for p in grip_points)-min(p.z for p in grip_points)
    assert .135 < grip_height < .17, f'Grip must stay Dawnseal-sized: {grip_height}'
    for obj in exports:
        assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
        assert len(obj.data.uv_layers) > 0
        assert all(poly.area > 1e-14 for poly in obj.data.polygons), f'Degenerate geometry: {obj.name}'
    scene=bpy.context.scene;scene.render.fps=30;scene.frame_start=1;scene.frame_end=13
    pivots=[]
    for group,point in [('Trigger',(.788,0,-.058)),('Bolt',(.90,0,.07))]:
        pivot=bpy.data.objects.new('Needle_'+group+'_Pivot',None);scene.collection.objects.link(pivot);pivot.location=transform@Vector(point);pivots.append(pivot);bpy.context.view_layer.update()
        for obj in [o for o in parts if o['assembly']==group]+[o for o in exports if o.name=='RareNeedle_'+group]:
            world=obj.matrix_world.copy();obj.parent=pivot;obj.matrix_world=world
        base=pivot.location.copy()
        for frame,amount in [(1,0),(3,1),(6,.7),(13,0)]:
            if group=='Trigger':pivot.rotation_euler.x=math.radians(-14)*amount;pivot.keyframe_insert(data_path='rotation_euler',frame=frame)
            else:pivot.location=base+Vector((0,-.005*amount,0));pivot.keyframe_insert(data_path='location',frame=frame)
        pivot.animation_data.action.name='Fire_'+group
    scene.frame_set(1);bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for obj in exports+pivots:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = exports[0]
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT/'rare_needle.glb'), export_format='GLB',
        use_selection=True, export_apply=True, export_yup=True, export_texcoords=True,
        export_normals=True, export_materials='EXPORT', export_cameras=False,
        export_lights=False, export_extras=True)
    # One playable Fire action combines bolt recoil and trigger pull.
    raw=(OUTPUT/'rare_needle.glb').read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);merged={'name':'Fire','samplers':[],'channels':[]}
    for clip in doc.get('animations',[]):
        off=len(merged['samplers']);merged['samplers'].extend(clip['samplers'])
        for channel in clip['channels']:channel['sampler']+=off;merged['channels'].append(channel)
    assert len(merged['channels'])==2
    doc['animations']=[merged];chunk=json.dumps(doc,separators=(',',':')).encode();chunk+=b' '*((-len(chunk))%4);tail=raw[20+n:];(OUTPUT/'rare_needle.glb').write_bytes(struct.pack('<III',0x46546C67,2,20+len(chunk)+len(tail))+struct.pack('<II',len(chunk),0x4E4F534A)+chunk+tail)
    stats = {'dimensions_m': {'width': dims[0], 'length': dims[1], 'height': dims[2]},
        'triangles': sum(len(o.data.polygons) for o in exports), 'assemblies': len(exports),
        'source_parts': len(parts), 'materials': len(materials), 'godot_forward': '-Z',
        'origin': 'Same grip attachment as Dawnseal', 'blender_only': True,
        'dawnseal_reference_length_m': .41731, 'length_ratio_to_dawnseal': dims[1]/.41731,
        'source_concepts': 'assets/source/concepts/gear/meshy_views_v2/gun_sidearm_rare_needle',
        'animations': ['Fire'], 'animation_seconds': .4, 'embedded_images':len(doc.get('images',[])), 'emissive':True, 'materials_note': 'Six 512px basecolor/ORM/normal sets, embedded in GLB; independently controllable cyan emission'}
    (OUTPUT/'rare_needle_stats.json').write_text(json.dumps(stats, indent=2)+'\n')
    # Persist orthographic concept images as packed, hidden modeling references.
    references = bpy.data.collections.new('REFERENCE | packed concept views (hidden)')
    scene = bpy.context.scene
    scene.collection.children.link(references)
    for view in ('side', 'three_quarter', 'top'):
        image = bpy.data.images.load(str(ROOT/'assets/source/concepts/gear/meshy_views_v2/gun_sidearm_rare_needle'/f'{view}.png'))
        image.pack()
        ref = bpy.data.objects.new('Concept_' + view, None)
        references.objects.link(ref)
        ref.empty_display_type = 'IMAGE'
        ref.data = image
        ref.empty_display_size = .6
        ref.hide_render = True
    references.hide_viewport = True
    references.hide_render = True
    export_collection.hide_render = True
    export_collection.hide_viewport = True
    bpy.ops.object.select_all(action='DESELECT')
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    # Open the editable source framed on the weapon, without preview cameras/lights.
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == 'VIEW_3D':
                space = area.spaces.active
                space.shading.type = 'MATERIAL'
                space.region_3d.view_location = transform @ Vector((.40,0,-.055))
                space.region_3d.view_distance = .8
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'rare_needle.blend'))
    render_reviews()
    print('RARE_NEEDLE_STATS', json.dumps(stats), flush=True)


def render_reviews():
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True;scene.render.resolution_x=1100;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
    scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.045,.055,.075,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
    target=(0,.22,.006)
    def aim(o):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    for name,loc,power,col,size in [('Key',(.5,.6,1),100,(1,.95,.88),.8),('Rim',(-.5,.4,.6),90,(.65,.8,1),.7),('Fill',(.4,-.4,.2),60,(1,1,1),.7)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=col;d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;aim(o)
    bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';scene.camera=cam;pre=SOURCE/'previews';pre.mkdir(exist_ok=True)
    for name,pos,scale in [('hero',(-.85,.75,.5),.86),('side',(-1.5,.22,.006),.80),('top',(0,.22,1.5),1.08),('front',(0,1.5,.006),.42)]:
        cam.location=pos;aim(cam);cam.data.ortho_scale=scale;scene.render.filepath=str(pre/(name+'.png'));bpy.ops.render.render(write_still=True)


def build():
    white = material('Needle | satin silver ceramic', (.70,.75,.77), .48, .29)
    silver = material('Needle | brushed titanium edges', (.39,.47,.52), .85, .28)
    dark = material('Needle | charcoal mechanism', (.027,.038,.046), .72, .34)
    navy = material('Needle | midnight grip', (.013,.023,.032), .12, .56)
    black = material('Needle | recessed channels', (.006,.010,.014), .25, .43)
    gold = material('Needle | brass pivot', (.64,.38,.115), .88, .26)
    cyan = material('Needle | pale cyan conductors', (.10,.70,.85), .2, .24, 2.8)

    # Receiver remains at the same .42-m authored scale as Dawnseal. The
    # needle extends to x=-.59; the grip/receiver are not globally stretched.
    receiver = [(.48,.039),(.56,.095),(.70,.113),(.87,.103),(.947,.074),(.969,.035),(.952,-.009),(.888,-.038),(.786,-.065),(.622,-.061),(.534,-.034)]
    profile('Compact charcoal receiver',receiver,.116,dark,bevel=.009)
    upper = [(.42,.037),(.511,.084),(.625,.111),(.759,.119),(.822,.095),(.805,.064),(.711,.067),(.637,.035),(.562,.011)]
    profile('Stepped silver receiver crown',upper,.102,white,bevel=.004)
    profile('Rear breech cap',[(.846,.103),(.906,.089),(.964,.053),(.969,.020),(.946,.007),(.907,.033),(.852,.047)],.111,silver,bevel=.008,group='Bolt')
    profile('Rear sight base',[(.822,.106),(.876,.106),(.893,.097),(.893,.085),(.822,.093)],.066,dark,bevel=.003)
    for s in (-1,1):
        profile('Rear sight ear',[(.832,.105),(.850,.133),(.870,.133),(.870,.105)],.012,dark,s*.025,.002)
        root_cheek = [(.465,.027),(.56,.065),(.63,.065),(.691,.039),(.707,-.003),(.655,-.035),(.558,-.042),(.491,-.019)]
        profile('Angular silver root cheek',root_cheek,.012,white,s*.061,.003)
        recess = [(.502,.024),(.574,.046),(.637,.034),(.661,.014),(.595,.012),(.55,-.010)]
        profile('Triangular root recess',recess,.003,black,s*.068,.001)
        trim('Root recess bevel',[(.515,.022),(.575,.038),(.629,.029)],s*.070,.0015,silver)
        profile('Lower white projecting cheek',[(.556,-.025),(.656,-.027),(.701,-.016),(.679,-.052),(.588,-.057),(.549,-.041)],.018,white,s*.050,.003)
        trim('Upper cyan status inset',[(.591,.095),(.660,.101),(.715,.100)],s*.052,.004,black)
        trim('Upper cyan status light',[(.600,.096),(.660,.102),(.708,.101)],s*.055,.0015,cyan)
        for x,z in ((.554,-.029),(.727,.087),(.890,.043)):
            bolt(x,s*.070,z,silver,black,.004)
        # Small machined gold pivot, not an oversized ornament or glowing disk.
        cylinder('Pivot dark socket',(.738,s*.063,.012),.048,.012,dark,'Y',48)
        ring('Pivot silver retaining ring',(.738,s*.071,.012),.038,.003,silver,'Y','Mechanism')
        cylinder('Recessed brass pivot',(.738,s*.073,.012),.032,.004,gold,'Y',48)
        cylinder('Pivot center spindle',(.738,s*.076,.012),.017,.002,dark,'Y',32)
        cylinder('Pivot brass hub',(.738,s*.078,.012),.010,.002,gold,'Y',32)
        trim('Pivot tool slot',[(.733,.012),(.743,.012)],s*.0795,.001,black)
        for i in range(3):
            x = .818+i*.024
            trim('Breech transverse seam',[(x,.075),(x+.014,.049),(x+.013,.017)],s*.059,.0016,black)

    # V2 rear view shows two separate bolt rails, plus diagonal shroud vents.
    for z in (.072,.025):
        cylinder('Rear exposed bolt cylinder',(.975,0,z),.018,.083,dark,'X',24,'Bolt')
        ring('Bolt rail titanium end ring',(1.015,0,z),.016,.0025,silver,'X','Bolt')
    for sign in (-1,1):
        profile('Shroud vent recess',[(.305,.039),(.478,.047),(.454,.018),(.297,.015)],.003,black,sign*.044,.001,'Barrel')
        for i in range(4):
            x=.32+i*.035
            trim('Diagonal vent louver',[(x,.017),(x+.024,.041)],sign*.046,.0019,silver,group='Barrel')
    tube('Dorsal cyan status inset',[(.59,0,.114),(.64,0,.12),(.70,0,.125)],.006,black,group='Energy')
    tube('Dorsal cyan status glass',[(.60,0,.119),(.64,0,.125),(.69,0,.130)],.003,cyan,group='Energy')
    stations = [(-.590,.0007,.0007,.009),(-.49,.005,.006,.010),(-.30,.012,.013,.014),
                (-.07,.021,.025,.024),(.17,.030,.037,.036),(.38,.041,.049,.047),(.54,.052,.058,.052),(.606,.048,.052,.050)]
    faceted_lance(stations,white,silver,dark)
    # Inset-like narrow emissive strips follow the planar tapered cheeks.
    # Their width stays tiny so the silver blade is the dominant silhouette.
    for s in (-1,1):
        channel = [(-.228,s*.014,.012),(-.06,s*.022,.019),(.16,s*.032,.029),(.325,s*.040,.037)]
        tube('Dark longitudinal conductor recess',channel,.0042,black,group='Barrel')
        tube('Fine cyan blade conductor',[(x,y+s*.006,z+.0003) for x,y,z in channel],.0028,cyan,group='Energy')
        tube('Blade termination silver lip',[(.324,s*.042,.037),(.349,s*.044,.049)],.002,silver,group='Barrel')
        tube('Dorsal panel break',[(.360,s*.031,.075),(.405,s*.044,.033),(.480,s*.047,.027)],.0012,dark,group='Barrel')
    tube('Central dorsal ridge',[(-.49,0,.016),(-.07,0,.049),(.17,0,.073),(.38,0,.096),(.54,0,.110)],.0012,white,group='Barrel')

    # Thin rigid guard with genuine negative space; no filled polygon aperture.
    guard_band([(.646,-.050),(.675,-.145),(.709,-.163),(.800,-.156),(.851,-.101),(.833,-.051)],
               [(.662,-.061),(.688,-.132),(.714,-.147),(.790,-.141),(.834,-.096),(.821,-.064)],dark)
    tube('Independent curved trigger',[(.788,0,-.056),(.778,0,-.086),(.753,0,-.119),(.735,0,-.123)],.005,dark,group='Trigger')
    cylinder('Trigger pivot',(.788,0,-.058),.010,.037,silver,'Y',24,'Trigger')
    for s in (-1,1):
        trim('Guard machined edge',[(.679,-.140),(.709,-.155),(.797,-.149)],s*.014,.0011,silver)

    # Dawnseal grip reference: z=.02 to -.341, width=.10 authored units.
    grip = [(.816,.016),(.895,.020),(.912,-.055),(.928,-.112),(.966,-.205),(1.011,-.294),(.998,-.323),(.889,-.340),(.868,-.320),(.856,-.251),(.835,-.174),(.806,-.105),(.793,-.043)]
    profile('Raked grip chassis',grip,.094,dark,bevel=.009,group='Grip')
    panel = [(.835,-.032),(.878,-.024),(.894,-.084),(.917,-.145),(.950,-.221),(.983,-.293),(.900,-.311),(.883,-.268),(.867,-.208),(.845,-.150),(.819,-.087)]
    for s in (-1,1):
        profile('Recessed navy grip face',panel,.009,navy,s*.049,.005,'Grip')
        trim('Grip titanium border',panel,s*.055,.0015,silver,True,'Grip')
        bolt(.854,s*.057,-.063,silver,black,.004)
        bolt(.947,s*.057,-.289,silver,black,.004)
        # Restrained diagonal machined grip grooves, real geometry on both faces.
        for i in range(16):
            z = -.106-i*.0105
            x = .847+i*.0035
            trim('Fine grip traction groove',[(x,z),(x+.038,z+.007)],s*.055,.00065,black,group='Grip')
    shoe = [(.878,-.319),(.996,-.304),(1.016,-.315),(1.009,-.337),(.893,-.354),(.875,-.342)]
    profile('Slim titanium grip base cap',shoe,.104,silver,bevel=.003,group='Grip')
    profile('Dark magazine floor',[(.893,-.345),(1.006,-.328),(1.006,-.341),(.896,-.358)],.081,black,bevel=.002,group='Grip')
    export_asset()


if __name__ == '__main__':
    build()
