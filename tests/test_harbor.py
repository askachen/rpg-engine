"""S3: authored independent content through the same public CLI and mouse UI."""
import json
import os
from pathlib import Path
import subprocess
import pytest
from test_cli import cli, ROOT


@pytest.mark.parametrize('game,scenario', [
    ('demo', None), ('fog_harbor', None),
    ('fog_harbor', 'games/fog_harbor/tests/courier_first.json'),
])
def test_independent_stories_share_cli(game, scenario):
    args = ['test', '--game', game]
    if scenario: args += ['--scenario', scenario]
    result = cli(*args)
    assert result['ok'], result
    if game == 'fog_harbor':
        state = result['data']['state']
        assert state['characters']['iris']['stage'] == 4
        assert state['characters']['mara']['stage'] == 2
        assert all(value == 0 for value in state['inventory'].values())


def test_harbor_mouse_and_ending(tmp_path):
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    result = subprocess.run([godot, '--headless', '--path', str(ROOT), '--script',
        'res://tests/harbor_mouse.gd', '--', '--game=res://games/fog_harbor/game.json'],
        capture_output=True, text=True, encoding='utf-8', timeout=60,
        env=dict(os.environ, APPDATA=str(tmp_path)))
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'SCRIPT ERROR' not in result.stdout + result.stderr
    assert '"harbor_mouse_failures":[]' in result.stdout
