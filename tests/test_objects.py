import json
import os
from pathlib import Path
import subprocess
import sys
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.content_loader import load_content
from tools.validate import validate


def fixture():
    data = load_content(ROOT/'games/fog_harbor/game.json')
    objects = data['maps']['quay']['objects']
    objects.append(dict(id='visitor', kind='npc', character='iris', label='iris',
        position=[18,8], schedule=[dict(map='quay', position=[18,8],
        conditions=[dict(kind='period',value='day')])]))
    objects.append(dict(id='broken_locker',kind='inspect',label='harbor_locker',
        position=[8,10],solid=False,text='harbor_locker_text',
        required_item=dict(id='locker_key',count=1,consume=True),
        effects=[dict(kind='flag',id='bad_flag',value=True),dict(kind='money',value=-999)]))
    # A conversation that would reveal a blocker on the player's tile.
    objects.append(dict(id='arrival_blocker',kind='inspect',label='harbor_note',
        position=[17,8],text='harbor_note_text',visible_when=[dict(kind='flag',id='arrival',value=True)]))
    data['events']['arrival_event'] = dict(character='iris',title='harbor_notice',text='harbor_notice_text',
        priority=999,conditions=[],choices=[dict(id='accept',text='accept')],
        effects=[dict(kind='flag',id='arrival',value=True)])
    return data


@pytest.mark.parametrize('defect', ['map','wall','furniture','spawn','overlap','condition','item','count','text'])
def test_rejects_invalid_dynamic_objects(defect):
    data = fixture()
    npc = next(o for o in data['maps']['quay']['objects'] if o['id']=='visitor')
    obj = next(o for o in data['maps']['quay']['objects'] if o['id']=='broken_locker')
    placement = npc['schedule'][0]
    if defect == 'map': placement['map'] = 'absent'
    if defect == 'wall': placement['position'] = [0,0]
    if defect == 'furniture': placement['position'] = [2,2]
    if defect == 'spawn': placement['position'] = next(iter(data['maps']['quay']['spawns'].values()))
    if defect == 'overlap': placement['position'] = [16,9]
    if defect == 'condition': placement['conditions'] = [dict(kind='item',id='absent',value=1)]
    if defect == 'item': obj['required_item']['id'] = 'absent'
    if defect == 'count': obj['required_item']['count'] = 0
    if defect == 'text': obj['text'] = 'absent'
    assert validate(data)


@pytest.mark.parametrize('script,marker', [('world_objects','object_failures'),('objects_mouse','objects_mouse_failures')])
def test_dynamic_objects_native(tmp_path, script, marker):
    data = fixture()
    assert validate(data) == []
    path = tmp_path/'objects.json'
    path.write_text(json.dumps(data),encoding='utf-8')
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    args = [str(path)] if script == 'world_objects' else [f'--game={path}']
    log = tmp_path/'objects.log'
    with log.open('w',encoding='utf-8') as output:
        result = subprocess.run([godot,'--headless','--path',str(ROOT),'--script',
            f'res://tests/{script}.gd','--',*args],env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),
            stdout=output,stderr=subprocess.STDOUT,timeout=40)
    text = log.read_text(encoding='utf-8')
    assert result.returncode == 0, text
    assert 'SCRIPT ERROR' not in text, text
    assert f'"{marker}":[]' in text
