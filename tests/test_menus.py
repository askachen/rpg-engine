import os
from pathlib import Path
import subprocess
import sys
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.content_loader import load_content
from tools.validate import validate


@pytest.mark.parametrize('field',['description','credits'])
def test_menu_text_references(field):
    data = load_content(ROOT/'games/fog_harbor/game.json')
    if field == 'description': data['items']['repair_kit']['description'] = 'missing_translation'
    else: data['credits'] = ['missing_translation']
    assert validate(data)


def test_inventory_shop_and_quit_mouse(tmp_path):
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    for extra in ([],['--quit-confirm']):
        result = subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://tests/menus_flow.gd',
                                '--','--game=res://games/fog_harbor/game.json',*extra],
                                env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),capture_output=True,text=True,timeout=40)
        output = result.stdout+result.stderr
        assert result.returncode == 0,output
        assert 'SCRIPT ERROR' not in output,output
        assert ('quit_confirmation_visible=true' if extra else '"menus_failures":[]') in output,output
