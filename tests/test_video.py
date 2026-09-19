import json
import os
from pathlib import Path
import subprocess
import sys
import pytest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.content_loader import load_content
from tools.validate import validate
from tools.video_tools import check_ogg,convert,ffmpeg,inspect_video

CLIP=ROOT/'games/fog_harbor/assets/video-check-v1.ogv'

@pytest.mark.parametrize('defect',['asset','format','volume','loop','mixed'])
def test_video_content_contract(defect):
    data=load_content(ROOT/'games/fog_harbor/game.json')
    line=data['events']['harbor_chat']['nodes']['film']['sequence'][0]
    if defect=='asset':line['video']['path']='res://missing.ogv'
    if defect=='format':line['video']['path']='res://movie.mp4'
    if defect=='volume':line['video']['volume']=2
    if defect=='loop':del line['video']['loop']
    if defect=='mixed':line['visual']={}
    assert validate(data)

@pytest.mark.parametrize('defect',['truncated','bitflip','header'])
def test_corrupted_video_is_rejected(tmp_path,defect):
    data=bytearray(CLIP.read_bytes())
    if defect=='truncated':data=data[:-50]
    if defect=='bitflip':data[len(data)//2]^=1
    if defect=='header':data[:4]=b'fake'
    path=tmp_path/'bad.ogv';path.write_bytes(data)
    with pytest.raises(ValueError):inspect_video(path)

def test_mp4_conversion_and_no_overwrite(tmp_path):
    source=tmp_path/'input.mp4';dest=tmp_path/'converted.ogv'
    subprocess.run([ffmpeg(),'-nostdin','-n','-v','error','-i',str(CLIP),'-c:v','libx264','-c:a','aac',str(source)],check=True,timeout=30)
    convert(source,dest);inspect_video(dest)
    before=dest.read_bytes()
    with pytest.raises(ValueError,match='overwrite'):convert(source,dest)
    assert dest.read_bytes()==before

def test_native_video_mouse(tmp_path):
    godot=os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    log=tmp_path/'video.log'
    with log.open('w',encoding='utf-8') as output:
        result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://tests/video_mouse.gd',
            '--','--game=res://games/fog_harbor/game.json'],env=dict(os.environ,APPDATA=str(tmp_path/'userdata')),
            stdout=output,stderr=subprocess.STDOUT,timeout=45)
    text=log.read_text(encoding='utf-8')
    assert result.returncode==0,text
    assert 'SCRIPT ERROR' not in text,text
    assert '"video_failures":[]' in text
