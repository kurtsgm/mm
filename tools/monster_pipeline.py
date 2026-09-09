#!/usr/bin/env python3
"""One entry point for monster validation, captures, rendered benchmarks and preview."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "content/monsters/asset_manifest.json"


def resource_path(value: str) -> Path:
    if not isinstance(value, str) or not value.startswith("res://"):
        raise ValueError(f"Expected res:// path: {value!r}")
    path = (ROOT / value[6:]).resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError(f"Path leaves project: {value}")
    return path


def positive(value, label: str, allow_zero: bool = False):
    if (type(value) not in (int, float) or not math.isfinite(value)
            or (value < 0 if allow_zero else value <= 0)):
        raise ValueError(f"{label} must be a finite {'nonnegative' if allow_zero else 'positive'} number")
    return value


def vector(value, label: str, nonnegative: bool = False):
    if not isinstance(value, list) or len(value) != 3:
        raise ValueError(f"{label} must contain three numbers")
    for component in value:
        if type(component) not in (int, float) or not math.isfinite(component) or (nonnegative and component < 0):
            raise ValueError(f"Invalid {label}")


def load_manifest(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or data.get("schema_version") != 1:
        raise ValueError("Expected manifest schema_version 1")
    if not isinstance(data.get("budget_status"), str) or not data["budget_status"]:
        raise ValueError("Missing budget_status")
    budgets = data.get("budgets", {})
    for key in ("triangles", "materials", "texture_edge", "bones", "glb_mib", "benchmark_instances", "benchmark_p95_ms"):
        positive(budgets.get(key), f"budgets.{key}")
    if type(budgets["benchmark_instances"]) is not int:
        raise ValueError("benchmark_instances must be an integer")
    if not isinstance(data.get("monsters"), list) or not data["monsters"]:
        raise ValueError("Manifest must contain monsters")
    ids = set()
    for spec in data["monsters"]:
        if not isinstance(spec, dict):
            raise ValueError("Each monster must be an object")
        monster_id = spec.get("id", "")
        if not isinstance(monster_id, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", monster_id) or monster_id in ids:
            raise ValueError(f"Invalid or duplicate monster ID: {monster_id!r}")
        ids.add(monster_id)
        if not isinstance(spec.get("display_name"), str) or not spec["display_name"]:
            raise ValueError(f"{monster_id}: missing display_name")
        for key in ("scene", "glb", "definition", "provenance"):
            resource_path(spec.get(key))
        for key in ("sources", "required_bones"):
            if not isinstance(spec.get(key), list) or not spec[key] or not all(isinstance(item, str) and item for item in spec[key]):
                raise ValueError(f"{monster_id}: {key} must be a nonempty string list")
        for source in spec["sources"]:
            resource_path(source)
        for key in ("size_min", "size_max"):
            vector(spec.get(key), key, nonnegative=True)
        if any(low >= high for low, high in zip(spec["size_min"], spec["size_max"])):
            raise ValueError(f"{monster_id}: inverted or empty size range")
        positive(spec.get("ground_tolerance"), "ground_tolerance")
        if spec.get("locomotion") not in ("ground", "hover"):
            raise ValueError(f"{monster_id}: locomotion must be ground or hover")
        if spec["locomotion"] == "hover":
            if not isinstance(spec.get("hover_bones"), list) or not spec["hover_bones"] or not all(isinstance(b, str) and b for b in spec["hover_bones"]):
                raise ValueError(f"{monster_id}: hover requires hover_bones")
            positive(spec.get("hover_min_y"), "hover_min_y")
        preview = spec.get("preview", {})
        vector(preview.get("target"), "preview.target")
        positive(preview.get("distance"), "preview.distance")
        positive(preview.get("pitch"), "preview.pitch", allow_zero=True)
        if not isinstance(preview.get("attack_label"), str) or not preview["attack_label"]:
            raise ValueError(f"{monster_id}: missing preview.attack_label")
    return data


def write_json(path: Path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run_supervised(command, *, cwd, stdout, log_path: Path, timeout):
    """Godot may log a script failure without quitting its SceneTree. Stop promptly."""
    started = time.monotonic()
    process = subprocess.Popen(command, cwd=cwd, stdout=stdout, stderr=subprocess.STDOUT)
    try:
        while True:
            try:
                return subprocess.CompletedProcess(command, process.wait(timeout=0.25))
            except subprocess.TimeoutExpired:
                log_text = log_path.read_text(encoding="utf-8", errors="replace")
                timed_out = timeout is not None and time.monotonic() - started > timeout
                if "SCRIPT ERROR:" in log_text or any(line.startswith("ERROR:") for line in log_text.splitlines()) or timed_out:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                    if timed_out:
                        raise subprocess.TimeoutExpired(command, timeout)
                    return subprocess.CompletedProcess(command, process.returncode)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


def run_worker(godot: str, job: dict, output: Path, timeout: int = 600) -> dict:
    mode = job["mode"]
    job_path = output / f"{mode}-job.json"
    write_json(job_path, job)
    command = [godot, "--path", str(ROOT)]
    if mode == "validate":
        command.append("--headless")
    else:
        command += ["--rendering-method", "gl_compatibility", "--windowed", "--resolution", f"{job['width']}x{job['height']}"]
    command += ["--script", "res://tools/monster_review_cli.gd", "--", "--job", str(job_path)]
    log_path = output / f"{mode}.log"
    print(f"{mode}: running… ({log_path})", flush=True)
    try:
        with log_path.open("w", encoding="utf-8") as log:
            result = run_supervised(command, cwd=ROOT, stdout=log, log_path=log_path,
                                    timeout=None if mode == "preview" else timeout)
        code = result.returncode
    except subprocess.TimeoutExpired:
        return {"status": "failed", "error": f"worker timed out after {timeout}s", "log": log_path.name}
    log_text = log_path.read_text(encoding="utf-8", errors="replace")
    script_errors = [line for line in log_text.splitlines() if "SCRIPT ERROR:" in line or line.startswith("ERROR:")]
    for line in log_text.splitlines():
        if line.startswith(("VALIDATE ", "CAPTURE ", "BENCHMARK ")):
            print(line, flush=True)
    if code or script_errors:
        return {"status": "failed", "exit_code": code, "error": "; ".join(script_errors[:8]) or "Worker reported failure; see log", "log": log_path.name}
    filename = {"validate": "validation.json", "capture": "captures.json", "benchmark": "benchmark.json"}.get(mode)
    if filename and not (output / filename).is_file():
        return {"status": "failed", "error": f"Worker produced no {filename}", "log": log_path.name}
    return {"status": "passed", "log": log_path.name}


def render_report(output: Path, run: dict):
    validation_path = output / "validation.json"
    validation = json.loads(validation_path.read_text()) if validation_path.exists() else []
    benchmark_path = output / "benchmark.json"
    benchmark = json.loads(benchmark_path.read_text()) if benchmark_path.exists() else None
    captures_path = output / "captures.json"
    captures = json.loads(captures_path.read_text()) if captures_path.exists() else None
    warnings = sum(len(row["warnings"]) for row in validation)
    if benchmark:
        warnings += sum(len(row["warnings"]) for row in benchmark["samples"])
    run["budget_warnings"] = warnings
    failed = any(stage["status"] == "failed" for stage in run["stages"].values())
    run["status"] = "failed" if failed else "warnings" if warnings else "passed"
    run["manual_review"] = "pending — technical checks do not approve visual quality or whole-game performance"
    write_json(output / "run.json", run)
    lines = ["# 怪物製作檢查報告", "", f"- 時間（UTC）：{run['created_at']}",
             f"- 技術流程結果：**{run['status']}**", f"- 怪物：{', '.join(run['monsters'])}",
             f"- 暫定預算警告：{warnings}", "- 人工視覺審查：待審；本報告不代表量產驗收通過。",
             "- 效能範圍：獨立資產渲染，並非完整遊戲 FPS。", "",
             "## 執行階段", "", "| 階段 | 結果 | 記錄 |", "|---|---|---|"]
    for mode, stage in run["stages"].items():
        lines.append(f"| {mode} | {stage['status']} | [{stage.get('log', '—')}]({stage.get('log', '')}) |")
        if stage.get("error"):
            lines += ["", f"{mode}: {stage['error']}", ""]
    lines += ["", "## 技術檢查與暫定預算", "", "以下門檻是工程預警值，尚未核定為普通怪／精英／Boss 的製作標準。", "",
              f"預算設定：`{json.dumps(run['budgets'], ensure_ascii=False)}`", "",
              "| 怪物 | 基底三角形 | 材質 | 骨骼 | 最大貼圖邊長 | GLB MiB | 錯誤／警告 |", "|---|---:|---:|---:|---:|---:|---|"]
    for row in validation:
        m = row["metrics"]
        lines.append(f"| {row['id']} | {m.get('triangles', '—')} | {m.get('materials', '—')} | {m.get('bones', '—')} | {m.get('texture_edge', '—')} | {m.get('glb_mib', 0):.2f} | {len(row['errors'])}／{len(row['warnings'])} |")
    for row in validation:
        if row["errors"] or row["warnings"]:
            lines += ["", f"### {row['id']}", ""]
            lines += [f"- 錯誤：{error}" for error in row["errors"]]
            lines += [f"- 暫定預算警告：{warning}" for warning in row["warnings"]]
    if benchmark:
        lines += ["", "## 實際渲染效能", "", f"環境：`{json.dumps(benchmark['environment'], ensure_ascii=False)}`", "",
                  f"各組暖機 {benchmark['warmup_frames']} 幀，採樣 {benchmark['sample_frames']} 幀；idle、陰影開啟。不同格陣使用不同相機距離，詳見 JSON；不與舊版固定相機基準直接比較。", "",
                  "每個採樣幀明確觸發離屏視口渲染；檢查渲染事件與非零繪製量，避免視窗停止更新時讀到舊統計。draw calls 為可見 pass，陰影負載仍包含在時間內。", "",
                  "| 組別 | 數量 | 中位 ms | P95 ms | 平均 FPS | 平均可見 draw calls |", "|---|---:|---:|---:|---:|---:|"]
        for row in benchmark["samples"]:
            label = f"[{row['group']}]({row['workload_image']})"
            lines.append(f"| {label} | {row['instances']} | {row['median_frame_ms']:.2f} | {row['p95_frame_ms']:.2f} | {row['mean_fps']:.1f} | {row['mean_draw_calls']:.1f} |")
        lines += ["", "預算檢查只套用設定的同屏數；未測該數量時，沒有對應效能門檻判定。"]
        for row in benchmark["samples"]:
            lines += [f"- {row['group']} × {row['instances']}：{warning}" for warning in row["warnings"]]
    if captures:
        lines += ["", "## 標準截圖", "", "所有怪物共用棚燈；相機依設定取景，因此圖片中的像素高度不能用來比較世界尺寸。姿勢時間、相機與環境記錄在 captures.json。", ""]
        for monster_id in run["monsters"]:
            lines += [f"### {monster_id}", ""]
            shots = [shot for shot in captures["captures"] if shot["id"] == monster_id]
            front = next(shot for shot in shots if shot["pose"]["name"] == "front")
            lines += [f"![{monster_id} 正面]({front['file']})", "",
                      " · ".join(f"[{shot['pose']['name']}]({shot['file']})" for shot in shots), ""]
    lines += ["", "## 人工驗收", "", "- [ ] 實際遊戲距離下的輪廓、臉部與招式可辨識。",
              "- [ ] 正側背面材質一致，無明顯穿模、滑步、異常拉伸。",
              "- [ ] +Z 正面、比例與地面／懸浮表現正確。",
              "- [ ] 大地圖與戰鬥整合、物種專屬測試通過。",
              "- [ ] 完整遊戲的目標設備與同屏負載實測通過。",
              "- [ ] 來源與授權內容經人工確認。", "",
              "執行設定與輸入 SHA-256：見 [run.json](run.json)。來源檔存在檢查不等同授權審查或重建成功。", ""]
    (output / "report.md").write_text("\n".join(lines), encoding="utf-8")
    return failed, warnings


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("review", "validate", "capture", "benchmark", "preview"))
    parser.add_argument("--monster", action="append", help="Repeat to select species; default: all manifest entries")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--output", type=Path, help="New or empty directory; default: build/monster-review/<UTC timestamp>")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--counts", type=int, nargs="+", default=[1, 2, 8, 16])
    parser.add_argument("--frames", type=int, default=180)
    parser.add_argument("--warmup", type=int, default=60)
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--no-lod", action="store_true", help="Disable automatic mesh LOD for captures/benchmarks")
    parser.add_argument("--strict-budgets", action="store_true", help="Exit 1 on draft budget warnings, in addition to technical errors")
    args = parser.parse_args(argv)
    try:
        manifest = load_manifest(args.manifest)
        known = {spec["id"]: spec for spec in manifest["monsters"]}
        selected = list(dict.fromkeys(args.monster or known))
        unknown = set(selected) - known.keys()
        if unknown:
            raise ValueError(f"Unknown monster IDs: {', '.join(sorted(unknown))}")
        if args.command == "preview" and len(selected) != 1:
            raise ValueError("preview requires exactly one --monster")
        if args.frames < 2 or args.warmup < 1 or not args.counts or any(count < 1 or count > 256 for count in args.counts):
            raise ValueError("frames >= 2, warmup >= 1, and counts between 1 and 256 are required")
        if args.width < 320 or args.height < 240:
            raise ValueError("Resolution must be at least 320×240")
        godot = shutil.which(args.godot)
        if not godot:
            raise ValueError(f"Godot not found: {args.godot}")
        created = datetime.now(timezone.utc)
        output = (args.output or ROOT / "build/monster-review" / created.strftime("%Y%m%dT%H%M%S%fZ")).resolve()
        if output.exists() and (not output.is_dir() or any(output.iterdir())):
            raise ValueError(f"Output must be new or empty (prevents stale reports): {output}")
        output.mkdir(parents=True, exist_ok=True)
    except (ValueError, OSError, TypeError, AttributeError) as error:
        parser.error(str(error))
    job = {"output": str(output), "monsters": [known[key] for key in selected], "budgets": manifest["budgets"],
           "check_catalog_coverage": args.monster is None,
           "counts": sorted(set(args.counts)), "frames": args.frames, "warmup": args.warmup,
           "width": args.width, "height": args.height, "no_lod": args.no_lod}
    paths = {args.manifest.resolve(), ROOT / "tools/monster_pipeline.py", ROOT / "tools/monster_review_cli.gd",
             ROOT / "tools/monster_asset_validator.gd", ROOT / "presentation/monsters/goblin_preview.gd",
             ROOT / "presentation/monsters/monster_model.gd", ROOT / "presentation/monsters/monster_model_catalog.gd", ROOT / "project.godot"}
    for spec in job["monsters"]:
        paths.update(resource_path(path) for path in spec["sources"] + [spec["scene"], spec["glb"], spec["definition"], spec["provenance"], spec["glb"] + ".import"])
    hashes = {str(path.relative_to(ROOT) if path.is_relative_to(ROOT) else path): hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing" for path in sorted(paths)}
    run = {"created_at": created.isoformat(), "command": args.command, "monsters": selected, "budgets": manifest["budgets"],
           "budget_status": manifest["budget_status"], "strict_budgets": args.strict_budgets, "input_sha256": hashes, "stages": {}}
    # First imports class metadata and assets, making this work in a clean checkout.
    print(f"Report directory: {output}", flush=True)
    try:
        with (output / "import.log").open("w") as log:
            imported = subprocess.run([godot, "--headless", "--path", str(ROOT), "--import"], cwd=ROOT,
                                      stdout=log, stderr=subprocess.STDOUT, timeout=300)
        import_text = (output / "import.log").read_text(errors="replace")
        import_failed = imported.returncode != 0 or "SCRIPT ERROR:" in import_text or "ERROR:" in import_text
        run["stages"]["import"] = {"status": "failed" if import_failed else "passed", "log": "import.log"}
        if not import_failed:
            modes = ["validate"]
            if args.command == "review":
                modes += ["capture", "benchmark"]
            elif args.command != "validate":
                modes.append(args.command)
            for mode in modes:
                run["stages"][mode] = run_worker(godot, dict(job, mode=mode), output)
                if run["stages"][mode]["status"] == "failed":
                    for remaining in modes[modes.index(mode) + 1:]:
                        run["stages"][remaining] = {"status": "skipped", "error": "Earlier stage failed"}
                    break
    except (OSError, subprocess.TimeoutExpired) as error:
        run["stages"]["execution"] = {"status": "failed", "error": str(error)}
    failed, warnings = render_report(output, run)
    print(f"Result: {run['status']}; report: {output / 'report.md'}", flush=True)
    return 1 if failed or (args.strict_budgets and warnings) else 0


if __name__ == "__main__":
    sys.exit(main())
