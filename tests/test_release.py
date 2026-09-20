"""Build contracts; actual Windows GUI checks use tools/verify_windows.py."""
import json
from pathlib import Path
import sys
import subprocess
import os
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from content_loader import load_content
from release_game import prepare_project, verify_toolchain, EXCLUDED


def test_release_project_isolated_and_complete(tmp_path):
    content = load_content(ROOT/'games/numeric_lab/game.json')
    project = tmp_path/'isolated'
    prepare_project(content,'0.7.0-test',project)
    assert json.loads((project/'content/game.json').read_text(encoding='utf-8')) == content
    text = (project/'project.godot').read_text(encoding='utf-8')
    assert 'config/version="0.7.0-test"' in text
    assert 'content_path="res://content/game.json"' in text
    assert 'config/name="numeric_lab"' in text
    for resource in content['assets']: assert (project/resource[6:]).is_file()
    names = {p.name for p in (project/'engine').iterdir()}
    assert not (names & EXCLUDED)
    assert not any('_test.gd' in name for name in names)
    assert not (project/'games/demo').exists()
    with pytest.raises(FileExistsError): prepare_project(content,'0.7.0-test',project)


@pytest.mark.parametrize('version',['','latest','../escape','1.0','1.0.0"\n[bad]'])
def test_release_rejects_invalid_version(tmp_path,version):
    with pytest.raises(ValueError): prepare_project({},version,tmp_path/'project')
    assert not (tmp_path/'project').exists()


def test_release_rejects_unlocked_toolchain(tmp_path):
    fake=tmp_path/'fake.exe'; fake.write_bytes(b'wrong executable')
    with pytest.raises(RuntimeError,match='SHA256'): verify_toolchain(fake,fake)
    with pytest.raises(RuntimeError,match='Missing'): verify_toolchain(tmp_path/'missing',fake)


def test_release_layout_mouse_long_text(tmp_path):
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    result = subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://tests/release_layout.gd',
        '--','--game=res://games/numeric_lab/game.json'],env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),
        capture_output=True,text=True,encoding='utf-8',timeout=40)
    output = result.stdout+result.stderr
    assert result.returncode == 0 and 'SCRIPT ERROR' not in output,output
    assert '"release_layout_failures":[]' in output,output
