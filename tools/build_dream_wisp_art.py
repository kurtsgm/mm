"""Assemble the fairy game-art source from the approved head and CC0 body.
Blender 4.5 LTS, -- --base-bundle /path/to/bundle.blend --render-dir /path
"""
import argparse, math, json, sys
from pathlib import Path
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--base-bundle',type=Path,required=True)
parser.add_argument('--render-dir',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
OUT=ROOT/'art_source/dream_wisp/production';OUT.mkdir(parents=True,exist_ok=True)
TEX=OUT/'textures';TEX.mkdir(exist_ok=True);args.render_dir.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art_source/dream_wisp/head_v2/dream_wisp_head_v2.blend'))
s=bpy.context.scene
head=bpy.data.objects['Fae_Head']
assetcols=[head.users_collection[0],bpy.data.collections['04 • Hair volumes (toggle for bare sculpt)'],bpy.data.collections['05 • Brows and circlet']]
for c in assetcols:c.hide_render=False;c.hide_viewport=False
# Bake the current head shape at its existing quad-cage resolution.
for mod in head.modifiers:mod.show_viewport=False
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
headmesh=bpy.data.meshes.new_from_object(head.evaluated_get(dg),depsgraph=dg)
headmesh.transform(Matrix.Translation((0,0,1.31))@head.matrix_world)
headobj=bpy.data.objects.new('Skin',headmesh);assetcols[0].objects.link(headobj)
bpy.data.objects.remove(head,do_unlink=True)
for c in assetcols:
    for o in c.objects:
        if o!=headobj:o.location.z+=1.31
# Append only the original body, leaving all v2 art intact.
with bpy.data.libraries.load(str(args.base_bundle),link=False) as(src,dst):dst.collections=['Body Female - Realistic']
c=dst.collections[0];s.collection.children.link(c)
body=next(o for o in c.all_objects if o.name.startswith('GEO-body_female_realistic') and '.eye' not in o.name)
for o in list(c.all_objects):
    if o!=body:bpy.data.objects.remove(o,do_unlink=True)
body.location=(0,0,0);body.modifiers[0].levels=1;body.modifiers[0].render_levels=1
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
lower=bpy.data.meshes.new_from_object(body.evaluated_get(dg),depsgraph=dg)
bm=bmesh.new();bm.from_mesh(lower)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.000001,plane_co=(0,0,1.31),plane_no=(0,0,1),clear_outer=True)
bm.to_mesh(lower);bm.free()
lowerobj=bpy.data.objects.new('LowerBody',lower);assetcols[0].objects.link(lowerobj)
bpy.data.objects.remove(body,do_unlink=True);bpy.data.collections.remove(c)
bpy.ops.object.select_all(action='DESELECT');headobj.select_set(True);lowerobj.select_set(True);bpy.context.view_layer.objects.active=headobj
bpy.ops.object.join()
body=headobj;body.name='Skin';body.data.name='Fae_body_quad_cage'
bm=bmesh.new();bm.from_mesh(body.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free()
if body.data.attributes.get('custom_normal'):body.data.attributes.remove(body.data.attributes['custom_normal'])
for p in body.data.polygons:p.use_smooth=True
body['source']='Blender Studio / Dan Ulrich / Human Base Meshes v1.4.1 / CC0; fairy head v2 local refinements'
verts=np.array([list(v.co) for v in body.data.vertices])
print('BODY',len(verts),'bounds',verts.min(0),verts.max(0),flush=True)
for z in [.08,.45,.87,1.0,1.12,1.33]:
    v=verts[abs(verts[:,2]-z)<.012]
    print('SLICE',z,v.min(0).tolist(),v.max(0).tolist(),flush=True)
surface=BVHTree.FromPolygons([v.co.copy() for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons])
torso_surface=BVHTree.FromPolygons([v.co.copy() for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons if abs(p.center.x)<.182 and .86<p.center.z<1.38])
clothcol=bpy.data.collections.new('06 • Garments and wing design');s.collection.children.link(clothcol);assetcols.append(clothcol)


def mat(name,color,rough=.65,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
    b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*color,1);b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal
    return m

skin=mat('Skin',(.63,.42,.32),.63)
hair=mat('Hair',(.42,.35,.49),.47)
silk=mat('Silk',(.055,.18,.17),.66)
petal=mat('Petals',(.12,.26,.24),.62)
gold=mat('Gold',(.55,.36,.10),.3,.82)
veins=mat('Veins',(.38,.38,.18),.55,.15)
sclera=mat('EyeWhite',(.70,.68,.61),.28)
iris=mat('Iris',(.13,.075,.21),.27)
pupil=mat('Pupil',(.008,.006,.012),.28)
glow=mat('Glow',(.30,.52,.66),.24,.10)
glow.node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value=(.18,.29,.42,1)
glow.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=.22
brow=mat('Brows',(.12,.055,.065),.74)
wing=mat('Wings',(1,1,1),.7)


def image_pixels(name,pixels,noncolor=False):
    h,w,_=pixels.shape
    im=bpy.data.images.new(name,width=w,height=h,alpha=True)
    if noncolor:im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(np.asarray(pixels,dtype=np.float32).ravel())
    im.filepath_raw=str(TEX/(name+'.png'));im.file_format='PNG';im.save();im.pack();return im


def normal_texture(name,height,strength):
    dy,dx=np.gradient(height);n=np.stack([-dx*strength,-dy*strength,np.ones_like(height)],-1)
    n/=np.linalg.norm(n,axis=-1,keepdims=True)
    return image_pixels(name,np.concatenate([n*.5+.5,np.ones((*height.shape,1))],-1),True)


def use_normal(material,image,strength=1):
    nodes=material.node_tree.nodes;links=material.node_tree.links
    tex=nodes.new('ShaderNodeTexImage');tex.image=image
    nm=nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=strength
    links.new(tex.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],nodes.get('Principled BSDF').inputs['Normal'])

# PBR microdetail, deterministic and neutral in color; no projected face photograph.
y,x=np.mgrid[0:1024,0:1024];rng=np.random.default_rng(9041)
pores=rng.normal(0,.1,(1024,1024))+.04*np.sin(x*.8)*np.sin(y*.91)
use_normal(skin,normal_texture('skin_micro_normal',pores,.75),.22)
weave=np.sin(x*np.pi*.5)*np.sin(y*np.pi*.5)*.25
use_normal(silk,normal_texture('silk_weave_normal',weave,1.1),.32)
use_normal(petal,bpy.data.images['silk_weave_normal'],.28)
strands=np.sin(x/1024*math.tau*36+.45*np.sin(y/1024*math.tau*3))*.28
use_normal(hair,normal_texture('hair_strand_normal',strands,5.5),.6)
im=bpy.data.images.load(str(TEX/'petal_embroidery.png'));im.pack()
tex=petal.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;petal.node_tree.links.new(tex.outputs['Color'],petal.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
# Vertex complexion follows the true 3D surface, including lips and blush.
col=body.data.color_attributes.get('Complexion') or body.data.color_attributes.new(name='Complexion',type='FLOAT_COLOR',domain='CORNER')
body.data.color_attributes.active_color=col
body.data.materials.clear();body.data.materials.append(skin)
for loop,entry in zip(body.data.loops,col.data):
    p=body.data.vertices[loop.vertex_index].co;xv,yv,zv=p
    color=np.array([.63,.42,.32])
    front=np.clip((-yv-.11)/.035,0,1)
    lip=math.exp(-((xv/.027)**4+((zv-1.456)/.010)**4))*front
    cheek=math.exp(-(((abs(xv)-.045)/.023)**2+((zv-1.505)/.022)**2))*front
    color=color*(1-.66*lip)+np.array([.39,.095,.105])*.66*lip
    color=color*(1-.12*cheek)+np.array([.70,.29,.24])*.12*cheek
    entry.color=(*color,1)
node=skin.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='Complexion'
skin.node_tree.links.new(node.outputs['Color'],skin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
# Map the gray studies' materials to the final fantasy palette.
for c in assetcols[:3]:
    for o in c.objects:
        if o==body or o.type not in {'MESH','CURVE'}:continue
        for i,m in enumerate(o.data.materials):
            name=m.name
            replacement=hair if 'Hair' in name else brow if 'Brow' in name else gold if 'Circlet' in name else glow if 'Moonstone' in name else sclera if 'Eyes' in name else iris if 'Iris' in name else pupil if 'Pupil' in name else None
            if replacement:o.data.materials[i]=replacement


def mesh_obj(name,vs,fs,material,uv=None):
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(name,me);clothcol.objects.link(ob);me.materials.append(material)
    for f in me.polygons:f.use_smooth=True
    if uv is not None:
        layer=me.uv_layers.new(name='UVMap')
        for loop in me.loops:layer.data[loop.index].uv=uv[loop.vertex_index]
    return ob


def tube(name,points,radius,material=gold):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=radius;cu.bevel_resolution=1
    sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
    for p,co in zip(sp.points,points):p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu);clothcol.objects.link(ob);cu.materials.append(material);return ob


def surface_point(angle,z,offset=.004):
    direction=Vector((math.sin(angle),-math.cos(angle),0))
    hit,normal,_,_=torso_surface.ray_cast(direction*.5+Vector((0,0,z)),-direction)
    if hit and abs(hit.x)>.155 and z<1.27: hit.x=math.copysign(.155,hit.x)
    return hit+normal*offset if hit else Vector((.11*math.sin(angle),-.08*math.cos(angle),z))


def neckline(p):
    return 1.235+.62*abs(p.x) if p.y<-.025 else 1.31+.12*abs(p.x)


def torso(p):
    return abs(p.x)<(.14 if p.z<1.23 else .175)

# Fitted opaque bodice follows the source anatomy; depth and seams are real geometry.
for name,predicate,material,offset in [
    ('Boots',lambda p:.055<p.z<.185,silk,.004)]:
    chosen=[p for p in body.data.polygons if predicate(p.center)]
    ids=sorted(set(i for p in chosen for i in p.vertices));remap={v:i for i,v in enumerate(ids)}
    vs=[body.data.vertices[i].co+body.data.vertices[i].normal*offset for i in ids]
    ob=mesh_obj(name,vs,[[remap[i] for i in p.vertices] for p in chosen],material)
    # Preserve the source UVs on extracted cloth regions.
    uv=ob.data.uv_layers.new(name='UVMap')
    src=body.data.uv_layers.active
    for dest,origin in zip(ob.data.polygons,chosen):
        for di,si in zip(dest.loop_indices,origin.loop_indices):uv.data[di].uv=src.data[si].uv
    mod=ob.modifiers.new('Cloth thickness','SOLIDIFY');mod.thickness=.0018;mod.offset=0
# Continuous fitted bodice with a smooth V neckline, no stair-stepped face-selection edge.
vs=[];fs=[];uv=[];rings=27;segments=96
for j in range(rings):
    t=j/(rings-1)
    for i in range(segments+1):
        a=i*math.tau/segments
        top=1.235+.10*abs(math.sin(a))**.65 if math.cos(a)>0 else 1.305+.03*abs(math.sin(a))
        z=.953+t*(top-.953)
        vs.append(surface_point(a,z,.007));uv.append((i/segments,t))
for j in range(rings-1):
    for i in range(segments):fs.append((j*(segments+1)+i,j*(segments+1)+i+1,(j+1)*(segments+1)+i+1,(j+1)*(segments+1)+i))
# Smooth the interior of the tailored garment while preserving the neckline.
for _ in range(10):
    nxt=[Vector(v) for v in vs]
    for j in range(1,rings-1):
        for i in range(segments):
            idx=j*(segments+1)+i
            avg=(Vector(vs[j*(segments+1)+(i-1)%segments])+Vector(vs[j*(segments+1)+(i+1)%segments])+Vector(vs[idx-segments-1])+Vector(vs[idx+segments+1]))/4
            nxt[idx]=Vector(vs[idx]).lerp(avg,.5)
        nxt[j*(segments+1)+segments]=nxt[j*(segments+1)]
    vs=nxt
ob=mesh_obj('Bodice',vs,fs,silk,uv);m=ob.modifiers.new('Cloth thickness','SOLIDIFY');m.thickness=.0016
for boundary in [0,rings-1]:tube('Bodice_edge',[Vector(vs[boundary*(segments+1)+i])+Vector((0,0,.0005)) for i in range(segments+1)],.00065,gold)
# Smooth toe envelopes conceal anatomical toes and provide a wearable flat sole.
for side in [-1,1]:
    vs=[];fs=[];uv=[];rows=30;cols=20
    for j in range(rows):
        t=j/(rows-1);y=-.165+t*.268
        width=float(np.interp(t,[0,.10,.35,.65,.87,1],[.0005,.038,.048,.041,.030,.0005]))
        h=float(np.interp(t,[0,.10,.35,.65,.87,1],[.001,.025,.031,.040,.035,.001]))
        zc=.010+h*.80
        for i in range(cols):
            a=i*math.tau/cols
            vs.append((side*(.124-.24*y)+width*math.cos(a),y,max(.003,zc+h*math.sin(a))))
            uv.append((i/cols,t))
    for j in range(rows-1):
        for i in range(cols):fs.append((j*cols+i,j*cols+(i+1)%cols,(j+1)*cols+(i+1)%cols,(j+1)*cols+i))
    fs.append(tuple(reversed(range(cols))));fs.append(tuple((rows-1)*cols+i for i in range(cols)))
    mesh_obj('Boot_toecap_'+str(side),vs,fs,silk,uv)
# Opaque lining under the overlapping petals.
vs=[];fs=[];uv=[]
for j in range(12):
    t=j/11
    for i in range(65):
        a=i*math.tau/64
        vs.append(((.137+.07*t)*math.sin(a),-(.105+.025*t)*math.cos(a)-.047+.038*t,1.025-.345*t))
        uv.append((i/64,t))
for j in range(11):
    for i in range(64):fs.append((j*65+i,j*65+i+1,(j+1)*65+i+1,(j+1)*65+i))
mesh_obj('Skirt_lining',vs,fs,silk,uv)
# Layered petal skirt, broad overlapping panels and a modest fully covered silhouette.
for layer in range(3):
    for k in range(12):
        angle=k*math.tau/12+layer*.22;vs=[];fs=[];uv=[]
        rows=18;cols=9
        for j in range(rows):
            t=j/(rows-1);z=1.035-layer*.065-t*(.245-.030*layer)
            if layer==2:z=.945-t*.270
            width=(.12+.88*math.sin(math.pi*t)**.6)*(.29 if layer==0 else .32)
            for i in range(cols):
                u=i/(cols-1)*2-1;a=angle+u*width
                rx=.142+.075*t+layer*.004;ry=.112+.030*t+layer*.004
                rib=.004*(1-u*u)*math.sin(math.pi*t)
                vs.append(((rx+rib)*math.sin(a),-(ry+rib)*math.cos(a)-.047+.038*t,z+.012*u*u*math.sin(math.pi*t)))
                uv.append((i/(cols-1),t))
        for j in range(rows-1):
            for i in range(cols-1):fs.append((j*cols+i,j*cols+i+1,(j+1)*cols+i+1,(j+1)*cols+i))
        ob=mesh_obj(f'Petal_skirt_{layer}_{k:02d}',vs,fs,petal,uv);ob['attachment']='skirt_L' if math.sin(angle)>0 else 'skirt_R'
        m=ob.modifiers.new('Petal thickness','SOLIDIFY');m.thickness=.0011;m.offset=0
        line=[Vector(vs[j*cols+cols//2])+Vector((math.sin(angle),-math.cos(angle),0))*.0011 for j in range(rows)]
        tube(f'Embroidery_skirt_{layer}_{k}',line,.00055,gold)['attachment']=ob['attachment']
# Belt follows the waist surface, and curved bodice seams trace its front.
for z in [1.043,1.053]:
    tube('Belt', [surface_point(i*math.tau/96,z,.008) for i in range(97)],.002,gold)
for side in [-1,1]:
    for a in [.25,.63]:
        tube(f'Bodice_seam_{side}_{a}',[surface_point(side*a,1.03+i*.20/24,.0065) for i in range(25)],.00065,gold)
# Shoulder petal fans, short enough to clear arm rotation.
for side in [-1,1]:
    for k in range(5):
        root=Vector((side*(.09+.010*k),-.045+.022*k,1.34))
        tip=Vector((side*(.205-.004*k),-.065+.024*k,1.255-.009*math.sin(k)))
        axis=tip-root;width=Vector((0,1,0));vs=[];fs=[];uv=[]
        for j in range(14):
            t=j/13
            for i in range(7):
                u=i/6*2-1;p=root+axis*t+width*u*.025*(.1+.9*math.sin(math.pi*t)**.7)+Vector((0,0,.012*(1-u*u)*math.sin(math.pi*t)))
                vs.append(p);uv.append((i/6,t))
        for j in range(13):
            for i in range(6):fs.append((j*7+i,j*7+i+1,(j+1)*7+i+1,(j+1)*7+i))
        ob=mesh_obj(f'Shoulder_{side}_{k}',vs,fs,petal,uv);m=ob.modifiers.new('Petal thickness','SOLIDIFY');m.thickness=.0013
# Boot gold seams follow the upper surfaces of the existing foot mesh.
for side in [-1,1]:
    for k in range(3):
        points=[]
        for j in range(18):
            z=.025+j*.008;x=side*(.078+.012*math.sin(j*.2+k));hit,n,_,_=surface.ray_cast(Vector((x,-.4,z)),Vector((0,1,0)))
            if hit:points.append(hit+n*.006)
        if len(points)>2:tube(f'Boot_seam_{side}_{k}',points,.0006,gold)
# Moonstone belt clasp with a thin metal bezel.
for name,scale,material,yv in [('Clasp_bezel',(.013,.004,.017),gold,-.159),('Clasp_stone',(.009,.003,.013),glow,-.163)]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=(0,yv,1.043));o=bpy.context.object;o.name=name;o.scale=scale
    for c in list(o.users_collection):c.objects.unlink(o)
    clothcol.objects.link(o);o.data.materials.append(material)
    for p in o.data.polygons:p.use_smooth=True
# Image-generated moth albedo retained losslessly as a PBR asset.
im=bpy.data.images.load(str(TEX/'moth_wing_design.png'));im.pack()
tex=wing.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;wing.node_tree.links.new(tex.outputs['Color'],wing.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
wing.use_backface_culling=False
# Each membrane has a clean pointed outline, fine raised branching veins, and UVs.
for side in [-1,1]:
    for upper in [True,False]:
        name=('upper' if upper else 'lower')+('_L' if side>0 else '_R')
        root=Vector((side*.053,.065,1.27 if upper else 1.20))
        tip=Vector((side*(1.065 if upper else .77),.145,1.89 if upper else .62))
        axis=tip-root;across=Vector((-axis.z,0,axis.x)).normalized()
        width=.245 if upper else .220
        rows=44;cols=17;vs=[];fs=[];uv=[]
        def pos(t,u):
            w=width*math.sin(math.pi*t)**.70*(1-.045*math.sin(t*math.pi*6)**2*abs(u)**5)
            return root+axis*t+across*(u*w)+Vector((0,.013*math.sin(math.pi*t)*(1-u*u),0))
        for j in range(rows):
            t=.002+.996*j/(rows-1)
            for i in range(cols):
                u=i/(cols-1)*2-1;vs.append(pos(t,u));uv.append((i/(cols-1),1-t))
        for j in range(rows-1):
            for i in range(cols-1):fs.append((j*cols+i,j*cols+i+1,(j+1)*cols+i+1,(j+1)*cols+i))
        o=mesh_obj('Wing_'+name,vs,fs,wing,uv);o['attachment']='wing_'+name
        tube('Vein_main_'+name,[pos(.01+j*.98/60,0)-Vector((0,.001,0)) for j in range(61)],.0011,veins)['attachment']='wing_'+name
        for branch in range(1,8):
            start=.07+branch*.085
            for flank in [-1,1]:
                line=[pos(start+t*.15,flank*t*.96)-Vector((0,.001,0)) for t in np.linspace(0,1,20)]
                tube(f'Vein_{name}_{branch}_{flank}',line,.00065,veins)['attachment']='wing_'+name
        for flank in [-1,1]:
            tube(f'Wing_edge_{name}_{flank}',[pos(t,flank) for t in np.linspace(.005,.995,80)],.00075,veins)['attachment']='wing_'+name
# Small spell orbit, follows the left hand when rigged.
for i in range(7):
    a=i*math.tau/7
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.0028,location=(.39+.027*math.cos(a),-.10, .92+.027*math.sin(a)))
    o=bpy.context.object;o.name='Spell_mote';o['attachment']='spell'
    for c in list(o.users_collection):c.objects.unlink(o)
    clothcol.objects.link(o);o.data.materials.append(glow)
# Hide covered skin faces to prevent unnecessary overdraw and clothing intersections.
bm=bmesh.new();bm.from_mesh(body.data)
remove=[f for f in bm.faces if ((.93<f.calc_center_median().z<1.225 and abs(f.calc_center_median().x)<.14) or f.calc_center_median().z<.175 or (.685<f.calc_center_median().z<.96 and abs(f.calc_center_median().x)<.21))]
bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(body.data);bm.free()
# Full source lighting and review cameras.
for o in list(s.objects):
    if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
target=Vector((0,0,1.0))
for name,loc,power,size in [('Key',(-2,-3,4),400,3),('Fill',(2,-2,2.6),220,3),('Rim',(.8,2,3),480,2.5)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.size=size;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
for o in s.objects:
    if o.type=='CAMERA':o.location.z+=1.31
for name,angle in [('FullFront',0),('FullQuarter',-25),('FullBack',180)]:
    a=math.radians(angle);bpy.ops.object.camera_add(location=target+Vector((3*math.sin(a),-3*math.cos(a),0)))
    o=bpy.context.object;o.name='Camera_'+name;o.data.type='ORTHO';o.data.ortho_scale=2.35;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
s.camera=bpy.data.objects['Camera_FullQuarter'];s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=True
s.render.resolution_x=1400;s.render.resolution_y=1400;s.render.resolution_percentage=100
s['Stage']='Complete fairy art source; game rig is baked by build_dream_wisp.gd'
# UVs for long hair locks use their known longitudinal ring layout.
for c in assetcols:
    for o in c.objects:
        if o.type=='MESH' and o.name.startswith(('Hair_lock','Hair_back','Hair_front_sweep')):
            uv=o.data.uv_layers.new(name='UVMap');count=len(o.data.vertices)//12
            for loop in o.data.loops:
                uv.data[loop.index].uv=((loop.vertex_index%12)/12,(loop.vertex_index//12)/max(1,count-1))
# Fine radial iris stroma and a dark limbal ring, with true spherical eye geometry.
iy,ix=np.mgrid[0:512,0:512];xx=(ix-255.5)/255.5;yy=(iy-255.5)/255.5
rr=np.sqrt(xx*xx+yy*yy);aa=np.arctan2(yy,xx)
fibers=.5+.25*np.sin(aa*137+rr*19)+.15*np.sin(aa*239-rr*31)
base=np.zeros((512,512,4));base[:,:,:3]=np.array([.23,.12,.36])[None,None,:]*(.7+.6*fibers[:,:,None])
ring=np.clip((rr-.84)/.14,0,1);base[:,:,:3]*=(1-.78*ring[:,:,None]);base[:,:,3]=1
im=image_pixels('iris_amethyst',base)
tex=iris.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;iris.node_tree.links.new(tex.outputs['Color'],iris.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
for o in assetcols[0].objects:
    if o.type=='MESH' and '_iris' in o.name:
        uv=o.data.uv_layers.new(name='UVMap');center=o.data.vertices[0].co
        for loop in o.data.loops:
            p=o.data.vertices[loop.vertex_index].co-center;uv.data[loop.index].uv=(.5+p.x/.0112,.5+p.z/.0112)
# Pack every texture in the editable source.
for im in bpy.data.images:
    if im.source=='FILE' and im.packed_file is None:
        try:im.pack()
        except RuntimeError:pass
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dream_wisp_art.blend'),compress=True)
for name in ['FullFront','FullQuarter','FullBack']:
    s.camera=bpy.data.objects['Camera_'+name];s.render.filepath=str(args.render_dir/(name.lower()+'.png'));bpy.ops.render.render(write_still=True)
s.camera=bpy.data.objects['Camera_ThreeQuarter'];s.render.resolution_x=880;s.render.resolution_y=1100;s.render.filepath=str(args.render_dir/'face.png');bpy.ops.render.render(write_still=True)
print('ART_SOURCE_READY',flush=True)
