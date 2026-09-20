import json
import os
from pathlib import Path
import subprocess
import sys
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.content_loader import load_content
from tools.schema_check import check_schema
from tools.validate import validate


@pytest.mark.parametrize('script,extra,marker', [
    ('reliability_contract', [], 'reliability_failures'),
    ('reliability_contract', ['--release'], 'reliability_failures'),
    ('reliability_mouse', ['--game=res://games/numeric_lab/game.json'], 'reliability_mouse_failures'),
])
def test_s6_runtime(tmp_path,script,extra,marker):
    godot=os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script',f'res://tests/{script}.gd','--',*extra],
        env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),capture_output=True,text=True,encoding='utf-8',timeout=40)
    assert result.returncode == 0 and 'SCRIPT ERROR' not in result.stdout+result.stderr,result.stdout+result.stderr
    assert f'"{marker}":[]' in result.stdout,result.stdout


@pytest.mark.parametrize('defect',['backwards','duplicate','destination','collision'])
def test_migration_definition_validation(defect):
    data=load_content(ROOT/'games/numeric_lab/game.json')
    data['version']=2
    migration={'from_version':1,'to_version':2,'renames':{'stats':{'old':'INT'}}}
    data['save_migrations']=[migration]
    assert validate(data)==[]
    if defect=='backwards': migration['to_version']=1
    if defect=='duplicate': data['save_migrations'].append(migration.copy())
    if defect=='destination': migration['renames']['stats']['old']='absent'
    if defect=='collision': migration['renames']['stats']['other']='INT'
    assert validate(data)


def test_save_schema_nested_types():
    data=load_content(ROOT/'games/numeric_lab/game.json')
    saved={'game_id':data['id'],'version':2,'content_version':1,'saved_at':1,'developer':False,'state':data['initial']}
    assert check_schema(saved,'save.schema.json')==[]
    saved['state']['characters']['guide']['affection']=True
    assert check_schema(saved,'save.schema.json')


@pytest.mark.parametrize('game',['numeric_lab','demo'])
def test_s6_scenarios(game):
    result=subprocess.run([sys.executable,'tools/dev.py','scenarios','--game',game,'--json'],cwd=ROOT,capture_output=True,text=True,timeout=60)
    report=json.loads(result.stdout)
    assert result.returncode==0,report
    assert len(report['data']['scenarios'])>=2
    assert all(case['ok'] for case in report['data']['scenarios'])


def test_s6_explore_reports_limits():
    result=subprocess.run([sys.executable,'tools/dev.py','explore','--game','numeric_lab','--max-states','1','--json'],cwd=ROOT,capture_output=True,text=True,timeout=40)
    report=json.loads(result.stdout)
    assert result.returncode==1 and report['data']['status']=='inconclusive',report
    assert report['data']['states']==1 and report['data']['guarantees_all_routes'] is False
    assert report['data']['resource_preflight']['validated'] is True

    replay=subprocess.run([sys.executable,'tools/dev.py','test','--game','numeric_lab','--scenario',report['artifacts']['replay'],'--json'],cwd=ROOT,capture_output=True,text=True,timeout=40)
    assert replay.returncode==0,replay.stdout+replay.stderr
