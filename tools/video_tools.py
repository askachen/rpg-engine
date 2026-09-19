"""Offline Ogg/Theora validation and conversion. No shell invocation."""
from functools import lru_cache
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def ffmpeg():
    if os.environ.get('FFMPEG_BIN'): return os.environ['FFMPEG_BIN']
    local = ROOT/'.tools/video_libs'
    if local.is_dir() and str(local) not in sys.path: sys.path.insert(0,str(local))
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except (ImportError,AttributeError,RuntimeError) as exc:
        raise ValueError('Video tools require imageio-ffmpeg==0.6.0 or FFMPEG_BIN') from exc

@lru_cache(maxsize=1)
def crc_table():
    table=[]
    for n in range(256):
        value=n<<24
        for _ in range(8): value=((value<<1)^ (0x04C11DB7 if value & 0x80000000 else 0)) & 0xffffffff
        table.append(value)
    return table

def check_ogg(path):
    streams={}
    with Path(path).open('rb') as source:
        while True:
            header=source.read(27)
            if not header: break
            if len(header)!=27 or header[:5]!=b'OggS\x00': raise ValueError('Invalid or truncated Ogg page header')
            segments=source.read(header[26])
            if len(segments)!=header[26]: raise ValueError('Truncated Ogg lacing table')
            body=source.read(sum(segments))
            if len(body)!=sum(segments): raise ValueError('Truncated Ogg page body')
            checksum=int.from_bytes(header[22:26],'little')
            crc=0
            for byte in header[:22]+b'\0'*4+header[26:]+segments+body:
                crc=((crc<<8)&0xffffffff)^crc_table()[((crc>>24)^byte)&255]
            if crc!=checksum: raise ValueError('Ogg checksum mismatch')
            serial=int.from_bytes(header[14:18],'little');seq=int.from_bytes(header[18:22],'little')
            if serial not in streams:
                if not header[5]&2 or seq!=0: raise ValueError('Missing Ogg beginning-of-stream')
                codec='theora' if body.startswith(b'\x80theora') else 'vorbis' if body.startswith(b'\x01vorbis') else None
                if codec is None: raise ValueError('Only Theora video and optional Vorbis audio are supported')
                streams[serial]={'next':0,'end':False,'codec':codec}
            stream=streams[serial]
            if stream['end'] or seq!=stream['next']: raise ValueError('Discontinuous Ogg stream')
            stream['next']+=1;stream['end']=bool(header[5]&4)
    if sum(s['codec']=='theora' for s in streams.values())!=1: raise ValueError('Expected one Theora video stream')
    if sum(s['codec']=='vorbis' for s in streams.values())>1: raise ValueError('Expected at most one Vorbis audio stream')
    if not all(s['end'] for s in streams.values()): raise ValueError('Missing Ogg end-of-stream (possibly truncated)')

def inspect_video(path):
    check_ogg(path)
    try:
        result=subprocess.run([ffmpeg(),'-nostdin','-v','error','-xerror','-err_detect','explode',
            '-i',str(path),'-map','0:v:0','-map','0:a?','-f','null','-'],capture_output=True,timeout=120)
    except (OSError,subprocess.TimeoutExpired) as exc: raise ValueError(f'Video decode could not finish: {exc}') from exc
    if result.returncode or result.stderr.strip(): raise ValueError('Video decode failed: '+result.stderr.decode('utf-8','replace')[-2000:])

def convert(source,destination):
    source=Path(source);destination=Path(destination)
    if not source.is_file(): raise ValueError('Source file does not exist')
    if destination.suffix.lower()!='.ogv': raise ValueError('Destination must use .ogv')
    if destination.exists(): raise ValueError('Refusing to overwrite existing destination')
    result=subprocess.run([ffmpeg(),'-nostdin','-n','-v','error','-i',str(source),'-map','0:v:0',
        '-map','0:a:0?','-vf','scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=1','-pix_fmt','yuv420p',
        '-c:v','libtheora','-q:v','7','-c:a','libvorbis','-q:a','4',str(destination)],capture_output=True,timeout=300)
    if result.returncode: raise ValueError(result.stderr.decode('utf-8','replace')[-2000:])
    inspect_video(destination)

def main():
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command',required=True)
    check=sub.add_parser('check');check.add_argument('source')
    conversion=sub.add_parser('convert');conversion.add_argument('source');conversion.add_argument('destination')
    args=parser.parse_args()
    try:
        if args.command=='check': inspect_video(args.source)
        else: convert(args.source,args.destination)
        print(json.dumps({'ok':True}));return 0
    except (ValueError,OSError,subprocess.TimeoutExpired) as exc:
        print(json.dumps({'ok':False,'error':str(exc)}));return 1

if __name__=='__main__': raise SystemExit(main())
