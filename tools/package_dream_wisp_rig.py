"""Import the baked game rig into a portable editable Blender review file."""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'content/monsters/models/dream_wisp.glb'))
for im in bpy.data.images:
    if not im.packed_file:
        try:im.pack()
        except RuntimeError:pass
s=bpy.context.scene;s['Source']='Game rig baked from dream_wisp_art.blend by tools/build_dream_wisp.gd'
s['Review']='39-bone deformation rig; animation clips are imported as NLA tracks. High resolution editable art is in dream_wisp_art.blend.'
for o in s.objects:
    if o.type=='ARMATURE':o.show_in_front=True
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=1.8
        area.spaces.active.region_3d.view_location=(0,0,.52)
        area.spaces.active.shading.type='MATERIAL'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/dream_wisp/production/dream_wisp_rigged.blend'),compress=True)
print('RIGGED_SOURCE_SAVED',flush=True)
