import os
from pathlib import Path
import subprocess
import sys
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.content_loader import load_content
from tools.validate import validate


@pytest.mark.parametrize('defect', ['day','map','target','zone','zone_duplicate','zone_bounds','opening','opening_condition','event','effects','repeatable'])
def test_entry_validation(defect):
    data = load_content(ROOT/'games/numeric_lab/game.json')
    event = data['events']['work']
    obj = next(o for o in data['maps']['room']['objects'] if o['id']=='work_desk')
    if defect == 'day': event['conditions'][0]['value'] = 0
    if defect == 'map': event['conditions'][1]['id'] = 'absent'
    if defect == 'target': event['conditions'][2]['id'] = 'absent'
    if defect == 'zone': event['conditions'][3]['id'] = 'absent'
    if defect == 'zone_duplicate': data['maps']['room']['zones'][1]['id'] = 'lobby'
    if defect == 'zone_bounds': data['maps']['room']['zones'][0]['rect'][2] = 100
    if defect == 'opening': data['opening_event'] = 'absent'
    if defect == 'opening_condition': data['events']['opening']['conditions'] = [{'kind':'day','op':'gte','value':2}]
    if defect == 'event': obj['event'] = 'absent'
    if defect == 'effects': obj['effects'] = [{'kind':'money','value':3}]
    if defect == 'repeatable': obj['repeatable'] = False
    assert validate(data)


def test_entry_rules(tmp_path):
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    result = subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://tests/entry_contract.gd'],
        env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),capture_output=True,text=True,encoding='utf-8',timeout=35)
    output=result.stdout+result.stderr
    assert result.returncode == 0 and 'SCRIPT ERROR' not in output,output
    assert '"entry_failures":[]' in output,output
