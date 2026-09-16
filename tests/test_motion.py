import copy
import os
from pathlib import Path
import subprocess
import sys
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.content_loader import load_content
from tools.validate import validate


@pytest.mark.parametrize('defect', ['direction','empty','fps','idle','asset','index'])
def test_walk_data_rejects_invalid_frames(defect):
    data = copy.deepcopy(load_content(ROOT/'games/fog_harbor/game.json'))
    walk = data['avatars']['noah']['walk']
    if defect == 'direction': del walk['up']
    if defect == 'empty': walk['left'] = []
    if defect == 'fps': walk['fps'] = 0
    if defect == 'idle': walk['idle_frame'] = 99
    if defect == 'asset': walk['down'][0] = {'path':'res://absent.png'}
    if defect == 'index': walk['right'][0]['index'] = 999
    assert validate(data)


def test_direction_animation_and_legacy_mouse(tmp_path):
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    log = tmp_path/'motion.log'
    with log.open('w',encoding='utf-8') as stream:
        result = subprocess.run([godot,'--headless','--path',str(ROOT),'--script',
            'res://tests/motion_mouse.gd','--','--game=res://games/fog_harbor/game.json'],
            env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),stdout=stream,stderr=subprocess.STDOUT,timeout=40)
    text = log.read_text(encoding='utf-8')
    assert result.returncode == 0, text
    assert 'SCRIPT ERROR' not in text, text
    assert '"motion_failures":[]' in text
