"""Failure-path checks for the offline CLI; run with unittest discovery."""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[2] / "tools/monster_pipeline.py"
SPEC = importlib.util.spec_from_file_location("monster_pipeline", MODULE)
pipeline = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pipeline)


class MonsterPipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.manifest = json.loads(pipeline.DEFAULT_MANIFEST.read_text())

    def load(self, manifest):
        path = self.directory / "manifest.json"
        path.write_text(json.dumps(manifest))
        return pipeline.load_manifest(path)

    def test_existing_manifest_is_valid(self):
        self.assertEqual({m["id"] for m in self.load(self.manifest)["monsters"]},
                         {"goblin", "poison_spider", "dream_wisp", "ogre"})

    def test_duplicate_ids_and_traversal_are_rejected(self):
        duplicate = copy.deepcopy(self.manifest)
        duplicate["monsters"].append(duplicate["monsters"][0])
        with self.assertRaisesRegex(ValueError, "duplicate"):
            self.load(duplicate)
        self.manifest["monsters"][0]["scene"] = "res://../outside.tscn"
        with self.assertRaisesRegex(ValueError, "leaves project"):
            self.load(self.manifest)

    def test_invalid_dimensions_hover_and_budget_are_rejected(self):
        for change in (lambda d: d["monsters"][0].update(size_min=[3, 3, 3]),
                       lambda d: d["monsters"][2].update(hover_bones=[]),
                       lambda d: d["budgets"].update(triangles=float("nan"))):
            data = copy.deepcopy(self.manifest)
            change(data)
            with self.assertRaises(ValueError):
                self.load(data)

    def test_unknown_species_does_not_start_godot(self):
        with patch.object(pipeline.subprocess, "run") as run:
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                pipeline.main(["validate", "--monster", "typo"])
            self.assertEqual(error.exception.code, 2)
            run.assert_not_called()

    def test_nonempty_output_is_never_reused(self):
        marker = self.directory / "old-report.md"
        marker.write_text("keep me")
        with patch.object(pipeline.shutil, "which", return_value="godot"), patch.object(pipeline.subprocess, "run") as run:
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                pipeline.main(["validate", "--output", str(self.directory)])
            run.assert_not_called()
        self.assertEqual(marker.read_text(), "keep me")

    def test_zero_exit_with_script_error_is_failure(self):
        def broken(command, **kwargs):
            kwargs["stdout"].write("SCRIPT ERROR: Invalid access\n")
            return subprocess.CompletedProcess(command, 0)
        with patch.object(pipeline, "run_supervised", side_effect=broken):
            result = pipeline.run_worker("godot", {"mode": "validate"}, self.directory)
        self.assertEqual(result["status"], "failed")

    def test_zero_exit_without_report_is_failure(self):
        with patch.object(pipeline, "run_supervised", return_value=subprocess.CompletedProcess([], 0)):
            result = pipeline.run_worker("godot", {"mode": "validate"}, self.directory)
        self.assertEqual(result["status"], "failed")
        self.assertIn("no validation.json", result["error"])

    def test_timeout_produces_failure(self):
        with patch.object(pipeline, "run_supervised", side_effect=subprocess.TimeoutExpired("godot", 1)):
            result = pipeline.run_worker("godot", {"mode": "validate"}, self.directory, timeout=1)
        self.assertEqual(result["status"], "failed")
        self.assertIn("timed out", result["error"])

    def test_supervisor_stops_a_worker_that_logs_error_and_hangs(self):
        log = self.directory / "hung.log"
        script = "import time; print('SCRIPT ERROR: test failure', flush=True); time.sleep(30)"
        with log.open("w") as output:
            result = pipeline.run_supervised([pipeline.sys.executable, "-c", script], cwd=self.directory,
                                             stdout=output, log_path=log, timeout=2)
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
