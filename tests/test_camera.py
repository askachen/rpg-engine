import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.content_loader import load_content
from tools.validate import validate


def large_map_fixture(path):
    content = load_content(ROOT/'games/fog_harbor/game.json')
    content['id'] = 'camera_fixture'
    area = content['maps']['quay']
    area.update(width=60, height=32, walls=[[x,y] for y in range(32) for x in range(60)
        if x in (0,59) or y in (0,31)], furniture=[])
    area['objects'] = [obj for obj in area['objects'] if obj['id']=='to_workshop']
    area['objects'][0]['position'] = [55,27]
    assert validate(content) == []
    path.write_text(json.dumps(content), encoding='utf-8')


def test_camera_mouse_transition_and_input_lock(tmp_path):
    path = tmp_path/'large-map.json'
    large_map_fixture(path)
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    log = tmp_path/'camera.log'
    with log.open('w', encoding='utf-8') as output:
        result = subprocess.run([godot, '--headless', '--path', str(ROOT), '--script',
            'res://tests/camera_mouse.gd', '--', f'--game={path}'],
            env=dict(os.environ, APPDATA=str(tmp_path/'userdata')), stdout=output,
            stderr=subprocess.STDOUT, timeout=45)
    text = log.read_text(encoding='utf-8')
    assert result.returncode == 0, text
    assert 'SCRIPT ERROR' not in text, text
    assert '"camera_failures":[]' in text


def test_floor_rug_can_underlie_actor_spawn_and_solid_furniture():
    content = load_content(ROOT/'games/fog_harbor/game.json')
    area = content['maps']['workshop']
    area['furniture'].insert(0, dict(id='overlapping_rug', sheet='decor', sprite=0,
        position=[2,2], size=[21,11], solid=False, layer='floor'))
    assert validate(content) == []
    area['furniture'][0]['solid'] = True
    assert any('footprint' in error or 'spawn' in error for error in validate(content))
