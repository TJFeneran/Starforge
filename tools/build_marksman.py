"""Build the optimized Needlecrest rig and authored in-place animation set.

blender -b --factory-startup -t 4 --python tools/build_marksman.py
Source Meshy geometry is never overwritten. Rebuilds are deterministic.
"""
from __future__ import annotations
import json, math, os, sys, traceback
from pathlib import Path
import bpy
from mathutils import Vector, Matrix, Quaternion, Euler
from mathutils.bvhtree import BVHTree
def fail_fast(typ,value,tb):
    traceback.print_exception(typ,value,tb);sys.stderr.flush();os._exit(1)
sys.excepthook=fail_fast

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/source/blender/rift_marksman'
GAME = ROOT / 'assets/models/enemies/rift_marksman'
SOURCE = ROOT / 'assets/source/meshy/rift_marksman/marksman_a.glb'
for p in [OUT, GAME, OUT/'previews']: p.mkdir(parents=True, exist_ok=True)
(OUT/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
body = next(o for o in bpy.data.objects if o.type == 'MESH')
bpy.context.view_layer.objects.active = body
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
points = [v.co.copy() for v in body.data.vertices]
lo = Vector(tuple(min(v[i] for v in points) for i in range(3)))
hi = Vector(tuple(max(v[i] for v in points) for i in range(3)))
center = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
for v in body.data.vertices: v.co = (v.co-center)*1.9/(hi.z-lo.z)
body.name = 'Needlecrest_Body'
raw = body.copy(); raw.data = body.data.copy(); bpy.context.collection.objects.link(raw)
raw.name = 'Source_Comparison'; raw.hide_render = True; raw.hide_set(True)
def tree_for(o):
    o.data.calc_loop_triangles()
    return BVHTree.FromPolygons([v.co for v in o.data.vertices], [tuple(t.vertices) for t in o.data.loop_triangles], all_triangles=True)
source_tree = tree_for(raw)
raw_count = len(raw.data.loop_triangles)
modifier = body.modifiers.new('Conservative 25 percent reduction', 'DECIMATE')
modifier.ratio = .75
modifier.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=modifier.name)
optimized_tree = tree_for(body)
errors = [optimized_tree.find_nearest(v.co)[3] for v in raw.data.vertices]
reverse_errors = [source_tree.find_nearest(v.co)[3] for v in body.data.vertices]
errors.sort(); reverse_errors.sort()
assert errors[int(len(errors)*.99)] < .003, 'Optimization exceeded 3 mm p99 surface error'
assert max(errors) < .012, 'Optimization exceeded 12 mm worst surface error'
protected_errors = [optimized_tree.find_nearest(v.co)[3] for v in raw.data.vertices if v.co.z>1.58 or (abs(v.co.x)>.46 and v.co.z<1.02)]
assert max(protected_errors)<.006, 'Crest or hand detail changed by more than 6 mm'

# A model-specific A-pose skeleton. All coordinates are meters, Blender front -Y.
spec = {}
def bone(name, head, tail, parent=None): spec[name]=(Vector(head), Vector(tail), parent)
bone('root',(0,0,0),(0,0,.18))
bone('pelvis',(0,0,.99),(0,0,1.09),'root')
bone('spine',(0,0,1.09),(0,-.005,1.23),'pelvis')
bone('chest',(0,-.005,1.23),(0,0,1.46),'spine')
bone('neck',(0,0,1.46),(0,.015,1.61),'chest')
bone('head',(0,.015,1.61),(0,.015,1.87),'neck')
for side,s in [('L',1),('R',-1)]:
    bone('clavicle.'+side,(s*.055,0,1.45),(s*.235,0,1.465),'chest')
    bone('upper_arm.'+side,(s*.235,0,1.465),(s*.393,-.055,1.20),'clavicle.'+side)
    bone('forearm.'+side,(s*.393,-.055,1.20),(s*.512,-.082,.963),'upper_arm.'+side)
    bone('hand.'+side,(s*.512,-.082,.963),(s*.558,-.079,.906),'forearm.'+side)
    # Preserve the actual generated hand: four separated fingers plus thumb.
    for digit,dy,dz in [('index',-.055,.008),('middle',-.018,0),('ring',.019,.003),('outer',.054,.017)]:
        a=Vector((s*.566,-.079+dy,.909+dz)); b=a+Vector((s*.018,-.003,-.052)); c=b+Vector((-s*.022,-.006,-.044)); d=c+Vector((-s*.025,-.003,-.023))
        bone(digit+'_1.'+side,a,b,'hand.'+side);bone(digit+'_2.'+side,b,c,digit+'_1.'+side);bone(digit+'_3.'+side,c,d,digit+'_2.'+side)
    a=(s*.515,-.147,.940); b=(s*.475,-.155,.902); c=(s*.463,-.151,.864)
    bone('thumb_1.'+side,a,b,'hand.'+side);bone('thumb_2.'+side,b,c,'thumb_1.'+side)
    bone('thigh.'+side,(s*.137,.012,.982),(s*.203,-.035,.565),'pelvis')
    bone('shin.'+side,(s*.203,-.035,.565),(s*.257,.031,.153),'thigh.'+side)
    bone('foot.'+side,(s*.257,.031,.153),(s*.268,-.095,.058),'shin.'+side)
    bone('toe.'+side,(s*.268,-.095,.058),(s*.274,-.165,.052),'foot.'+side)
bone('weapon_socket',(-.512,-.082,.963),(-.512,-.182,.963),'hand.R')
bpy.ops.object.armature_add()
rig=bpy.context.object;rig.name='Needlecrest_Rig';rig.data.name='Needlecrest_Skeleton';rig.show_in_front=True
bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
for name,(a,b,parent) in spec.items():
    eb=rig.data.edit_bones.new(name);eb.head=a;eb.tail=b
    eb.use_deform=name not in ['root','weapon_socket']
    if parent: eb.parent=rig.data.edit_bones[parent]
    eb.align_roll(Vector((0,-1,0)))
bpy.ops.object.mode_set(mode='OBJECT')

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def segment(p,a,b):
    t=max(0,min(1,(p-a).dot(b-a)/(b-a).length_squared));return (p-(a+(b-a)*t)).length,t
def chain_weights(p,names,width=.032):
    values=[(*segment(p,spec[n][0],spec[n][1]),i) for i,n in enumerate(names)]
    _,t,i=min(values)
    length=(spec[names[i]][1]-spec[names[i]][0]).length
    if i>0 and t*length<width:
        w=.5+.5*smooth(0,width,t*length);return {names[i]:w,names[i-1]:1-w}
    if i<len(names)-1 and (1-t)*length<width:
        w=.5+.5*smooth(0,width,(1-t)*length);return {names[i]:w,names[i+1]:1-w}
    return {names[i]:1.0}
for name in spec: body.vertex_groups.new(name=name)
for v in body.data.vertices:
    x,y,z=v.co; ax=abs(x);side='L' if x>=0 else 'R'
    is_arm=(ax > .305 or (z>1.18 and ax>.235)) and z>.72
    if is_arm:
        if z<.925 and ax>.455:
            names=[n for n in spec if n.endswith('.'+side) and any(n.startswith(d) for d in ['index','middle','ring','outer','thumb'])]
            nearest=min(names,key=lambda n:segment(v.co,*spec[n][:2])[0])
            digit=nearest.split('_')[0];names=[n for n in names if n.startswith(digit)]
            weights=chain_weights(v.co,['hand.'+side]+names,.012)
        else:
            weights=chain_weights(v.co,['upper_arm.'+side,'forearm.'+side,'hand.'+side],.030)
    elif z>1.61: weights={'head':1}
    elif z>1.54:
        w=smooth(1.54,1.61,z);weights={'neck':1-w,'head':w}
    elif z>1.46 and ax<.105: weights={'neck':1}
    elif z>1.225: weights={'chest':1}
    elif z>1.13:
        w=smooth(1.13,1.225,z);weights={'spine':1-w,'chest':w}
    elif z>1.03:
        w=smooth(1.03,1.11,z);weights={'pelvis':1-w,'spine':w}
    elif z>.96: weights={'pelvis':1}
    else:
        names=['thigh.'+side,'shin.'+side,'foot.'+side,'toe.'+side]
        weights=chain_weights(v.co,names,.035)
        if z>.89:
            w=smooth(.89,.96,z);weights={names[0]:1-w,'pelvis':w}
        # The solid patella shell belongs to the shin rather than rubber bending.
        elif .53<z<.635 and y<-.075:weights={'shin.'+side:1}
        elif z<.10 and y<-.07:weights={'toe.'+side:1}
        elif z<.16:weights={'foot.'+side:1}
    for n,w in weights.items():
        if w>1e-6: body.vertex_groups[n].add([v.index],w,'REPLACE')
body.parent=rig
mod=body.modifiers.new('Needlecrest skin','ARMATURE');mod.object=rig
body.data.update()

# A removable 65 cm rifle reference with separate primary/support grip markers.
def material(name,color,metal=.0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=.38
    return m
navy=material('Carbine navy',(.035,.065,.105),.5);ivory=material('Carbine ceramic',(.72,.68,.55),.12);teal=material('Carbine teal',(.065,.20,.20),.25);coral=material('Carbine emitter',(.9,.10,.035),.3)
gun_parts=[]
def box(name,center,size,mat,bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center);o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
    be=o.modifiers.new('Machined edges','BEVEL');be.width=bevel;be.segments=2
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=be.name)
    gun_parts.append(o);return o
# Coordinates relative to trigger hand: barrel -Y, top +Z.
box('Receiver',(0,-.09,.068),(.072,.27,.09),navy)
box('Upper shroud',(0,-.265,.092),(.085,.28,.043),ivory)
box('Lower shroud',(0,-.295,.022),(.074,.22,.024),ivory)
box('Stock',(0,.17,.065),(.075,.15,.080),navy)
box('Stock cap',(0,.239,.062),(.088,.025,.094),ivory)
box('Primary grip',(0,.006,-.032),(.047,.042,.115),teal)
box('Foregrip',(0,-.22,-.035),(.052,.038,.110),teal)
box('Support loop base',(0,-.27,-.083),(.051,.14,.022),navy)
box('Support loop front',(0,-.332,-.035),(.052,.022,.110),navy)
box('Sight',(0,-.08,.130),(.029,.080,.028),coral,.004)
box('Emitter',(0,-.394,.054),(.047,.012,.038),coral,.006)
bpy.ops.object.select_all(action='DESELECT')
for o in gun_parts:o.select_set(True)
bpy.context.view_layer.objects.active=gun_parts[0];bpy.ops.object.join();gun=bpy.context.object;gun.name='Carbine_Grip_Reference'
bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
gun.vertex_groups.new(name='weapon_socket').add(list(range(len(gun.data.vertices))),1,'REPLACE')
# Bind the prop at the right hand using its own deform bone, baked like any rigid part.
rig.data.bones['weapon_socket'].use_deform=True
gun.data.transform(Matrix.Translation(spec['weapon_socket'][0]));gun.parent=rig
m=gun.modifiers.new('Rigid weapon attachment','ARMATURE');m.object=rig
for name,local in [('grip_primary',(0,0,0)),('grip_support',(0,-.22,-.018)),('muzzle',(0,-.405,.054))]:
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.empty_display_type='ARROWS';o.empty_display_size=.055
    o.parent=rig;o.parent_type='BONE';o.parent_bone='weapon_socket'
    # Bone's local Y axis runs down barrel; translate from its tail-relative origin.
    o.matrix_world=Matrix.Translation(spec['weapon_socket'][0]+Vector(local))

scene=bpy.context.scene;scene.render.fps=30
rest={n:rig.data.bones[n].matrix_local.copy() for n in spec}
lengths={n:(b-a).length for n,(a,b,_) in spec.items()}
for p in rig.pose.bones:p.rotation_mode='QUATERNION'
def orient(n,head,tail,roll=None):
    q=(spec[n][1]-spec[n][0]).rotation_difference(Vector(tail)-Vector(head))
    if roll is not None:q=roll
    mat=q.to_matrix().to_4x4()@rest[n];mat.translation=Vector(head);rig.pose.bones[n].matrix=mat
    bpy.context.view_layer.update()
    return mat
def transformed(n):
    p=rig.pose.bones[n];return p.matrix.copy()@rest[n].inverted()
def pose_delta(n,xyz):
    pb=rig.pose.bones[n];basis=rest[n].to_quaternion()
    q=Euler(xyz,'XYZ').to_quaternion()
    pb.rotation_quaternion=basis.inverted()@q@basis
    bpy.context.view_layer.update()
def translate(n,world_offset):
    rig.pose.bones[n].location=rest[n].to_quaternion().inverted()@Vector(world_offset)
def solve(a,c,l1,l2,pole):
    d=c-a;dist=min(d.length,l1+l2-.0001);direction=d.normalized();c=a+direction*dist
    x=(l1*l1-l2*l2+dist*dist)/(2*dist);height=math.sqrt(max(.00001,l1*l1-x*x))
    pole=Vector(pole)-a;normal=(pole-direction*pole.dot(direction)).normalized()
    return a+direction*x+normal*height,c
soles={side:[v.co.copy() for v in body.data.vertices if v.co.z<.16 and v.co.x*s>0] for side,s in [('L',1),('R',-1)]}
def leg(side,ankle,foot_q,clearance=0.):
    ankle=Vector(ankle)
    sole_min=min((ankle+foot_q@(p-spec['foot.'+side][0])).z for p in soles[side])
    ankle.z+=clearance-sole_min
    intended=ankle.copy()
    n='thigh.'+side;a=transformed('pelvis')@spec[n][0]
    knee,ankle=solve(a,Vector(ankle),lengths[n],lengths['shin.'+side],(a.x,-1,a.z-.45))
    orient(n,a,knee);orient('shin.'+side,knee,ankle)
    foot=orient('foot.'+side,ankle,ankle+foot_q@(spec['foot.'+side][1]-spec['foot.'+side][0]),foot_q)
    toe_head=foot@rest['foot.'+side].inverted()@spec['toe.'+side][0]
    orient('toe.'+side,toe_head,toe_head+foot_q@(spec['toe.'+side][1]-spec['toe.'+side][0]),foot_q)
    return (ankle-intended).length
def arm(side,wrist,hand_q):
    n='upper_arm.'+side;a=transformed('clavicle.'+side)@spec[n][0];s=1 if side=='L' else -1
    elbow,wrist=solve(a,Vector(wrist),lengths[n],lengths['forearm.'+side],(s*.75,.0,1.03))
    orient(n,a,elbow);orient('forearm.'+side,elbow,wrist)
    orient('hand.'+side,wrist,wrist+hand_q@(spec['hand.'+side][1]-spec['hand.'+side][0]),hand_q)
def blend(a,b,t):return Vector(a).lerp(Vector(b),t)
def curve(t,keys):
    for (ta,va),(tb,vb) in zip(keys,keys[1:]):
        if t<=tb:return va+(vb-va)*smooth(ta,tb,t)
    return keys[-1][1]

clips={'idle':(90,True),'walk':(36,True),'run':(21,True),'strafe_left':(36,True),'strafe_right':(36,True),'aim':(60,True),'attack_anticipation':(24,False),'attack':(18,False),'attack_recovery':(27,False),'hit':(24,False),'death':(72,False)}
clip_metrics={};actions={}
for label,(duration,loop) in clips.items():
    action=bpy.data.actions.new(label);action.use_fake_user=True
    rig.animation_data_create();rig.animation_data.action=action
    max_grip_error=0.;max_foot_error=0.
    for frame in range(duration+1):
        scene.frame_set(frame);t=frame/duration;phase=t*math.tau
        for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
        locomotion=label in ['walk','run','strafe_left','strafe_right'];running=label=='run';strafe=label.startswith('strafe')
        aim_mix=1. if label in ['aim','attack','attack_recovery','hit'] or strafe else .50
        if label=='attack_anticipation':aim_mix=.5+.5*smooth(0,.65,t)
        if label=='attack_recovery':aim_mix=1-.5*smooth(.45,1,t)
        bob=(.018 if running else .009)*math.cos(phase*2) if locomotion else .003*math.sin(phase)
        crouch=.125 if running else (.080 if locomotion else .025)
        pelvis=rig.pose.bones['pelvis'];translate('pelvis',(.018*math.sin(phase) if locomotion else .004*math.sin(phase),0,-crouch+bob))
        pose_delta('pelvis',(.035 if running else 0,.018*math.sin(phase) if locomotion else 0,.04*math.sin(phase) if locomotion else 0))
        bpy.context.view_layer.update()
        pose_delta('spine',(.045 if running else -.015,0,-.025*math.sin(phase) if locomotion else 0))
        pose_delta('chest',(.01,0,.035*math.sin(phase) if locomotion else 0))
        pose_delta('head',(-.015,0,.06*math.sin(phase) if label=='idle' else .015*math.sin(phase)))
        recoil=0.
        if label=='attack':recoil=curve(t,[(0,0),(.22,0),(.28,1),(.40,.55),(.74,0),(1,0)])
        hit=curve(t,[(0,0),(.18,1),(.4,.4),(1,0)]) if label=='hit' else 0
        if hit:pose_delta('chest',(-.11*hit,.09*hit,.10*hit))
        for side,s in [('L',1),('R',-1)]:
            foot_q=Quaternion();ankle=Vector((s*.225,.031,.153));lift=0.
            if locomotion:
                # Constant-speed planted interval; smooth airborne return and toe clearance.
                u=(t+(0 if side=='L' else .5))%1;stance=.40 if running else .58
                stride=.86 if running else (.38 if strafe else .66)
                if u<stance:
                    along=-stride/2+stride*u/stance;lift=0.;pitch=.07*math.sin(math.pi*u/stance)
                else:
                    v=(u-stance)/(1-stance);along=stride/2-stride*smooth(0,1,v);lift=(.145 if running else .075)*math.sin(math.pi*v);pitch=-.22*math.sin(math.pi*v)
                if strafe:ankle.x+=along*(1 if label=='strafe_left' else -1);ankle.y=.02
                else:ankle.y+=along
                ankle.z+=lift;foot_q=Euler((pitch,0,0),'XYZ').to_quaternion()
            max_foot_error=max(max_foot_error,leg(side,ankle,foot_q,lift))
        # Both grips share one gun transform; solved elbows absorb recoil.
        origin=blend((0,-.175,1.19),(0,-.235,1.32),aim_mix)
        origin+=Vector((0,.050*recoil,.018*recoil+bob*.4))
        origin+=Vector((.020*hit,.02*hit,-.025*hit))
        gun_q=Euler((.38*(1-aim_mix)-.060*recoil,.02*math.sin(phase) if locomotion else 0,0),'XYZ').to_quaternion()
        death_drop=smooth(.15,.65,t) if label=='death' else 0.
        if death_drop:
            origin=origin.lerp(Vector((-.43,-.09,1.025)),death_drop)
            gun_q=gun_q.slerp(Euler((1.3,0,-.10),'XYZ').to_quaternion(),death_drop)
        # Neutral mesh palm directions mapped to a vertical rear grip and horizontal support palm.
        right_q=(spec['hand.R'][1]-spec['hand.R'][0]).rotation_difference(Vector((0,0,-1)))
        left_q=(spec['hand.L'][1]-spec['hand.L'][0]).rotation_difference(Vector((0,-.15,-.99)))
        right_offset=Vector((0,.006,.023));left_offset=Vector((0,-.213,.019))
        right_wrist=origin+gun_q@right_offset
        left_wrist=origin+gun_q@left_offset
        if death_drop:left_wrist=left_wrist.lerp(Vector((.43,-.08,1.0)),death_drop)
        arm('R',right_wrist,gun_q@right_q);arm('L',left_wrist,gun_q@left_q)
        orient('weapon_socket',origin,origin+gun_q@Vector((0,-.1,0)),gun_q)
        for side,s in [('L',1),('R',-1)]:
            for digit in ['index','middle','ring','outer']:
                curl=1-death_drop if side=='L' else 1
                pose_delta(digit+'_1.'+side,(0,s*.30*curl,0));pose_delta(digit+'_2.'+side,(0,s*.55*curl,0));pose_delta(digit+'_3.'+side,(0,s*.25*curl,0))
            pose_delta('thumb_1.'+side,(0,-s*.20,0))
        if label=='death':
            # Kneel, lose balance sideways/back, then settle fully on the floor.
            fall=smooth(.20,.82,t);kneel=math.sin(math.pi*smooth(0,.65,t))
            root=rig.pose.bones['root'];pose_delta('root',(-1.45*fall,-.20*fall,.18*fall))
            root_offset=Vector((.16*fall,-.48*fall,-.76*fall-.16*kneel));translate('root',root_offset)
            pose_delta('thigh.L',(.28*kneel+.12*fall,0,0));pose_delta('shin.L',(-.95*kneel-.28*fall,0,0))
            pose_delta('thigh.R',(.48*kneel+.25*fall,0,0));pose_delta('shin.R',(-1.10*kneel-.52*fall,0,0))
            bpy.context.view_layer.update()
            # Root height from evaluated vertices makes the final pose rest on the ground.
            deps=bpy.context.evaluated_depsgraph_get();evaluated=body.evaluated_get(deps);mesh=evaluated.to_mesh()
            min_z=min((evaluated.matrix_world@v.co).z for v in mesh.vertices);evaluated.to_mesh_clear()
            root_offset.z-=min_z;translate('root',root_offset);bpy.context.view_layer.update()
        for p in rig.pose.bones:
            p.keyframe_insert('location',frame=frame,group=p.name);p.keyframe_insert('rotation_quaternion',frame=frame,group=p.name)
        if label!='death':
            w=rig.pose.bones['weapon_socket'].head
            max_grip_error=max(max_grip_error,(rig.pose.bones['hand.R'].head-(w+gun_q@right_offset)).length,(rig.pose.bones['hand.L'].head-(w+gun_q@left_offset)).length)
    # Linear sampled transforms avoid interpolation overshoot at contact/recoil frames.
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points:k.interpolation='LINEAR'
    actions[label]=action
    clip_metrics[label]={'duration_seconds':duration/30,'loop':loop,'max_grip_error_m':max_grip_error,'max_foot_target_error_m':max_foot_error}
    if label=='attack':clip_metrics[label]['fire_time_seconds']=4/30
    if label!='death':assert max_grip_error<.003, f'{label}: unreachable grip {max_grip_error}'
    print('CLIP',label,clip_metrics[label],flush=True)
rig.animation_data.action=None
for label,action in actions.items():
    tr=rig.animation_data.nla_tracks.new();tr.name=label;tr.strips.new(label,0,action);tr.mute=True

report={'source':str(SOURCE.relative_to(ROOT)),'height_m':1.9,'source_triangles':raw_count,'optimized_triangles':len(body.data.loop_triangles),'reduction_percent':100*(1-len(body.data.loop_triangles)/raw_count),'surface_error_p99_mm':errors[int(.99*len(errors))]*1000,'surface_error_max_mm':max(errors)*1000,'reverse_error_p99_mm':reverse_errors[int(.99*len(reverse_errors))]*1000,'crest_and_hands_max_error_mm':max(protected_errors)*1000,'bones':len(spec),'unweighted_vertices':sum(not v.groups for v in body.data.vertices),'weight_sum_max_error':max(abs(sum(g.weight for g in v.groups)-1) for v in body.data.vertices),'clips':clip_metrics,'weapon':'Removable procedural grip reference; replace with final Needlecrest carbine.','forward_blender':'-Y','forward_godot':'+Z'}
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
(GAME/'animation_manifest.json').write_text(json.dumps({'fps':30,'clips':clip_metrics,'height_m':1.9,'forward_axis':'+Z','weapon_socket':'weapon_socket'},indent=2)+'\n')

def look(o,pt):o.rotation_euler=(Vector(pt)-o.location).to_track_quat('-Z','Y').to_euler()
for pos,energy in [((2,-3,4),420),((-3,-2,2.8),280),((1,3,3),500)]:
    bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=energy;o.data.shape='DISK';o.data.size=3;look(o,(0,0,1))
bpy.ops.object.camera_add(location=(2.5,-4,2.1));cam=bpy.context.object;cam.name='Review_Camera';cam.data.type='ORTHO';cam.data.ortho_scale=2.45;look(cam,(0,0,1));scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True;scene.render.resolution_x=800;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.world.color=(.12,.12,.12)
scene.frame_start=0;scene.frame_end=90
rig.animation_data.action=actions['idle'];scene.frame_set(0)
bpy.context.preferences.filepaths.save_version=0
for im in bpy.data.images:
    if im.size[0]:
        try:im.pack()
        except RuntimeError:pass
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'marksman_rigged.blend'))
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True);gun.select_set(True)
bpy.context.view_layer.objects.active=rig
# Named actions export on one armature; no unrelated source mesh or review objects.
bpy.ops.export_scene.gltf(filepath=str(GAME/'marksman.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_skins=True,export_def_bones=False,export_cameras=False,export_lights=False)
for label,frame in [('idle',0),('walk',8),('run',6),('aim',0),('attack',5),('hit',5),('death',72)]:
    rig.animation_data.action=actions[label];scene.frame_set(frame)
    if label=='death':cam.location=(2.5,-4,3.5);look(cam,(0,.5,.45));cam.data.ortho_scale=2.9
    scene.render.filepath=str(OUT/'previews'/f'{label}.png');bpy.ops.render.render(write_still=True)
print('MARKSMAN_BUILD_COMPLETE',json.dumps(report),flush=True)
# Some Linux audio backends hang during Blender shutdown after rendering.
sys.stdout.flush();os._exit(0)
