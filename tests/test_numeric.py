import os
from pathlib import Path
import subprocess
import sys
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.content_loader import load_content
from tools.validate import validate


@pytest.mark.parametrize('defect', ['default','bounds','fraction','initial','unknown_initial','translation','effect_id','effect_fraction','effect_set','condition_id','operator','nan','infinity','bool','unknown_field'])
def test_numeric_validation(defect):
    data = load_content(ROOT/'games/numeric_lab/game.json')
    assert validate(data) == []
    spec = data['stats']['INT']
    effect = data['events']['welcome']['effects'][1]
    condition = data['events']['welcome']['conditions'][0]
    if defect == 'default': spec['default'] = 4
    if defect == 'bounds': spec.update(min=5,max=2)
    if defect == 'fraction': spec['min'] = .5
    if defect == 'initial': data['initial']['stats'] = {'INT':-1}
    if defect == 'unknown_initial': data['initial']['stats'] = {'missing':1}
    if defect == 'translation': spec['name'] = 'missing_translation'
    if defect == 'effect_id': effect['id'] = 'absent'
    if defect == 'effect_fraction': effect['value'] = .5
    if defect == 'effect_set': effect.update(op='set',value=4)
    if defect == 'condition_id': condition['id'] = 'absent'
    if defect == 'operator': condition['op'] = 'equals'
    if defect == 'nan': effect['value'] = float('nan')
    if defect == 'infinity': spec['max'] = float('inf')
    if defect == 'bool': spec['default'] = True
    if defect == 'unknown_field': spec['mystery'] = 0
    assert validate(data), defect


def test_numeric_diagnostic_points_to_fragment_and_field():
    data = load_content(ROOT/'games/numeric_lab/game.json')
    data['events']['welcome']['effects'][1]['id'] = 'absent'
    errors = validate(data)
    assert any('welcome.json' in e and '/events/welcome/effects/1' in e and 'unknown numeric ID' in e for e in errors)
    data = load_content(ROOT/'games/numeric_lab/game.json')
    data['stats']['INT']['min'] = 1
    assert any('stats.json' in e and '/stats/INT/default' in e for e in validate(data))


@pytest.mark.parametrize('script', ['numeric_contract', 'numeric_mouse'])
def test_numeric_native(tmp_path, script):
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    result = subprocess.run([godot,'--headless','--path',str(ROOT),'--script',f'res://tests/{script}.gd',
        '--','--game=res://games/numeric_lab/game.json'], env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),
        capture_output=True,text=True,encoding='utf-8',timeout=45)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'SCRIPT ERROR' not in output, output
    assert f'"{script}_failures":[]' in output, output
