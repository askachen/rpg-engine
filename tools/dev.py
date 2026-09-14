"""python tools/dev.py check | play | editor | ui-smoke"""
from pathlib import Path
import os
import argparse
import json
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description='Validate, test or play a selected content package.')
    parser.add_argument('command',nargs='?',default='check',choices=['check','play','editor','ui-smoke','list','validate','new','test'])
    parser.add_argument('--game',default='demo',help='Directory name under games/, or a JSON manifest path')
    options=parser.parse_args()
    command=options.command
    if command=='new':
        from new_game import create_game
        try:manifest=create_game(options.game)
        except (ValueError,OSError,RuntimeError) as error:
            print(str(error),file=sys.stderr);return 2
        print(f'Created: {manifest}')
        print(f'Next: python tools/dev.py test --game {options.game}')
        return 0
    if command=='list':
        for manifest in sorted((ROOT/'games').glob('*/game.json')):print(manifest.parent.name)
        return 0
    candidate=Path(options.game)
    content=(ROOT/'games'/options.game/'game.json') if candidate.suffix.lower()!='.json' else (candidate if candidate.is_absolute() else ROOT/candidate)
    if not content.is_file():
        print(f'Content not found: {content}',file=sys.stderr);return 2
    from validate import load_unique,validate
    try:errors=validate(load_unique(content))
    except (ValueError,KeyError,TypeError,OSError,RuntimeError) as error:errors=[str(error)]
    for error in errors:print(error,file=sys.stderr)
    if errors:return 1
    if command=='validate':
        print(f'Content validation: 0 error(s) — {content}');return 0
    candidates=list((ROOT/'.tools/godot').glob('*console.exe'))
    godot=os.environ.get('GODOT_BIN') or (str(candidates[0]) if candidates else None)
    if not godot:raise SystemExit('Godot missing. Set GODOT_BIN to Godot 4.7.2.')
    results=ROOT/'test-results'; results.mkdir(exist_ok=True)
    (results/'.gdignore').touch()
    env=os.environ.copy()
    # Development-only data: never touch the installed game's save directory.
    userdata=ROOT/'.tools/userdata';userdata.mkdir(parents=True,exist_ok=True)
    env['APPDATA']=str(userdata)
    def run(args):
        return subprocess.run(args,cwd=ROOT,env=os.environ if args[0]==sys.executable else env).returncode
    base=[godot,'--path',str(ROOT)]
    def ensure_import():
        imported=subprocess.run(base+['--headless','--editor','--import','--quit'],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',timeout=60)
        (results/'import.log').write_text(imported.stdout+imported.stderr,encoding='utf-8')
        if imported.returncode or 'SCRIPT ERROR' in imported.stdout+imported.stderr:
            print(imported.stdout+imported.stderr);return False
        return True
    def probe_assets():
        output=results/'asset-probe.json'
        process=subprocess.run(base+['--headless','--script','res://engine/asset_probe.gd','--',str(content),str(output)],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',timeout=60)
        if process.returncode or 'SCRIPT ERROR' in process.stdout+process.stderr:
            print(process.stdout+process.stderr)
            if output.exists():print(output.read_text(encoding='utf-8'))
            return False
        return True
    if command=='test':
        route=content.parent/'tests/walkthrough.json'
        try:
            scenario=json.loads(route.read_text(encoding='utf-8'))
            if not isinstance(scenario.get('steps'),list) or not scenario['steps'] or not isinstance(scenario.get('expect'),dict) or not scenario['expect']:
                raise ValueError('Walkthrough requires nonempty steps and expect')
        except (ValueError,OSError,AttributeError) as error:
            print(f'{route}: {error}',file=sys.stderr);return 2
        if not ensure_import() or not probe_assets():return 1
        scenario['content']=str(content)
        request=results/'game-test-input.json';output=results/'game-test-result.json'
        request.write_text(json.dumps(scenario),encoding='utf-8')
        process=subprocess.run(base+['--headless','--script','res://engine/test_runner.gd','--',str(request),str(output)],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',timeout=60)
        if process.returncode or 'SCRIPT ERROR' in process.stdout+process.stderr:
            print(process.stdout+process.stderr);return 1
        report=json.loads(output.read_text(encoding='utf-8'))
        failures=[f'step {index}: {item}' for index,item in enumerate(report['responses']) if not item['ok']]
        failures += [f'expected {key}={value}, got {report["state"].get(key)}' for key,value in scenario['expect'].items() if report['state'].get(key)!=value]
        if report['active_event']:failures.append('Walkthrough ended with an active event')
        for error in failures:print(error,file=sys.stderr)
        print(f'Game walkthrough: {len(failures)} error(s); report: {output}')
        return 1 if failures else 0
    if command=='check':
        print(f'Checking content: {content}',flush=True)
        if not ensure_import() or not probe_assets():return 1
        scenario=results/'selected-content.json'
        scenario.write_text(json.dumps({'content':str(content),'steps':[]}),encoding='utf-8')
        if run(base+['--headless','--script','res://engine/test_runner.gd','--',str(scenario),str(results/'selected-content-result.json')]):return 1
        print('Selected package loaded. Running shared engine/demo regression suite (not a custom-game walkthrough).',flush=True)
        return run([sys.executable,'-m','pytest','-q','-p','no:cacheprovider',f'--basetemp={results / ("pytest-"+str(time.time_ns()))}',f'--junitxml={results / "junit.xml"}'])
    if command=='play':
        if not ensure_import() or not probe_assets():return 1
        return run(base+['--',f'--game={content}'])
    if command=='editor':return run(base+['--editor','--',f'--game={content}'])
    if command=='ui-smoke' and options.game!='demo':
        print('ui-smoke currently uses demo-specific visual fixtures; use play --game for other packages.',file=sys.stderr);return 2
    if command=='ui-smoke':return run(base+['--script','res://engine/ui_smoke.gd','--',f'--game={content}'])
    raise SystemExit('Expected check, play, editor, or ui-smoke')

if __name__=='__main__':raise SystemExit(main())
