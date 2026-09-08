"""Original small humanoid fae head, in normalized head coordinates.
Run with the dependencies in requirements-goblin.txt, then build_dream_wisp.gd.
The signed field unifies the skull, cheeks, jaw, nose and pointed cartilage.
"""
from pathlib import Path
import struct
import numpy as np
from skimage.measure import marching_cubes
from scipy.ndimage import gaussian_filter

step = 0.010
origin = np.array([-0.60, -0.06, -0.40])
axes = [np.arange(a, b, step) for a, b in zip(origin, [0.60, 1.06, 0.43])]
p = np.stack(np.meshgrid(*axes, indexing="ij"), axis=-1)

def ellipsoid(center, radius):
    q = (p-center)/radius
    return (np.linalg.norm(q, axis=-1)-1)*min(radius)

def union(a, b, k=0.045):
    h = np.clip(0.5+0.5*(b-a)/k, 0, 1)
    return b*(1-h)+a*h-k*h*(1-h)

def cut(a, center, radius, k=0.012):
    return -union(-a, ellipsoid(center, radius), k)

field = ellipsoid([0,0.56,-0.045], [0.305,0.425,0.280])
# Broad smooth unions keep the cheeks, brow and chin within one facial envelope.
for c,r in [([0,0.245,0.010],[0.241,0.230,0.231]),
            ([0,0.078,0.048],[0.145,0.090,0.155])]:
    field = union(field,ellipsoid(c,r),0.105)
field = union(field,ellipsoid([0,0.30,0.080],[0.225,0.170,0.170]),0.055)
for c,r in [([0,0.401,0.210],[0.031,0.113,0.054]),
            ([0,0.300,0.259],[0.037,0.027,0.037]),
            ([0,0.178,0.216],[0.086,0.021,0.024]),
            ([0,0.148,0.217],[0.079,0.019,0.024])]:
    field = union(field,ellipsoid(c,r),0.038)
for side in [-1,1]:
    field = cut(field,[side*0.130,0.442,0.236],[0.072,0.027,0.024],0.016)
    field = cut(field,[side*0.020,0.286,0.276],[0.010,0.006,0.010],0.003)
    x = side*p[...,0]
    t = np.clip((x-0.25)/0.24,0,1)
    cy = 0.46+0.18*t
    cz = -0.055-0.05*t
    width = 0.080*(1-t)**0.85+0.001
    thickness = 0.025*(1-t)**0.65+0.001
    ear = (np.sqrt(((p[...,1]-cy)/width)**2+((p[...,2]-cz)/thickness)**2)-1)*thickness
    ear = np.maximum(ear,np.maximum(0.24-x,x-0.49))
    field = union(field,ear,0.02)
field = cut(field,[0,0.164,0.239],[0.074,0.0035,0.014],0.003)
field = gaussian_filter(field, sigma=0.75)
verts, faces, normals, _ = marching_cubes(field,level=0,spacing=(step,)*3)
verts += origin
normals *= -1
cross = np.cross(verts[faces[:,1]]-verts[faces[:,0]],verts[faces[:,2]]-verts[faces[:,0]])
if np.mean(np.einsum('ij,ij->i',cross,normals[faces[:,0]]))>0:
    faces = faces[:,[0,2,1]]
out = Path(__file__).resolve().parents[1]/'content/monsters/models/fairy_head.meshbin'
with out.open('wb') as f:
    f.write(struct.pack('<II',len(verts),faces.size))
    f.write(np.asarray(verts,dtype='<f4').tobytes())
    f.write(np.asarray(normals,dtype='<f4').tobytes())
    f.write(np.asarray(faces,dtype='<u4').tobytes())
print(f'Fae head: {len(verts)} vertices, {len(faces)} triangles -> {out}')
