"""Bake the original goblin head as a smooth implicit sculpture.
Run with Python + numpy + scikit-image before build_goblin.gd.
Writes a compact vertex/normal/index buffer consumed by the Godot baker.
"""
from pathlib import Path
import struct
import numpy as np
from skimage.measure import marching_cubes

step = 0.006
origin = np.array([-0.52, -0.11, -0.22])
axes = [np.arange(a, b, step) for a, b in zip(origin, [0.524, 0.454, 0.364])]
p = np.stack(np.meshgrid(*axes, indexing="ij"), axis=-1)

def ellipsoid(center, radius, angle=0):
    q = p - center
    if angle:
        c, s = np.cos(angle), np.sin(angle)
        q = q @ np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
    q = q / radius
    return (np.linalg.norm(q, axis=-1) - 1) * min(radius)

def union(a, b, k=.026):
    h = np.clip(.5 + .5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)

field = ellipsoid([0,.242,-.012],[.191,.184,.154])
for center, radius in [([0,.121,.026],[.163,.112,.136]),([0,.034,.080],[.107,.047,.090]),([0,.087,.137],[.119,.031,.071]),([0,.032,.144],[.109,.019,.047]),([0,.21,.142],[.035,.101,.057]),([0,.144,.211],[.048,.043,.075]),([0,-.015,-.01],[.103,.10,.102])]:
    field = union(field, ellipsoid(center, radius))
for side in [-1,1]:
    field = union(field, ellipsoid([side*.135,.15,.086],[.054,.043,.061],side*.35))
    field = union(field, ellipsoid([side*.096,.251,.135],[.078,.028,.052],side*.22),.026)
    field = union(field, ellipsoid([side*.041,.137,.21],[.027,.023,.040]),.015)
    # Pointed curved cartilage; broad at the skull, tapering organically toward the tip.
    x = side*p[...,0]
    t = np.clip((x-.153)/.31,0,1)
    cy = .22 + .12*t
    cz = -.005 - .060*t + .035*np.sin(t*np.pi)
    width = .082*(1-t)**.8 + .0015
    thickness = .027*(1-t)**.65+.002
    ear = (np.sqrt(((p[...,1]-cy)/width)**2+((p[...,2]-cz)/thickness)**2)-1)*thickness
    ear = np.maximum(ear,np.maximum(.15-x,x-.465))
    field = union(field,ear,.018)
    # Inset eye sockets, nostrils and cheek hollows, cut into the unified face.
    for center,radius in [([side*.091,.220,.160],[.043,.020,.043]),([side*.035,.13,.245],[.013,.010,.018]),([side*.12,.096,.159],[.035,.018,.022])]:
        field = -union(-field,ellipsoid(center,radius),.009)
# Thin curved mouth opening and an asymmetric healed scar.
field = -union(-field,ellipsoid([0,.055,.187],[.102,.007,.027]),.004)
verts, faces, normals, _ = marching_cubes(field,level=0,spacing=(step,)*3)
verts += origin
# Gradient normals returned by skimage face inwards for this signed field.
normals *= -1
# Godot uses clockwise triangles. Verify geometric orientation against outward normals.
a,b,c = verts[faces[:,0]],verts[faces[:,1]],verts[faces[:,2]]
if np.mean(np.einsum('ij,ij->i',np.cross(b-a,c-a),normals[faces[:,0]])) > 0:
    faces = faces[:,[0,2,1]]
out = Path(__file__).resolve().parents[1]/'content/monsters/models/goblin_head.meshbin'
with out.open('wb') as f:
    f.write(struct.pack('<II',len(verts),faces.size))
    f.write(np.asarray(verts,dtype='<f4').tobytes())
    f.write(np.asarray(normals,dtype='<f4').tobytes())
    f.write(np.asarray(faces,dtype='<u4').tobytes())
print(f'Sculpt: {len(verts)} vertices, {len(faces)} triangles -> {out}')
