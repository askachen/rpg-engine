"""Isolated Windows release export. Does not use the developer's import cache."""
import hashlib
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / 'tools/windows-toolchain.json'
EXCLUDED = {'asset_probe.gd', 'test_runner.gd', 'explore_runner.gd', 'reachability.gd'}


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def verify_toolchain(godot, template):
    lock = json.loads(LOCK.read_text(encoding='utf-8'))
    runtime = Path(godot).parent / lock['editor_runtime']['filename']
    for path, key in ((godot, 'editor'), (runtime, 'editor_runtime'), (template, 'windows_release')):
        if not Path(path).is_file():
            raise RuntimeError(f'Missing {key}: {path}; see docs/windows-release.md')
        if sha256(path) != lock[key]['sha256']:
            raise RuntimeError(f'{key} SHA256 does not match tools/windows-toolchain.json')
    return lock


def prepare_project(content, version, destination):
    from build_game import build_source
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9.-]+)?', version):
        raise ValueError('Release version must be MAJOR.MINOR.PATCH[-suffix]')
    destination.mkdir(parents=True, exist_ok=False)
    with zipfile.ZipFile(build_source(content)) as archive:
        for name in archive.namelist():
            if Path(name).name.removesuffix('.uid') in EXCLUDED:
                continue
            if name in ('build-manifest.json', 'BUILD-README.txt'):
                continue
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(name))
    path = destination / 'project.godot'
    project = path.read_text(encoding='utf-8')
    project = re.sub(r'^config/name=.*$', 'config/name=' + json.dumps(content['id']), project, flags=re.M)
    project = project.replace('[application]', '[application]\nconfig/version=' + json.dumps(version))
    project = project.replace('[display]', '[display]\nwindow/dpi/allow_hidpi=true')
    path.write_text(project, encoding='utf-8')


def export_windows(content, version, godot, template, run_dir, run):
    lock = verify_toolchain(godot, template)
    project = run_dir / 'release-project'
    prepare_project(content, version, project)
    inputs = {p.relative_to(project).as_posix(): sha256(p) for p in sorted(project.rglob('*')) if p.is_file()}
    # Explicit custom template avoids per-user Godot template installations.
    preset = '\n'.join([
        '[preset.0]', 'name="Windows Desktop"', 'platform="Windows Desktop"',
        'runnable=true', 'export_filter="all_resources"', 'include_filter="*.json"',
        'exclude_filter="*.prompt.txt,README.md"', 'script_export_mode=2',
        '', '[preset.0.options]', 'custom_template/release=' + json.dumps(str(Path(template).resolve()).replace('\\', '/')),
        'binary_format/architecture="x86_64"', 'binary_format/embed_pck=false',
        'application/modify_resources=false', 'debug/export_console_wrapper=0',
        'codesign/enable=false', '',
    ])
    (project / 'export_presets.cfg').write_text(preset, encoding='utf-8')
    output = run_dir / 'windows'
    output.mkdir()
    exe = output / (content['id'] + '.exe')
    run([godot, '--headless', '--path', str(project), '--editor', '--import', '--quit'], 'release_import')
    run([godot, '--headless', '--path', str(project), '--export-release', 'Windows Desktop', str(exe)], 'release_export')
    for phase in ('release_import', 'release_export'):
        log = (run_dir/(phase+'.log')).read_text(encoding='utf-8', errors='replace')
        errors = [line for line in log.splitlines() if 'ERROR:' in line and 'Failed to read the root certificate store' not in line]
        if errors: raise RuntimeError(phase + ' reported errors: ' + '; '.join(errors))
    pck = exe.with_suffix('.pck')
    if not exe.is_file() or not pck.is_file() or pck.stat().st_size == 0:
        raise RuntimeError('Godot did not produce a complete EXE/PCK pair')
    manifest = dict(format_version=1, kind='windows-x86_64-release', game_id=content['id'], version=version,
        toolchain=lock, inputs=inputs, sha256={p.name: sha256(p) for p in (exe, pck)},
        signed=False)
    (output / 'release-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2), encoding='utf-8')
    (output / 'README.txt').write_text('Keep the EXE and PCK together. Run the EXE without Godot or Python.\nSaves/preferences: %APPDATA%/Godot/app_userdata/' + content['id'] + '\nUnsigned development distribution; not a Steam submission.\n', encoding='utf-8')
    digest = sha256(output / 'release-manifest.json')[:16]
    target = ROOT / 'builds' / f'{content["id"]}-{version}-{digest}-windows.zip'
    buffer = run_dir / 'release.zip'
    with zipfile.ZipFile(buffer, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(output.iterdir()):
            info = zipfile.ZipInfo(path.name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
    if target.exists():
        if sha256(target) != sha256(buffer): raise RuntimeError('Existing release differs; refusing overwrite')
    else:
        target.write_bytes(buffer.read_bytes())
    return target, exe, manifest
