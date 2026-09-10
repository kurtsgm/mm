#!/usr/bin/env python3
"""Validate, replay and review authored regions without duplicating runtime content."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
KINDS = ('maps', 'quests', 'dialogues', 'cutscenes')

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))

def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def require(ok, message):
    if not ok:
        raise ValueError(message)

def project_path(value):
    require(isinstance(value, str), 'path must be a string')
    path = (ROOT / value.removeprefix('res://')).resolve()
    require(path.is_relative_to(ROOT), f'path leaves project: {value}')
    return path

def strings(value):
    return isinstance(value, list) and all(isinstance(x, str) and x for x in value)

def location(value, maps, entry=True):
    require(isinstance(value, dict) and value.get('map') in maps, f'undeclared map location: {value}')
    if entry:
        require(isinstance(value.get('entry', 'start'), str), 'entry must be a string')
    else:
        p = value.get('pos')
        require(isinstance(p, list) and len(p) == 2 and all(type(n) is int and 0 <= n < 16 for n in p), f'invalid pos: {p}')

def condition(value, label):
    if value is None:
        return
    require(isinstance(value, dict), f'{label}: require must be an object')
    for key, v in value.items():
        if key in ('flag', 'has_item', 'quest_active', 'quest_done', 'quest_inactive'):
            require(isinstance(v, str) and v, f'{label}: invalid {key}')
        elif key == 'is':
            require(type(v) is bool and 'flag' in value, f'{label}: is needs a flag and boolean')
        elif key == 'gold_gte':
            require(type(v) is int and v >= 0, f'{label}: invalid gold_gte')
        elif key == 'quest_stage':
            require(isinstance(v, dict) and isinstance(v.get('id'), str) and type(v.get('eq')) is int and v['eq'] >= 0, f'{label}: invalid quest_stage')
        else:
            raise ValueError(f'{label}: unknown condition {key}')

def selections(value):
    return isinstance(value, list) and all(x is None or isinstance(x, str) for x in value)

def load_region(path, registry):
    r = read(path)
    require(isinstance(r, dict), 'region must be an object')
    require(isinstance(r.get('id'), str) and re.fullmatch(r'[a-z][a-z0-9_]*', r['id']), 'invalid region ID')
    for key in ('title', 'brief', 'status'):
        require(isinstance(r.get(key), str) and r[key], f'missing {key}')
    require(project_path(r['brief']).is_file(), f'missing brief: {r["brief"]}')
    require(isinstance(r.get('content'), dict), 'missing content')
    for kind in KINDS:
        ids = r['content'].get(kind)
        require(strings(ids) and len(ids) == len(set(ids)), f'invalid content.{kind}')
        for id in ids:
            require(id in registry[kind], f'content.{kind}: unknown {id}')
    maps = r['content']['maps']
    require(bool(maps), 'region needs maps')
    require(strings(r.get('external_flags', [])), 'invalid external_flags')
    require(strings(r.get('manual_checks')) and r['manual_checks'], 'manual_checks required')
    require(isinstance(r.get('routes'), list) and r['routes'], 'routes required')
    for route in r['routes']:
        require(isinstance(route, dict), 'route must be an object')
        location(route.get('from'), maps); location(route.get('to'), maps)
        require(type(route.get('return_required')) is bool, 'route must declare return_required')
    require(isinstance(r.get('scenarios'), dict) and r['scenarios'], 'scenarios required')
    for name, scenario in r['scenarios'].items():
        require(isinstance(scenario, dict), f'{name}: scenario must be an object')
        location(scenario.get('start'), maps)
        require(isinstance(scenario.get('steps'), list) and scenario['steps'], f'{name}: steps required')
        for i, s in enumerate(scenario['steps']):
            label = f'{name}/step {i+1}'
            require(isinstance(s, dict), f'{label}: step must be object')
            op = s.get('op')
            require(op in ('visit', 'talk', 'scene', 'chest', 'expect', 'reload'), f'{label}: unknown op {op}')
            if op in ('visit', 'talk', 'scene', 'chest'):
                location(s, maps, False)
            if op in ('talk', 'scene'):
                require(selections(s.get('choices', [])), f'{label}: invalid choices')
                require(isinstance(s.get('dialogues', []), list) and all(selections(x) for x in s.get('dialogues', [])), f'{label}: invalid dialogues')
                for key in ('abort', 'blocked'):
                    require(type(s.get(key, False)) is bool, f'{label}: invalid {key}')
                require(not (s.get('abort') and s.get('blocked')), f'{label}: abort and blocked are exclusive')
            if op == 'expect':
                require(any(k in s for k in ('require', 'gold_delta', 'items')), f'{label}: empty expectation')
                condition(s.get('require'), label)
                if 'gold_delta' in s: require(type(s['gold_delta']) is int, f'{label}: invalid gold_delta')
                items = s.get('items', {})
                require(isinstance(items, dict) and all(k in registry['items'] and type(v) is int and v >= 0 for k, v in items.items()), f'{label}: invalid items')
    require(isinstance(r.get('previews'), dict) and r['previews'], 'previews required')
    for name, preview in r['previews'].items():
        require(re.fullmatch(r'[a-z][a-z0-9_]*', name) is not None and isinstance(preview, dict), 'invalid preview')
        location(preview.get('start'), maps)
        require(type(preview.get('walk_forward', False)) is bool, 'invalid walk_forward')
        condition(preview.get('expect_after'), f'preview/{name}')
        if 'scenario' in preview:
            require(preview['scenario'] in r['scenarios'], 'unknown preview scenario')
            n = preview.get('after_steps')
            require(type(n) is int and 0 <= n <= len(r['scenarios'][preview['scenario']]['steps']), 'invalid after_steps')
        else:
            require('after_steps' not in preview, 'after_steps needs scenario')
    return r

def walk(value, prefix=''):
    if isinstance(value, dict):
        yield prefix, value
        for k, v in value.items(): yield from walk(v, f'{prefix}/{k}')
    elif isinstance(value, list):
        for i, v in enumerate(value): yield from walk(v, f'{prefix}/{i}')

def story_lint(region, registry):
    """Writer existence is structural evidence, not a proof of satisfiable story conditions."""
    documents = {}
    writers = {}
    for kind in KINDS:
        for id, entry in registry[kind].items():
            p = project_path(entry['path'])
            raw = read(p)
            documents[(kind, id)] = raw
            for loc, obj in walk(raw):
                if obj.get('op') == 'set_flag' and isinstance(obj.get('flag'), str):
                    writers.setdefault(obj['flag'], []).append(f'{kind}/{id}{loc}')
    dependencies = {}
    for kind, ids in region['content'].items():
        for id in ids:
            for loc, obj in walk(documents[(kind, id)]):
                label = f'{kind}/{id}{loc}'
                c = {'flag': obj['flag']} if obj.get('type') == 'flag' and 'flag' in obj else obj.get('require')
                condition(c, label)
                if not c: continue
                if 'flag' in c:
                    flag = c['flag']
                    require(flag in writers, f'{label}: flag {flag} has no content writer')
                    dependencies[flag] = writers[flag]
                    internal = any(src.split('/')[1] in region['content'][src.split('/')[0]] for src in writers[flag])
                    require(internal or flag in region.get('external_flags', []), f'{label}: declare external flag {flag}')
                for k in ('quest_active', 'quest_done', 'quest_inactive', 'has_item', 'quest_stage'):
                    if k not in c: continue
                    ref = c[k]['id'] if k == 'quest_stage' else c[k]
                    target = 'items' if k == 'has_item' else 'quests'
                    require(ref in registry[target], f'{label}: missing {target}/{ref}')
    return dependencies

def execute(command, log, timeout=180):
    started = time.monotonic()
    with log.open('w') as stream:
        process = subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                time.sleep(.2)
                output = log.read_text(errors='replace')
                if 'SCRIPT ERROR:' in output or time.monotonic()-started > timeout:
                    raise RuntimeError(f'Godot failed or timed out; see {log}')
            output = log.read_text(errors='replace')
            if process.returncode or 'SCRIPT ERROR:' in output or any(x.startswith('ERROR:') for x in output.splitlines()):
                raise RuntimeError(f'Godot exited {process.returncode}; see {log}')
        finally:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()
    return round(time.monotonic()-started, 3)

def atlas(report, region, output):
    sections = []
    for id, m in report['maps'].items():
        cells = []
        for y, row in enumerate(m['grid']):
            for x, t in enumerate(row):
                cells.append(f'<rect x="{x*24}" y="{y*24}" width="23" height="23" fill="{"#26343b" if t == "#" else "#d9ccab"}"/>')
        for marker in m['markers']:
            x, y = marker['pos']; label = html.escape(marker['label']); detail = html.escape(marker['detail'])
            cells.append(f'<g><title>({x},{y}) {detail}</title><circle cx="{x*24+12}" cy="{y*24+12}" r="10" fill="#803d28"/><text x="{x*24+12}" y="{y*24+16}" text-anchor="middle" fill="white" font-size="12">{label}</text></g>')
        sections.append(f'<section><h2>{html.escape(m["name"])} · {html.escape(id)}</h2><svg viewBox="0 0 384 384" role="img" aria-label="{html.escape(m["name"])}">{"".join(cells)}</svg></section>')
    body = '<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>區域路線審查</title><style>body{background:#101e25;color:#eee4ce;font:16px system-ui;margin:3vw}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:3vw}h2{font-size:17px}svg{width:100%;max-width:560px}p{line-height:1.7}</style>'
    body += f'<h1>{html.escape(region["title"])}</h1><p>P 出入口 · S 故事 · N 人物 · C 寶箱 · M 遭遇。滑過標記查看座標與引用。圖面依 Godot 匯入後的地形產生，包含建築覆蓋與阻擋 NPC；裝飾外觀請用遊戲預覽確認。</p><main>{"".join(sections)}</main></html>'
    (output/'atlas.html').write_text(body, encoding='utf-8')

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('command', choices=('check', 'review', 'preview', 'capture'))
    p.add_argument('--region', required=True, help='content/regions/<id>.json')
    p.add_argument('--case', default='entry')
    p.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    p.add_argument('--output', type=Path)
    a = p.parse_args()
    output = None
    owned_output = False
    try:
        require(re.fullmatch(r'[a-z][a-z0-9_]*', a.region) is not None, 'invalid region id')
        registry = read(ROOT/'content/registry.json')
        manifest = ROOT/'content/regions'/f'{a.region}.json'
        region = load_region(manifest, registry)
        dependencies = story_lint(region, registry)
        require(a.case in region['previews'], f'unknown preview {a.case}; choose {list(region["previews"])}')
        godot = shutil.which(a.godot)
        require(godot is not None, f'Godot not found: {a.godot}')
        output = (a.output or ROOT/'build/region-review'/f'{datetime.now(timezone.utc):%Y%m%dT%H%M%S%fZ}-{a.region}').resolve()
        require(not output.exists() or not any(output.iterdir()), 'output must be a new or empty directory')
        output.mkdir(parents=True, exist_ok=True)
        owned_output = True
        run = {'region': a.region, 'command': a.command, 'status': 'running', 'manual_review': 'pending', 'flag_sources': dependencies, 'timings_seconds': {}}
        inputs = [manifest, ROOT/'content/registry.json']
        inputs += [project_path(e['path']) for k in KINDS for e in registry[k].values()]
        inputs += [path for folder in ('tools', 'engine', 'autoload', 'resources') for path in (ROOT/folder).rglob('*') if path.suffix in ('.gd', '.py')]
        run['input_sha256'] = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs}
        write(output/'run.json', run)
        run['timings_seconds']['import'] = execute([godot, '--headless', '--path', str(ROOT), '--import'], output/'import.log')
        mode = 'capture' if a.command in ('review', 'capture') else a.command
        job = {'region': 'res://'+str(manifest.relative_to(ROOT)), 'mode': mode, 'case': a.case, 'report': str(output/'validation.json'), 'capture': str(output/f'{a.case}.webp')}
        write(output/'job.json', job)
        command = [godot, '--path', str(ROOT)]
        command += ['--headless'] if mode == 'check' else ['--windowed', '--resolution', '1280x720']
        command += ['--script', 'res://tools/region_review_cli.gd', '--', str(output/'job.json')]
        run['timings_seconds']['worker'] = execute(command, output/'worker.log', timeout=86400 if mode == 'preview' else 180)
        require((output/'validation.json').is_file(), 'worker did not produce validation report')
        report = read(output/'validation.json')
        require(not report['errors'], 'region validation failed')
        if mode == 'capture': require(Path(job['capture']).is_file(), 'missing capture')
        atlas(report, region, output)
        lines = [f'# {region["title"]} · 區域檢查', '', '自動檢查通過；人工遊玩、視覺、聲音與時長尚待驗收。', '', '[地圖配置圖](atlas.html)', '', '| 案例 | 步驟 | 路徑格數 |', '|---|---:|---:|']
        for name, result in report['scenarios'].items(): lines.append(f'| {name} | {result["steps"]} | {result["walked_cells"]} |')
        if report.get('warnings'):
            lines += ['', '待處理警告：', ''] + [f'- {warning}' for warning in report['warnings']]
        if report.get('rendered_scene_check'):
            lines += ['', '實際渲染檢查：踏入過場、對話期間鎖定操作、完成後寫入狀態與 once、恢復探索，全部通過。']
        lines += ['', '路徑重播假設遭遇可戰勝，未模擬漫遊怪物、戰鬥或實際鍵盤操作。reload 使用正式序列化做記憶體 JSON 往返，不寫入使用者存檔槽。', '']
        if mode == 'capture': lines += [f'![{a.case}]({a.case}.webp)', '']
        lines += [f'- [ ] {check}' for check in region['manual_checks']]
        (output/'report.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
        run['status'] = 'passed'; write(output/'run.json', run)
        print(output/'report.md')
        return 0
    except (ValueError, OSError, KeyError, TypeError, RuntimeError) as exc:
        if owned_output and (output/'run.json').is_file():
            run = read(output/'run.json'); run.update(status='failed', error=str(exc)); write(output/'run.json', run)
        print(str(exc), file=sys.stderr)
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
