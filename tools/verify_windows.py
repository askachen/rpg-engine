"""Black-box release smoke: extracted ZIP, mouse-only UI, persistent saves, restart.

Requires an interactive Windows desktop. Does not launch Godot editor or inject state.
The two checked-in content packages have stable UI coordinates at logical 1920x1080.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import uuid
import zipfile
from release_game import ROOT, sha256
from windows_mouse import Window


def verify_movie(path):
    """Recognize multiple decoded frames of the existing six-color Theora fixture."""
    from video_tools import ffmpeg
    result = subprocess.run([ffmpeg(), '-v', 'error', '-i', str(path), '-vf', 'fps=10,scale=96:54',
        '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], capture_output=True, timeout=60, check=True)
    distinct = set()
    frame_size = 96*54*3
    for offset in range(0,len(result.stdout),frame_size):
        frame = result.stdout[offset:offset+frame_size]
        counts = [0,0,0]
        for i in range(0,len(frame)-2,3):
            r,g,b = frame[i:i+3]
            counts[0] += r > 180 and g < 70 and b < 70
            counts[1] += g > 180 and r < 70 and b < 70
            counts[2] += b > 180 and r < 70 and g < 70
        if min(counts) > 200: distinct.add(hashlib.sha256(frame).hexdigest())
    assert len(distinct) >= 2, 'No changing Theora test frames in actual release capture'
    return len(distinct)


def read(path, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.is_file(): return json.loads(path.read_text(encoding='utf-8'))
        time.sleep(.1)
    raise AssertionError('Expected saved file: ' + str(path))


def verify(bundle):
    if ctypes.windll.shell32.IsUserAnAdmin(): raise RuntimeError('Run this acceptance as a non-elevated Windows user')
    out = ROOT / 'test-results' / ('windows-' + uuid.uuid4().hex)
    game_dir = out / '中文路徑 遊戲'
    game_dir.mkdir(parents=True)
    with zipfile.ZipFile(bundle) as archive:
        if any(Path(name).name != name for name in archive.namelist()): raise ValueError('Release must contain only flat files')
        archive.extractall(game_dir)
    manifest = read(game_dir/'release-manifest.json')
    game = manifest['game_id']
    if game not in ('numeric_lab', 'fog_harbor'): raise ValueError('Smoke fixtures support numeric_lab/fog_harbor only')
    for name, digest in manifest['sha256'].items():
        assert Path(name).name == name and sha256(game_dir/name) == digest, name
    before = {p.name: sha256(p) for p in game_dir.iterdir()}
    userdata = out/'中文存檔'
    saves = userdata/'Godot/app_userdata'/game
    exe = game_dir/(game+'.exe')
    result = {'game':game, 'bundle':str(bundle), 'manifest_sha256':sha256(game_dir/'release-manifest.json'), 'elevated':False, 'ok':False}
    try:
        for restart in (False, True):
            name = 'restart' if restart else 'new'
            with (out/(name+'.log')).open('w', encoding='utf-8') as log:
                process = subprocess.Popen([str(exe), '--write-movie', str(out/(name+'.avi')), '--fixed-fps', '10',
                    '--', '--dev', '--game=missing.json'], cwd=game_dir,
                    env=dict(os.environ, APPDATA=str(userdata)), stdout=log, stderr=log)
                try:
                    window = Window(process)
                    time.sleep(2)
                    window.click(450, 468 if restart else 402)
                    if not restart and game == 'numeric_lab':
                        time.sleep(2)
                        window.click(200,1000)
                        window.click(900,785)
                        assert 'opening' in read(saves/(game+'_auto.json'))['state']['completed']
                    if not restart and game == 'fog_harbor':
                        window.click(390,642,delay=2)  # Mailbag, ordinary walking/pickup (44px cells).
                        window.click(698,510,delay=2)  # Mara at her daytime desk.
                        for _ in range(2):
                            time.sleep(2); window.click(200,1000)
                        window.click(900,785)
                        state = read(saves/(game+'_auto.json'))['state']
                        assert 'sort_letters' in state['completed']
                        window.click(1650,138); window.click(1650,138)
                        window.click(698,510,delay=2)
                        for _ in range(2):
                            time.sleep(2); window.click(200,1000)
                        window.click(900,785)
                        profile = read(saves/(game+'_profile.json'))
                        assert 'letter_memory' in profile['unlocked']
                        window.click(1750,72); window.click(900,526)
                        window.click(1200,480)  # Unlocked movie gallery entry.
                        time.sleep(3)
                        window.click(120,1000); window.click(900,555)
                    window.click(1750,72); window.click(900,242); window.click(700 if not restart else 1200,253)
                    slot = read(saves/(game+('_slot2.json' if restart else '_slot1.json')))
                    assert slot['game_id'] == game and not slot['developer']
                    if restart:
                        assert slot['state'] == original, 'Continue did not restore the most recent saved state'
                    else:
                        original = slot['state']
                        window.click(1650,138)
                        window.click(1750,72); window.click(900,313); window.click(700,253)
                        window.click(1750,72); window.click(900,242); window.click(1200,253)
                        assert read(saves/(game+'_slot2.json'))['state'] == original, 'Load did not restore the saved day/period/state'
                        # Delete only this test's second slot so restart proves a fresh UI save.
                        (saves/(game+'_slot2.json')).unlink()
                    # Normal close confirmation flushes the movie and application log.
                    window.api.PostMessageW(window.handle, 0x10, 0, 0)
                    time.sleep(.2); window.click(900,171)
                    assert process.wait(timeout=15) == 0
                finally:
                    if process.poll() is None: process.terminate(); process.wait(timeout=10)
            text = (out/(name+'.log')).read_text(encoding='utf-8')
            assert 'SCRIPT ERROR' not in text and 'ERROR:' not in text, text
        assert before == {p.name:sha256(p) for p in game_dir.iterdir()}, 'Game wrote to installation directory'
        if game == 'fog_harbor': result['distinct_video_frames'] = verify_movie(out/'new.avi')
        result.update(ok=True, saved_state=original, checks=['Chinese install/save paths','mouse new/save/wait/load/continue','restart persistence','release ignores --dev/--game','install directory unchanged'])
    finally:
        (out/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
        print(out/'result.json',flush=True)
    return out


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle',type=Path)
    verify(parser.parse_args().bundle.resolve())
