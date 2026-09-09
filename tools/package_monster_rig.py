"""Save an editable Blender copy of a baked game rig. Run inside Blender."""
import argparse
from pathlib import Path
import re
import sys

import bpy

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--monster', required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
if not re.fullmatch(r'[a-z][a-z0-9_]*', args.monster):
    parser.error('Expected a snake_case monster ID')
source = ROOT / 'content/monsters/models' / (args.monster + '.glb')
if not source.is_file():
    parser.error(f'Missing game GLB: {source}')
output = ROOT / 'art_source' / args.monster / 'production' / (args.monster + '_rigged.blend')
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
for image in bpy.data.images:
    if not image.packed_file:
        image.pack()
for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        obj.show_in_front = True
bpy.context.scene['Source'] = str(source.relative_to(ROOT))
bpy.context.scene['Rig type'] = 'Baked game deformation skeleton and NLA clips; no DCC control rig'
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
print('RIGGED_SOURCE_SAVED', str(output), flush=True)
