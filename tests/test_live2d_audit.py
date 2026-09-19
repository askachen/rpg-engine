"""Preparation checks with synthetic files, never proof of native Live2D playback."""
import json
from pathlib import Path
import struct
import subprocess
import sys

from PIL import Image
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.live2d_audit import audit, inspect_model, Invalid


def write_json(path, value):
    path.write_text(json.dumps(value), encoding='utf-8')


@pytest.fixture
def model(tmp_path):
    (tmp_path / 'test.moc3').write_bytes(b'MOC3\x05\0\0\0synthetic, not a usable model')
    Image.new('RGBA', (4, 4), (255, 0, 0, 255)).save(tmp_path / 'texture.png')
    write_json(tmp_path / 'motion.motion3.json', {'Version': 3, 'Meta': {}, 'Curves': []})
    write_json(tmp_path / 'smile.exp3.json', {'Type': 'Live2D Expression', 'Parameters': []})
    data = {'Version': 3, 'FileReferences': {'Moc': 'test.moc3', 'Textures': ['texture.png'],
            'Motions': {'Idle': [{'File': 'motion.motion3.json'}]},
            'Expressions': [{'Name': 'smile', 'File': 'smile.exp3.json'}]}}
    path = tmp_path / 'test.model3.json'
    write_json(path, data)
    return path


def test_inventory_does_not_certify_playback(model):
    result = inspect_model(model)
    assert len(result['files']) == 5
    assert result['expressions'] == ['smile']
    assert result['motions'] == [{'group': 'Idle', 'index': 0}]
    assert all(len(entry['sha256']) == 64 for entry in result['files'])
    report = audit(model=model)
    assert not report['ok'] and not report['runtime_verified']
    assert {d['code'] for d in report['diagnostics']} == {'addon_missing', 'templates_missing'}


@pytest.mark.parametrize('defect', ['missing_texture', 'corrupt_texture', 'bad_moc', 'traversal',
                                   'absolute', 'bad_motion', 'duplicate_expression', 'bad_root'])
def test_invalid_resources(model, defect):
    data = json.loads(model.read_text())
    refs = data['FileReferences']
    if defect == 'missing_texture': refs['Textures'] = ['absent.png']
    if defect == 'corrupt_texture': (model.parent / 'texture.png').write_bytes(b'bad')
    if defect == 'bad_moc': (model.parent / 'test.moc3').write_bytes(b'not a model')
    if defect == 'traversal': refs['Moc'] = '../outside.moc3'
    if defect == 'absolute': refs['Moc'] = 'C:/outside.moc3'
    if defect == 'bad_motion': write_json(model.parent / 'motion.motion3.json', {'Version': 2})
    if defect == 'duplicate_expression': refs['Expressions'] *= 2
    if defect == 'bad_root': data = []
    write_json(model, data)
    report = audit(model=model)
    assert not report['ok'] and report['diagnostics'][0]['code'] == 'model_invalid'


def test_missing_animation_is_a_gate(model):
    data = json.loads(model.read_text())
    del data['FileReferences']['Motions']
    del data['FileReferences']['Expressions']
    write_json(model, data)
    codes = {d['code'] for d in audit(model=model)['diagnostics']}
    assert {'motions_missing', 'expressions_missing'} <= codes


def pe_fixture(path):
    data = bytearray(70)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 60, 64)
    data[64:68] = b'PE\0\0'
    struct.pack_into('<H', data, 68, 0x8664)
    path.write_bytes(data)  # Header-only fixture; never loaded as executable code.


def test_prepared_files_still_require_native_verification(model, tmp_path):
    addon = tmp_path / 'addon'; (addon / 'bin').mkdir(parents=True)
    descriptor = '[configuration]\nentry_symbol="gd_cubism_library_init"\n[libraries]\n'
    for mode in ('debug', 'release'):
        name = f'bin/libgd_cubism.windows.{mode}.x86_64.dll'
        descriptor += f'windows.{mode}.x86_64="{name}"\n'
        pe_fixture(addon / name)
    (addon / 'gd_cubism.gdextension').write_text(descriptor)
    templates = tmp_path / 'templates'; templates.mkdir()
    (templates / 'version.txt').write_text('4.7.2.stable')
    for mode in ('debug', 'release'): pe_fixture(templates / f'windows_{mode}_x86_64.exe')
    report = audit(model, addon, templates=templates)
    assert report['ok'] and not report['runtime_verified']
    (templates / 'version.txt').write_text('4.3.stable')
    assert 'templates_invalid' in {d['code'] for d in audit(model, addon, templates=templates)['diagnostics']}
    (addon / 'bin/libgd_cubism.windows.release.x86_64.dll').write_bytes(b'wrong architecture')
    assert 'addon_invalid' in {d['code'] for d in audit(model, addon)['diagnostics']}


def test_cli_missing_dependencies_fails_with_json():
    result = subprocess.run([sys.executable, str(ROOT / 'tools/live2d_audit.py')],
                            capture_output=True, text=True, timeout=10)
    report = json.loads(result.stdout)
    assert result.returncode == 1 and not report['runtime_verified']
    assert {d['code'] for d in report['diagnostics']} == {'model_missing', 'addon_missing', 'templates_missing'}
