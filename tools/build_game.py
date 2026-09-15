"""Build a deterministic, selected-game Godot source project (not a Windows binary)."""
from pathlib import Path
import hashlib
import io
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def build_source(content, root=ROOT):
    files = {}
    for path in (root/'engine').rglob('*'):
        if path.name.removesuffix('.uid').endswith('_test.gd') or path.name.startswith('ui_smoke.gd'):
            continue
        if path.is_file() and path.suffix in ('.gd', '.tscn', '.uid'):
            files[path.relative_to(root).as_posix()] = path.read_bytes()
    for resource in content['assets']:
        if not resource.startswith('res://'): raise ValueError(f'Build requires res:// asset: {resource}')
        relative = resource[6:]
        if not relative or relative.startswith('/') or ':' in relative or '\\' in relative or any(part in ('', '.', '..') for part in relative.split('/')):
            raise ValueError(f'Build requires canonical project-relative asset path: {resource}')
        path = (root/relative).resolve()
        if not path.is_relative_to(root.resolve()): raise ValueError(f'Asset escapes project: {resource}')
        files[relative] = path.read_bytes()
        imported = path.with_name(path.name + '.import')
        if imported.is_file(): files[relative + '.import'] = imported.read_bytes()
        for note in (path.with_suffix('.prompt.txt'), path.parent/'README.md'):
            if note.is_file(): files[note.relative_to(root).as_posix()] = note.read_bytes()
    files['content/game.json'] = json.dumps(content, ensure_ascii=False, indent=2).encode('utf-8')
    project = (root/'project.godot').read_text(encoding='utf-8')
    project = re.sub(r'^content_path=.*$', 'content_path="res://content/game.json"', project, flags=re.MULTILINE)
    files['project.godot'] = project.encode('utf-8')
    files['BUILD-README.txt'] = b'Godot 4.7.2 source project. Import project.godot in Godot or run godot --path <extracted-directory>. Requires Godot; this is not a Windows executable. Only selected game content is packaged.\n'
    inventory = {name: hashlib.sha256(value).hexdigest() for name, value in sorted(files.items())}
    files['build-manifest.json'] = json.dumps(dict(format_version=1, game_id=content['id'],
        kind='godot-source-project', sha256=inventory), sort_keys=True, indent=2).encode('utf-8')
    output = root/'builds'
    output.mkdir(exist_ok=True)
    digest = hashlib.sha256(files['build-manifest.json']).hexdigest()[:16]
    target = output/f'{content["id"]}-{digest}-source.zip'
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, value in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, value)
    payload = buffer.getvalue()
    if target.exists():
        if target.read_bytes() != payload: raise ValueError(f'Existing build differs: {target}')
    else:
        with target.open('xb') as stream: stream.write(payload)
    return target
