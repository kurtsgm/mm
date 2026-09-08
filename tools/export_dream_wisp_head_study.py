"""Validate, export and render the existing editable head study with Blender.

Run after build_dream_wisp_head_study.py, or on the saved v1 study.
The .blend is saved before temporary topology-render settings are applied.
"""
import argparse, sys
import bpy,bmesh,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--render-dir',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
args.render_dir.mkdir(parents=True,exist_ok=True)
OUT=ROOT/'art_source/dream_wisp/head_v1'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'dream_wisp_head_v1.blend'))
s=bpy.context.scene;head=bpy.data.objects['Fae_Head'];coll=head.users_collection[0]
report={'blender':bpy.app.version_string,'stage':'head_gray_study_v1','meshes':[],'image_texture_nodes':[]}
for o in coll.objects:
    bm=bmesh.new();bm.from_mesh(o.data)
    bad=sum(f.calc_area()<1e-12 for f in bm.faces)
    report['meshes'].append({'name':o.name,'cage_vertices':len(bm.verts),'cage_faces':len(bm.faces),'quad_faces':sum(len(f.verts)==4 for f in bm.faces),'zero_area_faces':bad,'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_nonboundary_edges':sum(not e.is_manifold and not e.is_boundary for e in bm.edges),'shape_keys':[k.name for k in o.data.shape_keys.key_blocks] if o.data.shape_keys else []})
    bm.free()
    for mat in o.data.materials:
        if mat.use_nodes:
            for n in mat.node_tree.nodes:
                if n.type=='TEX_IMAGE':report['image_texture_nodes'].append(mat.name)
    assert bad==0,(o.name,bad)
assert not report['image_texture_nodes']
report['nominal_head_height_m']=.222
report['neck_boundary']='Open lower bust cut is intentional for later body attachment.'
# Export an evaluated static mesh snapshot; source keeps all sculpt shape keys.
exp=bpy.data.collections.new('Export_snapshot');s.collection.children.link(exp)
bpy.ops.object.select_all(action='DESELECT')
for o in coll.objects:
    for m in o.modifiers:
        if m.type=='SUBSURF':m.levels=1
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
for o in coll.objects:
    mesh=bpy.data.meshes.new_from_object(o.evaluated_get(dg),depsgraph=dg);ob=bpy.data.objects.new(o.name+'_snapshot',mesh);exp.objects.link(ob);ob.matrix_world=o.matrix_world.copy();ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'dream_wisp_head_v1.glb'),use_selection=True,export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
for o in list(exp.objects):bpy.data.objects.remove(o,do_unlink=True)
bpy.data.collections.remove(exp)
for o in coll.objects:
    for m in o.modifiers:
        if m.type=='SUBSURF':m.levels=2 if o==head else 1
s.camera=bpy.data.objects['Camera_ThreeQuarter']
bpy.ops.object.select_all(action='DESELECT');head.select_set(True);bpy.context.view_layer.objects.active=head
# Per-object inspectable sculpt masks, using the anatomical base's face sets.
sets=head.data.attributes['.sculpt_face_set'];groups={name:(head.vertex_groups.get(name) or head.vertex_groups.new(name=name)) for name in ['Ear_L','Ear_R','Lips_upper','Lips_lower']}
map_ids={4:'Ear_L',5:'Ear_R',7:'Lips_upper',8:'Lips_lower'}
for poly,entry in zip(head.data.polygons,sets.data):
    if entry.value in map_ids:groups[map_ids[entry.value]].add(list(poly.vertices),1,'REPLACE')
report['packed_reference_images']=[i.name for i in bpy.data.images if i.packed_file]
report['camera_views']=[o.name for o in s.objects if o.type=='CAMERA']
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dream_wisp_head_v1.blend'),compress=True)
# Re-render all views from the saved model, keeping source camera unchanged.
s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=True
s.render.resolution_x=800;s.render.resolution_y=1000;s.render.resolution_percentage=100
for name in ['Front','ThreeQuarter','Profile','Back']:
    s.camera=bpy.data.objects['Camera_'+name]
    s.render.filepath=str(args.render_dir/('sculpt-'+name.lower()+'.png'))
    bpy.ops.render.render(write_still=True)
print(json.dumps(report,indent=2))
