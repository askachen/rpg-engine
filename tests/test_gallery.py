import os
from pathlib import Path
import subprocess
import sys
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.content_loader import load_content
from tools.validate import validate


@pytest.mark.parametrize('defect',['missing','thumbnail_type','video_format','kind','required'])
def test_gallery_media_validation(defect):
    data = load_content(ROOT/'games/fog_harbor/game.json')
    media = data['gallery']['letter_memory']['media']
    if defect == 'missing': media['thumbnail'] = 'res://absent.png'
    if defect == 'thumbnail_type': media['thumbnail'] = media['path']
    if defect == 'video_format': media['path'] = media['thumbnail']
    if defect == 'kind': media['kind'] = 'live2d'
    if defect == 'required': del media['thumbnail']
    assert validate(data)


def test_gallery_mouse_and_restart(tmp_path):
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    for extra in ([],['--verify-gallery']):
        result = subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://tests/gallery_flow.gd',
                                '--','--game=res://games/fog_harbor/game.json',*extra],
                                env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),capture_output=True,text=True,timeout=35)
        output = result.stdout+result.stderr
        assert result.returncode == 0,output
        assert 'SCRIPT ERROR' not in output,output
        assert '"gallery_failures":[]' in output,output
