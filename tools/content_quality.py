"""Asset integrity and localization checks; no mutation of source artwork."""
from collections import Counter
from functools import lru_cache
from pathlib import Path
import re
import wave
from PIL import Image

RASTER = {'.png', '.jpg', '.jpeg', '.webp'}
IMAGES = RASTER | {'.svg'}
AUDIO = {'.wav', '.ogg', '.mp3'}

@lru_cache(maxsize=256)
def inspect_file(path, stamp, size):
    path = Path(path)
    if path.suffix.lower() == '.ogv':
        if __package__: from .video_tools import inspect_video
        else: from video_tools import inspect_video
        inspect_video(path)
    if path.suffix.lower() in RASTER:
        with Image.open(path) as image:
            expected={'.png':'PNG','.jpg':'JPEG','.jpeg':'JPEG','.webp':'WEBP'}[path.suffix.lower()]
            if image.format != expected:raise ValueError(f'extension expects {expected}, decoded {image.format}')
            image.verify()
        with Image.open(path) as image:
            image.load()
            return image.size
    if path.suffix.lower() == '.wav':
        with wave.open(str(path), 'rb') as audio:
            expected = audio.getnframes() * audio.getnchannels() * audio.getsampwidth()
            if not expected or len(audio.readframes(audio.getnframes())) != expected:
                raise ValueError('empty or truncated PCM audio')
    return None

def quality_errors(data, root):
    errors = []
    dimensions = {}
    for asset in data['assets']:
        target = root / asset.removeprefix('res://')
        if not target.is_file(): continue # Main validator reports missing files.
        try:
            stat = target.stat()
            dimensions[asset] = inspect_file(str(target.resolve()), stat.st_mtime_ns, stat.st_size)
        except (OSError, ValueError, EOFError, wave.Error, Image.DecompressionBombError) as error:
            errors.append(f'{target}: asset decode failed: {error}')
    for gid, card in data.get('gallery', {}).items():
        if 'media' not in card: continue
        media = card['media']
        if Path(media['thumbnail']).suffix.lower() not in IMAGES: errors.append(f'gallery/{gid}: thumbnail must be an image')
        allowed = IMAGES if media['kind'] == 'image' else {'.ogv'}
        if Path(media['path']).suffix.lower() not in allowed: errors.append(f'gallery/{gid}: media format does not match kind')
    for name, spec in data['visuals'].items():
        if Path(spec['path']).suffix.lower() not in IMAGES:
            errors.append(f'visuals/{name}/path: expected image, got {spec["path"]}')
        size = dimensions.get(spec['path'])
        if size and (size[0] / spec['columns'] < 16 or size[1] / spec['rows'] < 16):
            errors.append(f'visuals/{name}: atlas cells must be at least 16 pixels for alpha-region sampling')
        count = spec['columns'] * spec['rows']
        for index in spec.get('opaque', []):
            if index >= count: errors.append(f'visuals/{name}/opaque: invalid region index {index}')
        for index, rect in spec.get('regions', {}).items():
            if not index.isdigit() or int(index) >= count:
                errors.append(f'visuals/{name}/regions/{index}: invalid region index')
            x, y, width, height = rect
            if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > 1 or y + height > 1:
                errors.append(f'visuals/{name}/regions/{index}: normalized region outside atlas cell')
    for eid, event in data['events'].items():
        groups = [('sequence', event.get('sequence', []))]
        groups += [(f'choices/{choice["id"]}/sequence', choice.get('sequence', [])) for choice in event['choices']]
        for node_id,node in event.get('nodes',{}).items():
            groups.append((f'nodes/{node_id}/sequence',node.get('sequence',[])))
            groups += [(f'nodes/{node_id}/choices/{choice["id"]}/sequence',choice.get('sequence',[])) for choice in node['choices']]
        for group, lines in groups:
            for line in lines:
                if 'video' in line and Path(line['video']['path']).suffix.lower()!='.ogv':
                    errors.append(f'events/{eid}/{group}/{line["id"]}: video must be .ogv; convert MP4 with tools/video_tools.py')
                for field, allowed in [('background', IMAGES), ('portrait', IMAGES), ('bgm', AUDIO), ('sfx', AUDIO), ('voice', AUDIO)]:
                    path = line.get(field)
                    if path and Path(path).suffix.lower() not in allowed:
                        errors.append(f'events/{eid}/{group}/{line["id"]}/{field}: wrong media type: {path}')
    base = data.get('default_language', 'zh_TW')
    if base not in data['locales']: return errors
    catalog = data['locales'][base]
    def signature(text):
        # %% is a literal percent; widths/precision do not change argument type.
        text = text.replace('%%', '')
        percent = re.findall(r'%[-+0 #]*\d*(?:\.\d+)?([sdifxXocv])', text)
        named = Counter(re.findall(r'(?<!\{)\{([A-Za-z_][A-Za-z_0-9]*)\}(?!\})', text))
        return percent, named
    for locale, strings in data['locales'].items():
        for key in catalog.keys() - strings.keys():
            errors.append(f'locales/{locale}/{key}: missing translation (default {base})')
        for key in strings.keys() - catalog.keys():
            errors.append(f'locales/{locale}/{key}: key absent from default language {base}')
        for key in catalog.keys() & strings.keys():
            if signature(catalog[key]) != signature(strings[key]):
                errors.append(f'locales/{locale}/{key}: format parameters differ from {base}')
    return errors
