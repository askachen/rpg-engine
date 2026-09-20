"""Install SHA256-locked official Windows editor/template into .tools (Python stdlib only)."""
import argparse
import json
import shutil
import urllib.request
import zipfile
from pathlib import Path
from release_game import ROOT, LOCK, sha256, verify_toolchain


def install(key, destination, member, binary_key, local=None):
    lock = json.loads(LOCK.read_text(encoding='utf-8'))
    expected = lock[key]
    destination.parent.mkdir(parents=True, exist_ok=True)
    downloads = ROOT / '.tools/downloads'
    downloads.mkdir(parents=True, exist_ok=True)
    archive = Path(local) if local else downloads / (key + '.zip')
    if not archive.is_file() or sha256(archive) != expected['sha256']:
        if local: raise ValueError(f'Archive SHA256 mismatch: {archive}')
        temporary = archive.with_suffix('.partial')
        print('Downloading ' + expected['url'], flush=True)
        with urllib.request.urlopen(expected['url'], timeout=60) as response, temporary.open('wb') as stream:
            shutil.copyfileobj(response, stream)
        if sha256(temporary) != expected['sha256']:
            raise ValueError('Downloaded archive SHA256 mismatch')
        temporary.replace(archive)
    with zipfile.ZipFile(archive) as archive_file:
        data = archive_file.read(member)
    temporary = destination.with_suffix('.tmp')
    temporary.write_bytes(data)
    if sha256(temporary) != lock[binary_key]['sha256']:
        raise ValueError('Extracted executable SHA256 mismatch')
    temporary.replace(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--templates-archive', help='Optional already-downloaded official TPZ')
    args = parser.parse_args()
    lock = json.loads(LOCK.read_text(encoding='utf-8'))
    editor = ROOT / '.tools/godot' / lock['editor']['filename']
    runtime = editor.parent / lock['editor_runtime']['filename']
    template = ROOT / '.tools/export-templates' / lock['windows_release']['filename']
    if not editor.is_file() or sha256(editor) != lock['editor']['sha256']:
        install('editor_archive', editor, lock['editor']['filename'], 'editor')
    if not runtime.is_file() or sha256(runtime) != lock['editor_runtime']['sha256']:
        install('editor_archive', runtime, lock['editor_runtime']['filename'], 'editor_runtime')
    if not template.is_file() or sha256(template) != lock['windows_release']['sha256']:
        install('templates_archive', template, 'templates/' + template.name, 'windows_release', args.templates_archive)
    verify_toolchain(editor, template)
    print('Windows toolchain verified: ' + lock['version'])


if __name__ == '__main__':
    main()
