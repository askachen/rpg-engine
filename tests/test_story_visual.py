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


@pytest.mark.parametrize('defect', ['missing_asset','index','duplicate','rect','empty','fps','end','loop_end','mixed','two_sources'])
def test_rejects_invalid_story_visual(defect):
    data = load_content(ROOT/'games/fog_harbor/game.json')
    line = data['events']['harbor_chat']['sequence'][0]
    layer = line['visual']['layers'][0]
    if defect == 'missing_asset': line['visual']['background'] = {'path':'res://absent.png'}
    if defect == 'index': layer['animation']['frames'][0]['index'] = 999
    if defect == 'duplicate': line['visual']['layers'].append(copy.deepcopy(layer))
    if defect == 'rect': layer['rect'] = [0,0,1921,1080]
    if defect == 'empty': layer['animation']['frames'] = []
    if defect == 'fps': layer['animation']['fps'] = 0
    if defect == 'end': layer['animation']['end'] = 'unknown'
    if defect == 'loop_end': layer['animation']['end'] = 'hide'
    if defect == 'mixed': line['portrait'] = data['assets'][0]
    if defect == 'two_sources': layer['image'] = layer['animation']['frames'][0]
    assert validate(data)


def test_native_story_visual_mouse(tmp_path):
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    log = tmp_path/'visual.log'
    with log.open('w',encoding='utf-8') as output:
        result = subprocess.run([godot,'--headless','--path',str(ROOT),'--script',
            'res://tests/visual_mouse.gd','--','--game=res://games/fog_harbor/game.json'],
            env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),stdout=output,stderr=subprocess.STDOUT,timeout=45)
    text = log.read_text(encoding='utf-8')
    assert result.returncode == 0, text
    assert 'SCRIPT ERROR' not in text, text
    assert '"visual_failures":[]' in text
