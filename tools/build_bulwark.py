"""Build the optimized Split Crown mechanical rig and seven authored clips.

blender -b --factory-startup -t 4 --python tools/build_bulwark.py
The original Meshy GLB remains untouched; output is deterministic.
"""
from __future__ import annotations
import json, math, os, sys, traceback
from pathlib import Path
import bpy
from mathutils import Vector, Matrix, Quaternion, Euler
from mathutils.bvhtree import BVHTree

def fail(typ, value, tb):
    traceback.print_exception(typ, value, tb)
    sys.stderr.flush()
    os._exit(1)
sys.excepthook = fail
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/source/blender/forge_bulwark"
GAME = ROOT / "assets/models/enemies/forge_bulwark"
SOURCE = ROOT / "assets/source/meshy/forge_bulwark/bulwark_a.glb"
for directory in (OUT, GAME, OUT / "previews"):
    directory.mkdir(parents=True, exist_ok=True)
(OUT / ".gdignore").touch()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
body = next(o for o in bpy.data.objects if o.type == "MESH")
bpy.context.view_layer.objects.active = body
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
points = [v.co.copy() for v in body.data.vertices]
lo = Vector(tuple(min(v[i] for v in points) for i in range(3)))
hi = Vector(tuple(max(v[i] for v in points) for i in range(3)))
center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for v in body.data.vertices:
    v.co = (v.co - center) * 2.8 / (hi.z - lo.z)
body.name = "Bulwark_Body"
raw = body.copy()
raw.data = body.data.copy()
bpy.context.collection.objects.link(raw)
raw.name = "Source_Comparison"
raw.hide_render = True
raw.hide_set(True)

def tree_for(obj):
    obj.data.calc_loop_triangles()
    return BVHTree.FromPolygons([v.co for v in obj.data.vertices],
                               [tuple(t.vertices) for t in obj.data.loop_triangles], all_triangles=True)
source_tree = tree_for(raw)
source_triangles = len(raw.data.loop_triangles)
modifier = body.modifiers.new("Conservative mechanical reduction", "DECIMATE")
modifier.ratio = .82
modifier.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=modifier.name)
optimized_tree = tree_for(body)
errors = sorted(optimized_tree.find_nearest(v.co)[3] for v in raw.data.vertices)
reverse_errors = sorted(source_tree.find_nearest(v.co)[3] for v in body.data.vertices)
assert errors[int(.99 * len(errors))] < .003, "Body p99 surface error exceeds 3 mm"
assert max(errors) < .012, "Body maximum surface error exceeds 12 mm"
crown_errors = [optimized_tree.find_nearest(v.co)[3] for v in raw.data.vertices if v.co.z > 2.45]
assert max(crown_errors) < .006, "Crown changed by more than 6 mm"

# Anatomical landmarks are fitted to the generated A-pose at 2.8 m height.
# Blender front is -Y, with the ground below the broad feet at Z=0.
spec = {}
def bone(name, head, tail, parent=None): spec[name] = (Vector(head), Vector(tail), parent)
bone("root", (0,0,0), (0,0,.18))
bone("pelvis", (0,0,1.38), (0,0,1.50), "root")
bone("spine", (0,0,1.50), (0,0,1.77), "pelvis")
bone("chest", (0,0,1.77), (0,0,2.27), "spine")
bone("neck", (0,0,2.27), (0,0,2.43), "chest")
bone("head", (0,0,2.43), (0,0,2.62), "neck")
for side, s in (("L", 1), ("R", -1)):
    bone("crown."+side, (s*.24,.08,2.30), (s*.24,.08,2.79), "chest")
    bone("clavicle."+side, (s*.22,0,2.22), (s*.59,0,2.23), "chest")
    bone("upper_arm."+side, (s*.59,0,2.23), (s*.78,-.015,1.72), "clavicle."+side)
    bone("forearm."+side, (s*.78,-.015,1.72), (s*1.03,-.045,1.17), "upper_arm."+side)
    bone("hand."+side, (s*1.03,-.045,1.17), (s*1.08,-.05,.99), "forearm."+side)
    for digit, dy in (("index",-.08), ("middle",-.025), ("ring",.03), ("outer",.085)):
        a = Vector((s*1.08,-.05+dy,1.01)); b = a + Vector((s*.025,0,-.09)); c = b + Vector((-s*.045,-.02,-.055))
        bone(digit+"_1."+side, a, b, "hand."+side)
        bone(digit+"_2."+side, b, c, digit+"_1."+side)
    a=(s*1.03,-.17,1.11); b=(s*.99,-.21,1.05); c=(s*.97,-.20,.99)
    bone("thumb_1."+side,a,b,"hand."+side); bone("thumb_2."+side,b,c,"thumb_1."+side)
    bone("thigh."+side, (s*.31,.01,1.36), (s*.39,-.015,.77), "pelvis")
    bone("shin."+side, (s*.39,-.015,.77), (s*.43,.04,.27), "thigh."+side)
    bone("foot."+side, (s*.43,.04,.27), (s*.44,-.19,.105), "shin."+side)
    bone("toe."+side, (s*.44,-.19,.105), (s*.45,-.30,.08), "foot."+side)
bpy.ops.object.armature_add()
rig = bpy.context.object
rig.name = "Bulwark_Rig"
rig.data.name = "Bulwark_Skeleton"
rig.show_in_front = True
bpy.ops.object.mode_set(mode="EDIT")
rig.data.edit_bones.remove(rig.data.edit_bones[0])
for name, (a, b, parent) in spec.items():
    eb = rig.data.edit_bones.new(name)
    eb.head = a; eb.tail = b
    eb.use_deform = name != "root"
    if parent: eb.parent = rig.data.edit_bones[parent]
    eb.align_roll(Vector((0,-1,0)))
bpy.ops.object.mode_set(mode="OBJECT")

def smooth(a, b, x):
    t = max(0, min(1, (x-a)/(b-a)))
    return t*t*(3-2*t)
def segment(p, a, b):
    t = max(0, min(1, (p-a).dot(b-a)/(b-a).length_squared))
    return (p-(a+(b-a)*t)).length, t
def chain_weights(p, names, width):
    _, t, i = min((*segment(p, spec[n][0], spec[n][1]), i) for i,n in enumerate(names))
    length = (spec[names[i]][1]-spec[names[i]][0]).length
    if i and t*length < width:
        w=.5+.5*smooth(0,width,t*length)
        return {names[i]:w, names[i-1]:1-w}
    if i<len(names)-1 and (1-t)*length < width:
        w=.5+.5*smooth(0,width,(1-t)*length)
        return {names[i]:w, names[i+1]:1-w}
    return {names[i]:1.0}
for name in spec: body.vertex_groups.new(name=name)
for v in body.data.vertices:
    x,y,z=v.co; ax=abs(x); side="L" if x>=0 else "R"
    if z>2.42 and ax>.13 and ax<.50:
        weights={"crown."+side:1}
    elif z>2.43 and ax<.19:
        weights={"head":1}
    elif (ax>.55 and z>1.35) or (ax>.75 and z>.88):
        if z<1.11 and ax>.98:
            names=[n for n in spec if n.endswith("."+side) and any(n.startswith(d) for d in ("index","middle","ring","outer","thumb"))]
            nearest=min(names,key=lambda n:segment(v.co,*spec[n][:2])[0])
            digit=nearest.split("_")[0]
            weights=chain_weights(v.co,["hand."+side]+[n for n in names if n.startswith(digit)],.012)
        else:
            weights=chain_weights(v.co,["upper_arm."+side,"forearm."+side,"hand."+side],.13)
            # Ceramic plates and guards remain rigid around the bearing axes.
            if z>2.09: weights={"upper_arm."+side:1}
            if 1.25<z<1.62 and ax>.83: weights={"forearm."+side:1}
    elif z>2.30: weights={"upper_arm."+side:1} if ax>.42 else {"head":1}
    elif z>1.83: weights={"chest":1}
    elif z>1.50: weights=chain_weights(v.co,["spine","chest"],.045)
    elif z>1.27: weights={"pelvis":1}
    else:
        names=["thigh."+side,"shin."+side,"foot."+side,"toe."+side]
        weights=chain_weights(v.co,names,.13)
        if z>1.15: weights={"thigh."+side:1}
        elif .70<z<.88 and y<-.04: weights={"shin."+side:1}
        elif z<.13 and y<-.18: weights={"toe."+side:1}
        elif z<.29: weights={"foot."+side:1}
    # The source is one mesh across arm sockets; a gradual dark-coupling zone
    # prevents connected triangles from tearing between torso and arm bones.
    if 1.35<z<2.25 and .43<ax<.72:
        arm_name=("forearm." if z<1.70 else "upper_arm.")+side
        torso_name="pelvis" if z<1.48 else ("spine" if z<1.80 else "chest")
        arm_weight=smooth(.43,.72,ax)
        weights={arm_name:arm_weight,torso_name:1-arm_weight}
    if z>=2.25 and .40<ax<.72:
        arm_weight=smooth(.40,.72,ax)
        weights={"upper_arm."+side:arm_weight,"chest":1-arm_weight}
    for name,weight in weights.items():
        if weight>1e-6:body.vertex_groups[name].add([v.index],weight,"REPLACE")
# The long front thigh guards are separate mechanical plates that cross the
# nearest-bone knee threshold. Keep each whole guard on the thigh bearing.
parents=list(range(len(body.data.vertices)))
def part_root(i):
    while parents[i]!=i:parents[i]=parents[parents[i]];i=parents[i]
    return i
for edge in body.data.edges:
    a,b=edge.vertices;a=part_root(a);b=part_root(b)
    if a!=b:parents[b]=a
parts={}
for v in body.data.vertices:parts.setdefault(part_root(v.index),[]).append(v.index)
for indices in parts.values():
    if len(indices)<100:continue
    votes={}
    for i in indices:
        for g in body.data.vertices[i].groups:
            name=body.vertex_groups[g.group].name
            votes[name]=votes.get(name,0)+g.weight
    for side in ("L","R"):
        thigh="thigh."+side;shin="shin."+side
        if votes.get(thigh,0)>len(indices)*.6 and votes.get(shin,0)>len(indices)*.1 and set(votes)<={thigh,shin}:
            body.vertex_groups[shin].remove(indices)
            body.vertex_groups[thigh].add(indices,1,"REPLACE")
body.parent=rig
modifier=body.modifiers.new("Mechanical skin", "ARMATURE")
modifier.object=rig
body.data.update()

scene=bpy.context.scene
scene.render.fps=30
rest={n:rig.data.bones[n].matrix_local.copy() for n in spec}
lengths={n:(b-a).length for n,(a,b,_) in spec.items()}
for p in rig.pose.bones: p.rotation_mode="QUATERNION"
def orient(n, head, tail, roll=None):
    q=(spec[n][1]-spec[n][0]).rotation_difference(Vector(tail)-Vector(head))
    if roll is not None: q=roll
    mat=q.to_matrix().to_4x4()@rest[n]
    mat.translation=Vector(head)
    rig.pose.bones[n].matrix=mat
    bpy.context.view_layer.update()
    return mat
def transformed(n): return rig.pose.bones[n].matrix.copy()@rest[n].inverted()
def pose_delta(n, xyz):
    basis=rest[n].to_quaternion()
    rig.pose.bones[n].rotation_quaternion=basis.inverted()@Euler(xyz,"XYZ").to_quaternion()@basis
    bpy.context.view_layer.update()
def translate(n, offset): rig.pose.bones[n].location=rest[n].to_quaternion().inverted()@Vector(offset)
def solve(a, c, l1, l2, pole):
    d=c-a; dist=min(d.length,l1+l2-.0001); direction=d.normalized(); c=a+direction*dist
    x=(l1*l1-l2*l2+dist*dist)/(2*dist)
    height=math.sqrt(max(.00001,l1*l1-x*x))
    pole=Vector(pole)-a
    normal=(pole-direction*pole.dot(direction)).normalized()
    return a+direction*x+normal*height,c
soles={side:[v.co.copy() for v in body.data.vertices if v.co.z<.29 and v.co.x*s>0] for side,s in (("L",1),("R",-1))}
def leg(side, ankle, foot_q, clearance=0):
    ankle=Vector(ankle)
    sole_min=min((ankle+foot_q@(p-spec["foot."+side][0])).z for p in soles[side])
    ankle.z+=clearance-sole_min
    intended=ankle.copy()
    a=transformed("pelvis")@spec["thigh."+side][0]
    knee,ankle=solve(a,ankle,lengths["thigh."+side],lengths["shin."+side],(a.x,-1,a.z-.45))
    orient("thigh."+side,a,knee); orient("shin."+side,knee,ankle)
    foot=orient("foot."+side,ankle,ankle+foot_q@(spec["foot."+side][1]-spec["foot."+side][0]),foot_q)
    toe_head=foot@rest["foot."+side].inverted()@spec["toe."+side][0]
    orient("toe."+side,toe_head,toe_head+foot_q@(spec["toe."+side][1]-spec["toe."+side][0]),foot_q)
    return (ankle-intended).length
def arm(side, wrist, hand_q):
    n="upper_arm."+side; a=transformed("clavicle."+side)@spec[n][0]; s=1 if side=="L" else -1
    elbow,wrist=solve(a,Vector(wrist),lengths[n],lengths["forearm."+side],(s*1.3,-.45,1.75))
    orient(n,a,elbow);orient("forearm."+side,elbow,wrist)
    orient("hand."+side,wrist,wrist+hand_q@(spec["hand."+side][1]-spec["hand."+side][0]),hand_q)
    return (rig.pose.bones["hand."+side].head-Vector(wrist)).length
def curve(t, keys):
    for (ta,va),(tb,vb) in zip(keys,keys[1:]):
        if t<=tb:return va+(vb-va)*smooth(ta,tb,t)
    return keys[-1][1]

clips={"idle":(90,True),"walk":(42,True),"attack_anticipation":(36,False),"attack":(36,False),"attack_recovery":(42,False),"hit":(27,False),"death":(90,False)}
metrics={}; actions={}
for label,(duration,loop) in clips.items():
    action=bpy.data.actions.new(label);action.use_fake_user=True
    rig.animation_data_create();rig.animation_data.action=action
    max_foot_error=0.;max_hand_error=0.
    for frame in range(duration+1):
        scene.frame_set(frame); t=frame/duration; phase=t*math.tau
        for p in rig.pose.bones: p.matrix_basis=Matrix.Identity(4)
        is_walk=label=="walk"
        pre=curve(t,[(0,0),(.62,1),(1,1)]) if label=="attack_anticipation" else 0
        slam=curve(t,[(0,0),(.24,.9),(.5,1),(.62,.87),(1,.7)]) if label=="attack" else 0
        recover=curve(t,[(0,.7),(.24,.7),(.9,0),(1,0)]) if label=="attack_recovery" else 0
        hit=curve(t,[(0,0),(.22,1),(.48,.45),(1,0)]) if label=="hit" else 0
        crouch=.04+(.025*math.cos(phase*2) if is_walk else .007*math.sin(phase))+.20*pre+.69*slam+.69*recover
        translate("pelvis",(0,-.05*pre-.10*slam-.10*recover,-crouch))
        pose_delta("spine",(.025*math.sin(phase) if is_walk else .1*slam+.1*recover,0,.015*math.sin(phase) if is_walk else 0))
        pose_delta("chest",(-.09*hit+.04*slam,0,.07*hit))
        pose_delta("head",(.012*math.sin(phase),0,.018*math.sin(phase)))
        for side,s in (("L",1),("R",-1)):
            ankle=Vector((s*.43,.04,.27)); foot_q=Quaternion();lift=0.
            if is_walk:
                u=(t+(0 if side=="L" else .5))%1;stance=.63;stride=.65
                if u<stance:
                    along=-stride/2+stride*u/stance
                else:
                    v=(u-stance)/(1-stance)
                    along=stride/2-stride*smooth(0,1,v)
                    lift=.09*math.sin(math.pi*v)
                ankle.y+=along;ankle.z+=lift
            max_foot_error=max(max_foot_error,leg(side,ankle,foot_q,lift))
            raised=Vector((s*1.17,-.30,2.78))
            contact=Vector((s*.72,-.58,.31))
            neutral=Vector((s*1.03,-.045,1.17))
            wrist=neutral.copy()
            if is_walk:wrist.y+=(-.19 if side=="L" else .19)*math.sin(phase)
            if pre:wrist=wrist.lerp(raised,pre)
            if slam:wrist=raised.lerp(contact,slam)
            if recover:wrist=neutral.lerp(contact,recover)
            if hit:wrist+=Vector((s*.02,.13,-.08))*hit
            hand_q=Euler((-.25*pre+.30*slam+.30*recover,0,0),"XYZ").to_quaternion()
            max_hand_error=max(max_hand_error,arm(side,wrist,hand_q))
            for digit in ("index","middle","ring","outer"):
                curl=max(pre,slam,recover)
                pose_delta(digit+"_1."+side,(0,s*.35*curl,0))
                pose_delta(digit+"_2."+side,(0,s*.45*curl,0))
            pose_delta("thumb_1."+side,(0,-s*.2*max(pre,slam,recover),0))
        if label=="death":
            kneel=curve(t,[(0,0),(.32,1),(.58,.85),(1,.4)])
            fall=curve(t,[(0,0),(.37,0),(.83,1),(1,1)])
            pose_delta("root",(-1.22*fall,-.13*fall,.15*fall))
            offset=Vector((.13*fall,-.33*fall,-.51*kneel-.34*fall))
            translate("root",offset)
            pose_delta("thigh.L",(.30*kneel+.20*fall,0,0));pose_delta("shin.L",(-.95*kneel-.36*fall,0,0))
            pose_delta("thigh.R",(.44*kneel+.22*fall,0,0));pose_delta("shin.R",(-1.10*kneel-.44*fall,0,0))
            bpy.context.view_layer.update()
            evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
            min_z=min((evaluated.matrix_world@v.co).z for v in mesh.vertices)
            evaluated.to_mesh_clear()
            offset.z-=min_z
            translate("root",offset)
            bpy.context.view_layer.update()
        for p in rig.pose.bones:
            p.keyframe_insert("location",frame=frame,group=p.name)
            p.keyframe_insert("rotation_quaternion",frame=frame,group=p.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points:key.interpolation="LINEAR"
    actions[label]=action
    metrics[label]={"duration_seconds":duration/30,"loop":loop,"max_foot_target_error_m":max_foot_error,"max_hand_target_error_m":max_hand_error}
    if label=="attack": metrics[label]["contact_frame"]=18;metrics[label]["contact_time_seconds"]=.6
    print("BULWARK_CLIP",label,metrics[label],flush=True)
rig.animation_data.action=None
for label,action in actions.items():
    track=rig.animation_data.nla_tracks.new();track.name=label
    track.strips.new(label,0,action);track.mute=True

rig.animation_data.action=actions["attack_anticipation"]
scene.frame_set(36)
evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
deformed=evaluated.to_mesh()
stress_edges=sorted(((deformed.vertices[e.vertices[0]].co-deformed.vertices[e.vertices[1]].co).length,
                     (body.data.vertices[e.vertices[0]].co-body.data.vertices[e.vertices[1]].co).length)
                    for e in body.data.edges)
worst_stretched_edge_m=max(length for length,rest_length in stress_edges if rest_length<.1)
evaluated.to_mesh_clear()
print("BULWARK_SKIN_STRESS",worst_stretched_edge_m,flush=True)

report={"source":str(SOURCE.relative_to(ROOT)),"height_m":2.8,"source_triangles":source_triangles,
        "optimized_triangles":len(body.data.loop_triangles),
        "reduction_percent":100*(1-len(body.data.loop_triangles)/source_triangles),
        "surface_error_p99_mm":errors[int(.99*len(errors))]*1000,
        "surface_error_max_mm":max(errors)*1000,
        "reverse_error_p99_mm":reverse_errors[int(.99*len(reverse_errors))]*1000,
        "crown_max_error_mm":max(crown_errors)*1000,
        "bones":len(spec),"skin_stress_edge_max_m":worst_stretched_edge_m,
        "unweighted_vertices":sum(not v.groups for v in body.data.vertices),
        "weight_sum_max_error":max(abs(sum(g.weight for g in v.groups)-1) for v in body.data.vertices),
        "clips":metrics,"forward_blender":"-Y","forward_godot":"+Z"}
(OUT/"validation.json").write_text(json.dumps(report,indent=2)+"\n")
(GAME/"animation_manifest.json").write_text(json.dumps({"fps":30,"clips":metrics,"height_m":2.8,"forward_axis":"+Z"},indent=2)+"\n")

def look(obj,point): obj.rotation_euler=(Vector(point)-obj.location).to_track_quat("-Z","Y").to_euler()
for pos,energy in (((3,-4,5),500),((-4,-2,4),300),((0,4,5),550)):
    bpy.ops.object.light_add(type="AREA",location=pos)
    lamp=bpy.context.object;lamp.data.energy=energy;lamp.data.shape="DISK";lamp.data.size=4;look(lamp,(0,0,1.4))
bpy.ops.object.camera_add(location=(4,-6,3.4))
cam=bpy.context.object;cam.name="Review_Camera";cam.data.type="ORTHO";cam.data.ortho_scale=3.7;look(cam,(0,0,1.4));scene.camera=cam
scene.render.engine="CYCLES";scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=800;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world.color=(.12,.12,.12)
scene.frame_start=0;scene.frame_end=90
rig.animation_data.action=actions["idle"];scene.frame_set(0)
bpy.context.preferences.filepaths.save_version=0
for im in bpy.data.images:
    if im.size[0]:
        try: im.pack()
        except RuntimeError: pass
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"bulwark_rigged.blend"))
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(GAME/"bulwark.glb"),export_format="GLB",use_selection=True,
    export_animations=True,export_animation_mode="ACTIONS",export_frame_range=False,
    export_force_sampling=True,export_skins=True,export_def_bones=False,
    export_cameras=False,export_lights=False)
if os.getenv("BULWARK_SKIP_RENDERS") != "1":
    for label,frame in (("idle",0),("walk",12),("attack_anticipation",36),("attack",18),("attack_recovery",8),("death",90)):
        rig.animation_data.action=actions[label];scene.frame_set(frame)
        if label=="death":cam.location=(4,-6,4.6);look(cam,(0,0,.8));cam.data.ortho_scale=4.1
        scene.render.filepath=str(OUT/"previews"/f"{label}.png")
        bpy.ops.render.render(write_still=True)
print("BULWARK_BUILD_COMPLETE",json.dumps(report),flush=True)
sys.stdout.flush();os._exit(0)
