"""Two actual games alternate processes in a single production-style user directory."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def test_two_games_persist_without_cross_contamination(tmp_path):
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    env = dict(os.environ, APPDATA=str(tmp_path/'shared-userdata'))
    evidence = {game: tmp_path/(game+'.json') for game in ('demo', 'fog_harbor')}

    def launch(game, phase, foreign=''):
        args = [godot, '--headless', '--path', str(ROOT), '--script',
            'res://tests/isolation_mouse.gd', '--', f'--game=res://games/{game}/game.json',
            f'--phase={phase}', f'--route=res://games/{game}/tests/walkthrough.json',
            f'--evidence={evidence[game]}', f'--foreign={foreign}']
        log = tmp_path/(game+'-'+phase+'.log')
        with log.open('w', encoding='utf-8') as output:
            process = subprocess.run(args, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=60)
        text = log.read_text(encoding='utf-8')
        assert process.returncode == 0, text
        assert 'SCRIPT ERROR' not in text, text
        assert '"isolation_failures":[]' in text

    def fingerprints(directory, prefix):
        return {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                for p in directory.glob(prefix+'*.json')}

    launch('demo', 'write')
    demo = json.loads(evidence['demo'].read_text(encoding='utf-8'))
    directory = Path(demo['user_dir'])
    original = fingerprints(directory, 'story_garden_demo')
    launch('fog_harbor', 'write')
    harbor = json.loads(evidence['fog_harbor'].read_text(encoding='utf-8'))
    assert harbor['user_dir'] == demo['user_dir']
    assert fingerprints(directory, 'story_garden_demo') == original
    assert demo['profile']['language'] == 'en' and harbor['profile']['language'] == 'zh_TW'
    assert demo['profile']['dash'] is False and harbor['profile']['dash'] is True
    assert demo['profile']['volume'] != harbor['profile']['volume']
    assert set(demo['profile']['read_lines']).isdisjoint(harbor['profile']['read_lines'])
    assert set(demo['profile']['unlocked']) == {'a', 'b'}
    assert set(harbor['profile']['unlocked']) == {'signal_memory', 'letter_memory'}
    # Only the disposable test directory is modified: simulate a misplaced save file.
    shutil.copyfile(directory/'fog_harbor_slot1.json', directory/'story_garden_demo_slot6.json')
    shutil.copyfile(directory/'story_garden_demo_slot1.json', directory/'fog_harbor_slot6.json')
    baseline = fingerprints(directory, '')
    for game, foreign in [('demo','fog_harbor'), ('fog_harbor','story_garden_demo'), ('demo','fog_harbor')]:
        launch(game, 'verify', str(directory/(foreign+'_slot1.json')))
        assert fingerprints(directory, '') == baseline
