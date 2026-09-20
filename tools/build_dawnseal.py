"""Direct Blender reconstruction of the three meshy_views_v2 Dawnseal side/top/front references.
Run: blender --background --factory-startup --python tools/build_dawnseal.py
No external generation services. Units: meters; Godot forward: -Z.
"""
from pathlib import Path
import json
import math
import sys
import bpy
import numpy as np
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/blender/dawnseal'
OUTPUT = ROOT / 'assets/models/gear/guns/dawnseal'
PREVIEW = SOURCE / 'previews'
for directory in (SOURCE, OUTPUT, PREVIEW):
    directory.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for block in list(bpy.data.materials):
    bpy.data.materials.remove(block)

# UV-addressed hard-surface PBR atlas plus independently editable solar emission.
# All surfaces use actual PNG texture maps rather than Blender-only shader noise.
PALETTE = [
    ('Ivory ceramic', (0.79, .78, .70), .26, .15),
    ('Midnight enamel', (.038, .065, .105), .27, .38),
    ('Antique gold', (.68, .46, .18), .29, 1.0),
    ('Polished gold', (.90, .67, .31), .22, 1.0),
    ('Cobalt enamel', (.025, .15, .43), .18, .40),
    ('Blackened steel', (.022, .030, .038), .40, .83),
    ('Warm brass', (.42, .25, .075), .32, 1.0),
    ('Contained dawn energy', (1.0, .94, .70), .20, .0),
]
SIZE = 2048
TILE_W, TILE_H = SIZE // 4, SIZE // 2
rng = np.random.default_rng(104729)
base = np.ones((SIZE, SIZE, 4), dtype=np.float32)
orm = np.ones_like(base)
emission = np.zeros_like(base)
emission[:, :, 3] = 1
normal = np.ones_like(base)
normal[:, :, :3] = (.5, .5, 1)
for index, (_, color, roughness, metallic) in enumerate(PALETTE):
    row, col = divmod(index, 4)
    ys = slice(row*TILE_H, (row+1)*TILE_H)
    xs = slice(col*TILE_W, (col+1)*TILE_W)
    grain = rng.normal(0, .006, (TILE_H, TILE_W)).astype(np.float32)
    yy, xx = np.mgrid[0:TILE_H, 0:TILE_W]
    brushed = .003*np.sin(yy*2.7 + np.sin(xx*.035))
    wear = np.zeros((TILE_H, TILE_W), dtype=np.float32)
    for _ in range(110 if index in (2, 3, 6) else 50):
        x, y = rng.integers(10, TILE_W-70), rng.integers(10, TILE_H-10)
        length = int(rng.integers(4, 65))
        wear[y:y+1, x:x+length] += rng.uniform(.02, .065)
    variation = grain + brushed + wear
    base[ys, xs, :3] = np.clip(np.array(color)[None, None, :] * (1+variation[:, :, None]*2), 0, 1)
    orm[ys, xs, 0] = 1.0
    orm[ys, xs, 1] = np.clip(roughness + grain*2 + wear, .08, .8)
    orm[ys, xs, 2] = metallic
    normal[ys, xs, 0] = .5 + grain*.3
    normal[ys, xs, 1] = .5 + brushed*.6 + wear*.15
    if index == 7:
        emission[ys, xs, :3] = (1, .88, .48)

def save_image(name, pixels, non_color=False):
    image = bpy.data.images.new(name, width=SIZE, height=SIZE, alpha=True)
    if non_color:
        image.colorspace_settings.name = 'Non-Color'
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw = str(OUTPUT / (name + '.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    return image

images = {
    'base_color': save_image('dawnseal_base_color', base),
    'orm': save_image('dawnseal_orm', orm, True),
    'normal': save_image('dawnseal_normal', normal, True),
    'emission': save_image('dawnseal_emission', emission),
}
mat = bpy.data.materials.new('Dawnseal_PBR_2K')
mat.use_nodes = True
nodes, links = mat.node_tree.nodes, mat.node_tree.links
bsdf = nodes.get('Principled BSDF')
for i, (key, image) in enumerate(images.items()):
    node = nodes.new('ShaderNodeTexImage')
    node.name = key
    node.image = image
    node.location = (-650, 300-i*260)
    if key == 'base_color':
        links.new(node.outputs['Color'], bsdf.inputs['Base Color'])
    elif key == 'orm':
        separate = nodes.new('ShaderNodeSeparateColor')
        links.new(node.outputs['Color'], separate.inputs['Color'])
        links.new(separate.outputs['Green'], bsdf.inputs['Roughness'])
        links.new(separate.outputs['Blue'], bsdf.inputs['Metallic'])
    elif key == 'normal':
        normal_node = nodes.new('ShaderNodeNormalMap')
        normal_node.inputs['Strength'].default_value = .22
        links.new(node.outputs['Color'], normal_node.inputs['Color'])
        links.new(normal_node.outputs['Normal'], bsdf.inputs['Normal'])
    # Emission is exclusive to the separately addressable solar material.

solar = bpy.data.materials.new('Dawnseal_Solar_Chamber_Emission')
solar.use_nodes = True
solar_bsdf = solar.node_tree.nodes.get('Principled BSDF')
solar_bsdf.inputs['Base Color'].default_value = (1.0, .65, .13, 1)
solar_bsdf.inputs['Roughness'].default_value = .24
solar_bsdf.inputs['Emission Color'].default_value = (1.0, .58, .12, 1)
solar_bsdf.inputs['Emission Strength'].default_value = 4.0
solar['runtime_control'] = 'Independent emission color and energy; no atlas mask required'

parts = []

def finish(obj, name, tile, bevel=0, smooth=False, group='Frame'):
    obj.name = name
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if obj.type != 'MESH':
        bpy.ops.object.convert(target='MESH')
        obj = bpy.context.object
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new('Machined edge radii', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = smooth
    if bevel:
        modifier = obj.modifiers.new('Area weighted normals', 'WEIGHTED_NORMAL')
        modifier.keep_sharp = True
        modifier.weight = 40
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.clear()
    obj.data.materials.append(solar if tile == 7 else mat)
    uv = obj.data.uv_layers.new(name='PBR_Trim_UV') if not obj.data.uv_layers else obj.data.uv_layers.active
    coords = np.array([v.co[:] for v in obj.data.vertices])
    lo, span = coords.min(axis=0), np.maximum(np.ptp(coords, axis=0), .0001)
    col, row = tile % 4, tile // 4
    # Box projection inside a padded palette tile; deliberate trim-sheet overlaps.
    for face in obj.data.polygons:
        axis = max(range(3), key=lambda i: abs(face.normal[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for loop_id in face.loop_indices:
            coord = obj.data.vertices[obj.data.loops[loop_id].vertex_index].co
            u = .025 + .95*(coord[a]-lo[a])/span[a]
            v = .025 + .95*(coord[b]-lo[b])/span[b]
            uv.data[loop_id].uv = ((col+u)/4, (row+v)/2)
    obj['assembly'] = group
    obj['finish'] = PALETTE[tile][0]
    parts.append(obj)
    obj.select_set(False)
    return obj

def path(name, points, radius, tile, cyclic=False, group='Ornament', resolution=5):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = resolution
    curve.bevel_depth = radius
    curve.bevel_resolution = 1
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for p, co in zip(spline.bezier_points, points):
        p.co = co
        p.handle_left_type = 'AUTO'
        p.handle_right_type = 'AUTO'
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, tile, smooth=True, group=group)

def profile(name, points, width, tile, center_y=0, bevel=.006, group='Frame'):
    count = len(points)
    vertices = [(x, center_y+y*width/2, z) for y in (-1, 1) for x, z in points]
    faces = [tuple(reversed(range(count))), tuple(range(count, 2*count))]
    faces += [(i, (i+1)%count, (i+1)%count+count, i+count) for i in range(count)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    # Recalculate winding for concave profiles before bevel and export.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    return finish(obj, name, tile, bevel=bevel, group=group)

def ellipsoid(name, center, scale, tile, group='Frame', segments=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=12, location=center)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, tile, smooth=True, group=group)

def cylinder(name, center, radius, depth, tile, axis='X', vertices=48, radius2=None, group='Mechanism'):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius if radius2 is None else radius2, depth=depth, location=center)
    obj = bpy.context.object
    if axis == 'X':
        obj.rotation_euler[1] = math.pi/2
    elif axis == 'Y':
        obj.rotation_euler[0] = math.pi/2
    return finish(obj, name, tile, bevel=.0013, smooth=True, group=group)

def oval_ring(name, center, a, b, tube, tile, plane='YZ', group='Ornament', steps=48):
    vertices, faces = [], []
    c = Vector(center)
    u, v, n = {'YZ': (Vector((0,1,0)), Vector((0,0,1)), Vector((1,0,0))),
               'XZ': (Vector((1,0,0)), Vector((0,0,1)), Vector((0,1,0))),
               'XY': (Vector((1,0,0)), Vector((0,1,0)), Vector((0,0,1)))}[plane]
    sides = 6
    for i in range(steps):
        angle = math.tau*i/steps
        radial = (u*math.cos(angle)+v*math.sin(angle)).normalized()
        mid = c + u*(a*math.cos(angle)) + v*(b*math.sin(angle))
        for j in range(sides):
            theta = math.tau*j/sides
            vertices.append(mid+radial*(tube*math.cos(theta))+n*(tube*math.sin(theta)))
    for i in range(steps):
        for j in range(sides):
            faces.append((i*sides+j, ((i+1)%steps)*sides+j, ((i+1)%steps)*sides+(j+1)%sides, i*sides+(j+1)%sides))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, tile, smooth=True, group=group)

def side_trim(name, points, y, radius=.0024, tile=3, cyclic=True):
    return path(name, [(x,y,z) for x,z in points], radius, tile, cyclic)

def bolt(x, y, z, r=.005):
    sign = 1 if y >= 0 else -1
    cylinder('Inset gold fastener', (x,y,z), r, .003, 2, 'Y', 16)
    path('Fastener slot', [(x-r*.5,y+sign*.002,z),(x+r*.5,y+sign*.002,z)], .00065, 5)

# Layered, flowing receiver: the open chamber remains genuinely hollow.
receiver = [(.34,.074),(.42,.12),(.49,.15),(.53,.151),(.59,.126),(.73,.121),(.82,.102),(.88,.077),(.94,.035),(.93,.019),(.85,.014),(.78,-.037),(.73,-.073),(.62,-.082),(.53,-.065),(.45,-.094),(.37,-.077)]
profile('Receiver midnight core', receiver, .124, 1, bevel=.012)
armor = [(.365,.072),(.441,.117),(.50,.148),(.538,.145),(.575,.119),(.705,.113),(.782,.091),(.803,.060),(.77,.004),(.725,-.048),(.642,-.060),(.552,-.042),(.50,-.062),(.432,-.049),(.39,-.031)]
for s in (-1,1):
    profile('Sculpted ivory receiver shell', armor, .020, 0, s*.061, .008)
    side_trim('Receiver perimeter gilding', armor, s*.073, .0023)
    inset = [(.399,.068),(.459,.101),(.53,.096),(.537,.078),(.501,.049),(.446,.037),(.408,.047)]
    profile('Forward navy cartouche', inset, .007, 1, s*.076, .004)
    side_trim('Cartouche gold lip', inset, s*.081, .0019)
    side_trim('Cartouche diamond',[(.455,.068),(.479,.083),(.500,.068),(.479,.058)],s*.084,.0014)
    for p in ((.551,.100),(.783,.044),(.403,-.039),(.571,-.039)):
        bolt(p[0],s*.079,p[1])

# Barrel lantern: ringed muzzle, deeply recessed emitter, open rail cage.
for x, a, b, tube, tile in ((.036,.088,.106,.013,2),(.016,.088,.106,.004,3),(.058,.089,.106,.004,3),(.040,.074,.090,.007,0),(.027,.067,.081,.004,6)):
    oval_ring('Layered muzzle annulus',(x,0,0),a,b,tube,tile)
oval_ring('Bore inner lip',(.065,0,0),.057,.067,.005,5)
cylinder('Recessed bore shadow',(.092,0,0),.059,.010,5)
for r,x in ((.045,.085),(.033,.079),(.024,.074)):
    oval_ring('Concentric focusing rings',(x,0,0),r,r,.003,3)
cylinder('Muzzle luminous pupil',(.070,0,0),.020,.004,7,group='Energy')
for angle in (0,math.pi/2,math.pi,math.pi*1.5):
    path('Emitter radial brace',[(.079,.025*math.cos(angle),.025*math.sin(angle)),(.051,.067*math.cos(angle),.080*math.sin(angle))],.003,2)
for s in (-1,1):
    cylinder('Muzzle face rivet',(.012,s*.084,0),.005,.004,3)
# Inner body narrows into a ringed brass throat.
ellipsoid('Luminous chamber',(.186,0,0),(.132,.052,.068),7,'Energy',48)
for i in range(7):
    x = .277+i*.011
    radius = .059-i*.0047
    cylinder('Stepped brass chamber coupler',(x,0,0),radius,.009,6 if i%2 else 2)
    oval_ring('Coupler highlight',(x-.004,0,0),radius,radius,.0018,3,steps=32)
cylinder('Chamber feed spindle',(.354,0,0),.020,.033,5)
# Four rails flare at the muzzle, and taper into the receiver shoulder.
for s in (-1,1):
    for t in (-1,1):
        rail = [(.055,s*.039,t*.094),(.092,s*.046,t*.145),(.153,s*.050,t*.133),(.25,s*.057,t*.113),(.332,s*.050,t*.106),(.411,s*.038,t*.081)]
        path('Lantern navy structural rib',rail,.013,1,group='Cage')
        path('Gilded lantern edge',[(x,y+s*.010,z+t*.003) for x,y,z in rail],.0032,3,group='Cage')
        path('Ivory chamber flying brace',[(.156,s*.057,t*.115),(.235,s*.066,t*.086),(.31,s*.058,t*.063),(.40,s*.057,t*.059)],.010,0,group='Cage')
        path('Brace fine gold inlay',[(.156,s*.067,t*.115),(.235,s*.075,t*.086),(.31,s*.068,t*.063),(.40,s*.067,t*.059)],.0018,2,group='Cage')
for z in (-.111,.111):
    profile('Muzzle bridge',[(.01,z-.009),(.071,z-.009),(.081,z+.009),(.018,z+.014)],.036,0,bevel=.003,group='Cage')
    ellipsoid('Muzzle sapphire index',(.041,0,z+( .014 if z>0 else -.012)),(.009,.010,.004),4,'Ornament',20)

# Guard is a continuous ring with real negative space, and an independent trigger.
guard = [(.53,-.061),(.543,-.121),(.58,-.157),(.656,-.161),(.737,-.143),(.782,-.088),(.754,-.057)]
path('Ivory trigger guard',[(x,0,z) for x,z in guard],.015,0,True,'Frame',8)
for s in (-1,1):
    side_trim('Trigger guard gilt edge',guard,s*.013,.0023)
    profile('Guard mounting cheek',[(.499,-.063),(.536,-.065),(.56,-.113),(.545,-.171),(.522,-.156),(.529,-.125)],.012,0,s*.026,.003)
    bolt(.535,s*.035,-.117,.007)
path('Curved trigger blade',[(.721,0,-.071),(.708,0,-.095),(.694,0,-.119),(.669,0,-.127)],.006,5,group='Trigger',resolution=9)
path('Trigger gold edge',[(.718,-.005,-.073),(.705,-.005,-.096),(.692,-.005,-.119),(.669,-.005,-.125)],.0016,3,group='Trigger')
cylinder('Trigger pivot',(.721,0,-.071),.011,.051,2,'Y',24,group='Trigger')

# Swept grip with separate inset enamel panels, ivory backstrap, and flared shoe.
grip = [(.782,.015),(.852,.020),(.866,-.036),(.875,-.084),(.914,-.158),(.956,-.215),(.998,-.269),(.987,-.290),(.848,-.331),(.825,-.315),(.819,-.258),(.806,-.208),(.779,-.143),(.751,-.107),(.742,-.063)]
profile('Swept ivory grip chassis',grip,.088,0,bevel=.013,group='Grip')
grip_panel = [(.801,-.030),(.837,-.024),(.844,-.078),(.888,-.165),(.938,-.232),(.962,-.275),(.861,-.305),(.848,-.284),(.846,-.242),(.827,-.187),(.797,-.131),(.776,-.092)]
for s in (-1,1):
    profile('Midnight enamel grip panel',grip_panel,.010,1,s*.047,.006,'Grip')
    side_trim('Grip gold pinstripe',grip_panel,s*.054,.0021)
    bolt(.826,s*.055,-.071,.0045)
    bolt(.955,s*.055,-.270,.006)
    bolt(.862,s*.055,-.287,.004)
    # Eight-point compass rose in a recessed round navy seal.
    cx, cz, cy = .895,-.236,s*.058
    ellipsoid('Grip seal backing',(cx,cy,cz),(.040,.006,.040),1,'Ornament')
    oval_ring('Grip compass bezel',(cx,cy+s*.004,cz),.038,.038,.0028,2,'XZ')
    oval_ring('Compass inset hairline',(cx,cy+s*.007,cz),.032,.032,.0009,3,'XZ',steps=32)
    star = []
    for i in range(32):
        a = math.tau*i/32
        r = (.029 if i%8==0 else .020) if i%4==0 else .0055
        star.append((cx+math.sin(a)*r,cz+math.cos(a)*r))
    profile('Eight point dawn compass',star,.002,3,cy+s*.009,.0004,'Ornament')
    ellipsoid('Compass center',(cx,cy+s*.011,cz),(.004,.002,.004),2,'Ornament',16)
shoe = [(.840,-.313),(.987,-.272),(1.001,-.280),(.996,-.299),(.850,-.341),(.833,-.331)]
profile('Flared gold grip shoe',shoe,.098,2,bevel=.005,group='Grip')
for s in (-1,1):
    side_trim('Grip shoe bright edge',shoe,s*.050,.0017)
# Subtle physical finger grooves across the front strap.
for i in range(5):
    z = -.17-i*.026
    x = .803 + i*.009
    path('Front strap engraved scallop',[(x,-.026,z+.003),(x-.007,0,z),(x,.026,z+.003)],.0014,5,group='Grip')

# Convex cobalt celestial seals, matching the bilateral bulges in the top view.
for s in (-1,1):
    cx, cz = .66,.024
    ellipsoid('Gold medallion foundation',(cx,s*.077,cz),(.119,.021,.079),2,'Ornament',48)
    oval_ring('Medallion outer polished lip',(cx,s*.091,cz),.111,.071,.0032,3,'XZ')
    ellipsoid('Cobalt cabochon',(cx,s*.097,cz),(.105,.022,.064),4,'Ornament',48)
    oval_ring('Cabochon inner bezel',(cx,s*.103,cz),.103,.063,.0016,2,'XZ')
    def globe_point(dx,dz):
        height = .022*math.sqrt(max(.01,1-(dx/.105)**2-(dz/.064)**2))
        return (cx+dx,s*(.098+height+.0007),cz+dz)
    for rx, rz in ((.083,.023),(.029,.052),(.058,.050)):
        pts = [globe_point(rx*math.cos(math.tau*i/20),rz*math.sin(math.tau*i/20)) for i in range(20)]
        path('Celestial meridian gold wire',pts,.00085,3,True,resolution=2)
    path('Celestial polar axis',[globe_point(0,-.054),globe_point(0,0),globe_point(0,.054)],.0008,3)
    path('Celestial equatorial axis',[globe_point(-.086,0),globe_point(0,0),globe_point(.086,0)],.00065,3)
    for a in range(4):
        theta = a*math.pi/2
        path('Seal central star ray',[globe_point(0,0),globe_point(.014*math.cos(theta),.014*math.sin(theta))],.0012,3)
    for dx,dz in ((-.075,.027),(.066,-.029),(.049,.036)):
        ellipsoid('Seal gold star',globe_point(dx,dz),(.0018,.001,.0018),3,'Ornament',12)

# Centerline top cartouche, orb mount, rear hinge, and ornamental hammer.
profile('Ivory dorsal rail',[(.394,.111),(.50,.150),(.56,.127),(.729,.126),(.807,.112),(.816,.093),(.58,.109),(.50,.134),(.403,.096)],.071,0,bevel=.004)
profile('Dorsal navy inset',[(.445,.135),(.50,.148),(.559,.13),(.706,.13),(.716,.122),(.555,.120),(.50,.138),(.444,.125)],.038,1,bevel=.002)
for s in (-1,1):
    path('Dorsal gilt seam',[(.435,s*.023,.131),(.50,s*.023,.148),(.56,s*.023,.130),(.708,s*.023,.130)],.0018,3)
path('Dorsal center gold motif',[(.493,0,.153),(.534,0,.140),(.637,0,.136),(.68,0,.136)],.0012,3)
cylinder('Top orb ivory socket',(.769,0,.123),.037,.017,0,'Z',40)
oval_ring('Top orb gold rim',(.769,0,.136),.032,.032,.004,2,'XY')
ellipsoid('Cobalt top orb',(.769,0,.136),(.027,.027,.022),4,'Ornament',40)
profile('Rear ivory hinge',[(.800,.115),(.848,.104),(.857,.081),(.802,.088)],.062,0,bevel=.004)
for s in (-1,1):
    bolt(.826,s*.034,.099,.006)
    ellipsoid('Rear sapphire selector',(.86,s*.064,.052),(.013,.005,.010),4,'Mechanism',20)
    path('Rear gilded beak',[(.800,s*.057,.021),(.85,s*.055,.005),(.934,s*.027,.022)],.003,2)
profile('Swept ceremonial hammer',[(.83,.105),(.864,.130),(.875,.156),(.884,.159),(.888,.149),(.881,.118),(.856,.091)],.021,6,bevel=.003,group='Hammer')
for s in (-1,1):
    side_trim('Hammer edge',[(.839,.107),(.869,.132),(.879,.153)],s*.012,.0015,cyclic=False)

# Second silhouette pass: broad navy armor petals instead of skeletal round rails.
for s in (-1, 1):
    for t in (-1, 1):
        petal = [(.046,t*.093),(.070,t*.145),(.104,t*.162),(.154,t*.140),(.232,t*.126),(.316,t*.121),(.385,t*.088),(.347,t*.084),(.280,t*.095),(.209,t*.101),(.126,t*.114),(.081,t*.087)]
        profile('Broad navy lantern shroud',petal,.038,1,s*.041,.005,'Cage')
        side_trim('Shroud gilded perimeter',petal,s*.061,.0024)
        side_trim('Shroud inset chasing',[(.092,t*.141),(.155,t*.126),(.23,t*.115),(.302,t*.110)],s*.062,.0011,cyclic=False)
        bolt(.105,s*.064,t*.133,.003)
    lower_panel = [(.408,-.017),(.465,-.014),(.529,-.038),(.518,-.057),(.454,-.064),(.418,-.047)]
    profile('Lower receiver midnight inset',lower_panel,.008,1,s*.074,.003)
    side_trim('Lower receiver inset lip',lower_panel,s*.079,.0015)
    # Small engraved sunray sweeps frame the medallion without flat image decals.
    for j in range(4):
        side_trim('Shoulder engraved gold rays',[(.531+j*.011,.126-j*.004),(.555+j*.012,.111-j*.004),(.57+j*.014,.097-j*.005)],s*.073,.00075,cyclic=False)
# Widen the enamel insert and slim the visible ivory grip perimeter.
for obj in parts:
    if obj.name.startswith('Midnight enamel grip panel'):
        for vertex in obj.data.vertices:
            vertex.co.x = .872 + (vertex.co.x-.872)*1.13
            vertex.co.z = -.18 + (vertex.co.z+.18)*1.07
    elif obj.name.startswith('Grip gold pinstripe'):
        for vertex in obj.data.vertices:
            vertex.co.x = .872 + (vertex.co.x-.872)*1.13
            vertex.co.z = -.18 + (vertex.co.z+.18)*1.07

# V2 refinement: navy shoulder panels and ivory rear sweep from the side silhouette.
for side in (-1, 1):
    shoulder = [(.451,.123),(.496,.147),(.535,.137),(.566,.112),(.539,.096),(.496,.106)]
    profile('Upper shoulder navy inset', shoulder, .006, 1, side*.076, .003)
    side_trim('Shoulder inset gilding', shoulder, side*.081, .0015)
    tail = [(.809,.028),(.851,.022),(.913,.044),(.938,.038),(.944,.020),(.867,-.001),(.825,-.018)]
    profile('Ivory rear beak armor', tail, .008, 0, side*.062, .003)
    side_trim('Rear beak gold rim', tail, side*.067, .0017)
    # V2's celestial seal has radial starwork across fine orbital engraving.
    for j in range(16):
        angle = math.tau*j/16
        reach = .079 if j%4 == 0 else .059
        dx,dz=math.cos(angle)*reach,math.sin(angle)*reach*.61
        def surface(dx,dz):
            return (.66+dx,side*(.099+.022*math.sqrt(max(.01,1-(dx/.105)**2-(dz/.064)**2))+.0015),.024+dz)
        path('Celestial star ray', [surface(0,0),surface(dx*.24-dz*.09,dz*.24+dx*.04),surface(dx,dz)], .00065, 3, resolution=2)
# Bright winding filaments make the contained solar volume visibly active.
for i in range(6):
    points=[]
    for j in range(15):
        x=.078+j*.014
        a=i*math.tau/6+j*.24
        fade=math.sin(math.pi*(j+1)/17)
        points.append((x,.053*fade*math.cos(a),.069*fade*math.sin(a)))
    path('Solar winding filament',points,.0016,7,group='Energy',resolution=3)
for obj in parts:
    if obj.name.startswith('Hammer edge'):
        obj['assembly']='Hammer'

# Apply real scale and orient muzzle to Godot -Z; origin is hand/grip attachment.
SCALE = .42
rotation = Matrix.Rotation(-math.pi/2,4,'Z')
transform = rotation @ Matrix.Translation(Vector((-.80,0,.105)))
scale_matrix = Matrix.Scale(SCALE,4)
transform = scale_matrix @ transform
for obj in parts:
    obj.matrix_world = transform @ obj.matrix_world

# Keep all individual modeling components in the source; export joined assemblies.
source_collection = bpy.data.collections.new('DAWNSEAL | editable components')
bpy.context.scene.collection.children.link(source_collection)
for obj in parts:
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    source_collection.objects.link(obj)

# Assembly pivots animate source parts and the exported merged copies identically.
scene = bpy.context.scene
pivots = {}
for group in sorted({o['assembly'] for o in parts}):
    pivot = bpy.data.objects.new('Dawnseal_'+group+'Pivot', None)
    source_collection.objects.link(pivot)
    pivot.location = transform @ Vector({'Energy':(.186,0,0),'Trigger':(.721,0,-.071),'Hammer':(.84,0,.10)}.get(group,(.80,0,-.105)))
    pivot['reference'] = 'meshy_views_v2/gun_sidearm_legendary_dawnseal'
    pivots[group] = pivot
bpy.context.view_layer.update()
for obj in parts:
    world = obj.matrix_world.copy()
    obj.parent = pivots[obj['assembly']]
    obj.matrix_world = world
scene.render.fps = 30
for name, angle in [('Trigger', -.16), ('Hammer', -.32)]:
    obj=pivots[name]
    for frame,value in [(1,0),(4,angle),(9,0)]:
        obj.rotation_euler.x=value
        obj.keyframe_insert(data_path='rotation_euler',frame=frame)
    action=obj.animation_data.action;action.name='Fire_'+name
    track=obj.animation_data.nla_tracks.new();track.name='Fire';track.strips.new('Fire',1,action)
    obj.animation_data.action=None
obj=pivots['Energy']
for frame,value in [(1,1),(10,.91),(20,1.06),(25,1)]:
    obj.scale=(value,value,value)
    obj.keyframe_insert(data_path='scale',frame=frame)
action=obj.animation_data.action;action.name='Charge_Solar_Chamber'
track=obj.animation_data.nla_tracks.new();track.name='Charge';track.strips.new('Charge',1,action)
obj.animation_data.action=None
scene.frame_set(1)
bpy.context.view_layer.update()
scene.unit_settings.system = 'METRIC'
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1600
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.world.color = (.17,.17,.17)
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.13,.16,.22,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .45
scene.view_settings.view_transform = 'AgX'

def transformed(point):
    return transform @ Vector(point)

def aim(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

studio = bpy.data.collections.new('STUDIO | not exported')
scene.collection.children.link(studio)
def studio_link(obj):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    studio.objects.link(obj)

def area(name, position, power, color, size):
    data = bpy.data.lights.new(name,'AREA')
    data.energy = power
    data.shape = 'DISK'
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location = transformed(position)
    aim(obj,transformed((.5,0,0)))

area('Warm key softbox',(-.15,-1.5,1.8),75,(1,.88,.70),.8)
area('Cool rim softbox',(.65,1.2,1.1),95,(.60,.77,1),.65)
area('Front broad fill',(1.4,-1.0,.5),35,(.83,.9,1),.7)
area('Muzzle white rim',(-.9,.3,.3),25,(1,.93,.8),.4)
bpy.ops.object.camera_add()
camera = bpy.context.object
camera.name = 'Dawnseal inspection camera'
studio_link(camera)
scene.camera = camera
camera.data.type = 'ORTHO'
camera.data.lens = 65
camera.data.clip_start = .001
camera.data.clip_end = 100
# Ground is deliberately excluded from GLB.
bpy.ops.mesh.primitive_plane_add(size=200,location=transformed((.5,0,-.365)))
floor = bpy.context.object
floor.name = 'Studio ground (not exported)'
studio_link(floor)
floor_mat = bpy.data.materials.new('Studio charcoal')
floor_mat.diffuse_color = (.024,.033,.05,1)
floor_mat.use_nodes = True
floor_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.024,.033,.05,1)
floor_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .6
floor.data.materials.append(floor_mat)
# Emission bloom is a preview effect; texture emission itself exports to glTF.
scene.use_nodes = True
composite_tree = scene.compositing_node_group if hasattr(scene,'compositing_node_group') else scene.node_tree
if composite_tree is not None:
    render_layers = composite_tree.nodes.get('Render Layers') or composite_tree.nodes.new('CompositorNodeRLayers')
    composite = composite_tree.nodes.get('Composite') or composite_tree.nodes.new('CompositorNodeComposite')
    glare = composite_tree.nodes.new('CompositorNodeGlare')
    glare.glare_type = 'FOG_GLOW'
    glare.quality = 'MEDIUM'
    composite_tree.links.new(render_layers.outputs['Image'],glare.inputs['Image'])
    composite_tree.links.new(glare.outputs['Image'],composite.inputs['Image'])

# Merge only export duplicates; retain fully editable named parts in .blend.
export_collection = bpy.data.collections.new('EXPORT | game assemblies')
scene.collection.children.link(export_collection)
export_objects = []
for group in sorted({obj['assembly'] for obj in parts}):
    bpy.ops.object.select_all(action='DESELECT')
    duplicates = []
    for original in [o for o in parts if o['assembly'] == group]:
        duplicate = original.copy()
        duplicate.data = original.data.copy()
        duplicate.parent = None
        duplicate.matrix_world = original.matrix_world.copy()
        export_collection.objects.link(duplicate)
        duplicate.select_set(True)
        duplicates.append(duplicate)
    bpy.context.view_layer.objects.active = duplicates[0]
    bpy.ops.object.join()
    merged = bpy.context.object
    merged.name = 'Dawnseal_' + group
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    # All assemblies share a hand-attachment origin and deterministic triangles.
    modifier = merged.modifiers.new('Game triangulation','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    world = merged.matrix_world.copy()
    merged.parent = pivots[group]
    merged.matrix_world = world
    export_objects.append(merged)

bpy.ops.object.select_all(action='DESELECT')
for obj in [*export_objects, *pivots.values()]:
    obj.select_set(True)
bpy.context.view_layer.objects.active = export_objects[0]
bpy.ops.export_scene.gltf(filepath=str(OUTPUT/'dawnseal.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_cameras=False,export_lights=False,export_extras=True,export_animations=True,export_animation_mode='NLA_TRACKS')
stats = {'triangles':sum(len(o.data.polygons) for o in export_objects),'vertices':sum(len(o.data.vertices) for o in export_objects),'assemblies':len(export_objects),'materials':2,'animations':['Fire','Charge'],'emission_material':'Dawnseal_Solar_Chamber_Emission','reference':'meshy_views_v2/gun_sidearm_legendary_dawnseal','texture_resolution':SIZE,'length_m':.42,'godot_forward':'-Z','origin':'grip attachment','source_parts':len(parts),'uv_layout':'Overlapping padded trim atlas; not unique bake UVs','reference_interpretation':'Side silhouette prioritized; front/top reconcile depth; mirrored unseen side ornament'}
(OUTPUT/'dawnseal_stats.json').write_text(json.dumps(stats,indent=2)+'\n')
print('DAWNSEAL_STATS',json.dumps(stats),flush=True)
export_collection.hide_render = True
export_collection.hide_viewport = True
bpy.ops.object.select_all(action='DESELECT')

views = {
    'dawnseal_hero': ((-.28,-1.8,.72),(.50,0,-.055),.52),
    'dawnseal_side': ((.50,-2.5,-.035),(.50,0,-.065),.51),
    'dawnseal_front': ((-2.0,0,.04),(.5,0,-.065),.30),
    'dawnseal_top': ((.50,0,2.5),(.50,0,0),.51),
}
for name,(position,target,ortho) in views.items():
    camera.location = transformed(position)
    aim(camera,transformed(target))
    camera.data.ortho_scale = ortho
    scene.render.filepath = str(PREVIEW/(name+'.png'))
    if name == 'dawnseal_top':
        floor.hide_render = True
    else:
        floor.hide_render = False
    if name == 'dawnseal_hero':
        for area_ in bpy.context.screen.areas:
            if area_.type == 'VIEW_3D':
                area_.spaces.active.region_3d.view_perspective = 'CAMERA'
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'dawnseal.blend'))
    bpy.ops.render.render(write_still=True)
(SOURCE/'README.md').write_text('# Dawnseal\n\nAuthored using meshy_views_v2/gun_sidearm_legendary_dawnseal side, top and front only. Editable named source components retain ivory/navy/gold PBR trim textures. Solar chamber uses the independent Dawnseal_Solar_Chamber_Emission material: set its emission color and strength without affecting the armor.\n\nFire animates trigger and hammer around their own pivots; Charge contracts and expands the solar chamber and winding filaments. Both clips export to GLB. Godot forward -Z; grip attachment origin. Rebuild with blender -b --factory-startup -t 4 --python tools/build_dawnseal.py.\n\nV2 refinements include shoulder enamel insets, ivory rear armor, radial celestial seal engraving, and solar filaments. Existing lobby and sandbox GLB paths are preserved.\n')
print('DAWNSEAL_COMPLETE',flush=True)
