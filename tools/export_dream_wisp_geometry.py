"""Bake optimized, textured geometry from the editable fairy source for Godot rigging."""
from pathlib import Path
import bpy,json
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'art_source/dream_wisp/production'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'dream_wisp_art.blend'))
objects=[];manifest={};triangles=0
for col in bpy.data.collections:
    if not col.name.startswith(('01','04','05','06')):continue
    for ob in list(col.objects):
        if ob.type not in {'MESH','CURVE'} or '_ridge_' in ob.name or '_strand_' in ob.name:continue
        if ob.hide_render:continue
        objects.append(ob)
# Include body collection by direct identity if naming changed.
if bpy.data.objects['Skin'] not in objects:objects.append(bpy.data.objects['Skin'])
for ob in objects:
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    for mod in ob.modifiers:
        if mod.type in {'SUBSURF','MULTIRES'}:mod.show_viewport=False
    if ob.type=='CURVE':ob.data.bevel_resolution=0;ob.data.resolution_u=2
    bpy.ops.object.convert(target='MESH');ob=bpy.context.object
    if ob.name.startswith(('Hair_lock','Hair_back','Hair_front_sweep','Hair_scalp_cap')) and len(ob.data.polygons)>200:
        mod=ob.modifiers.new('Game reduction','DECIMATE');mod.ratio=.055 if ob.name=='Hair_scalp_cap' else .20
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    ob.scale=(.494,)*3;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    # Godot importer sanitizes spaces; explicit stable names avoid ambiguous manifest keys.
    old=ob.name;ob.name='part_%03d'%len(manifest)
    manifest[ob.name]={'source':old,'attachment':ob.get('attachment',''),'triangles':sum(len(p.vertices)-2 for p in ob.data.polygons)}
    ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles)
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'dream_wisp_geometry.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_materials='EXPORT',export_extras=True)
(OUT/'geometry_manifest.json').write_text(json.dumps({'triangles':triangles,'parts':manifest},indent=2))
print('GAME_GEOMETRY',triangles,'triangles',len(manifest),'parts',flush=True)
