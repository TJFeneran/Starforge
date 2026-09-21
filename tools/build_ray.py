"""Build the optimized Crescent Ray, fitted fin/tail rig and 30 fps clips.

blender -b --factory-startup -t 4 --python tools/build_ray.py
The approved Meshy GLB remains untouched; all output is deterministic.
"""
from __future__ import annotations
import json, math, os, sys, traceback
from pathlib import Path
import bpy
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree

def fail_fast(typ, value, tb):
    traceback.print_exception(typ, value, tb)
    sys.stderr.flush()
    os._exit(1)

sys.excepthook = fail_fast
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'assets/source/meshy/rift_ray/ray_a.glb'
OUT = ROOT/'assets/source/blender/rift_ray'
GAME = ROOT/'assets/models/enemies/rift_ray'
for p in [OUT, OUT/'previews', GAME]: p.mkdir(parents=True, exist_ok=True)
(OUT/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
body = next(o for o in bpy.data.objects if o.type == 'MESH')
bpy.context.view_layer.objects.active = body
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
points = [v.co.copy() for v in body.data.vertices]
lo = Vector(tuple(min(v[i] for v in points) for i in range(3)))
hi = Vector(tuple(max(v[i] for v in points) for i in range(3)))
factor = 1.6/(hi.x-lo.x)
# The selected head faces -Y; shift to the armored torso, not the long tail's bbox center.
for v in body.data.vertices:
    p = v.co
    v.co = ((p.x-(hi.x+lo.x)/2)*factor, (p.y+.24)*factor, (p.z-(hi.z+lo.z)/2)*factor)
body.name = 'Crescent_Ray_Body'
raw = body.copy(); raw.data = body.data.copy(); bpy.context.collection.objects.link(raw)
raw.name = 'Source_Comparison'; raw.hide_render = True; raw.hide_set(True)
raw.data.calc_loop_triangles()
source_triangles = len(raw.data.loop_triangles)
# Compress just the extra-long rear taper after the shell/tail seam; UVs stay intact.
tail_start = (.20+.24)*factor
for v in body.data.vertices:
    if v.co.y > tail_start:
        v.co.y = tail_start + (v.co.y-tail_start)*.42
trimmed = body.copy(); trimmed.data = body.data.copy(); bpy.context.collection.objects.link(trimmed)
trimmed.name = 'Tail_Corrected_Pre_Optimization'; trimmed.hide_render = True; trimmed.hide_set(True)

def tree_for(obj):
    obj.data.calc_loop_triangles()
    return BVHTree.FromPolygons([v.co for v in obj.data.vertices], [tuple(t.vertices) for t in obj.data.loop_triangles], all_triangles=True)

base_tree = tree_for(trimmed)
source_tree = tree_for(raw)
pre_count = len(trimmed.data.loop_triangles)
modifier = body.modifiers.new('Conservative 18 percent reduction', 'DECIMATE')
modifier.ratio = .82
modifier.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=modifier.name)
final_tree = tree_for(body)
errors = sorted(final_tree.find_nearest(v.co)[3] for v in trimmed.data.vertices)
reverse = sorted(base_tree.find_nearest(v.co)[3] for v in body.data.vertices)
protected = [final_tree.find_nearest(v.co)[3] for v in trimmed.data.vertices if v.co.y < -.38 or abs(v.co.x) > .63]
assert errors[int(len(errors)*.99)] < .003, 'Ray optimization p99 exceeds 3 mm'
assert max(errors) < .012, 'Ray optimization worst vertex exceeds 12 mm'
assert max(protected) < .008, 'Face or fin-tip detail shifted more than 8 mm'

spec = {}
def bone(name, a, b, parent=None): spec[name] = (Vector(a), Vector(b), parent)
bone('root',(0,0,0),(0,0,.12))
bone('body',(0,0,0),(0,-.30,0),'root')
bone('head',(0,-.30,0),(0,-.59,-.03),'body')
for side,s in [('L',1),('R',-1)]:
    bone('fin_root.'+side,(s*.25,-.04,-.015),(s*.42,-.025,-.045),'body')
    bone('fin_mid.'+side,(s*.42,-.025,-.045),(s*.61,-.005,-.16),'fin_root.'+side)
    bone('fin_tip.'+side,(s*.61,-.005,-.16),(s*.78,.015,-.34),'fin_mid.'+side)
bone('tail_root',(0,.27,.015),(0,.40,.03),'body')
bone('tail_mid',(0,.40,.03),(0,.53,.07),'tail_root')
bone('tail_tip',(0,.53,.07),(0,.66,.10),'tail_mid')
bone('muzzle_socket',(0,-.59,-.03),(0,-.69,-.03),'head')
bpy.ops.object.armature_add()
rig = bpy.context.object; rig.name='Crescent_Ray_Rig'; rig.data.name='Crescent_Ray_Skeleton'; rig.show_in_front=True
bpy.ops.object.mode_set(mode='EDIT'); rig.data.edit_bones.remove(rig.data.edit_bones[0])
for name,(a,b,parent) in spec.items():
    eb=rig.data.edit_bones.new(name); eb.head=a; eb.tail=b
    eb.use_deform = name not in ('root','muzzle_socket')
    if parent: eb.parent=rig.data.edit_bones[parent]
    eb.align_roll(Vector((0,0,1)))
bpy.ops.object.mode_set(mode='OBJECT')

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)))
    return t*t*(3-2*t)

for name in spec: body.vertex_groups.new(name=name)
for v in body.data.vertices:
    x,y,z = v.co
    side='L' if x>=0 else 'R'
    ax=abs(x)
    if y>.27 and ax<.30:
        if y<.40: weights={'tail_root':1}
        elif y<.53: weights={'tail_mid':1}
        else: weights={'tail_tip':1}
        # Only blend the narrow actual joint regions, preserving rigid shell panels.
        for joint,prev,nxt in [(.40,'tail_root','tail_mid'),(.53,'tail_mid','tail_tip')]:
            if abs(y-joint)<.018:
                w=smooth(joint-.018,joint+.018,y)
                weights={prev:1-w,nxt:w}
    elif ax>.265:
        chain=['fin_root.'+side,'fin_mid.'+side,'fin_tip.'+side]
        if ax<.445: weights={chain[0]:1}
        elif ax<.615: weights={chain[1]:1}
        else: weights={chain[2]:1}
        for joint,prev,nxt in [(.445,chain[0],chain[1]),(.615,chain[1],chain[2])]:
            if abs(ax-joint)<.025:
                w=smooth(joint-.025,joint+.025,ax)
                weights={prev:1-w,nxt:w}
        if ax<.31:
            w=smooth(.265,.31,ax)
            weights={'body':1-w,chain[0]:w}
    elif y<-.39:
        weights={'head':1}
    elif y<-.31:
        w=smooth(-.39,-.31,y)
        weights={'head':1-w,'body':w}
    else:
        weights={'body':1}
    for name,weight in weights.items():
        if weight>1e-6: body.vertex_groups[name].add([v.index],weight,'REPLACE')
body.parent=rig
armature=body.modifiers.new('Fitted fin and tail skin','ARMATURE'); armature.object=rig
body.data.update()

scene=bpy.context.scene; scene.render.fps=30
rest={n:rig.data.bones[n].matrix_local.copy() for n in spec}
for p in rig.pose.bones: p.rotation_mode='QUATERNION'
def rotate(name,xyz):
    basis=rest[name].to_quaternion()
    q=Euler(xyz,'XYZ').to_quaternion()
    rig.pose.bones[name].rotation_quaternion=basis.inverted()@q@basis
def curve(t,keys):
    for (ta,va),(tb,vb) in zip(keys,keys[1:]):
        if t<=tb: return va+(vb-va)*smooth(ta,tb,t)
    return keys[-1][1]

clips={
    'hover_idle':(90,True),'fly_forward':(36,True),
    'bank_left':(48,True),'bank_right':(48,True),
    'attack_anticipation':(21,False),'attack':(18,False),
    'attack_recovery':(24,False),'hit':(24,False),'death':(60,False),
}
actions={}; metrics={}
for label,(frames,loop) in clips.items():
    action=bpy.data.actions.new(label); action.use_fake_user=True
    rig.animation_data_create(); rig.animation_data.action=action
    for frame in range(frames+1):
        scene.frame_set(frame); t=frame/frames; phase=math.tau*t
        for p in rig.pose.bones: p.matrix_basis=Matrix.Identity(4)
        hover=.025*math.sin(phase) if label=='hover_idle' else 0
        flight=.055*math.sin(phase*2) if label=='fly_forward' else 0
        bank_side=1 if label=='bank_left' else -1
        bank=bank_side*.28*math.sin(math.pi*t)**2 if label.startswith('bank_') else 0
        attack_hold=curve(t,[(0,0),(.55,1),(1,1)]) if label=='attack_anticipation' else 0
        pulse=curve(t,[(0,0),(.20,0),(.33,1),(.48,.35),(.78,0),(1,0)]) if label=='attack' else 0
        recover=1-smooth(0,1,t) if label=='attack_recovery' else 0
        hit=curve(t,[(0,0),(.18,1),(.42,.3),(1,0)]) if label=='hit' else 0
        death=smooth(.12,.86,t) if label=='death' else 0
        root=rig.pose.bones['root']
        root.location=(0,0,hover+flight-.55*death)
        rotate('body',(-.10*attack_hold+.12*pulse-.08*recover+.15*hit+.38*death,
                       bank+.18*hit+1.08*death,
                       .025*math.sin(phase) if label=='fly_forward' else 0))
        rotate('head',(-.07*attack_hold+.04*pulse-.05*recover,0,.015*math.sin(phase)))
        for side,s in [('L',1),('R',-1)]:
            flap=.10*math.sin(phase) if label=='hover_idle' else 0
            flap+=.18*math.sin(phase) if label=='fly_forward' else 0
            flap+=.09*math.sin(phase) if label.startswith('bank_') else 0
            flap+=.10*attack_hold-.12*pulse+.08*recover+.18*hit+.55*death
            flap+=bank*s*.25
            rotate('fin_root.'+side,(0,s*flap,0))
            rotate('fin_mid.'+side,(0,s*(.55*flap+.07*math.sin(phase+1)),0))
            rotate('fin_tip.'+side,(0,s*(.40*flap+.05*math.sin(phase+1.8)),0))
        rotate('tail_root',(.025*math.sin(phase)+.10*attack_hold-.16*pulse+.20*death,0,.06*math.sin(phase)+.22*bank))
        rotate('tail_mid',(.035*math.sin(phase+.8)+.08*death,0,.04*math.sin(phase+.9)))
        rotate('tail_tip',(.04*math.sin(phase+1.6)+.12*death,0,.05*math.sin(phase+1.3)))
        for p in rig.pose.bones:
            p.keyframe_insert('location',frame=frame,group=p.name)
            p.keyframe_insert('rotation_quaternion',frame=frame,group=p.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points: key.interpolation='LINEAR'
    actions[label]=action
    metrics[label]={'duration_seconds':frames/30,'loop':loop}
    if label=='attack':
        metrics[label]['contact_frame']=6
        metrics[label]['contact_seconds']=6/30
        metrics[label]['contact_socket']='muzzle_socket'
    print('RAY_CLIP',label,metrics[label],flush=True)
rig.animation_data.action=None
for label,action in actions.items():
    track=rig.animation_data.nla_tracks.new(); track.name=label
    track.strips.new(label,0,action); track.mute=True

report={
    'source':str(SOURCE.relative_to(ROOT)), 'wingspan_m':1.6,
    'source_triangles':source_triangles, 'tail_corrected_triangles':pre_count,
    'optimized_triangles':len(body.data.loop_triangles),
    'reduction_percent':100*(1-len(body.data.loop_triangles)/source_triangles),
    'surface_error_p99_mm':errors[int(.99*len(errors))]*1000,
    'surface_error_max_mm':max(errors)*1000,
    'reverse_error_p99_mm':reverse[int(.99*len(reverse))]*1000,
    'face_and_fin_tip_max_error_mm':max(protected)*1000,
    'tail_compression_factor':.42,
    'bones':len(spec),
    'unweighted_vertices':sum(not v.groups for v in body.data.vertices),
    'weight_sum_max_error':max(abs(sum(g.weight for g in v.groups)-1) for v in body.data.vertices),
    'clips':metrics,
    'forward_blender':'-Y','forward_godot':'+Z','origin':'armored body center',
    'source_texture_sizes':[list(im.size) for im in bpy.data.images if im.size[0]>=1024],
}
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
(GAME/'animation_manifest.json').write_text(json.dumps({'fps':30,'clips':metrics,'wingspan_m':1.6,'forward_axis':'+Z','origin':'armored body center','muzzle_socket':'muzzle_socket'},indent=2)+'\n')

def look(o,pt): o.rotation_euler=(Vector(pt)-o.location).to_track_quat('-Z','Y').to_euler()
for pos,energy in [((2,-3,3),550),((-3,-2,2),350),((1,3,3),600)]:
    bpy.ops.object.light_add(type='AREA',location=pos)
    light=bpy.context.object;light.data.energy=energy;light.data.size=3;look(light,(0,0,0))
bpy.ops.object.camera_add(location=(2,-3,1.5))
camera=bpy.context.object;camera.name='Review_Camera';camera.data.type='ORTHO';camera.data.ortho_scale=2.05;look(camera,(0,0,0));scene.camera=camera
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.world.color=(.14,.14,.14)
scene.frame_start=0;scene.frame_end=90
rig.animation_data.action=actions['hover_idle'];scene.frame_set(0)
bpy.context.preferences.filepaths.save_version=0
for im in bpy.data.images:
    if im.size[0]:
        try: im.pack()
        except RuntimeError: pass
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'ray_rigged.blend'))
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(GAME/'ray.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_skins=True,export_def_bones=False,export_cameras=False,export_lights=False)
for label,frame in [('hover_idle',0),('fly_forward',8),('bank_left',18),('bank_right',18),('attack',6),('death',60)]:
    rig.animation_data.action=actions[label];scene.frame_set(frame)
    scene.render.filepath=str(OUT/'previews'/f'{label}.png')
    bpy.ops.render.render(write_still=True)
print('RAY_BUILD_COMPLETE',json.dumps(report),flush=True)
sys.stdout.flush();os._exit(0)
