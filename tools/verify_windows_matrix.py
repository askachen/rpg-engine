"""Native DPI-aware release input checks. Never changes desktop DPI settings."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import subprocess
import time
import uuid
import zipfile
import re
from windows_mouse import Window
from release_game import ROOT,sha256
from verify_windows import read

SIZES=[(1280,720),(1920,1080),(2560,1440),(3840,2160),(1920,1200),(2560,1080)]


def verify(bundle):
    if ctypes.windll.shell32.IsUserAnAdmin(): raise RuntimeError('Run as a non-elevated user')
    out=ROOT/'test-results'/('windows-matrix-'+uuid.uuid4().hex)
    destination=out/'遊戲';destination.mkdir(parents=True)
    with zipfile.ZipFile(bundle) as archive:
        if any(Path(n).name!=n for n in archive.namelist()): raise ValueError('Expected flat release archive')
        archive.extractall(destination)
    manifest=read(destination/'release-manifest.json');game=manifest['game_id']
    if game not in ('numeric_lab','fog_harbor'): raise ValueError('Unsupported acceptance fixture')
    for name,digest in manifest['sha256'].items():
        assert Path(name).name == name and sha256(destination/name)==digest
    userdata=out/'userdata';saves=userdata/'Godot/app_userdata'/game
    report={'ok':False,'game':game,'cases':[],'dpi_transition_scope':'native current monitor; 100/125/150/200% physical-size model is exercised by platform_check matrix'}
    with (out/'game.log').open('w',encoding='utf-8') as log:
        process=subprocess.Popen([str(destination/(game+'.exe')),'--print-fps'],cwd=destination,env=dict(os.environ,APPDATA=str(userdata)),stdout=log,stderr=log)
        try:
            window=Window(process);time.sleep(2)
            report['native_dpi']=window.dpi()
            assert report['native_dpi']['awareness'] in (1,2),'Release must be DPI aware'
            report['native_dpi']['mode']='system-aware' if report['native_dpi']['awareness']==1 else 'per-monitor-aware'
            window.click(450,402)
            if game=='numeric_lab':
                time.sleep(3);window.click(200,1000);window.click(900,785)
                read(saves/(game+'_auto.json'))
            for width,height in SIZES:
                window.resize(width,height)
                time.sleep(1.5) # Exclude resizing/shader warmup from steady FPS samples.
                offset=len((out/'game.log').read_text(encoding='utf-8'))
                time.sleep(3)
                segment=(out/'game.log').read_text(encoding='utf-8')[offset:]
                fps=[float(value) for value in re.findall(r'FPS:\s*([0-9.]+)',segment)]
                assert len(fps)>=2,'Missing real release FPS samples'
                assert min(fps)>=30,('Release steady FPS below 30',width,height,fps)
                # Every row proves real native-pixel mouse mapping by a new saved period.
                window.click(1650,138)
                slot=saves/(game+'_slot1.json')
                existed=slot.exists()
                window.click(1750,72);window.click(900,242);window.click(700,253)
                if existed: window.click(900,215)  # Overwrite confirmation.
                state=read(slot)['state']
                expected=('evening','late','day')[len(report['cases'])%3]
                assert state['period']==expected,(state['period'],expected)
                report['cases'].append({'physical':[width,height],'dpi':window.dpi(),'period':state['period'],'steady_fps':fps,'min_fps_budget':30,'ok':True})
            window.api.PostMessageW(window.handle,0x10,0,0);time.sleep(.2);window.click(900,171)
            assert process.wait(timeout=15)==0
            text=(out/'game.log').read_text(encoding='utf-8')
            assert 'SCRIPT ERROR' not in text and 'ERROR:' not in text,text
            report['ok']=True
        finally:
            if process.poll() is None:process.terminate();process.wait(timeout=10)
            (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
            print(out/'result.json',flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('bundle',type=Path)
    verify(parser.parse_args().bundle.resolve())
