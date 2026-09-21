"""Build selected Shieldback B's local quadruped rig and eight in-place clips.

Run: blender -b --factory-startup -t 4 --python tools/build_skitter.py
The paid Meshy source is never modified.
"""
from __future__ import annotations
import json, math, os, sys, traceback
from pathlib import Path
import bpy
from mathutils import Vector, Matrix, Quaternion, Euler
from mathutils.bvhtree import BVHTree

def fail_fast(typ, value, tb):
    traceback.print_exception(typ, value, tb)
    sys.stderr.flush()
    os._exit(1)
sys.excepthook = fail_fast
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'assets/source/meshy/rift_skitter/shieldback_b.glb'
OUT = ROOT/'assets/source/blender/rift_skitter'
GAME = ROOT/'assets/models/enemies/rift_skitter'
for directory in (OUT, OUT/'previews', GAME): directory.mkdir(parents=True, exist_ok=True)
(OUT/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
body = next(o for o in bpy.data.objects if o.type == 'MESH')
bpy.context.view_layer.objects.active = body
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
lo = Vector(tuple(min(v.co[i] for v in body.data.vertices) for i in range(3)))
hi = Vector(tuple(max(v.co[i] for v in body.data.vertices) for i in range(3)))
center = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
scale = 1.2/(hi.z-lo.z)
for vertex in body.data.vertices: vertex.co = (vertex.co-center)*scale
body.name = 'Shieldback_Body'
source_copy = body.copy()
source_copy.data = body.data.copy()
bpy.context.collection.objects.link(source_copy)
source_copy.name = 'Source_Comparison'
source_copy.hide_render = True
source_copy.hide_set(True)
body.data.calc_loop_triangles()
source_triangles = len(body.data.loop_triangles)
modifier = body.modifiers.new('Conservative geometry reduction', 'DECIMATE')
modifier.ratio = .82
modifier.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=modifier.name)
body.data.calc_loop_triangles()
optimized_triangles = len(body.data.loop_triangles)
def bvh(mesh):
    mesh.data.calc_loop_triangles()
    return BVHTree.FromPolygons([v.co for v in mesh.data.vertices], [tuple(t.vertices) for t in mesh.data.loop_triangles], all_triangles=True)
tree = bvh(body)
errors = sorted(tree.find_nearest(v.co)[3] for v in source_copy.data.vertices)
p99 = errors[int(.99*len(errors))]
maximum = errors[-1]
assert p99 < .003 and maximum < .012, (p99, maximum)

# Skeleton follows the actual four-leg layout, facing Blender -Y.
spec = {}
def bone(name, a, b, parent=None): spec[name] = (Vector(a), Vector(b), parent)
bone('root',(0,0,0),(0,0,.16))
bone('body',(0,0,.65),(0,-.05,.90),'root')
bone('neck',(0,-.30,.72),(0,-.44,.70),'body')
bone('head',(0,-.44,.70),(0,-.63,.59),'neck')
for label,side,front in [('front.L',1,True),('front.R',-1,True),('hind.L',1,False),('hind.R',-1,False)]:
    hy = -.29 if front else .32
    ky = -.43 if front else .46
    ay = -.47 if front else .53
    fy = -.54 if front else .60
    hip = (side*.28,hy,.66)
    knee = (side*.46,ky,.43)
    ankle = (side*.48,ay,.11)
    toe = (side*.49,fy,.025)
    bone('upper.'+label,hip,knee,'body')
    bone('lower.'+label,knee,ankle,'upper.'+label)
    bone('foot.'+label,ankle,toe,'lower.'+label)
    bone('toe.'+label,toe,(side*.50,fy-.07 if front else fy+.07,.015),'foot.'+label)
bpy.ops.object.armature_add()
rig = bpy.context.object
rig.name = 'Shieldback_Rig'
rig.data.name = 'Shieldback_Skeleton'
rig.show_in_front = True
bpy.ops.object.mode_set(mode='EDIT')
rig.data.edit_bones.remove(rig.data.edit_bones[0])
for name,(a,b,parent) in spec.items():
    eb = rig.data.edit_bones.new(name)
    eb.head=a; eb.tail=b
    eb.use_deform = name != 'root'
    if parent: eb.parent = rig.data.edit_bones[parent]
    eb.align_roll(Vector((0,-1,0)))
bpy.ops.object.mode_set(mode='OBJECT')

for name in spec: body.vertex_groups.new(name=name)
def distance_to_segment(p,a,b):
    t = max(0., min(1., (p-a).dot(b-a)/(b-a).length_squared))
    return (p-(a+(b-a)*t)).length
for vertex in body.data.vertices:
    p=vertex.co
    side='L' if p.x>=0 else 'R'
    front=p.y<0
    label=('front.' if front else 'hind.')+side
    if p.z>.73 or (abs(p.x)<.21 and p.z>.38):
        name='head' if p.y<-.50 and p.z<.77 else 'body'
    elif p.y<-.46 and abs(p.x)<.28 and p.z>.46:
        name='head'
    else:
        names=['upper.'+label,'lower.'+label,'foot.'+label,'toe.'+label]
        name=min(names,key=lambda n:distance_to_segment(p,*spec[n][:2]))
        if p.z<.10: name='foot.'+label if abs(p.y)<.56 else 'toe.'+label
    body.vertex_groups[name].add([vertex.index],1.0,'REPLACE')
body.parent=rig
skin=body.modifiers.new('Quadruped skin','ARMATURE')
skin.object=rig
rest={n:rig.data.bones[n].matrix_local.copy() for n in spec}
lengths={n:(b-a).length for n,(a,b,_) in spec.items()}
for p in rig.pose.bones:p.rotation_mode='QUATERNION'
def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3-2*t)
def curve(t,keys):
    for (a,va),(b,vb) in zip(keys,keys[1:]):
        if t<=b:return va+(vb-va)*smooth(a,b,t)
    return keys[-1][1]
def orient(name,head,tail):
    q=(spec[name][1]-spec[name][0]).rotation_difference(Vector(tail)-Vector(head))
    mat=q.to_matrix().to_4x4()@rest[name]
    mat.translation=Vector(head)
    rig.pose.bones[name].matrix=mat
    bpy.context.view_layer.update()
def transformed(name):return rig.pose.bones[name].matrix@rest[name].inverted()
def translate(name,offset):
    rig.pose.bones[name].location=rest[name].to_quaternion().inverted()@Vector(offset)
def rotate(name,angles):
    base=rest[name].to_quaternion()
    rig.pose.bones[name].rotation_quaternion=base.inverted()@Euler(angles,'XYZ').to_quaternion()@base
def solve(a,c,l1,l2,pole):
    d=c-a
    dist=min(d.length,l1+l2-.0001)
    direct=d.normalized()
    c=a+direct*dist
    x=(l1*l1-l2*l2+dist*dist)/(2*dist)
    h=math.sqrt(max(1e-8,l1*l1-x*x))
    pole=Vector(pole)-a
    normal=(pole-direct*pole.dot(direct)).normalized()
    return a+direct*x+normal*h,c
def leg(label,foot_target):
    upper='upper.'+label
    lower='lower.'+label
    foot='foot.'+label
    toe='toe.'+label
    hip=transformed('body')@spec[upper][0]
    knee,target=solve(hip,Vector(foot_target),lengths[upper],lengths[lower],(hip.x*2,hip.y,.22))
    orient(upper,hip,knee)
    orient(lower,knee,target)
    delta=target-spec[foot][0]
    orient(foot,target,spec[foot][1]+delta)
    orient(toe,spec[toe][0]+delta,spec[toe][1]+delta)

scene=bpy.context.scene
scene.render.fps=30
clips={'idle':(90,True),'walk':(36,True),'run':(24,True),'attack_anticipation':(24,False),'attack':(21,False),'attack_recovery':(27,False),'hit':(21,False),'death':(60,False)}
actions={};metrics={}
for label,(duration,loop) in clips.items():
    action=bpy.data.actions.new(label)
    action.use_fake_user=True
    rig.animation_data_create()
    rig.animation_data.action=action
    for frame in range(duration+1):
        scene.frame_set(frame)
        t=frame/duration
        phase=t*math.tau
        for pose_bone in rig.pose.bones:pose_bone.matrix_basis=Matrix.Identity(4)
        locomotion=label in ('walk','run')
        running=label=='run'
        bob=(.018 if running else .010)*math.cos(phase*2) if locomotion else .004*math.sin(phase)
        crouch=(.045 if running else .020) if locomotion else 0.
        anticipation=curve(t,[(0,0),(.48,1),(1,1)]) if label=='attack_anticipation' else 0.
        lunge=curve(t,[(0,0),(.14,0),(.38,1),(.65,.35),(1,0)]) if label=='attack' else 0.
        strike_lift=curve(t,[(0,0),(.12,0),(.28,1),(.38,0),(1,0)]) if label=='attack' else 0.
        recovery=1-curve(t,[(0,0),(.6,1),(1,1)]) if label=='attack_recovery' else 0.
        hit=curve(t,[(0,0),(.20,1),(.45,.30),(1,0)]) if label=='hit' else 0.
        drop=curve(t,[(0,0),(.22,.05),(.66,1),(1,1)]) if label=='death' else 0.
        translate('body',(0,-.18*lunge+.025*hit,-crouch+bob-.14*anticipation-.08*lunge-.12*recovery-.29*drop))
        rotate('body',(.13*anticipation+.28*lunge+.10*hit+.18*drop,.04*hit,.012*math.sin(phase) if locomotion else 0))
        bpy.context.view_layer.update()
        rotate('head',(.14*anticipation+.27*lunge-.19*hit+.33*drop,0,.025*math.sin(phase)))
        for leg_label,s,front in [('front.L',1,True),('front.R',-1,True),('hind.L',1,False),('hind.R',-1,False)]:
            a=spec['lower.'+leg_label][1]
            foot_target=Vector(a)
            if locomotion:
                # Diagonal support pair and lifted recovery pair, baked in place.
                offset=0 if (front and s>0) or ((not front) and s<0) else .5
                u=(t+offset)%1
                stance=.48 if running else .61
                stride=.25 if running else .16
                if u<stance:
                    foot_target.y+=-stride/2+stride*u/stance
                else:
                    v=(u-stance)/(1-stance)
                    foot_target.y+=stride/2-stride*smooth(0,1,v)
                    foot_target.z+=(.12 if running else .065)*math.sin(math.pi*v)
            if front:
                foot_target.y-=.28*lunge-.05*anticipation
                foot_target.z+=.18*strike_lift+.025*lunge
            else:foot_target.y+=.10*lunge
            if label=='death':
                foot_target.x-=s*.08*drop
                foot_target.z+=.06*drop
            leg(leg_label,foot_target)
        if label=='death':
            # Fold legs and settle on the ground, keeping the shell rigid.
            rotate('root',(-.16*drop,0,.12*drop))
            bpy.context.view_layer.update()
            if frame>0:
                deps=bpy.context.evaluated_depsgraph_get()
                evaluated=body.evaluated_get(deps)
                mesh=evaluated.to_mesh()
                min_z=min((evaluated.matrix_world@v.co).z for v in mesh.vertices)
                evaluated.to_mesh_clear()
                translate('root',(0,0,-min_z if min_z<0 else 0))
        for pose_bone in rig.pose.bones:
            pose_bone.keyframe_insert('location',frame=frame,group=pose_bone.name)
            pose_bone.keyframe_insert('rotation_quaternion',frame=frame,group=pose_bone.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fcurve in bag.fcurves:
                    for key in fcurve.keyframe_points:key.interpolation='LINEAR'
    actions[label]=action
    metrics[label]={'duration_seconds':duration/30,'loop':loop}
    if label=='attack':metrics[label]['contact_frame']=8;metrics[label]['contact_time_seconds']=8/30
    print('SKITTER_CLIP',label,metrics[label],flush=True)
rig.animation_data.action=None
for label,action in actions.items():
    track=rig.animation_data.nla_tracks.new()
    track.name=label
    track.strips.new(label,0,action)
    track.mute=True
report={'source':str(SOURCE.relative_to(ROOT)),'height_m':1.2,'source_triangles':source_triangles,'optimized_triangles':optimized_triangles,'reduction_percent':100*(1-optimized_triangles/source_triangles),'surface_error_p99_mm':p99*1000,'surface_error_max_mm':maximum*1000,'bones':len(spec),'unweighted_vertices':sum(not v.groups for v in body.data.vertices),'clips':metrics,'forward_blender':'-Y','forward_godot':'+Z'}
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
(GAME/'animation_manifest.json').write_text(json.dumps({'fps':30,'height_m':1.2,'forward_axis':'+Z','clips':metrics},indent=2)+'\n')
bpy.context.preferences.filepaths.save_version=0
for im in bpy.data.images:
    if im.size[0]:
        try:im.pack()
        except RuntimeError:pass
rig.animation_data.action=actions['idle']
scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'skitter_rigged.blend'))
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True);rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(GAME/'skitter.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_skins=True,export_def_bones=False,export_cameras=False,export_lights=False)
print('SKITTER_BUILD_COMPLETE',json.dumps(report),flush=True)
sys.stdout.flush();os._exit(0)
