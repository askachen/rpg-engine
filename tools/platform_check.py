"""S7 matrix/resource acceptance. GPU runs are explicit; headless is not a performance pass."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import uuid
import time
import ctypes
from ctypes import wintypes

ROOT = Path(__file__).resolve().parents[1]


def memory_bytes(pid):
    class Counters(ctypes.Structure):
        _fields_=[('cb',wintypes.DWORD),('faults',wintypes.DWORD)]+[(name,ctypes.c_size_t) for name in ('peak_working','working','peak_paged','paged','peak_nonpaged','nonpaged','pagefile','peak_pagefile','private')]
    kernel=ctypes.windll.kernel32
    kernel.OpenProcess.restype=ctypes.c_void_p
    kernel.CloseHandle.argtypes=[ctypes.c_void_p]
    api=ctypes.windll.psapi.GetProcessMemoryInfo
    api.argtypes=[ctypes.c_void_p,ctypes.POINTER(Counters),wintypes.DWORD]
    handle=kernel.OpenProcess(0x410,False,pid)
    if not handle: raise ctypes.WinError()
    try:
        data=Counters();data.cb=ctypes.sizeof(data)
        if not api(handle,ctypes.byref(data),data.cb): raise ctypes.WinError()
        return data.private
    finally: kernel.CloseHandle(handle)


def run(mode, headless=False, cycles=40, quick=False):
    out = ROOT/'test-results'/('platform-'+uuid.uuid4().hex)
    out.mkdir(parents=True)
    godot = os.environ.get('GODOT_BIN') or str(next((ROOT/'.tools/godot').glob('*console.exe')))
    request = {'mode':mode,'cycles':cycles,'quick':quick,'output':str(out/'result.json'),'directory':str(out)}
    (out/'request.json').write_text(json.dumps(request),encoding='utf-8')
    env = dict(os.environ,APPDATA=str(out/'userdata'))
    memory=[]
    for name,args in [('import',['--headless','--editor','--import','--quit']),
                      ('acceptance',(['--headless'] if headless else [])+['--script','res://tests/platform_'+mode+'.gd',
                         '--',str(out/'request.json'),'--game=res://games/numeric_lab/game.json'])]:
        with (out/(name+'.log')).open('w',encoding='utf-8') as stream:
            executable=godot
            direct=Path(godot).with_name(Path(godot).name.replace('_console.exe','.exe'))
            if name=='acceptance' and direct.is_file(): executable=str(direct)
            proc = subprocess.Popen([executable,'--path',str(ROOT),*args],cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT)
            started=time.monotonic()
            try:
                while proc.poll() is None:
                    if time.monotonic()-started > 600: raise subprocess.TimeoutExpired(proc.args,600)
                    if 'SCRIPT ERROR' in (out/(name+'.log')).read_text(encoding='utf-8',errors='replace'):
                        raise RuntimeError('Native script error: '+str(out))
                    if name=='acceptance' and mode=='stress' and os.name=='nt':
                        phase='baseline' if (out/'baseline.ready').exists() else 'warmup'
                        if (out/'finished.ready').exists(): phase='finished'
                        try: memory.append({'seconds':time.monotonic()-started,'phase':phase,'bytes':memory_bytes(proc.pid)})
                        except OSError:
                            if proc.poll() is None: raise
                    time.sleep(.1)
            finally:
                if proc.poll() is None:proc.terminate();proc.wait(timeout=10)
        log = (out/(name+'.log')).read_text(encoding='utf-8',errors='replace')
        if proc.returncode or 'SCRIPT ERROR' in log: raise RuntimeError(f'{name} failed; inspect {out}')
    report = json.loads((out/'result.json').read_text(encoding='utf-8'))
    if mode=='stress' and os.name=='nt':
        steady=[s['bytes'] for s in memory if s['phase']=='baseline']
        final=[s['bytes'] for s in memory if s['phase']=='finished']
        if not steady or not final: raise RuntimeError('Missing native memory samples: '+str(out))
        growth=(max(final)-steady[0])/1048576
        report['process_memory']={'private_growth_mb':growth,'peak_private_mb':max(s['bytes'] for s in memory)/1048576,'growth_limit_mb':128,'samples':memory}
        if growth>128:
            report['ok']=False;report['performance_verified']=False;report['failures'].append('Native private memory growth exceeded 128 MiB')
        (out/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    if not report['ok']: raise RuntimeError(f'Acceptance failed: {out}/result.json')
    return out,report


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=['matrix','stress'])
    parser.add_argument('--headless',action='store_true')
    parser.add_argument('--cycles',type=int,default=40)
    args=parser.parse_args()
    if not 10 <= args.cycles <= 500: parser.error('--cycles must be 10..500')
    path,result=run(args.mode,args.headless,args.cycles)
    print(json.dumps({'ok':result['ok'],'report':str(path/'result.json'),'performance_verified':result.get('performance_verified',False)}))
