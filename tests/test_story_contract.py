import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.content_loader import load_content
from tools.validate import validate


def fixture():
    data = load_content(ROOT/'games/fog_harbor/game.json')
    event = data['events']['harbor_chat']
    event['effects'].append(dict(kind='money',value=2))
    event['nodes']['work']['choices'] += [
        dict(id='fail',text='failure_choice',effects=[dict(kind='money',value=-999)]),
        dict(id='locked',text='locked',conditions=[dict(kind='money',value=999)])]
    data['events']['z_chat'] = copy.deepcopy(event)
    data['events']['z_priority'] = dict(character='mara',title='harbor_chat',text='harbor_chat_intro',
        priority=99,conditions=[dict(kind='flag',id='priority_unlocked',value=True)],
        choices=[dict(id='accept',text='accept')])
    note = next(o for o in data['maps']['quay']['objects'] if o['id']=='harbor_note')
    note['effects'] = [dict(kind='flag',id='priority_unlocked',value=True)]
    for lang,strings in data['locales'].items(): strings['failure_choice'] = '測試失敗後重試' if lang=='zh_TW' else 'Test failed commit'
    return data


@pytest.mark.parametrize('defect', ['missing_node','cycle','unreachable','duplicate_choice','cancel_effect',
    'route_repeat','translation','media','condition','empty_node'])
def test_rejects_invalid_story_graph(defect):
    data = fixture()
    event = data['events']['harbor_chat']
    if defect == 'missing_node': event['choices'][0]['next'] = 'absent'
    if defect == 'cycle': event['nodes']['work']['choices'][0]['next'] = 'work'
    if defect == 'unreachable': event['nodes']['unused'] = copy.deepcopy(event['nodes']['weather'])
    if defect == 'duplicate_choice': event['nodes']['work']['choices'].append(copy.deepcopy(event['nodes']['work']['choices'][0]))
    if defect == 'cancel_effect': event['choices'][0]['cancel'] = True
    if defect == 'route_repeat': data['routes']['mara']['events'].append('harbor_chat')
    if defect == 'translation': event['nodes']['work']['sequence'][0]['text'] = 'absent'
    if defect == 'media': event['nodes']['work']['sequence'][0]['sfx'] = data['assets'][0]
    if defect == 'condition': event['nodes']['work']['choices'][0]['conditions'] = [dict(kind='item',id='absent',value=1)]
    if defect == 'empty_node': event['nodes'][''] = event['nodes'].pop('work')
    assert validate(data)


@pytest.mark.parametrize('script', ['story_contract','story_mouse'])
def test_story_contract_native(tmp_path,script):
    data = fixture()
    assert validate(data) == []
    path = tmp_path/'story.json'
    path.write_text(json.dumps(data),encoding='utf-8')
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    args = [str(path)] if script=='story_contract' else [f'--game={path}']
    log = tmp_path/'story.log'
    with log.open('w',encoding='utf-8') as output:
        result = subprocess.run([godot,'--headless','--path',str(ROOT),'--script',
            f'res://tests/{script}.gd','--',*args],env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),
            stdout=output,stderr=subprocess.STDOUT,timeout=45)
    text = log.read_text(encoding='utf-8')
    assert result.returncode == 0, text
    assert 'SCRIPT ERROR' not in text, text
    assert f'"{script}_failures":[]' in text
