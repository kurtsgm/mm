"""Create the editable ogre art and budgeted geometry. Blender 4.5 LTS.

First run: --base-bundle /path/to/human_base_meshes_bundle.blend
Later runs reuse the isolated local CC0 base. Output is deterministic.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art_source/ogre/production'
OUT.mkdir(parents=True, exist_ok=True)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--base-bundle', type=Path)
parser.add_argument('--render-dir', type=Path, default=ROOT / 'build/ogre-art')
parser.add_argument('--skip-render', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
args.render_dir.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
asset = bpy.data.collections.new('Ogre — game art')
scene.collection.children.link(asset)

base_path = OUT / 'ogre_base.blend'
if args.base_bundle:
    with bpy.data.libraries.load(str(args.base_bundle), link=False) as (src, dst):
        dst.collections = ['Body Male - Realistic']
    source = dst.collections[0]
    scene.collection.children.link(source)
    body = next(o for o in source.objects if o.name == 'GEO-body_male_realistic')
    body.location = (0, 0, 0)
    body.modifiers[0].levels = 1
    bpy.context.view_layer.update()
    mesh = bpy.data.meshes.new_from_object(body.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    baked = bpy.data.objects.new('CC0_Male_Base_Level1', mesh)
    asset.objects.link(baked)
    baked['source'] = 'Dan Ulrich / Blender Human Base Meshes v1.4.1 / CC0'
    bpy.data.libraries.write(str(base_path), {baked}, fake_user=True, compress=True)
    for o in list(source.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(source)
else:
    with bpy.data.libraries.load(str(base_path), link=False) as (src, dst):
        dst.objects = ['CC0_Male_Base_Level1']
    baked = dst.objects[0]
    asset.objects.link(baked)
body = baked
body.name = 'Skin'
body['attachment'] = 'body'
body.data.materials.clear()


def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


def morph(points):
    p = np.asarray(points, dtype=float)
    x, y, z = p[..., 0], p[..., 1], p[..., 2]
    # Short load-bearing legs, long massive trunk, short neck, enlarged jaw.
    zz = np.interp(z, [-.006, .10, .48, .86, 1.00, 1.18, 1.34, 1.43, 1.52, 1.69],
                   [0, .16, .65, 1.22, 1.62, 2.09, 2.51, 2.62, 2.80, 3.15])
    width = np.interp(z, [0, .48, .86, 1.0, 1.18, 1.34, 1.43, 1.52, 1.69],
                      [2.8, 2.9, 3.2, 3.35, 3.4, 3.25, 3.7, 4.0, 3.55])
    xx = x * width
    yy = y * np.interp(z, [0, .86, 1.1, 1.34, 1.43, 1.69], [2.7, 3.1, 3.9, 3.4, 3.15, 3.05])
    core = 1 - smooth(.16, .27, np.abs(x))
    front = smooth(.025, -.10, y)
    belly = np.exp(-((z-1.045)/.15)**2) * core * front
    yy -= .20 * belly
    zz -= .05 * belly
    xx *= 1 + .20*np.exp(-((z-1.035)/.16)**2)*core
    # Broaden jaw/nose and project the brow while retaining anatomical topology.
    jaw = np.exp(-((z-1.48)/.065)**2) * smooth(.09, .045, np.abs(x))
    xx *= 1 + .18 * jaw
    yy -= .045 * jaw * front
    nose = np.exp(-((z-1.55)/.032)**2 - (x/.028)**2) * front
    xx *= 1 + .20 * nose
    yy += .022 * nose
    brow = np.exp(-((z-1.592)/.016)**2 - ((np.abs(x)-.033)/.035)**2) * front
    yy -= .022 * brow
    zz -= .010 * brow
    arm = smooth(.20, .29, np.abs(x)) * smooth(.72, .84, z) * (1-smooth(1.31,1.42,z))
    arm_x = np.interp(z, [.74,.85,1.085,1.31,1.42], [.415,.390,.318,.222,.16])
    xx += np.sign(x)*(np.abs(x)-arm_x)*width*.55*arm
    yy += (y+.035)*2.0*arm
    zz += .075*np.exp(-((z-1.345)/.07)**2-((np.abs(x)-.105)/.15)**2)
    return np.stack([xx, yy, zz], axis=-1)


original = np.array([v.co[:] for v in body.data.vertices])
shaped = morph(original)
for v, co in zip(body.data.vertices, shaped):
    v.co = co
for face in body.data.polygons:
    face.use_smooth = True
surface = BVHTree.FromPolygons([v.co.copy() for v in body.data.vertices], [list(p.vertices) for p in body.data.polygons])
# Keep the sculptable source mesh; export will reduce only a duplicate.
body['design'] = 'Heavy human mutation: broadened jaw, lowered brow, long torso, short powerful legs'


def material(name, color, roughness=.75, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1)
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (1, 1, 1, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    vertex = mat.node_tree.nodes.new('ShaderNodeVertexColor')
    vertex.layer_name = 'Tint'
    mat.node_tree.links.new(vertex.outputs['Color'], bsdf.inputs['Base Color'])
    return mat


MATS = {
    'Skin': material('Skin', (.32, .27, .19), .82),
    'Hide': material('Hide', (.105, .038, .022), .86),
    'Iron': material('Iron', (.065, .070, .065), .82, .35),
    'Stone': material('Stone', (.22, .245, .24), .91),
    'Wood': material('Wood', (.095, .040, .016), .86),
    'Ivory': material('Ivory', (.62, .53, .33), .57),
    'Eyes': material('Eyes', (.30, .22, .08), .32),
}


def paint(obj, mat_name, tint=None):
    obj.data.materials.clear()
    obj.data.materials.append(MATS[mat_name])
    color = obj.data.color_attributes.get('Tint') or obj.data.color_attributes.new(name='Tint', type='FLOAT_COLOR', domain='POINT')
    obj.data.color_attributes.active_color = color
    obj.data.color_attributes.render_color_index = list(obj.data.color_attributes).index(color)
    base = np.array(tint or MATS[mat_name].diffuse_color[:3])
    for vertex, item in zip(obj.data.vertices, color.data):
        p = vertex.co
        variation = .96 + .045*math.sin(p.x*29 + p.z*19)*math.sin(p.y*23-p.z*7)
        c = base * variation
        if mat_name == 'Skin':
            # Subtle warm face/elbows and darker natural lip region, no decal face.
            lip = math.exp(-((p.z-2.725)/.028)**2 - (p.x/.19)**2) if p.y < -.39 else 0
            c *= 1-.32*lip
            c += np.array([.035, -.012, -.012])*math.exp(-((p.z-2.82)/.15)**2)
        item.color = (*np.clip(c, 0, 1), 1)


paint(body, 'Skin')


def move_to_asset(o, name, tag, mat_name, tint=None):
    o.name = name
    for col in list(o.users_collection):
        col.objects.unlink(o)
    asset.objects.link(o)
    o['attachment'] = tag
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    paint(o, mat_name, tint)
    for face in o.data.polygons:
        face.use_smooth = True
    return o


def ellipsoid(name, center, radius, mat, tag, segments=20, rings=12, tint=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=center)
    o = bpy.context.object
    o.scale = radius
    return move_to_asset(o, name, tag, mat, tint)


def mesh_object(name, vertices, faces, mat, tag, tint=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    asset.objects.link(o)
    o['attachment'] = tag
    paint(o, mat, tint)
    uv = mesh.uv_layers.new(name='UVMap')
    for loop in mesh.loops:
        p = mesh.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (p.x*1.7+p.y*.4, p.z*1.7)
    for face in mesh.polygons:
        face.use_smooth = True
    return o


def tube(name, points, radii, mat, tag, sides=10, tint=None):
    points = [Vector(p) for p in points]
    vertices, faces = [], []
    for j, p in enumerate(points):
        axis = (points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized()
        reference = Vector((0,1,0)) if abs(axis.y)<.9 else Vector((1,0,0))
        u = axis.cross(reference).normalized()
        v = axis.cross(u).normalized()
        r = radii[j] if isinstance(radii, list) else radii
        for i in range(sides):
            a = i/sides*math.tau
            vertices.append(p+r*(u*math.cos(a)+v*math.sin(a)))
    for j in range(len(points)-1):
        for i in range(sides):
            n=(i+1)%sides
            faces.append((j*sides+i,j*sides+n,(j+1)*sides+n,(j+1)*sides+i))
    faces += [tuple(reversed(range(sides))),tuple((len(points)-1)*sides+i for i in range(sides))]
    return mesh_object(name,vertices,faces,mat,tag,tint)


def band(name, center, rx, ry, height, mat, tag, tilt=0, tint=None):
    # Closed thick ribbon, rather than intersecting independent strap cylinders.
    vertices, faces = [], []
    for radial in [0, -.022]:
        for z in [-height/2, height/2]:
            for i in range(40):
                a=i/40*math.tau
                vertices.append((center[0]+(rx+radial)*math.cos(a),center[1]+(ry+radial)*math.sin(a),center[2]+z+tilt*math.sin(a)))
    for i in range(40):
        n=(i+1)%40
        faces += [(i,n,40+n,40+i),(80+i,120+i,120+n,80+n),(40+i,40+n,120+n,120+i),(i,80+i,80+n,n)]
    return mesh_object(name,vertices,faces,mat,tag,tint)


# Eyes are physically separate, embedded behind the deformed eyelids.
for sign, side in [(-1,'R'),(1,'L')]:
    center = morph(np.array([sign*.0329,-.12182,1.5737]))
    ellipsoid('Eye_'+side,center,(.040,.039,.037),'Eyes','head',24,16,(.42,.33,.19))
    iris = center+np.array([0,-.037,0])
    ellipsoid('Iris_'+side,iris,(.019,.006,.019),'Eyes','head',20,10,(.30,.115,.014))
    ellipsoid('Pupil_'+side,iris+np.array([0,-.005,0]),(.009,.003,.012),'Eyes','head',16,8,(.006,.004,.002))
    # Two short lower tusks, rooted beside the lower lip.
    tube('Tusk_'+side,[(sign*.142,-.482,2.676),(sign*.160,-.526,2.727),(sign*.154,-.535,2.788)],[.034,.025,.002],'Ivory','jaw',12)

def section(z, arm_side=0):
    mask=abs(shaped[:,2]-z)<.035
    mask &= shaped[:,0]*arm_side>.95 if arm_side else abs(shaped[:,0])<.85
    cloud=shaped[mask]
    low,high=cloud.min(0),cloud.max(0)
    center=(low+high)*.5
    return center, (high[0]-low[0])*.5+.018, (high[1]-low[1])*.5+.020

# Fit waist clothing to the actual sculpt, including the hanging abdomen.
waist,waist_x,waist_y=section(1.44)
band('Belt',(0,waist[1],1.44),waist_x+.016,waist_y+.02,.15,'Hide','pelvis')
band('Skirt_lining',(0,-.06,1.14),.64,.47,.49,'Hide','pelvis',tint=(.058,.023,.014))
for i in range(12):
    angle=i/12*math.tau
    length=.53+.08*math.sin(i*2.17)
    vertices=[]
    for row in range(5):
        t=row/4
        for col in range(5):
            u=col/4
            a=angle+(u-.5)*.63
            z=1.46-length*t+.022*math.sin(u*math.pi*3+i)*t
            mid,rx,ry=section(z)
            rx=max(rx+.038,.64);ry=max(ry+.042,.47)
            vertices.append((rx*math.cos(a),mid[1]+ry*math.sin(a),z))
    faces=[(r*5+c,r*5+c+1,(r+1)*5+c+1,(r+1)*5+c) for r in range(4) for c in range(4)]
    o=mesh_object('Hide_panel_%02d'%i,vertices,faces,'Hide','skirt_L' if math.cos(angle)>=0 else 'skirt_R',(.095+.015*(i%3),.033,.019))
    solid=o.modifiers.new('Hide thickness','SOLIDIFY');solid.thickness=.016
    bevel=o.modifiers.new('Worn edges','BEVEL');bevel.width=.006;bevel.segments=2
    for j in [-.16,.16]:
        a=angle+j
        ellipsoid('Skirt_rivet',(math.cos(a)*(waist_x+.045),waist[1]+math.sin(a)*(waist_y+.045),1.43),(.017,.017,.017),'Iron','pelvis',10,6)
# Rectangular buckle built as a continuous thick frame.
front_y=waist[1]-waist_y-.04
tube('Buckle',[(-.16,front_y,1.51),(.16,front_y,1.51),(.16,front_y,1.37),(-.16,front_y,1.37),(-.16,front_y,1.51)],.022,'Iron','pelvis',8)
tube('Buckle_pin',[(0,front_y-.012,1.38),(.045,front_y-.012,1.50)],.011,'Iron','pelvis',8)

# Foot and wrist bindings follow their skeletal attachment, not torso height.
for sign, side in [(-1,'R'),(1,'L')]:
    for i in range(3):
        z=1.37+i*.052
        wrist,rx,ry=section(z,sign)
        band('Wrist_wrap_'+side+str(i),(wrist[0],wrist[1],z),rx,ry,.059,'Hide','hand_'+side,tilt=.014)
    ankle=morph(np.array([sign*.162,.05,.10]))
    for i in range(3):
        band('Ankle_wrap_'+side+str(i),(ankle[0],ankle[1]+.02,.20+i*.065),.12,.13,.072,'Hide','foot_'+side,tilt=.024)
    # Front instep band leaves modeled toes visible.
    band('Instep_'+side,(ankle[0],.06,.10),.16,.19,.08,'Hide','foot_'+side,tilt=.015)

# One-sided leather harness across the shoulder and back.
for back in [False,True]:
    vertices=[]
    for i in range(20):
        t=i/19;x=.65-1.0*t;z=2.48-1.04*t
        for edge in [-1,1]:
            px=x+edge*.065
            origin=Vector((px,2 if back else -2,z))
            point=surface.ray_cast(origin,Vector((0,-1 if back else 1,0)))[0]
            if point is None:point=Vector((px,.30 if back else -.35,z))
            point.y+=.020 if back else -.020
            vertices.append(point)
    faces=[(i*2,i*2+1,i*2+3,i*2+2) for i in range(19)]
    o=mesh_object('Harness_back' if back else 'Harness_front',vertices,faces,'Hide','body')
    solid=o.modifiers.new('Strap thickness','SOLIDIFY');solid.thickness=.02
# Curved overlapping steel plates with closed backs; no spiky silhouette.
for plate in range(3):
    vertices=[]
    for row in range(5):
        a=-.90+row/4*1.80
        for col in range(6):
            u=col/5
            x=.61+plate*.09+u*.17+.15*math.cos(a)
            z=2.44-plate*.105-.09*u+.16*math.cos(a)
            vertices.append((x,.32*math.sin(a),z))
    faces=[(r*6+c,r*6+c+1,(r+1)*6+c+1,(r+1)*6+c) for r in range(4) for c in range(5)]
    o=mesh_object('Shoulder_plate_'+str(plate),vertices,faces,'Iron','upper_arm_L')
    solid=o.modifiers.new('Plate thickness','SOLIDIFY');solid.thickness=.027
    bevel=o.modifiers.new('Hammered rim','BEVEL');bevel.width=.010;bevel.segments=2
    for y in [-.22,.22]:
        ellipsoid('Shoulder_rivet',(.78+plate*.09,y,2.52-plate*.105),(.022,.022,.014),'Iron','upper_arm_L',12,8,(.29,.26,.19))

# Wooden maul, irregular stone and crossed lashings; all rigidly hand-bound.
grip=morph(np.array([-.395,-.052,.855]))
# Replace the open right fingers with a modeled closed grip, joined under the cuff.
bm=bmesh.new();bm.from_mesh(body.data)
remove=[f for f in bm.faces if f.calc_center_median().x < -.85 and f.calc_center_median().z < 1.34]
bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(body.data);bm.free()
ellipsoid('Fist_palm',grip+np.array([0,.018,.045]),(.12,.102,.15),'Skin','hand_R',24,16)
for finger in range(4):
    x=grip[0]-.076+finger*.051
    tube('Gripping_finger_'+str(finger),[(x,grip[1]-.054,grip[2]+.05),(x,grip[1]-.115,grip[2]-.045),(x,grip[1]-.055,grip[2]-.115),(x,grip[1]+.014,grip[2]-.068)],[.034,.034,.03,.022],'Skin','hand_R',10)
tube('Gripping_thumb',[grip+np.array([.10,-.015,.085]),grip+np.array([.115,-.10,.016]),grip+np.array([.025,-.13,-.024])],[.04,.035,.025],'Skin','hand_R',12)
tip=grip+np.array([-.36,-.02,-.69])
tube('Maul_shaft',[grip+np.array([.04,0,.23]),grip,tip],[.055,.058,.074],'Wood','hand_R',14)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1,location=tip)
rock=bpy.context.object
for v in rock.data.vertices:
    p=v.co.copy();v.co*=1+.07*math.sin(p.x*19+p.y*13+p.z*7)
rock.scale=(.31,.25,.34)
rock=move_to_asset(rock,'Maul_stone','hand_R','Stone')
for face in rock.data.polygons:face.use_smooth=False
for k in range(3):
    points=[]
    for i in range(33):
        a=i/32*math.tau
        points.append(tip+np.array([.28*math.cos(a),.257*math.sin(a),(-.12+k*.12)+.06*math.cos(a)]))
    tube('Maul_lashing_'+str(k),points,.025,'Hide','hand_R',8)
for i in range(7):
    center=grip+np.array([-.015*i,0,-.033*i])
    band('Grip_wrap_'+str(i),center,.065,.065,.032,'Hide','hand_R')

# PBR microdetail at restrained strength. Generated maps are lossless and packed.
TEX=OUT/'textures';TEX.mkdir(exist_ok=True)
yy,xx=np.mgrid[0:512,0:512]
rng=np.random.default_rng(1729)
for family in ['Skin','Hide','Stone','Wood','Iron']:
    height=rng.normal(0,.035,(512,512))
    if family=='Hide':height+=.08*np.sin(xx*.32)*np.sin(yy*.29)
    if family=='Wood':height+=.10*np.sin(xx*.18+.8*np.sin(yy*.02))
    if family=='Stone':height+=.04*np.sin(xx*.09)*np.sin(yy*.06)
    dy,dx=np.gradient(height)
    normal=np.stack([-dx*.55,-dy*.55,np.ones_like(height)],axis=-1)
    normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
    pixels=np.concatenate([normal*.5+.5,np.ones((512,512,1))],axis=-1).astype(np.float32)
    image=bpy.data.images.new(family.lower()+'_micro_normal',width=512,height=512,alpha=False)
    image.colorspace_settings.name='Non-Color';image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw=str(TEX/(family.lower()+'_normal.png'));image.file_format='PNG';image.save();image.pack()
    nodes=MATS[family].node_tree.nodes;links=MATS[family].node_tree.links
    tex=nodes.new('ShaderNodeTexImage');tex.image=image
    normal_node=nodes.new('ShaderNodeNormalMap');normal_node.inputs['Strength'].default_value=.24
    links.new(tex.outputs['Color'],normal_node.inputs['Color']);links.new(normal_node.outputs['Normal'],nodes.get('Principled BSDF').inputs['Normal'])
    if family in ['Hide','Wood','Stone','Iron']:
        value=np.clip(.67+.14*np.sin(xx*.035+np.sin(yy*.027))*np.sin(yy*.043)+height*.65,.35,.95)
        pixels=np.stack([value,value,value,np.ones_like(value)],axis=-1).astype(np.float32)
        image=bpy.data.images.new(family.lower()+'_albedo_detail',width=512,height=512,alpha=False)
        image.pixels.foreach_set(pixels.ravel());image.filepath_raw=str(TEX/(family.lower()+'_color.png'))
        image.file_format='PNG';image.save();image.pack()
        tex=nodes.new('ShaderNodeTexImage');tex.image=image
        multiply=nodes.new('ShaderNodeMixRGB');multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=1
        links.new(next(n for n in nodes if n.type=='VERTEX_COLOR').outputs['Color'],multiply.inputs[1])
        links.new(tex.outputs['Color'],multiply.inputs[2]);links.new(multiply.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])

skin_image=bpy.data.images.load(str(TEX/'skin_detail.png'));skin_image.pack()
nodes=MATS['Skin'].node_tree.nodes;links=MATS['Skin'].node_tree.links
tex=nodes.new('ShaderNodeTexImage');tex.image=skin_image
multiply=nodes.new('ShaderNodeMixRGB');multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=1
links.new(next(n for n in nodes if n.type=='VERTEX_COLOR').outputs['Color'],multiply.inputs[1])
links.new(tex.outputs['Color'],multiply.inputs[2]);links.new(multiply.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])

# Cameras and lights are review-only and never exported to the runtime GLB.
target=Vector((0,0,1.65))
for name,loc,power,size in [('Key',(-4,-6,7),1000,5),('Fill',(4,-3,4),500,5),('Rim',(2,4,5),1100,4)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name
    o.data.energy=power;o.data.size=size;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
for name,angle in [('Front',0),('Quarter',-22),('Back',180)]:
    a=math.radians(angle);bpy.ops.object.camera_add(location=target+Vector((7*math.sin(a),-7*math.cos(a),.2)))
    o=bpy.context.object;o.name='Camera_'+name;o.data.type='ORTHO';o.data.ortho_scale=4.1
    o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
scene.camera=bpy.data.objects['Camera_Quarter'];scene.render.engine='CYCLES';scene.cycles.samples=24
scene.cycles.use_denoising=True;scene.render.resolution_x=1100;scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.12,.14,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
scene.view_settings.view_transform='AgX'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'ogre_art.blend'),compress=True)
if not args.skip_render:
    gray=bpy.data.materials.new('Gray review');gray.diffuse_color=(.42,.42,.42,1)
    scene.view_layers[0].material_override=gray
    scene.render.filepath=str(args.render_dir/'gray.png');bpy.ops.render.render(write_still=True)
    scene.view_layers[0].material_override=None
    for view in ['Front','Quarter','Back']:
        scene.camera=bpy.data.objects['Camera_'+view];scene.render.filepath=str(args.render_dir/(view.lower()+'.png'))
        bpy.ops.render.render(write_still=True)

# Evaluate modifiers on export duplicates; the editable sculpt stays untouched.
parts={};total=0;exports=[]
for source in list(asset.objects):
    if source.type!='MESH':continue
    o=source.copy();o.data=source.data.copy();asset.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
    if source==body:
        # Remove skin fully under the opaque skirt, then budget the continuous body.
        bm=bmesh.new();bm.from_mesh(o.data)
        hidden=[f for f in bm.faces if .98<f.calc_center_median().z<1.45 and abs(f.calc_center_median().x)<.78]
        bmesh.ops.delete(bm,geom=hidden,context='FACES');bm.to_mesh(o.data);bm.free()
        mod=o.modifiers.new('Game skin budget','DECIMATE');mod.ratio=.30
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.name='ogre_part_%03d'%len(parts)
    o.data.calc_loop_triangles();triangles=len(o.data.loop_triangles);total+=triangles
    parts[o.name]={'source':source.name,'attachment':source.get('attachment','body'),'triangles':triangles}
    exports.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in exports:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'ogre_geometry.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_materials='EXPORT',export_extras=True,export_vertex_color='NAME',export_vertex_color_name='Tint',export_all_vertex_colors=False)
landmarks={'root':('',[0,0,-.006]),'pelvis':('root',[0,0,.88]),'spine':('pelvis',[0,-.03,1.07]),'chest':('spine',[0,-.01,1.27]),'neck':('chest',[0,0,1.43]),'head':('neck',[0,-.04,1.53]),'jaw':('head',[0,-.10,1.48])}
for sign,side in [(-1,'R'),(1,'L')]:
    for name,parent,p in [('upper_arm','chest',[.222,0,1.31]),('forearm','upper_arm_'+side,[.318,-.035,1.085]),('hand','forearm_'+side,[.39,-.052,.855]),('thigh','pelvis',[.112,.02,.86]),('shin','thigh_'+side,[.148,0,.475]),('foot','shin_'+side,[.165,.035,.085]),('toe','foot_'+side,[.165,-.10,.035]),('skirt','pelvis',[.13,0,.88])]:
        p[0]*=sign;landmarks[name+'_'+side]=(parent,p)
bones={name:{'parent':parent,'position':[float(q[0]),float(q[2]),float(-q[1])]} for name,(parent,p) in landmarks.items() for q in [morph(np.array(p))]}
bones['root']['position']=[0,0,0]
(OUT/'geometry_manifest.json').write_text(json.dumps({'triangles':total,'parts':parts,'bones':bones},indent=2)+'\n')
print('OGRE_GEOMETRY',total,'triangles',len(parts),'parts',flush=True)
