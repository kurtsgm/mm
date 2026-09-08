"""Refine the approved fairy head study and add editable hair volumes.

Blender 4.5 LTS: --background --python this_file -- --render-dir /path/to/renders
Reads the saved v1, writes a sibling v2; all outputs are real mesh renders.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--render-dir', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
args.render_dir.mkdir(parents=True, exist_ok=True)
OUT = ROOT / 'art_source/dream_wisp/head_v2'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art_source/dream_wisp/head_v1/dream_wisp_head_v1.blend'))
scene = bpy.context.scene
head = bpy.data.objects['Fae_Head']
headcoll = head.users_collection[0]


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def refine(points):
    p = points.copy()
    x, y, z = points.T
    a = np.abs(x)
    front = 1 - smoothstep(-.128, -.080, y)
    # Calm almond eyelids; keep separate eyeballs aligned by using the same map.
    orbit = np.exp(-(((a - .033) / .022) ** 4 + ((z - .216) / .016) ** 4)) * front
    upper_lid = np.exp(-((z - .222) / .0045) ** 2) * orbit
    p[:, 2] += (a - .033) * .035 * orbit - .00045 * upper_lid
    p[:, 1] += .00035 * upper_lid
    # Reduce upturn and bulb at nasal tip, preserve the nasal openings.
    tip = np.exp(-((x / .015) ** 2 + ((z - .179) / .013) ** 2)) * (1 - smoothstep(-.150, -.133, y))
    p[:, 2] -= .0018 * tip
    p[:, 1] += .0010 * tip
    alae = np.exp(-(((a - .011) / .010) ** 2 + ((z - .174) / .010) ** 2)) * front
    p[:, 0] *= 1 - .035 * alae
    # Gentle neutral mouth corners, less lip projection, soften lower lip/chin transition.
    corner = np.exp(-(((a - .024) / .010) ** 2 + ((z - .148) / .009) ** 2)) * front
    p[:, 2] += .0010 * corner
    lips = np.exp(-((x / .030) ** 4 + ((z - .146) / .014) ** 4)) * front
    p[:, 0] *= 1 - .025 * lips
    p[:, 1] += .0006 * lips
    sublip = np.exp(-((x / .021) ** 2 + ((z - .133) / .008) ** 2)) * front
    p[:, 1] -= .0010 * sublip
    return p


# Extend the existing non-destructive shape-key chain. Iris meshes get a matching key.
for obj in list(headcoll.objects):
    if obj.type != 'MESH':
        continue
    if obj.data.shape_keys:
        previous = obj.data.shape_keys.key_blocks[-1]
    else:
        previous = obj.shape_key_add(name='Basis')
    matrix = obj.matrix_world.copy()
    inverse = matrix.inverted()
    p = np.array([list(matrix @ v.co) for v in previous.data])
    key = obj.shape_key_add(name='04_Refined_lids_nose_mouth')
    key.relative_key = previous
    for v, co in zip(key.data, refine(p)):
        v.co = inverse @ Vector(co)
    key.value = 1

bpy.context.view_layer.update()
depsgraph = bpy.context.evaluated_depsgraph_get()
evaluated = head.evaluated_get(depsgraph)
mesh = bpy.data.meshes.new_from_object(evaluated, depsgraph=depsgraph)
points = [head.matrix_world @ v.co for v in mesh.vertices]
polygons = [list(poly.vertices) for poly in mesh.polygons]
surface = BVHTree.FromPolygons(points, polygons)


def top_surface(x, y):
    hit, normal, _, _ = surface.ray_cast(Vector((x, y, .6)), Vector((0, 0, -1)))
    if hit is None:
        return Vector((x, y, .28))
    return hit + normal * .004


def front_surface(x, z, offset=.0007):
    hit, normal, _, _ = surface.ray_cast(Vector((x, -.6, z)), Vector((0, 1, 0)))
    return hit + normal * offset if hit else Vector((x, -.13, z))


def material(name, color, roughness=.65):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = roughness
    return mat


hair_mat = material('Hair clay • graphite', (.135, .125, .145), .57)
hair_detail_mat = material('Hair ridges • gray', (.17, .16, .18), .6)
brow_mat = material('Brow clay', (.10, .085, .095), .7)
circlet_mat = material('Circlet clay', (.30, .29, .31), .42)
gem_mat = material('Moonstone clay', (.42, .42, .44), .4)
haircoll = bpy.data.collections.new('04 • Hair volumes (toggle for bare sculpt)')
scene.collection.children.link(haircoll)
detailcoll = bpy.data.collections.new('05 • Brows and circlet')
scene.collection.children.link(detailcoll)


def new_mesh(name, verts, faces, collection, mat):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    collection.objects.link(obj)
    me.materials.append(mat)
    for poly in me.polygons:
        poly.use_smooth = True
    return obj


# A cap copied from the actual deformed cranial surface, with its own editable quad mesh.
cap_faces = []
cap_ids = set()
for poly in mesh.polygons:
    center = head.matrix_world @ poly.center
    x, y, z = center
    front = 1 - float(smoothstep(-.125, .035, y))
    hairline = .192 + .082 * front + .008 * (abs(x) / .08) ** 2 * front
    if z > hairline and abs(x) < .080:
        cap_faces.append(list(poly.vertices))
        cap_ids.update(poly.vertices)
ids = sorted(cap_ids)
remap = {old: new for new, old in enumerate(ids)}
cap_verts = [points[i] + (head.matrix_world.to_3x3() @ mesh.vertices[i].normal).normalized() * .0020 for i in ids]
cap = new_mesh('Hair_scalp_cap', cap_verts, [[remap[i] for i in f] for f in cap_faces], haircoll, hair_mat)
solid = cap.modifiers.new('Hairline thickness', 'SOLIDIFY')
solid.thickness = .001
solid.offset = 0
scalp_surface = BVHTree.FromPolygons(cap_verts, [[remap[i] for i in f] for f in cap_faces])


def catmull(control, count=90):
    control = [Vector(p) for p in control]
    extended = [control[0]] + control + [control[-1]]
    result = []
    for j in range(count):
        s = j / (count - 1) * (len(control) - 1)
        k = min(int(s), len(control) - 2)
        t = s - k
        p0, p1, p2, p3 = extended[k:k + 4]
        result.append(.5 * ((2 * p1) + (-p0 + p2) * t + (2*p0 - 5*p1 + 4*p2 - p3) * t*t + (-p0 + 3*p1 - 3*p2 + p3) * t*t*t))
    return result


def curve(name, coords, radius, collection, mat):
    data = bpy.data.curves.new(name, 'CURVE')
    data.dimensions = '3D'
    data.resolution_u = 2
    data.bevel_depth = radius
    data.bevel_resolution = 2
    spline = data.splines.new('POLY')
    spline.points.add(len(coords) - 1)
    for p, co in zip(spline.points, coords):
        p.co = (*co, 1)
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    data.materials.append(mat)
    return obj


def lock(name, controls, width, phase):
    path = catmull(controls, 100)
    # Project the upper sweep onto the scalp and transport the ribbon frame smoothly.
    for j, center in enumerate(path):
        t = j / (len(path)-1)
        weight = 1-float(smoothstep(.43,.59,t))
        if weight > 0:
            hit, normal, _, distance = scalp_surface.find_nearest(center)
            if hit is not None:
                path[j] = center.lerp(hit+normal*.0022,weight)
    verts, faces, frames = [], [], []
    previous_side = None
    for j, center in enumerate(path):
        t = j / (len(path) - 1)
        tangent = (path[min(j + 1, len(path) - 1)] - path[max(j - 1, 0)]).normalized()
        normal = Vector((center.x, center.y + .045, 0)).normalized()
        sideways = tangent.cross(normal).normalized() if previous_side is None else (previous_side-tangent*previous_side.dot(tangent)).normalized()
        previous_side=sideways
        normal = sideways.cross(tangent).normalized()
        tail = float(smoothstep(.35, .72, t))
        center = center + sideways * (.0050 * math.sin(t * 5 * math.pi + phase) * tail)
        # Ribbon-like hair volumes with tapered ends, never cylindrical dreadlocks.
        taper = (.18 + .82 * math.sin(math.pi * min(t / .98, 1)) ** .35) * (1 - float(smoothstep(.91, 1.0, t)) * .94)
        w = width * taper
        thickness = (.0020 + .0010 * tail) * taper
        frames.append((center, sideways, normal, w, thickness))
        for k in range(12):
            a = 2 * math.pi * k / 12
            verts.append(center + sideways * (math.cos(a) * w * .5) + normal * (math.sin(a) * thickness * .5))
    for j in range(len(path) - 1):
        for k in range(12):
            faces.append((j*12+k, j*12+(k+1)%12, (j+1)*12+(k+1)%12, (j+1)*12+k))
    faces.append(tuple(reversed(range(12))))
    faces.append(tuple((len(path)-1)*12+k for k in range(12)))
    obj = new_mesh(name, verts, faces, haircoll, hair_mat)
    # Sparse sculpt ridges convey strand direction without image textures.
    for i, ratio in enumerate([-.64, -.30, .08, .44, .74]):
        strand = [c + side*(ratio*w*.5) + norm*(math.sqrt(1-ratio*ratio)*th*.5+.00004) for c,side,norm,w,th in frames[2:-2]]
        curve(name + '_ridge_' + str(i), strand, .000065, haircoll, hair_detail_mat)
    return obj


# Centre-part roots flow over the head and tuck behind the ears before falling in waves.
for side in [-1, 1]:
    for i in range(20):
        u = i / 19
        root_y = -.139 + .162 * u
        p0 = top_surface(side*.0015, root_y)
        p1 = top_surface(side*.033, min(root_y + .010,.029))
        p2 = top_surface(side*.061, min(root_y + .026, .04))
        p3 = Vector((side*(.074 + .005*math.sin(math.pi*u)), .003 + .042*u, .246 - .024*u))
        p4 = Vector((side*(.078 + .012*math.sin(math.pi*u)), .027 + .046*u, .182 - .010*u))
        p5 = Vector((side*(.084 - .012*u), .014 + .071*u, .105 - .008*math.sin(i)))
        p6 = Vector((side*(.067 - .030*u), .032 + .06*u, .030 + .018*(.5+.5*math.sin(i*1.7))))
        lock(f'Hair_lock_{side:+d}_{i:02d}', [p0,p1,p2,p3,p4,p5,p6], .011 + .003*math.sin(i*1.4)**2, i*.66)

# Forehead sweep: cover the cap edge with short, tucked framing locks.
for side in [-1,1]:
    for i in range(6):
        d=i*.0022
        controls=[front_surface(side*.002,.276+d,.004),front_surface(side*.027,.282+d,.004),front_surface(side*.052,.272+d,.004),(side*.075,-.015,.236+d),(side*.080,.022,.198),(side*.076,.038,.153)]
        lock(f'Hair_front_sweep_{side:+d}_{i:02d}',controls,.0065,i*.5)

# A few back locks cover the centre back and preserve the split front silhouette.
for i in range(9):
    x = -.046 + i*.0115
    p0 = top_surface(x, .031)
    lock(f'Hair_back_{i:02d}', [p0,(x,.056,.26),(x,.073,.21),(x+.006*math.sin(i),.084,.145),(x-.005,.085,.075),(x+.005,.072,.027+.009*math.cos(i))], .014, i*.8)

# Sculpted eyebrow ribbons and sparse hair-direction grooves, fitted to facial surface.
for side in [-1, 1]:
    verts, faces = [], []
    n = 48
    for i in range(n):
        t = i / (n - 1)
        x = side * (.013 + .044*t)
        z = .236 + .0075*math.sin(math.pi*t*.95) - .003*t
        half = .0016*(1-.78*t) * (.55 + .45*math.sin(math.pi*t)**.3)
        for dz in [-half, half]:
            verts.append(front_surface(x, z+dz, .0009))
    for i in range(n - 1):
        faces.append((i*2, i*2+1, i*2+3, i*2+2))
    brow = new_mesh(f'Brow_{side:+d}', verts, faces, detailcoll, brow_mat)
    mod = brow.modifiers.new('Brow volume', 'SOLIDIFY')
    mod.thickness = .00045
    for i in range(28):
        t = (i+.3)/29
        x = side*(.013+.044*t)
        z = .236+.0075*math.sin(math.pi*t*.95)-.003*t
        a = front_surface(x, z-.00065, .0012)
        b = front_surface(x+side*.0013, z+.00075*(1-.55*t), .0012)
        curve(f'Brow_{side:+d}_strand_{i:02d}', [a,(a+b)*.5+Vector((0,-.00012,0)),b], .000075, detailcoll, hair_detail_mat)

# Simple gray twig circlet to evaluate the forehead silhouette from the approved design.
coords=[]
for i in range(181):
    angle=2*math.pi*i/180
    coords.append(Vector((.0815*math.sin(angle),-.046-.104*math.cos(angle),.266+.005*math.cos(2*angle))))
curve('Circlet_main',coords,.0008,detailcoll,circlet_mat)
for side in [-1,1]:
    for i in range(6):
        angle=side*(.13+i*.17)
        root=Vector((.0815*math.sin(angle),-.046-.104*math.cos(angle),.266+.005*math.cos(2*angle)))
        end=root+Vector((side*.007, .003, .0045*(1 if i%2==0 else -1)))
        curve(f'Circlet_twig_{side:+d}_{i}',[root,(root+end)*.5+Vector((0,-.001,.001)),end],.00035,detailcoll,circlet_mat)
        tangent=(end-root).normalized();width=Vector((0,-1,.1)).cross(tangent).normalized()*.0012
        midpoint=(root+end)*.5
        new_mesh(f'Circlet_leaf_{side:+d}_{i}',[root,midpoint+width,end,midpoint-width,midpoint+Vector((0,-.0006,0))],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],detailcoll,circlet_mat)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=(0,-.151,.267))
gem=bpy.context.object;gem.name='Circlet_moonstone';gem.scale=(.0026,.0017,.004)
for c in list(gem.users_collection):c.objects.unlink(gem)
detailcoll.objects.link(gem);gem.data.materials.append(gem_mat)
for p in gem.data.polygons:p.use_smooth=True
bpy.data.meshes.remove(mesh)

# Retain matching comparison cameras; lengthen framing for the added hair tips.
for obj in scene.objects:
    if obj.type == 'CAMERA':
        obj.data.ortho_scale = .405
scene.camera=bpy.data.objects['Camera_ThreeQuarter']
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.cycles.preview_samples=64;scene.cycles.use_preview_denoising=True
scene.render.resolution_x=880;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene['Stage']='Head gray study v2: local facial refinement, parted wavy hair volumes, brows and circlet'
scene['Hair_stage']='Editable gray sculpt volumes and direction ridges, not production hair cards or rig'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL'
            area.spaces.active.overlay.show_overlays=False
bpy.ops.object.select_all(action='DESELECT');head.select_set(True);bpy.context.view_layer.objects.active=head
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dream_wisp_head_v2.blend'),compress=True)
for name in ['Front','ThreeQuarter','Profile','Back']:
    scene.camera=bpy.data.objects['Camera_'+name]
    scene.render.filepath=str(args.render_dir/('head-'+name.lower()+'.png'))
    bpy.ops.render.render(write_still=True)
# Same frontal camera, original clay only: prove the facial changes beneath hair.
haircoll.hide_render=True;detailcoll.hide_render=True
scene.camera=bpy.data.objects['Camera_Front'];scene.render.filepath=str(args.render_dir/'head-bare-front.png')
bpy.ops.render.render(write_still=True)
print('V2_RENDERED',str(OUT))
