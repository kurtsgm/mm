import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('region_pipeline', ROOT/'tools/region_pipeline.py')
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)

class RegionPipelineTests(unittest.TestCase):
    def setUp(self):
        self.registry = pipeline.read(ROOT/'content/registry.json')
        self.region = pipeline.read(ROOT/'content/regions/oak_ruins.json')

    def validate(self, region):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'region.json'
            path.write_text(json.dumps(region))
            return pipeline.load_region(path, self.registry)

    def test_both_real_manifests_and_flag_sources(self):
        for id in ('oak_ruins', 'oak_antidote'):
            r = pipeline.load_region(ROOT/f'content/regions/{id}.json', self.registry)
            sources = pipeline.story_lint(r, self.registry)
            self.assertIn('oak_omen_seen', sources)

    def test_preview_cannot_replay_beyond_scenario(self):
        self.region['previews']['returned']['after_steps'] = 999
        with self.assertRaisesRegex(ValueError, 'after_steps'):
            self.validate(self.region)

    def test_unknown_operation_and_fractional_position_rejected(self):
        for update in ({'op': 'teleport_anywhere'}, {'pos': [1.5, 3]}):
            r = copy.deepcopy(self.region)
            r['scenarios']['normal']['steps'][0].update(update)
            with self.assertRaises(ValueError): self.validate(r)

    def test_unknown_conditions_and_orphan_is_rejected(self):
        for condition in ({'flga': 'x'}, {'is': False}, {'quest_stage': {'id': 'x', 'eq': -1}}):
            with self.assertRaises(ValueError): pipeline.condition(condition, 'test')

    def test_external_dependency_must_be_declared(self):
        self.region['external_flags'] = []
        with self.assertRaisesRegex(ValueError, 'external flag'):
            pipeline.story_lint(self.region, self.registry)

    def test_output_atlas_escapes_content(self):
        report = {'maps': {'map': {'name': '<script>alert(1)</script>', 'grid':['.'], 'markers':[]}}}
        with tempfile.TemporaryDirectory() as tmp:
            pipeline.atlas(report, self.region, Path(tmp))
            result = (Path(tmp)/'atlas.html').read_text()
            self.assertNotIn('<script>', result)
            self.assertIn('&lt;script&gt;', result)

    def test_refusing_nonempty_output_does_not_rewrite_old_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'run.json'
            previous = '{"status":"passed","region":"other"}\n'
            path.write_text(previous)
            result = subprocess.run([sys.executable, str(ROOT/'tools/region_pipeline.py'), 'check', '--region', 'oak_ruins', '--output', tmp, '--godot', sys.executable], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('new or empty', result.stderr)
            self.assertEqual(path.read_text(), previous)

if __name__ == '__main__': unittest.main()
