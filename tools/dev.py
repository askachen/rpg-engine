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
            'check', 'play', 'editor', 'ui-smoke', 'list', 'validate', 'new', 'test', 'build'])
        parser.add_argument('--game', default='demo', help='games/ directory name or manifest JSON path')
        parser.add_argument('--json', action='store_true', help='Emit exactly one JSON result to stdout')
        parser.add_argument('--scenario', help='test only: scenario path relative to project root')
        parser.add_argument('--timeout', type=float, default=240, help='Per-process deadline in seconds, except interactive play/editor')
        options = parser.parse_args(argv)
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

    run(base+['--headless', '--editor', '--import', '--quit'], 'import')
    output = run_dir/'asset-probe.json'
    run(base+['--headless', '--script', 'res://engine/asset_probe.gd', '--', str(content), str(output)], 'asset_probe')
    report['artifacts']['asset_probe'] = str(output)
    probe = json.loads(output.read_text(encoding='utf-8'))
    if probe['errors']: raise Failure(1, 'asset_probe', str(probe['errors']))
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
            failures = [f'step {i}: {item}' for i, item in enumerate(result['responses']) if not item.get('ok')]
            if len(result['responses']) != len(scenario['steps']): failures.append('Incomplete response count')
            failures += [f'expected {key}={value}, got {result["state"].get(key)}'
                         for key, value in scenario['expect'].items() if result['state'].get(key) != value]
            if result['active_event']: failures.append('Walkthrough ended with an active event')
            report['data'].update(state=result['state'], steps=len(result['responses']))
            if failures:
                report['diagnostics'].extend(dict(code='assertion', message=item) for item in failures)
                raise Failure(1, 'test_failed', f'{len(failures)} walkthrough failure(s)')
            return
        report['data']['scope'] = 'selected package load plus shared engine/demo regressions'
        report['artifacts']['junit'] = str(run_dir/'junit.xml')
        run([sys.executable, '-m', 'pytest', '-q', '-p', 'no:cacheprovider',
             f'--basetemp={run_dir / "pytest"}', f'--junitxml={run_dir / "junit.xml"}'], 'pytest', python=True)
        return
    args = {'play': [], 'editor': ['--editor'], 'ui-smoke': ['--script', 'res://engine/ui_smoke.gd']}[command]
    run(base+args+['--', f'--game={content}'], command, interactive=command in ('play', 'editor'))


if __name__ == '__main__':
    raise SystemExit(main())
