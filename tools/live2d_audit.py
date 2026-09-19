"""Offline Live2D preparation audit; passing does not certify rendering support."""
import argparse
import configparser
import hashlib
import json
from pathlib import Path
import struct
import sys

from PIL import Image


class Invalid(ValueError):
    pass


def read_object(path):
    data = json.loads(path.read_text(encoding='utf-8-sig'))
    if not isinstance(data, dict):
        raise Invalid(f'{path.name}: expected JSON object')
    return data


def local_file(root, value):
    if not isinstance(value, str) or not value or '\\' in value or ':' in value:
        raise Invalid(f'Invalid relative file reference: {value!r}')
    relative = Path(value)
    if relative.is_absolute() or '..' in relative.parts:
        raise Invalid(f'File reference escapes model folder: {value!r}')
    path = (root / relative).resolve()
    if not path.is_relative_to(root) or not path.is_file():
        raise Invalid(f'Missing file or reference outside model folder: {value}')
    return path


def inspect_model(filename):
    """Validate declared resources, not Cubism's proprietary MOC internals."""
    path = Path(filename).resolve()
    if not path.name.endswith('.model3.json'):
        raise Invalid('Model entry must end with .model3.json')
    model = read_object(path)
    if type(model.get('Version')) is not int or model['Version'] != 3:
        raise Invalid('Model entry requires Version 3')
    refs = model.get('FileReferences')
    if not isinstance(refs, dict):
        raise Invalid('FileReferences must be an object')
    root = path.parent
    files = {path}
    moc = local_file(root, refs.get('Moc'))
    with moc.open('rb') as source:
        header = source.read(8)
    if len(header) < 8 or header[:4] != b'MOC3':
        raise Invalid('Invalid MOC3 signature; requires exported runtime model')
    files.add(moc)
    textures = refs.get('Textures')
    if not isinstance(textures, list) or not textures:
        raise Invalid('Textures must be a nonempty array')
    for value in textures:
        texture = local_file(root, value)
        with Image.open(texture) as decoded:
            if decoded.format != 'PNG':
                raise Invalid(f'{value}: expected PNG texture')
            decoded.verify()
        with Image.open(texture) as decoded:
            decoded.load()
        files.add(texture)
    for key in ('Physics', 'Pose', 'UserData', 'DisplayInfo'):
        if key in refs:
            resource = local_file(root, refs[key])
            read_object(resource)
            files.add(resource)
    expressions = refs.get('Expressions', [])
    if not isinstance(expressions, list):
        raise Invalid('Expressions must be an array')
    names = []
    for entry in expressions:
        if not isinstance(entry, dict) or not isinstance(entry.get('Name'), str) or not entry['Name']:
            raise Invalid('Expression requires a nonempty Name')
        if entry['Name'] in names:
            raise Invalid(f'Duplicate expression: {entry["Name"]}')
        resource = local_file(root, entry.get('File'))
        expression = read_object(resource)
        if expression.get('Type') != 'Live2D Expression' or not isinstance(expression.get('Parameters'), list):
            raise Invalid(f'{resource.name}: invalid expression structure')
        files.add(resource)
        names.append(entry['Name'])
    motions = refs.get('Motions', {})
    if not isinstance(motions, dict):
        raise Invalid('Motions must be an object')
    motion_names = []
    for group, entries in motions.items():
        if not group or not isinstance(entries, list):
            raise Invalid('Motion group requires a name and array')
        for index, entry in enumerate(entries):
            if not isinstance(entry, dict):
                raise Invalid('Motion entry must be an object')
            resource = local_file(root, entry.get('File'))
            motion = read_object(resource)
            if motion.get('Version') != 3 or not isinstance(motion.get('Curves'), list) or not isinstance(motion.get('Meta'), dict):
                raise Invalid(f'{resource.name}: invalid motion structure')
            files.add(resource)
            if 'Sound' in entry:
                files.add(local_file(root, entry['Sound']))
            motion_names.append({'group': group, 'index': index})
    return {
        'entry': str(path), 'moc_version_byte': header[4],
        'motions': motion_names, 'expressions': names,
        'files': [dict(path=p.relative_to(root).as_posix(), size=p.stat().st_size,
                       sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(files)],
        'limitations': ['MOC3 signature only; native Core consistency and rendering are unverified',
                        'Motion/expression structure only; parameter and curve semantics are unverified'],
    }


def pe_x64(path):
    """Read PE header without loading or executing a provided DLL."""
    with path.open('rb') as source:
        dos = source.read(64)
        if len(dos) != 64 or dos[:2] != b'MZ':
            raise Invalid(f'{path.name}: not a PE binary')
        source.seek(struct.unpack_from('<I', dos, 60)[0])
        pe = source.read(6)
    if pe[:4] != b'PE\0\0' or len(pe) != 6 or struct.unpack_from('<H', pe, 4)[0] != 0x8664:
        raise Invalid(f'{path.name}: expected Windows x86_64 binary')


def audit(model=None, addon=None, sdk=None, templates=None):
    report = dict(protocol_version=1, command='live2d-audit', ok=False,
                  runtime_verified=False, diagnostics=[], data={})

    def issue(code, message):
        report['diagnostics'].append(dict(code=code, message=message))

    if not model:
        issue('model_missing', 'Provide --model PATH.model3.json with exported textures, motions and expressions')
    else:
        try:
            report['data']['model'] = inspect_model(model)
            if not report['data']['model']['motions']:
                issue('motions_missing', 'S4-06 verification requires at least one motion')
            if not report['data']['model']['expressions']:
                issue('expressions_missing', 'S4-06 verification requires at least one expression')
        except (OSError, ValueError, TypeError) as exc:
            issue('model_invalid', str(exc))
    if not addon:
        issue('addon_missing', 'Provide --addon PATH to a built GDCubism 0.9.1 addon')
    else:
        root = Path(addon)
        descriptor = root / 'gd_cubism.gdextension'
        try:
            config = configparser.ConfigParser(interpolation=None)
            config.read_string(descriptor.read_text(encoding='utf-8'))
            if config.get('configuration', 'entry_symbol', fallback='').strip('"') != 'gd_cubism_library_init':
                raise Invalid('Unexpected GDExtension entry symbol')
            for mode in ('debug', 'release'):
                name = f'bin/libgd_cubism.windows.{mode}.x86_64.dll'
                if config.get('libraries', f'windows.{mode}.x86_64', fallback='').strip('"') != name:
                    raise Invalid(f'Descriptor must reference {name}')
                binary = root / name
                pe_x64(binary)
            report['data']['addon'] = str(root.resolve())
        except (OSError, ValueError, configparser.Error) as exc:
            issue('addon_invalid', str(exc))
    if sdk:
        root = Path(sdk)
        required = ['Core/include/Live2DCubismCore.h', 'Framework/src/CubismFramework.hpp']
        missing = [name for name in required if not (root / name).is_file()]
        if missing:
            issue('sdk_invalid', 'SDK incomplete: ' + ', '.join(missing))
        report['data']['sdk'] = str(root.resolve())
    else:
        report['data']['sdk'] = 'Not supplied; needed to build addon, not to use an already built addon'
    if not templates:
        issue('templates_missing', 'Provide --templates PATH containing Godot 4.7.2 Windows export templates')
    else:
        root = Path(templates)
        try:
            version = (root / 'version.txt').read_text(encoding='utf-8').strip()
            if version != '4.7.2.stable':
                raise Invalid(f'Expected template version 4.7.2.stable, got {version}')
            for mode in ('debug', 'release'):
                pe_x64(root / f'windows_{mode}_x86_64.exe')
            report['data']['templates'] = str(root.resolve())
        except (OSError, ValueError) as exc:
            issue('templates_invalid', str(exc))
    report['ok'] = not report['diagnostics']
    report['data']['next_gate'] = 'Native model load, transparent rendering, motion/expression, hide/reload and exported EXE verification'
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', help='Exported model3.json entry')
    parser.add_argument('--addon', help='Built GDCubism 0.9.1 addon folder')
    parser.add_argument('--sdk', help='Optional Cubism SDK for Native folder for source build audit')
    parser.add_argument('--templates', help='Unpacked Godot 4.7.2 template folder')
    args = parser.parse_args(argv)
    report = audit(**vars(args))
    print(json.dumps(report, ensure_ascii=False))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
