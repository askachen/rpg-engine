import os
from pathlib import Path
import subprocess
import sys
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.content_loader import load_content
from tools.validate import validate


@pytest.mark.parametrize('defect',['missing','wrong_type','wrong_format','mixed_video'])
def test_voice_reference_validation(defect):
    data = load_content(ROOT/'games/demo/game.json')
    data['events']['a1']['sequence'] = [{'id':'voice','speaker':'a','text':data['events']['a1']['text'],'voice':'res://missing.wav'}]
    line = data['events']['a1']['sequence'][0]
    if defect == 'wrong_type': line['voice'] = 123
    if defect == 'wrong_format': line['voice'] = next(path for path in data['assets'] if path.endswith('.png'))
    if defect == 'mixed_video':
        line['voice'] = next(path for path in data['assets'] if path.endswith('.wav'))
        line['video'] = {'path':'res://test.ogv','loop':False,'volume':1}
    assert validate(data)


def test_settings_mouse_playback_and_process_restart(tmp_path):
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    for extra in ([],['--verify-settings']):
        result = subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://tests/settings_flow.gd','--',*extra],
                                env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),capture_output=True,text=True,timeout=35)
        output = result.stdout+result.stderr
        assert result.returncode == 0,output
        assert 'SCRIPT ERROR' not in output,output
        assert '"settings_failures":[]' in output,output
