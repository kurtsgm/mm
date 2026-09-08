"""Build the editable fairy head study from Blender Studio's CC0 base mesh.

Run with Blender 4.5 LTS, not system Python. The approved design images are
reference boards only: no generated face image is projected onto this mesh.
Use --base-bundle to point at the extracted Human Base Meshes v1.4.1 .blend.
Rebuilding replaces the generated study; save later manual sculpting as v2.
"""
import argparse
import sys
import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector,Matrix
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--base-bundle',type=Path,required=True)
parser.add_argument('--render-dir',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=ROOT/'art_source/dream_wisp/head_v1'
TMP=args.render_dir
OUT.mkdir(parents=True,exist_ok=True)
TMP.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=bpy.context.scene
p=args.base_bundle
with bpy.data.libraries.load(str(p),link=False) as(src,dst):dst.collections=['Body Female - Realistic']
c=dst.collections[0];s.collection.children.link(c);bpy.context.view_layer.update()
body=bpy.data.objects['GEO-body_female_realistic'];offset=body.matrix_world.translation.copy()
# Capture world transforms before clearing parent relationships.
world={o.name:o.matrix_world.copy() for o in c.all_objects}
objects=list(c.all_objects)
for o in objects:
    m=world[o.name];m.translation-=offset;o.parent=None;o.matrix_world=m
bpy.context.view_layer.update()
body.modifiers[0].levels=1;body.modifiers[0].render_levels=1
bpy.context.view_layer.objects.active=body;body.select_set(True)
bpy.ops.object.convert(target='MESH');body=bpy.context.object
bm=bmesh.new();bm.from_mesh(body.data)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.000001,plane_co=(0,0,1.31),plane_no=(0,0,1),clear_inner=True,clear_outer=False)
# Keep the lower bust boundary intentionally open for body attachment.
bm.to_mesh(body.data);bm.free();body.name='Fae_Head';body.data.name='Fae_Head_Quad_Cage'
# Isolate the original ear face sets, so proportional edits cannot pull the cranium.
EAR_MASK=np.zeros(len(body.data.vertices));inc=[[] for _ in body.data.vertices]
sets=body.data.attributes['.sculpt_face_set']
for poly,entry in zip(body.data.polygons,sets.data):
    for i in poly.vertices:inc[i].append(entry.value)
for i,groups in enumerate(inc):
    EAR_MASK[i]=1.0 if groups and all(g in (4,5) for g in groups) else 0.0
if body.data.attributes.get('custom_normal'):body.data.attributes.remove(body.data.attributes['custom_normal'])
headcoll=bpy.data.collections.new('01 • Head sculpture');s.collection.children.link(headcoll)
for o in list(c.all_objects):
    headcoll.objects.link(o);c.objects.unlink(o)
bpy.data.collections.remove(c)
for o in headcoll.objects:
    if o.type=='MESH':
        o.data.materials.clear()
        for f in o.data.polygons:f.use_smooth=True
        o.asset_clear()
body['source']='Blender Studio Human Base Meshes v1.4.1 / Body Female - Realistic / Dan Ulrich / CC0'
# Mesh deformation in the original anatomical metre coordinates, preserving topology.
def smoothstep(a,b,x):
    t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def proportion(P):
    p=P.copy();x,y,z=P.T;a=np.abs(x)
    front=1-smoothstep(-.11,-.045,y)
    dest=np.interp(z,[1.31,1.39,1.421,1.441,1.466,1.497,1.532,1.554,1.60,1.65],[1.31,1.39,1.419,1.437,1.459,1.485,1.524,1.546,1.60,1.65])
    p[:,2]+=(dest-z)*front
    jaw=np.exp(-((z-1.458)/.042)**2)*front
    p[:,0]*=1-.09*jaw
    neck=(1-smoothstep(1.415,1.435,z))*smoothstep(1.31,1.38,z)
    p[:,0]*=1-.10*neck
    return p
def planes(P):
    p=P.copy();x,y,z=P.T;a=np.abs(x)
    front=1-smoothstep(-.128,-.080,y)
    # Straighter bridge and restrained nasal alae.
    bridge=np.exp(-((x/.012)**2+((z-1.507)/.027)**2))*front
    p[:,1]-=.003*bridge
    ala=np.exp(-((z-1.489)/.014)**2)*(1-smoothstep(-.143,-.126,y))
    p[:,0]*=1-.16*ala
    tip=np.exp(-((x/.016)**2+((z-1.489)/.014)**2))*(1-smoothstep(-.153,-.137,y))
    p[:,1]+=.0025*tip
    lowerlip=np.exp(-((x/.024)**2+((z-1.449)/.009)**2))*(1-smoothstep(-.143,-.122,y))
    p[:,1]+=.0015*lowerlip
    # Almond orbit: increase horizontal aperture while keeping eye centres.
    orbit=np.exp(-(((a-.033)/.023)**4+((z-1.526)/.019)**4))*front
    p[:,0]+=np.sign(x)*(a-.033)*.15*orbit
    p[:,2]+=(a-.033)*.06*orbit
    # Small cheek-plane adjustment, retaining scan anatomy.
    cheek=np.exp(-(((a-.046)/.024)**2+((z-1.504)/.021)**2))*front
    p[:,1]-=.0015*cheek
    return p
def ears(P):
    p=P.copy();x,y,z=P.T;a=np.abs(x)
    # Smooth proportional edit of upper helix: retain concha, tragus, lobe.
    if len(P)!=len(EAR_MASK):return p
    ear=EAR_MASK*smoothstep(.065,.080,a)
    upper=smoothstep(1.488,1.534,z)
    w=ear*upper
    p[:,0]+=np.sign(x)*.024*w
    p[:,2]+=.020*w
    p[:,1]-=.009*w
    return p
funcs=[('01_Face_proportions',proportion),('02_Orbits_nose_cheeks',planes),('03_Pointed_ears',ears)]
for o in headcoll.objects:
    if o.type!='MESH':continue
    # Work in anatomical world coordinates for the same deformation of eyes and face.
    w=o.matrix_world.copy();inv=w.inverted()
    P=np.array([list(w@v.co) for v in o.data.vertices],dtype=float)
    basis=o.shape_key_add(name='Basis');previous=basis
    for name,func in funcs:
        P=func(P);key=o.shape_key_add(name=name);key.relative_key=previous
        for v,p in zip(key.data,P):v.co=inv@Vector(p)
        key.value=1;previous=key
    # Shift complete bust to origin without changing editable deformation coordinates.
    o.location.z-=1.31
    if o!=body:o.name='Eye_'+('L' if '.L' in o.name else 'R')
    mod=o.modifiers.new('Sculpt surface','SUBSURF');mod.levels=2 if o==body else 1;mod.render_levels=2

def material(name,color,rough):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*color,1);b.inputs['Roughness'].default_value=rough;return m
clay=material('Clay • no textures',(.34,.32,.29),.67)
eyeclay=material('Eyes • untextured neutral',(.44,.43,.40),.45)
for o in headcoll.objects:o.data.materials.append(clay if o==body else eyeclay)
# Eye iris surface is geometry and a flat gray material, no image projections.
irismat=material('Iris • neutral gray',(.095,.09,.08),.55)
pupilmat=material('Pupil • charcoal',(.018,.018,.018),.5)
bpy.context.view_layer.update()
for eye in [o for o in list(headcoll.objects) if o!=body]:
    dg=bpy.context.evaluated_depsgraph_get();ev=eye.evaluated_get(dg)
    vv=np.array([list(eye.matrix_world@v.co) for v in ev.data.vertices]);center=(vv.min(axis=0)+vv.max(axis=0))/2
    radius=(vv.max(axis=0)-vv.min(axis=0)).mean()/2
    print('EYE',eye.name,center,radius)
    verts=[(center[0],center[1]-radius-.00012,center[2])];faces=[];n=64;rings=12;ir=.0056
    for j in range(1,rings+1):
        r=ir*j/rings
        for i in range(n):
            t=2*math.pi*i/n;verts.append((center[0]+r*math.cos(t),center[1]-math.sqrt(max(.000001,radius**2-r*r))-.00012,center[2]+r*math.sin(t)))
    for i in range(n):faces.append((0,1+i,1+(i+1)%n))
    for j in range(rings-1):
        for i in range(n):faces.append((1+j*n+i,1+(j+1)*n+i,1+(j+1)*n+(i+1)%n,1+j*n+(i+1)%n))
    me=bpy.data.meshes.new(eye.name+'_iris');me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new(eye.name+'_iris',me);headcoll.objects.link(ob)
    me.materials.append(irismat);me.materials.append(pupilmat)
    for poly in me.polygons:poly.use_smooth=True;poly.material_index=1 if poly.index//n<5 else 0
# Neutral studio: light energy scaled to life-size bust.
s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=True
s.render.resolution_x=800;s.render.resolution_y=1000;s.render.resolution_percentage=100
s.world.color=(.12,.12,.12);s.view_settings.view_transform='AgX'
s.view_settings.look='AgX - Medium High Contrast'
target=Vector((0,-.025,.20))
studio=bpy.data.collections.new('02 • Studio and cameras');s.collection.children.link(studio)
def movecoll(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    studio.objects.link(o)
for name,loc,power,size in [('Key',(-.48,-.60,.80),10,.5),('Fill',(.50,-.32,.40),4,.55),('Rim',(.20,.40,.60),14,.4)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler();movecoll(o)
for name,angle in [('Front',0),('ThreeQuarter',-45),('Profile',-90),('Back',180)]:
    a=math.radians(angle);bpy.ops.object.camera_add(location=target+Vector((2*math.sin(a),-2*math.cos(a),0)))
    cam=bpy.context.object;cam.name='Camera_'+name;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=.39;movecoll(cam)
# Packed design board, reference only, excluded from render.
refcoll=bpy.data.collections.new('03 • Approved design reference (toggle)');s.collection.children.link(refcoll)
ref=bpy.data.objects.new('Face design • orthographic calibration still required',None);ref.empty_display_type='IMAGE';ref.data=bpy.data.images.load(str(ROOT/'docs/art/dream-wisp-design-v1/face-turnaround.webp'));ref.data.pack();ref.empty_display_size=.75;ref.location=(.65,.12,.22);ref.rotation_euler=(math.pi/2,0,0);ref.hide_render=True;refcoll.objects.link(ref);refcoll.hide_viewport=True
s.camera=bpy.data.objects['Camera_ThreeQuarter']
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.region_3d.view_perspective='CAMERA';sp.shading.type='SOLID';sp.shading.light='STUDIO';sp.shading.studiolight_rotate_z=.4;sp.shading.color_type='MATERIAL';sp.shading.show_shadows=True;sp.shading.show_cavity=True
s['Stage']='Head gray sculpt v1, approved 2D concept; no production rig or textures'
s['Source_license']='CC0, Blender Studio / Dan Ulrich, Human Base Meshes v1.4.1'
s['Modeling_scale']='Life-size sculpt; head height about 0.22 m, scale about 0.5 for 0.8 m fairy'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dream_wisp_head_v1.blend'),compress=True)
for name in ['Front','ThreeQuarter','Profile','Back']:
    s.camera=bpy.data.objects['Camera_'+name];s.render.filepath=str(TMP/('sculpt-'+name.lower()+'.png'));bpy.ops.render.render(write_still=True)
print('SCULPT_DONE',len(body.data.vertices),len(body.data.polygons))
