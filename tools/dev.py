"""Supported automation entry point. See docs/cli.md for protocol version 1."""
from pathlib import Path
import argparse
import json
import os
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]


class Failure(Exception):
    def __init__(self, exit_code, code, message):
        self.exit_code, self.code = exit_code, code
        super().__init__(message)


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Failure(2, 'usage', message)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    report = dict(protocol_version=1, command=None, game=None, ok=False,
                  exit_code=0, diagnostics=[], artifacts={}, data={})
    started = time.monotonic()
    try:
        parser = Parser(description=__doc__)
        parser.add_argument('command', nargs='?', default='check', choices=[
            'check', 'play', 'editor', 'ui-smoke', 'list', 'validate', 'new', 'test', 'build', 'explore', 'scenarios', 'release'])
        parser.add_argument('--game', default='demo', help='games/ directory name or manifest JSON path')
        parser.add_argument('--json', action='store_true', help='Emit exactly one JSON result to stdout')
        parser.add_argument('--scenario', help='test only: scenario path relative to project root')
        parser.add_argument('--timeout', type=float, default=240, help='Per-process deadline in seconds, except interactive play/editor')
        parser.add_argument('--suite', choices=['fast','static','rules','ui','media','full'], default='full', help='check test layer')
        parser.add_argument('--dev', action='store_true', help='play only: enable marked developer commands')
        parser.add_argument('--max-states', type=int, default=1000)
        parser.add_argument('--max-depth', type=int, default=30)
        parser.add_argument('--search-seconds', type=float, default=10)
        parser.add_argument('--goal', default='', help='explore: ending ID; default any ending')
        parser.add_argument('--version', help='release only: MAJOR.MINOR.PATCH[-suffix]')
        options = parser.parse_args(argv)
        if (options.command == 'release') != bool(options.version): raise Failure(2,'usage','--version is required for release and only supported there')
        if options.dev and options.command != 'play': raise Failure(2,'usage','--dev is only supported by play')
        if options.suite != 'full' and options.command != 'check': raise Failure(2,'usage','--suite is only supported by check')
        if not 1 <= options.max_states <= 100000 or not 1 <= options.max_depth <= 1000 or not 0 < options.search_seconds <= 300:
            raise Failure(2,'usage','Invalid exploration limits')
        report.update(command=options.command, game=options.game)
        if not 0 < options.timeout <= 3600:
            raise Failure(2, 'usage', '--timeout must be greater than zero and at most 3600')
        if options.scenario and options.command != 'test':
            raise Failure(2, 'usage', '--scenario is only supported by test')
        execute(options, report)
        report['ok'] = True
    except Failure as error:
        report['exit_code'] = error.exit_code
        report['diagnostics'].append(dict(code=error.code, message=str(error)))
    except subprocess.TimeoutExpired as error:
        report['exit_code'] = 3
        report['diagnostics'].append(dict(code='timeout', message=f'Process exceeded {error.timeout} seconds'))
    except (OSError, RuntimeError, ImportError) as error:
        report['exit_code'] = 3
        report['diagnostics'].append(dict(code='environment', message=str(error)))
    except (ValueError, KeyError, TypeError) as error:
        report['exit_code'] = 1
        report['diagnostics'].append(dict(code='invalid_data', message=str(error)))
    report['duration_seconds'] = round(time.monotonic() - started, 3)
    if '--json' in argv:
        print(json.dumps(report, ensure_ascii=True))
    else:
        print(f'{report["command"] or "CLI"}: {"OK" if report["ok"] else "FAILED"} (exit {report["exit_code"]})')
        for item in report['diagnostics']: print(f'[{item["code"]}] {item["message"]}', file=sys.stderr)
        for key, value in report['artifacts'].items(): print(f'{key}: {value}')
        if report['data']: print(json.dumps(report['data'], ensure_ascii=True, indent=2))
    return report['exit_code']


def execute(options, report):
    command = options.command
    if command == 'list':
        report['data']['games'] = [p.parent.name for p in sorted((ROOT/'games').glob('*/game.json'))]
        return
    if command == 'new':
        from new_game import create_game
        try: manifest = create_game(options.game)
        except ValueError as error: raise Failure(2, 'destination', str(error)) from error
        report['artifacts']['manifest'] = str(manifest)
        return
    candidate = Path(options.game)
    content = ((ROOT/'games'/candidate/'game.json') if candidate.suffix.lower() != '.json'
               else (candidate if candidate.is_absolute() else ROOT/candidate)).resolve()
    report['data']['manifest'] = str(content)
    if not content.is_file(): raise Failure(2, 'not_found', f'Content not found: {content}')
    from validate import load_unique, validate
    data = load_unique(content)
    errors = validate(data)
    if errors:
        report['diagnostics'].extend(dict(code='content', message=error) for error in errors)
        raise Failure(1, 'validation_failed', f'{len(errors)} content error(s)')
    if command == 'validate': return
    if command == 'ui-smoke' and content != (ROOT/'games/demo/game.json').resolve():
        raise Failure(2, 'unsupported', 'ui-smoke supports only the demo visual fixtures')
    scenario = None
    if command == 'test':
        from scenario import load_scenario
        route = Path(options.scenario) if options.scenario else content.parent/'tests/walkthrough.json'
        if not route.is_absolute(): route = ROOT/route
        if not route.is_file(): raise Failure(2, 'not_found', f'Walkthrough not found: {route}')
        scenario = load_scenario(route, data)
        report['data']['scenario'] = str(route)
    candidates = sorted((ROOT/'.tools/godot').glob('*console.exe'))
    godot = os.environ.get('GODOT_BIN') or (str(candidates[0]) if candidates else None)
    if not godot: raise Failure(3, 'dependency', 'Set GODOT_BIN to a Godot 4.7.2 executable')
    results = ROOT/'test-results'
    results.mkdir(exist_ok=True)
    (results/'.gdignore').touch()
    run_dir = results/('run-' + uuid.uuid4().hex)
    run_dir.mkdir()
    report['artifacts']['run_directory'] = str(run_dir)
    env = os.environ.copy()
    userdata = ROOT/'.tools/userdata' if command in ('play', 'editor') else run_dir/'userdata'
    userdata.mkdir(parents=True, exist_ok=True)
    env['APPDATA'] = str(userdata)
    base = [godot, '--path', str(ROOT)]

    def run(args, name, interactive=False, python=False):
        log = run_dir/(name + '.log')
        report['artifacts'][name + '_log'] = str(log)
        with log.open('w', encoding='utf-8') as stream:
            process = subprocess.run(args, cwd=ROOT, env=os.environ if python else env,
                                     stdout=stream, stderr=subprocess.STDOUT,
                                     timeout=None if interactive else options.timeout)
        text = log.read_text(encoding='utf-8', errors='replace')
        if process.returncode or 'SCRIPT ERROR' in text:
            raise Failure(1, 'process_failed', f'{name} failed (exit {process.returncode}); see {log}')

    if command == 'release':
        from release_game import verify_toolchain
        template = ROOT/'.tools/export-templates/windows_release_x86_64.exe'
        verify_toolchain(godot, template)
    run(base+['--headless', '--editor', '--import', '--quit'], 'import')
    output = run_dir/'asset-probe.json'
    run(base+['--headless', '--script', 'res://engine/asset_probe.gd', '--', str(content), str(output)], 'asset_probe')
    report['artifacts']['asset_probe'] = str(output)
    probe = json.loads(output.read_text(encoding='utf-8'))
    if probe['errors']: raise Failure(1, 'asset_probe', str(probe['errors']))
    if command == 'release':
        from release_game import export_windows
        bundle, exe, manifest = export_windows(data, options.version, godot, template, run_dir, run)
        report['artifacts'].update(windows_bundle=str(bundle), executable=str(exe), release_manifest=str(exe.parent/'release-manifest.json'))
        report['data'].update(build_kind=manifest['kind'], version=options.version, signed=False)
        return
    if command == 'explore':
        if not data.get('endings') or (options.goal and options.goal not in data['endings']): raise Failure(2,'goal','Choose a declared ending')
        request, output = run_dir/'explore-request.json', run_dir/'exploration.json'
        request.write_text(json.dumps({'content':str(content),'limits':{'max_states':options.max_states,'max_depth':options.max_depth,'seconds':options.search_seconds,'goal':options.goal}}),encoding='utf-8')
        run(base+['--headless','--script','res://engine/explore_runner.gd','--',str(request),str(output)],'explore')
        exploration=json.loads(output.read_text(encoding='utf-8'))
        report['artifacts']['exploration']=str(output)
        report['data'].update({key:value for key,value in exploration.items() if key not in ('steps','state')})
        report['data']['resource_preflight']={'declared_assets':len(data['assets']),'validated':True}
        steps=list(exploration['steps'])
        if exploration['active_event']: steps.append({'op':'cancel_event'})
        if not steps: steps=[{'op':'snapshot','id':'initial'}]
        replay=run_dir/'replay.json'
        replay.write_text(json.dumps({'steps':steps,'expect':exploration['state']},indent=2),encoding='utf-8')
        report['artifacts']['replay']=str(replay)
        report['data']['replay_cancels_active_event']=bool(exploration['active_event'])
        if exploration['status'] != 'witness_found': raise Failure(1,'reachability_'+exploration['status'],exploration['reason']+'; this is not a proof that every route is completable')
        return
    if command == 'scenarios':
        from scenario import load_scenario, assertions
        routes=sorted((content.parent/'tests/scenarios').glob('*.json'))
        if not routes: raise Failure(2,'not_found','No tests/scenarios/*.json in selected package')
        report['data']['scenarios']=[]
        failed=False
        for i,route in enumerate(routes):
            scenario=load_scenario(route,data)
            request,output=run_dir/f'case-{i}.json',run_dir/f'case-{i}-result.json'
            request.write_text(json.dumps(dict(scenario,content=str(content))),encoding='utf-8')
            run(base+['--headless','--script','res://engine/test_runner.gd','--',str(request),str(output)],f'case-{i}')
            result=json.loads(output.read_text(encoding='utf-8'))
            errors=assertions(scenario,result)
            report['data']['scenarios'].append({'scenario':str(route),'ok':not errors,'errors':errors,'result':str(output)})
            if errors:
                failed=True
                replay=run_dir/f'case-{i}-replay.json'
                replay.write_text(json.dumps(scenario,indent=2),encoding='utf-8')
                report['artifacts'][f'replay_{i}']=str(replay)
        if failed: raise Failure(1,'scenario_failed','Scenario failures; inspect result history/diff and replay artifacts')
        return
    if command == 'build':
        from build_game import build_source
        report['artifacts']['source_bundle'] = str(build_source(data))
        report['data']['build_kind'] = 'godot-source-project'
        return
    if command in ('test', 'check'):
        request, output = run_dir/'scenario.json', run_dir/'result.json'
        request.write_text(json.dumps(dict(scenario or {'steps': []}, content=str(content))), encoding='utf-8')
        run(base+['--headless', '--script', 'res://engine/test_runner.gd', '--', str(request), str(output)], 'walkthrough')
        report['artifacts']['walkthrough'] = str(output)
        result = json.loads(output.read_text(encoding='utf-8'))
        if command == 'test':
            from scenario import assertions
            failures = assertions(scenario,result)
            report['data'].update(state=result['state'], steps=len(result['responses']))
            if failures:
                replay = run_dir/'replay.json'
                replay.write_text(json.dumps(scenario,indent=2),encoding='utf-8')
                report['artifacts']['replay'] = str(replay)
                report['diagnostics'].extend(dict(code='assertion', message=item) for item in failures)
                raise Failure(1, 'test_failed', f'{len(failures)} walkthrough failure(s)')
            return
        report['data']['scope'] = 'selected package load plus '+options.suite+' engine regressions'
        report['data']['suite'] = options.suite
        report['artifacts']['junit'] = str(run_dir/'junit.xml')
        run([sys.executable, '-m', 'pytest', '-q', '-p', 'no:cacheprovider',
             f'--basetemp={run_dir / "pytest"}', f'--junitxml={run_dir / "junit.xml"}'] + ([] if options.suite == 'full' else ['-m',options.suite]), 'pytest', python=True)
        return
    args = {'play': [], 'editor': ['--editor'], 'ui-smoke': ['--script', 'res://engine/ui_smoke.gd']}[command]
    run(base+args+['--', f'--game={content}'] + (['--dev'] if options.dev else []), command, interactive=command in ('play', 'editor'))


if __name__ == '__main__':
    raise SystemExit(main())
