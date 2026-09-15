"""Public CLI contract, failures and independent bundle execution."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import zipfile
import pytest

ROOT = Path(__file__).resolve().parents[1]


def cli(*args, env=None):
    process = subprocess.run([sys.executable, str(ROOT/'tools/dev.py'), *args, '--json'],
        cwd=ROOT, capture_output=True, text=True, encoding='utf-8', timeout=60, env=env)
    result = json.loads(process.stdout)
    assert result['protocol_version'] == 1
    assert result['exit_code'] == process.returncode
    assert result['ok'] == (process.returncode == 0)
    assert 'Traceback' not in process.stderr
    return result


@pytest.mark.parametrize('args,code', [
    (('list',), 0), (('validate', '--game', 'first_story'), 0),
    (('validate', '--game', 'missing_cli_fixture'), 2),
    (('test', '--game', 'demo'), 2), (('new', '--game', 'first_story'), 2),
    (('wat',), 2), (('validate', '--scenario', 'unused'), 2),
    (('validate', '--timeout', 'nan'), 2),
])
def test_cli_json_exit_contract(args, code):
    assert cli(*args)['exit_code'] == code


def test_cli_missing_godot():
    env = dict(os.environ, GODOT_BIN=str(ROOT/'missing-godot.exe'))
    assert cli('play', '--game', 'first_story', env=env)['exit_code'] == 3


def test_cli_invalid_scenario_and_failed_expectation(tmp_path):
    path = tmp_path/'scenario with spaces.json'
    path.write_text(json.dumps({'steps':[{'op':'inject', 'money':999}], 'expect':{'money':999}}))
    assert cli('test', '--game', 'first_story', '--scenario', str(path))['exit_code'] == 1
    path.write_text(json.dumps({'steps':[{'op':'wait'}], 'expect':{'money':999}}))
    report = cli('test', '--game', 'first_story', '--scenario', str(path))
    assert report['exit_code'] == 1
    assert any(item['code'] == 'assertion' for item in report['diagnostics'])


def test_cli_walkthrough_isolated():
    first = cli('test', '--game', 'first_story')
    second = cli('test', '--game', 'first_story')
    assert first['ok'] and second['ok']
    assert first['data']['state'] == second['data']['state']
    assert first['artifacts']['run_directory'] != second['artifacts']['run_directory']


def test_cli_timeout():
    result = cli('test', '--game', 'first_story', '--timeout', '0.001')
    assert result['exit_code'] == 3
    assert result['diagnostics'][0]['code'] == 'timeout'


def test_build_reproducible_and_runs_without_demo(tmp_path):
    first = cli('build', '--game', 'first_story')
    second = cli('build', '--game', 'first_story')
    assert first['ok'] and second['ok']
    assert first['artifacts']['source_bundle'] == second['artifacts']['source_bundle']
    bundle = Path(first['artifacts']['source_bundle'])
    project = tmp_path/'extracted project'
    with zipfile.ZipFile(bundle) as archive:
        assert not any(name.startswith(('games/demo/', '.tools/', '.godot/')) for name in archive.namelist())
        manifest = json.loads(archive.read('build-manifest.json'))
        for name, digest in manifest['sha256'].items():
            assert hashlib.sha256(archive.read(name)).hexdigest() == digest
        archive.extractall(project)
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    env = dict(os.environ, APPDATA=str(tmp_path/'userdata'))
    def run(args):
        process = subprocess.run([godot, '--headless', '--path', str(project), *args],
            capture_output=True, text=True, encoding='utf-8', timeout=45, env=env)
        assert process.returncode == 0, process.stdout+process.stderr
        assert 'SCRIPT ERROR' not in process.stdout+process.stderr
    run(['--editor', '--import', '--quit'])
    run(['--quit-after', '3'])
    route = ROOT/'games/first_story/tests/walkthrough.json'
    output = tmp_path/'result.json'
    run(['--script', 'res://engine/test_runner.gd', '--', str(route), str(output)])
    result = json.loads(output.read_text())
    assert all(item['ok'] for item in result['responses'])
    assert result['state']['completed'] == ['welcome', 'tea_time']
