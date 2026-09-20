import os
import subprocess
import sys
from pathlib import Path
import pytest
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.content_loader import load_content
from tools.validate import validate

@pytest.mark.parametrize('defect',['empty','unknown_tag','depth','window','bad_event','unlimited','capacity','restock','date','stock_effect','nested_reference'])
def test_p1_validation(defect):
    d=load_content(ROOT/'games/numeric_lab/game.json')
    c=d['events']['milestone']['conditions'][0]
    if defect=='empty': c['conditions']=[]
    if defect=='unknown_tag': c['conditions'][0]['conditions'][0]['tags']=['typo']
    if defect=='depth':
        for _ in range(10): c={'kind':'all','conditions':[c]}
        d['events']['milestone']['conditions']=[c]
    if defect=='window': c['conditions'][0]['conditions'][0]['window']['size']=0
    if defect=='bad_event': d['gallery']['milestone_replay']['event']='absent'
    if defect=='unlimited': d['shops']['kiosk']['snack']['capacity']=5
    if defect=='capacity': d['shops']['kiosk']['voucher']['capacity']=0
    if defect=='restock': del d['shops']['kiosk']['voucher']['capacity']
    if defect=='date': d['locales']['en']['date_extra']='Missing placeholder'
    if defect=='stock_effect': d['events']['work']['effects'].append({'kind':'stock','shop':'kiosk','id':'snack','op':'set','value':1})
    if defect=='nested_reference': c['conditions'][0]['conditions'].append({'kind':'completed','id':'absent'})
    assert validate(d)

def test_p1_rules(tmp_path):
    godot=os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    r=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://tests/p1_contract.gd'],env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),capture_output=True,text=True,encoding='utf-8',timeout=35)
    output=r.stdout+r.stderr
    assert r.returncode==0 and 'SCRIPT ERROR' not in output,output
    assert '\"p1_failures\":[]' in output,output
