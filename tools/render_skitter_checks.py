"""Render representative Shieldback poses without a desktop display."""
import os, sys
from pathlib import Path
import bpy
from mathutils import Vector

root=Path(__file__).resolve().parents[1]
out=root/'assets/source/blender/rift_skitter/previews'
out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(root/'assets/source/blender/rift_skitter/skitter_rigged.blend'))
rig=bpy.data.objects['Shieldback_Rig']
scene=bpy.context.scene
def look(obj,at):obj.rotation_euler=(Vector(at)-obj.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.2,-3.5,1.8))
camera=bpy.context.object
camera.data.type='ORTHO';camera.data.ortho_scale=2.2
look(camera,(0,0,.62));scene.camera=camera
for xyz,power in [((2,-3,3),500),((-2,-2,2),300),((1,2,3),400)]:
    bpy.ops.object.light_add(type='AREA',location=xyz)
    lamp=bpy.context.object;lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=3
    look(lamp,(0,0,.55))
scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=900;scene.render.resolution_y=700
scene.render.resolution_percentage=100
scene.world.color=(.12,.12,.12)
for name,frame in [('idle',0),('walk',9),('run',6),('attack_anticipation',20),('attack',8),('attack_recovery',7),('hit',5),('death',60)]:
    rig.animation_data.action=bpy.data.actions[name]
    scene.frame_set(frame)
    scene.render.filepath=str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('SKITTER_POSE_RENDER',name,frame,flush=True)
sys.stdout.flush();os._exit(0)
