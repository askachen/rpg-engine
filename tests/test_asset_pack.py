import json
from pathlib import Path
import sys
import pytest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.asset_pack import PACK, catalog, install, prop
from tools.content_loader import load_content
from tools.new_game import create_game
from tools.validate import validate


def test_catalog_regions_and_showroom():
    data = catalog()
    assert len(data['entries']) == 48
    content = load_content(ROOT/'games/asset_showroom/game.json')
    assert validate(content) == []
    displayed = [p['sheet'] for m in content['maps'].values()
                 for section in ('furniture', 'decorations') for p in m.get(section, [])]
    assert sorted(displayed) == sorted('cozy_'+key for key in data['entries'])
    for key, entry in data['entries'].items():
        with Image.open(PACK/entry['file']) as image:
            assert image.mode == 'RGBA'
            x,y,w,h = entry['region']
            assert min(x,y) >= 0 and min(w,h) > 0 and x+w <= 1 and y+h <= 1
            width,height = image.size
            alpha = image.getchannel('A').crop((round(x*width),round(y*height),round((x+w)*width),round((y+h)*height)))
            assert alpha.getextrema() == (0,255), key
            assert sum(alpha.histogram()[128:]) > alpha.width*alpha.height*.1, key
        placed = prop(key,'test',[1,1])
        assert placed['size'] == entry['size']
        assert placed['solid'] == (placed['layer'] == 'prop')


def test_install_is_independent_repeatable_and_preserves_edits(tmp_path):
    create_game('pack_test', root=tmp_path)
    install('pack_test', root=tmp_path)
    manifest = tmp_path/'games/pack_test/game.json'
    before = manifest.read_bytes()
    install('pack_test', root=tmp_path)
    assert manifest.read_bytes() == before
    content = load_content(manifest)
    assert validate(content, tmp_path) == []
    for filename in catalog()['files']:
        assert (manifest.parent/'assets/cozy_home'/filename).read_bytes() == (PACK/filename).read_bytes()
    edited = manifest.parent/'assets/cozy_home/furniture-v1.png'
    edited.write_bytes(b'user artwork')
    with pytest.raises(ValueError, match='conflicts'):
        install('pack_test', root=tmp_path)
    assert edited.read_bytes() == b'user artwork'
    assert manifest.read_bytes() == before


def test_install_rejects_visual_conflict_before_copy(tmp_path):
    create_game('conflict', root=tmp_path)
    manifest = tmp_path/'games/conflict/game.json'
    data = json.loads(manifest.read_text(encoding='utf-8'))
    data['visuals']['cozy_sofa'] = data['visuals']['interior']
    manifest.write_text(json.dumps(data),encoding='utf-8')
    with pytest.raises(ValueError, match='visual conflicts'):
        install('conflict', root=tmp_path)
    assert not (manifest.parent/'assets/cozy_home').exists()


@pytest.mark.parametrize('game_id', ['../demo', '/demo', 'bad/name'])
def test_install_rejects_non_game_paths(game_id, tmp_path):
    with pytest.raises(ValueError):
        install(game_id, root=tmp_path)
